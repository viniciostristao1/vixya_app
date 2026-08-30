import 'dart:async';
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:gal/gal.dart';
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
  double _display = 0.02;
  int _phaseStartMs = DateTime.now().millisecondsSinceEpoch;
  String? _error;
  bool _busy = false;
  VideoPlayerController? _player;
  int _loadedVersion = -1;

  // Cada fase tem uma FAIXA [lo, hi] e um tempo típico (tau). A barra sobe por TEMPO com uma
  // curva que desacelera perto do teto (1 - e^-t/tau) — nunca "trava" nem estoura. Em RENDERING
  // o % real do ffmpeg entra como PISO: se ele adianta, a barra sobe junto (nunca volta atrás).
  ({double lo, double hi, double tau, String label}) _band() {
    switch (_state) {
      case 'QUEUED':
        return (lo: 0.02, hi: 0.10, tau: 3, label: tr('queued'));
      case 'ANALYZING':
        return (lo: 0.10, hi: 0.24, tau: 4, label: tr('analyzing'));
      case 'PLANNING':
        return (lo: 0.24, hi: 0.60, tau: 11, label: tr('buildingScript'));
      case 'RENDERING':
        final p = _progress.clamp(0, 100) / 100.0;
        return (lo: 0.60, hi: 0.97, tau: 20, label: p < 0.9 ? tr('buildingVideo') : tr('finalTouches'));
      case 'PREVIEW':
        return (lo: 0.95, hi: 0.99, tau: 3, label: tr('finalTouches'));
      default:
        return (lo: _display, hi: _display, tau: 1, label: _state);
    }
  }

  // Teto por fase do "rastejo": mesmo se a fase demora muito (ex.: IA de 3 min), a barra segue
  // subindo devagar até aqui — nunca congela. RENDERING quase chega ao fim; as demais param cedo.
  double get _slowCap {
    switch (_state) {
      case 'QUEUED': return 0.12;
      case 'ANALYZING': return 0.30;
      case 'PLANNING': return 0.80;
      case 'RENDERING': return 0.985;
      default: return _display;
    }
  }

  double get _targetProgress {
    final b = _band();
    final elapsed = (DateTime.now().millisecondsSinceEpoch - _phaseStartMs) / 1000.0;
    // (a) curva que desacelera perto do teto da fase; (b) rampa linear lenta (+0.75%/s) que
    // ASSUME quando (a) satura -> garante movimento perpétuo até _slowCap. O maior dos dois.
    final curve = b.lo + (b.hi - b.lo) * (1 - math.exp(-elapsed / b.tau));
    final ramp = math.min(b.lo + elapsed * 0.0075, _slowCap);
    var t = math.max(curve, ramp);
    if (_state == 'RENDERING') {
      // ffmpeg = acelerador LEVE (teto +0.30): puxa quando adianta, mas o TEMPO é o motor.
      t = math.max(t, 0.60 + (_progress.clamp(0, 100) / 100.0) * 0.30);
    }
    return t.clamp(0.0, 0.985);
  }

  @override
  void initState() {
    super.initState();
    _startPolling();
    _anim = Timer.periodic(const Duration(milliseconds: 80), (_) {
      if (!mounted || _state == 'WAITING_APPROVAL' || _state == 'COMPLETED') return;
      final t = _targetProgress;
      if (_display < t) {
        final step = math.max((t - _display) * 0.15, 0.0016); // ease + mínimo garantido
        setState(() => _display = math.min(_display + step, t));
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
      final newState = s['state'] as String? ?? _state;
      if (newState != _state) _phaseStartMs = DateTime.now().millisecondsSinceEpoch; // reinicia o creep da fase
      setState(() {
        _state = newState;
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
      _phaseStartMs = DateTime.now().millisecondsSinceEpoch;
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
      setState(() { _state = 'QUEUED'; _progress = 0; _display = 0.03; _phaseStartMs = DateTime.now().millisecondsSinceEpoch; });
      _startPolling();
    } catch (e) {
      _snack('Erro: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<File> _downloadFinal() async {
    final dir = await getTemporaryDirectory();
    return Api.download('/jobs/${widget.jobId}/video', File('${dir.path}/vixya_${widget.jobId}.mp4'));
  }

  Future<void> _shareFinal() async {
    setState(() => _busy = true);
    try {
      final f = await _downloadFinal();
      await Share.shareXFiles([XFile(f.path)], text: 'Feito com Vixya');
    } catch (e) {
      _snack('Erro: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _saveToGallery() async {
    setState(() => _busy = true);
    try {
      final f = await _downloadFinal();
      if (!await Gal.hasAccess()) await Gal.requestAccess();
      await Gal.putVideo(f.path, album: 'Vixya');
      _snack(tr('savedGallery'));
    } on GalException catch (e) {
      _snack('${tr('galleryFail')}: ${e.type.message}');
    } catch (e) {
      _snack('${tr('galleryFail')}: $e');
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
            Row(children: [
              Expanded(
                child: FilledButton.icon(
                  onPressed: _busy ? null : _saveToGallery,
                  icon: const Icon(Icons.download),
                  label: Text(tr('saveGallery')),
                  style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(52)),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _busy ? null : _shareFinal,
                  icon: const Icon(Icons.ios_share),
                  label: Text(tr('share')),
                  style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(52)),
                ),
              ),
            ]),
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
    final label = _band().label;
    final pct = (_display * 100).round().clamp(1, 99);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Expanded(child: Text(label, style: Theme.of(context).textTheme.titleMedium)),
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
