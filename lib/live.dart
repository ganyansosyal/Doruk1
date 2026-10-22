import 'dart:async';

import 'package:flutter/material.dart';
import 'package:youtube_player_iframe/youtube_player_iframe.dart';

import 'theme.dart';

// Yayın değişirse yalnızca bu kod güncellenir (youtube.com/live/<KOD>)
const _liveId = 'I1FgwiDqpS8';

const _bg = Color(0xFF0B0F17);
const _card = Color(0xFF161B26);
const _ac = Color(0xFF12B886);
const _red = Color(0xFFE0305A);

/// Canlı yayını uygulama içinde açar (web'deki canlı yayın penceresinin karşılığı).
Future<void> showLive(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: _bg,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(22))),
    builder: (_) => const _LiveSheet(),
  );
}

class _Lv {
  final bool playing, wait;
  final double lag;
  const _Lv({this.playing = false, this.wait = true, this.lag = 0});
}

String _fmt(double t) {
  final s = t.floor().clamp(0, 999999);
  return '${s ~/ 60}:${(s % 60).toString().padLeft(2, '0')}';
}

class _LiveSheet extends StatefulWidget {
  const _LiveSheet();
  @override
  State<_LiveSheet> createState() => _LiveSheetState();
}

class _LiveSheetState extends State<_LiveSheet> {
  late final YoutubePlayerController _c = YoutubePlayerController.fromVideoId(
    videoId: _liveId,
    autoPlay: true,
    params: const YoutubePlayerParams(
      showControls: false,
      showFullscreenButton: false,
      enableKeyboard: false,
      playsInline: true,
      strictRelatedVideos: true,
      showVideoAnnotations: false,
      pointerEvents: PointerEvents.none,
    ),
  );
  final _st = ValueNotifier<_Lv>(const _Lv());
  final _muted = ValueNotifier<bool>(false);
  Timer? _t;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _t = Timer.periodic(const Duration(milliseconds: 500), (_) => _tick());
  }

  @override
  void dispose() {
    _t?.cancel();
    _c.close();
    _st.dispose();
    _muted.dispose();
    super.dispose();
  }

  Future<void> _tick() async {
    if (_busy) return;
    _busy = true;
    try {
      final ps = await _c.playerState;
      final d = await _c.duration;
      final cur = await _c.currentTime;
      if (!mounted) return;
      _st.value = _Lv(
        playing: ps == PlayerState.playing || ps == PlayerState.buffering,
        wait: ps == PlayerState.buffering || ps == PlayerState.unStarted,
        lag: d > 1 ? (d - cur).clamp(0, 1e9).toDouble() : 0,
      );
    } catch (_) {
    } finally {
      _busy = false;
    }
  }

  Future<void> _toggle() async {
    if (_st.value.playing) {
      await _c.pauseVideo();
    } else {
      await _c.playVideo();
    }
    _tick();
  }

  Future<void> _seek(double dt) async {
    try {
      final d = await _c.duration;
      final cur = await _c.currentTime;
      await _c.seekTo(seconds: (cur + dt).clamp(0, d > 1 ? d - 1 : 0).toDouble(), allowSeekAhead: true);
      _tick();
    } catch (_) {}
  }

  Future<void> _edge() async {
    try {
      final d = await _c.duration;
      await _c.seekTo(seconds: d, allowSeekAhead: true);
      await _c.playVideo();
      _tick();
    } catch (_) {}
  }

  Future<void> _mute() async {
    if (_muted.value) {
      await _c.unMute();
    } else {
      await _c.mute();
    }
    _muted.value = !_muted.value;
  }

  void _full() => _c.enterFullScreen();

  Widget _btn(Widget child, VoidCallback f, {EdgeInsets pad = const EdgeInsets.symmetric(horizontal: 18, vertical: 14)}) => GestureDetector(
        onTap: f,
        child: Container(
          padding: pad,
          decoration: BoxDecoration(color: _card, borderRadius: BorderRadius.circular(16), border: Border.all(color: const Color(0xFF2A3345))),
          child: child,
        ),
      );

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: SingleChildScrollView(
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
            child: Row(children: [
              ValueListenableBuilder<_Lv>(
                valueListenable: _st,
                builder: (_, v, __) {
                  final lagging = v.lag > 20;
                  return Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(color: lagging ? const Color(0xFFD97706) : _red, borderRadius: BorderRadius.circular(10)),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      Container(width: 8, height: 8, decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle)),
                      const SizedBox(width: 7),
                      Text(lagging ? 'GERİDE ${_fmt(v.lag)}' : 'CANLI', style: jakarta(14, FontWeight.w800, Colors.white)),
                    ]),
                  );
                },
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('Canlı yayın', style: jakarta(17, FontWeight.w800, Colors.white)),
                  Text('TJK yarış yayını', style: jakarta(12.5, FontWeight.w600, Colors.white54)),
                ]),
              ),
              GestureDetector(
                onTap: () => Navigator.pop(context),
                child: Container(
                  width: 40,
                  height: 40,
                  decoration: const BoxDecoration(color: _ac, shape: BoxShape.circle),
                  child: const Icon(Icons.close, color: Colors.white, size: 20),
                ),
              ),
            ]),
          ),
          YoutubePlayer(
            controller: _c,
            aspectRatio: 16 / 9,
            autoFullScreen: false,
            enableFullScreenOnVerticalDrag: false,
            backgroundColor: Colors.black,
            controlsBuilder: (context, fs) => _Overlay(
              st: _st,
              muted: _muted,
              fs: fs,
              onToggle: _toggle,
              onSeek: _seek,
              onMute: _mute,
              onFull: _full,
              onClose: () => _c.exitFullScreen(),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
            child: Row(children: [
              _btn(
                Row(mainAxisSize: MainAxisSize.min, children: [
                  const Icon(Icons.replay, color: Colors.white, size: 22),
                  const SizedBox(width: 8),
                  Text('30 sn', style: jakarta(15, FontWeight.w800, Colors.white)),
                ]),
                () => _seek(-30),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: ValueListenableBuilder<_Lv>(
                  valueListenable: _st,
                  builder: (_, v, __) {
                    final behind = v.lag > 5;
                    return GestureDetector(
                      onTap: _edge,
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        decoration: BoxDecoration(color: _card, borderRadius: BorderRadius.circular(16), border: Border.all(color: behind ? _red : const Color(0xFF2A3345))),
                        child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                          Container(width: 16, height: 16, decoration: BoxDecoration(color: behind ? _red : _ac, shape: BoxShape.circle, border: Border.all(color: Colors.white24, width: 3))),
                          const SizedBox(width: 10),
                          Text(behind ? 'Canlıya dön' : 'Canlıdasın', style: jakarta(16, FontWeight.w700, Colors.white)),
                        ]),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(width: 10),
              _btn(const Icon(Icons.fullscreen, color: Colors.white, size: 24), _full, pad: const EdgeInsets.all(14)),
            ]),
          ),
        ]),
      ),
    );
  }
}

