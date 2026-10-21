import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:video_player/video_player.dart';

import 'predict.dart' show NoBadge;
import 'theme.dart';

class FilmRow {
  final int no;
  final String name;
  final String? gny;
  const FilmRow(this.no, this.name, this.gny);
}

const _bg = Color(0xFF0B0F17);
const _card = Color(0xFF161B26);
const _ac = Color(0xFF12B886);

/// Koşu filmini uygulama içinde açar (web'deki açılır pencerenin karşılığı).
Future<void> showRaceFilm(
  BuildContext context, {
  required String url,
  required int race,
  required String city,
  required String dateLabel,
  required List<FilmRow> rows,
  String? title,
  String? subtitle,
  String? badge,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: _bg,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(22))),
    builder: (_) => _FilmSheet(url: url, race: race, city: city, dateLabel: dateLabel, rows: rows, title: title, subtitle: subtitle, badge: badge),
  );
}

class _FilmSheet extends StatefulWidget {
  final String url, city, dateLabel;
  final int race;
  final List<FilmRow> rows;
  final String? title, subtitle, badge;
  const _FilmSheet({required this.url, required this.race, required this.city, required this.dateLabel, required this.rows, this.title, this.subtitle, this.badge});
  @override
  State<_FilmSheet> createState() => _FilmSheetState();
}

class _FilmSheetState extends State<_FilmSheet> {
  late final VideoPlayerController _v = VideoPlayerController.networkUrl(Uri.parse(widget.url));
  double _speed = 1;
  bool _err = false;

  @override
  void initState() {
    super.initState();
    _v.initialize().then((_) {
      if (!mounted) return;
      setState(() {});
      _v.play();
    }).catchError((_) {
      if (mounted) setState(() => _err = true);
    });
  }

  @override
  void dispose() {
    _v.dispose();
    super.dispose();
  }

  void _seek(int sec) {
    final p = _v.value.position + Duration(seconds: sec);
    final d = _v.value.duration;
    _v.seekTo(p < Duration.zero ? Duration.zero : (p > d ? d : p));
  }

  void _setSpeed(double s) {
    setState(() => _speed = s);
    _v.setPlaybackSpeed(s);
  }

  Future<void> _full() async {
    await Navigator.of(context).push(MaterialPageRoute(builder: (_) => _FullVideo(controller: _v)));
  }

