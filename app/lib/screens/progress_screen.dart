import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:video_player/video_player.dart';

import '../api.dart';

class ProgressScreen extends StatefulWidget {
  final String jobId;
  const ProgressScreen({super.key, required this.jobId});
  @override
  State<ProgressScreen> createState() => _ProgressScreenState();
}

class _ProgressScreenState extends State<ProgressScreen> {
  Timer? _timer;
  String _state = 'QUEUED';
  int _version = 1;
  int _progress = 0;
  String? _error;
  bool _busy = false;
  VideoPlayerController? _player;
  int _loadedVersion = -1;

  static const _labels = {
    'QUEUED': 'Na fila...',
    'ANALYZING': 'Analisando o material...',
    'PLANNING': 'A IA está criando o roteiro...',
    'RENDERING': 'Montando o vídeo...',
    'PREVIEW': 'Preparando o preview...',
  };

  @override
  void initState() {
    super.initState();
    _startPolling();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _player?.dispose();
    super.dispose();
  }

  void _startPolling() {
    _timer?.cancel();
    _poll();
    _timer = Timer.periodic(const Duration(seconds: 4), (_) => _poll());
  }

  Future<void> _poll() async {
    try {
      final s = await Api.status(widget.jobId);
      if (!mounted) return;
      setState(() {
        _state = s['state'] as String? ?? _state;
        _version = (s['version'] as int?) ?? _version;
        _progress = (s['progress'] as int?) ?? _progress;
        _error = s['error'] as String?;
      });
      if (_state == 'WAITING_APPROVAL' && _loadedVersion != _version) {
        _loadedVersion = _version;
        await _loadPreview();
      }
      if (_state == 'COMPLETED' || _state == 'FAILED' || _state == 'CANCELLED') {
        _timer?.cancel();
      }
    } catch (_) {/* transitório: continua tentando */}
  }

  Future<void> _loadPreview() async {
    try {
      final dir = await getTemporaryDirectory();
      final file = await Api.download('/jobs/${widget.jobId}/preview', File('${dir.path}/preview_$_version.mp4'));
      final c = VideoPlayerController.file(file);
      await c.initialize();
      await c.setLooping(true);
      await c.play();
      if (!mounted) { c.dispose(); return; }
      setState(() { _player?.dispose(); _player = c; });
    } catch (e) {
      if (mounted) setState(() => _error = 'Falha ao carregar o preview: $e');
    }
  }

  Future<void> _otherVersion() async {
    setState(() => _busy = true);
    try {
      await Api.requestVersion(widget.jobId);
      _loadedVersion = -1;
      setState(() { _state = 'QUEUED'; _progress = 0; });
      _startPolling();
    } catch (e) {
      _snack('Erro: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _approve() async {
    setState(() => _busy = true);
    try {
      await Api.approve(widget.jobId);
      setState(() { _state = 'QUEUED'; _progress = 0; });
      _startPolling();
    } catch (e) {
      _snack('Erro: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _shareFinal() async {
    setState(() => _busy = true);
    try {
      final dir = await getTemporaryDirectory();
      final f = await Api.download('/jobs/${widget.jobId}/video', File('${dir.path}/vixya_${widget.jobId}.mp4'));
      await Share.shareXFiles([XFile(f.path)], text: 'Feito com Vixya');
    } catch (e) {
      _snack('Erro: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _snack(String m) {
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));
  }

  @override
  Widget build(BuildContext context) {
    final waiting = _state == 'WAITING_APPROVAL';
    final done = _state == 'COMPLETED';
    final failed = _state == 'FAILED' || _state == 'CANCELLED';
    final showPlayer = _player != null && _player!.value.isInitialized;
    return Scaffold(
      appBar: AppBar(title: const Text('Seu vídeo')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(children: [
          Expanded(child: Center(child: _center(showPlayer, failed))),
          const SizedBox(height: 12),
          if (waiting)
            Row(children: [
              Expanded(child: OutlinedButton.icon(
                onPressed: _busy ? null : _otherVersion, icon: const Icon(Icons.refresh), label: const Text('Outra versão'))),
              const SizedBox(width: 12),
              Expanded(child: FilledButton.icon(
                onPressed: _busy ? null : _approve, icon: const Icon(Icons.check), label: const Text('Aprovar'))),
            ]),
          if (done)
            FilledButton.icon(
              onPressed: _busy ? null : _shareFinal,
              icon: const Icon(Icons.ios_share),
              label: const Text('Salvar / Compartilhar'),
              style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(52)),
            ),
        ]),
      ),
    );
  }

  Widget _center(bool showPlayer, bool failed) {
    if (showPlayer) {
      return AspectRatio(
        aspectRatio: _player!.value.aspectRatio,
        child: GestureDetector(
          onTap: () => setState(() => _player!.value.isPlaying ? _player!.pause() : _player!.play()),
          child: VideoPlayer(_player!),
        ),
      );
    }
    if (failed) {
      return Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        const Icon(Icons.error_outline, size: 48),
        const SizedBox(height: 12),
        Text('Não deu certo.\n${_error ?? ''}', textAlign: TextAlign.center),
      ]);
    }
    final showPct = _state == 'RENDERING' && _progress > 0;
    return Column(mainAxisAlignment: MainAxisAlignment.center, children: [
      if (showPct)
        SizedBox(
          width: 96,
          height: 96,
          child: Stack(alignment: Alignment.center, children: [
            SizedBox(
              width: 96,
              height: 96,
              child: CircularProgressIndicator(value: _progress / 100, strokeWidth: 7),
            ),
            Text('$_progress%', style: Theme.of(context).textTheme.titleLarge),
          ]),
        )
      else
        const CircularProgressIndicator(),
      const SizedBox(height: 16),
      Text(_labels[_state] ?? _state, style: Theme.of(context).textTheme.titleMedium),
    ]);
  }
}