/// Videonun üstündeki kontroller: dokununca görünür / gizlenir (YouTube'un kendi kontrolleri kapalı)
class _Overlay extends StatefulWidget {
  final ValueNotifier<_Lv> st;
  final ValueNotifier<bool> muted;
  final bool fs;
  final VoidCallback onToggle, onMute, onFull, onClose;
  final void Function(double) onSeek;
  const _Overlay({required this.st, required this.muted, required this.fs, required this.onToggle, required this.onSeek, required this.onMute, required this.onFull, required this.onClose});
  @override
  State<_Overlay> createState() => _OverlayState();
}

class _OverlayState extends State<_Overlay> {
  bool _show = true;
  Timer? _h;

  @override
  void initState() {
    super.initState();
    _arm();
  }

  @override
  void dispose() {
    _h?.cancel();
    super.dispose();
  }

  void _arm() {
    _h?.cancel();
    _h = Timer(const Duration(milliseconds: 3200), () {
      if (mounted && widget.st.value.playing) setState(() => _show = false);
    });
  }

  void _tap() {
    setState(() => _show = !_show);
    if (_show) _arm();
  }

  Widget _small(Widget child, VoidCallback f) => GestureDetector(
        onTap: () {
          f();
          _arm();
        },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(color: Colors.black54, borderRadius: BorderRadius.circular(10)),
          child: child,
        ),
      );

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<_Lv>(
      valueListenable: widget.st,
      builder: (_, v, __) {
        final show = _show || !v.playing;
        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: _tap,
          child: Stack(children: [
            const Positioned.fill(child: SizedBox.shrink()),
            if (v.wait) const Center(child: CircularProgressIndicator(color: _ac)),
            if (show && !v.wait)
              Center(
                child: GestureDetector(
                  onTap: () {
                    widget.onToggle();
                    _arm();
                  },
                  child: Container(
                    width: 64,
                    height: 64,
                    decoration: const BoxDecoration(color: Colors.black54, shape: BoxShape.circle),
                    child: Icon(v.playing ? Icons.pause_rounded : Icons.play_arrow_rounded, color: Colors.white, size: 40),
                  ),
                ),
              ),
            if (show && widget.fs)
              Positioned(
                left: 12,
                top: 12,
                child: _small(Text('✕ Kapat', style: jakarta(13, FontWeight.w800, Colors.white)), widget.onClose),
              ),
            if (show)
              Positioned(
                left: 10,
                right: 10,
                bottom: 8,
                child: Row(children: [
                  _small(Text('↺ 10', style: jakarta(13, FontWeight.w800, Colors.white)), () => widget.onSeek(-10)),
                  const SizedBox(width: 6),
                  _small(Text('10 ↻', style: jakarta(13, FontWeight.w800, Colors.white)), () => widget.onSeek(10)),
                  const SizedBox(width: 8),
                  Text(v.lag > 5 ? '-${_fmt(v.lag)}' : 'CANLI', style: jakarta(12.5, FontWeight.w800, v.lag > 5 ? const Color(0xFFFFB627) : Colors.white)),
                  const Spacer(),
                  ValueListenableBuilder<bool>(
                    valueListenable: widget.muted,
                    builder: (_, m, __) => _small(Icon(m ? Icons.volume_off : Icons.volume_up, color: Colors.white, size: 20), widget.onMute),
                  ),
                  const SizedBox(width: 6),
                  _small(Icon(widget.fs ? Icons.fullscreen_exit : Icons.fullscreen, color: Colors.white, size: 20), widget.fs ? widget.onClose : widget.onFull),
                ]),
              ),
          ]),
        );
      },
    );
  }
}