  @override
  Widget build(BuildContext context) {
    final ratio = _v.value.isInitialized ? _v.value.aspectRatio : 16 / 9;
    return SafeArea(
      top: false,
      child: SingleChildScrollView(
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
            child: Row(children: [
              Container(
                width: 36,
                height: 36,
                alignment: Alignment.center,
                decoration: BoxDecoration(color: _ac, borderRadius: BorderRadius.circular(10)),
                child: Text(widget.badge ?? '${widget.race}', style: jakarta(17, FontWeight.w800, Colors.white)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(widget.title ?? '${widget.city} · ${widget.race}. Koşu', style: jakarta(17, FontWeight.w800, Colors.white)),
                  Text(widget.subtitle ?? 'Koşu filmi · ${widget.dateLabel}', style: jakarta(12.5, FontWeight.w600, Colors.white54)),
                ]),
              ),
              GestureDetector(
                onTap: () => Navigator.pop(context),
                child: Container(
                  width: 40,
                  height: 40,
                  decoration: const BoxDecoration(color: Color(0xFF232A38), shape: BoxShape.circle),
                  child: const Icon(Icons.close, color: Colors.white, size: 20),
                ),
              ),
            ]),
          ),
          AspectRatio(
            aspectRatio: ratio,
            child: Container(
              color: Colors.black,
              child: _err
                  ? Center(child: Text('Video yüklenemedi.', style: jakarta(14, FontWeight.w600, Colors.white70)))
                  : !_v.value.isInitialized
                      ? const Center(child: CircularProgressIndicator(color: _ac))
                      : GestureDetector(
                          onTap: () => setState(() => _v.value.isPlaying ? _v.pause() : _v.play()),
                          child: Stack(alignment: Alignment.center, children: [
                            VideoPlayer(_v),
                            if (!_v.value.isPlaying) const Icon(Icons.play_circle_fill, color: Colors.white70, size: 64),
                          ]),
                        ),
            ),
          ),
          if (_v.value.isInitialized) VideoProgressIndicator(_v, allowScrubbing: true, colors: const VideoProgressColors(playedColor: _ac)),
          if (widget.rows.isNotEmpty) ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Text('Koşu sonucu', style: jakarta(14, FontWeight.w700, Colors.white60)),
            ),
            for (var i = 0; i < widget.rows.length && i < 4; i++) _row(i, widget.rows[i]),
          ],
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
            child: Row(children: [
              _btn('↺ 10', () => _seek(-10)),
              const SizedBox(width: 8),
              _btn('10 ↻', () => _seek(10)),
              const Spacer(),
              Container(
                padding: const EdgeInsets.all(3),
                decoration: BoxDecoration(color: _card, borderRadius: BorderRadius.circular(14)),
                child: Row(children: [
                  for (final sp in const [0.5, 1.0, 2.0])
                    GestureDetector(
                      onTap: () => _setSpeed(sp),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
                        decoration: BoxDecoration(color: _speed == sp ? _ac : Colors.transparent, borderRadius: BorderRadius.circular(11)),
                        child: Text('${sp == 1.0 ? '1' : sp == 2.0 ? '2' : '0.5'}x',
                            style: jakarta(14, FontWeight.w800, _speed == sp ? Colors.white : Colors.white70)),
                      ),
                    ),
                ]),
              ),
              const SizedBox(width: 8),
              GestureDetector(
                onTap: _full,
                child: Container(
                  padding: const EdgeInsets.all(11),
                  decoration: BoxDecoration(color: _card, borderRadius: BorderRadius.circular(14)),
                  child: const Icon(Icons.fullscreen, color: Colors.white, size: 22),
                ),
              ),
            ]),
          ),
        ]),
      ),
    );
  }

  Widget _btn(String t, VoidCallback f) => GestureDetector(
        onTap: f,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
          decoration: BoxDecoration(color: _card, borderRadius: BorderRadius.circular(14)),
          child: Text(t, style: jakarta(15, FontWeight.w800, Colors.white)),
        ),
      );

  Widget _row(int i, FilmRow r) {
    const rk = [Color(0xFFF5C518), Color(0xFFC9D1DC), Color(0xFFD08B4B), Color(0xFF5B8DEF)];
    const lb = ['Kazandı', '2. oldu', '3. oldu', '4. oldu'];
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: i == 0 ? const Color(0xFF241F10) : _card,
        borderRadius: BorderRadius.circular(16),
        border: i == 0 ? Border.all(color: const Color(0xFF6B5A1E)) : null,
      ),
      child: Row(children: [
        Container(
          width: 34,
          height: 34,
          alignment: Alignment.center,
          decoration: BoxDecoration(color: rk[i], shape: BoxShape.circle),
          child: Text('${i + 1}', style: jakarta(15, FontWeight.w800, const Color(0xFF111111))),
        ),
        const SizedBox(width: 10),
        NoBadge(r.no, size: 36),
        const SizedBox(width: 10),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(r.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: jakarta(15, FontWeight.w800, Colors.white)),
            Text(lb[i], style: jakarta(12.5, FontWeight.w700, rk[i])),
          ]),
        ),
        if (r.gny != null) Text('Ganyan ${r.gny}', style: jakarta(14.5, FontWeight.w800, const Color(0xFFFFB627))),
      ]),
    );
  }
}

class _FullVideo extends StatefulWidget {
  final VideoPlayerController controller;
  const _FullVideo({required this.controller});
  @override
  State<_FullVideo> createState() => _FullVideoState();
}

class _FullVideoState extends State<_FullVideo> {
  @override
  void initState() {
    super.initState();
    SystemChrome.setPreferredOrientations([DeviceOrientation.landscapeLeft, DeviceOrientation.landscapeRight]);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  }

  @override
  void dispose() {
    SystemChrome.setPreferredOrientations(DeviceOrientation.values);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final v = widget.controller;
    return Scaffold(
      backgroundColor: Colors.black,
      body: GestureDetector(
        onTap: () => Navigator.pop(context),
        child: Center(
          child: AspectRatio(aspectRatio: v.value.isInitialized ? v.value.aspectRatio : 16 / 9, child: VideoPlayer(v)),
        ),
      ),
    );
  }
}
