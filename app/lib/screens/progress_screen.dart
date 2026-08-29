import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:video_player/video_player.dart';

import '../api.dart';
import '../i18n.dart';

class ProgressScreen extends StatefulWidget {
  final String jobId;
  const ProgressScreen({super.key, required this.jobId});
  @override
  State<ProgressScreen> createState() => _ProgressScreenState();
}

class _ProgressScreenState extends State<ProgressScreen> {
  Timer? _timer;
  Timer? _anim;
  String _state = 'QUEUED';
  int _version = 1;
  int _progress = 0;
  double _display = 0.03;
  String? _error;
  bool _busy = false;
  VideoPlayerController? _player;
  int _loadedVersion = -1;

  ({String label, double progress}) get _target {
    if (_state == 'QUEUED') return (label: tr('queued'), progress: 0.08);
    if (_state == 'ANALYZING') return (label: tr('buildingScript'), progress: 0.20);
    if (_state == 'PLANNING') return (label: tr('buildingScript'), progress: 0.35);
    if (_state == 'RENDERING') {
      final p = _progress.clamp(0, 100) / 100.0;
      final prog = 0.35 + p * 0.55;
      final label = p < 0.85 ? tr('buildingVideo') : tr('finalTouches');
      return (label: label, progress: prog.clamp(0.0, 0.95));
    }
    if (_state == 'PREVIEW') return (label: tr('finalTouches'), progress: 0.96);
    return (label: _state, progress: _display);
  }

  @override
  void initState() {
    super.initState();
    _startPolling();
    _anim = Timer.periodic(const Duration(milliseconds: 90), (_) {
      if (!mounted || _state == 'WAITING_APPROVAL' || _state == 'COMPLETED') return;
      final t = _target.progress;
      if (_display < t - 0.008) {
        final step = (t - _display) * 0.20 + 0.007;
        setState(() => _display = (_display + step).clamp(0.0, t));
      } else if (_display < t) {
        setState(() => _display = (_display + 0.005).clamp(0.0, t));
      } else if (_display < 0.88) {
        setState(() => _display = (_display + 0.002).clamp(0.0, 0.88));
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _anim?.cancel();
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
        setState(() => _display = 1.0);
        await _loadPreview();
      }
      if (_state == 'COMPLETED' || _state == 'FAILED' || _state == 'CANCELLED') {
        _timer?.cancel();
        _anim?.cancel();
        if (_state == 'COMPLETED') setState(() => _display = 1.0);
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
      await _player?.pause();
      await _player?.dispose();
      if (mounted) setState(() { _player = null; _loadedVersion = -1; _state = 'QUEUED'; _progress = 0; _display = 0.02; _error = null; });
      await Api.requestVersion(widget.jobId);
      _startPolling();
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('${tr('buildingScript')} (v${_version + 1})')));
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
      setState(() { _state = 'QUEUED'; _progress = 0; _display = 0.03; });
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
      appBar: AppBar(title: Text(tr('yourVideo'))),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(children: [
          Expanded(child: Center(child: _center(showPlayer, failed))),
          const SizedBox(height: 12),
          if (waiting)
            Row(children: [
              Expanded(child: OutlinedButton.icon(
                onPressed: _busy ? null : _otherVersion, icon: const Icon(Icons.refresh), label: Text(tr('otherVersion')))),
              const SizedBox(width: 12),
              Expanded(child: FilledButton.icon(
                onPressed: _busy ? null : _approve, icon: const Icon(Icons.check), label: Text(tr('approve')))),
            ]),
          if (done)
            FilledButton.icon(
              onPressed: _busy ? null : _shareFinal,
              icon: const Icon(Icons.ios_share),
              label: Text(tr('saveShare')),
              style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(52)),
            ),
        ]),
      ),
    );
  }

  Widget _center(bool showPlayer, bool failed) {
    if (showPlayer && _state == 'WAITING_APPROVAL') {
      return Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        AspectRatio(
          aspectRatio: _player!.value.aspectRatio,
          child: GestureDetector(
            onTap: () => setState(() => _player!.value.isPlaying ? _player!.pause() : _player!.play()),
            child: VideoPlayer(_player!),
          ),
        ),
        const SizedBox(height: 8),
        Text('v$_version • ${tr('yourVideo')}', style: const TextStyle(fontSize: 12, color: Colors.grey)),
      ]);
    }
    if (failed) {
      return Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        const Icon(Icons.error_outline, size: 48),
        const SizedBox(height: 12),
        Text('${tr('failed')}\n${_error ?? ''}', textAlign: TextAlign.center),
      ]);
    }
    final u = _target;
    final pct = (_display * 100).round().clamp(1, 99);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Expanded(child: Text(u.label, style: Theme.of(context).textTheme.titleMedium)),
          const SizedBox(width: 12),
          Text('$pct%', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
        ]),
        const SizedBox(height: 12),
        ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: LinearProgressIndicator(value: _display, minHeight: 14),
        ),
      ]),
    );
  }
}
