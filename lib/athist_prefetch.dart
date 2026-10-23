import 'dart:async';

import 'package:flutter/gestures.dart';
import 'package:flutter/widgets.dart';

import 'tjk.dart';

/// Seçili hipodromdaki atların "son yarış / son galibiyet" bilgisini arka planda, sırayla önceden çeker.
/// - Seçili koşunun atları en önde gelir.
/// - Parmak ekrana değiyorsa bekler (kaydırma kasmasın); uygulama arka plandaysa çekmez.
/// - Tek tek, aralarında kısa bekleyerek çeker (TJK'yı yormaz).
/// - Bir kez çekilen at tekrar çekilmez (bellek + telefon önbelleği).
class AtHistPrefetch {
  AtHistPrefetch._() {
    GestureBinding.instance.pointerRouter.addGlobalRoute(_onPointer);
  }
  static final AtHistPrefetch i = AtHistPrefetch._();

  final List<String> _q = [];
  final Map<String, DateTime> _fail = {};
  DateTime _touch = DateTime.fromMillisecondsSinceEpoch(0);
  bool _run = false;

  void _onPointer(PointerEvent e) {
    if (e is PointerDownEvent || e is PointerMoveEvent) _touch = DateTime.now();
  }

  /// Kuyruğu seçili hipodrom için yeniden kurar (seçili koşu önde) ve ekran boşalınca çekmeye başlar.
  void start(String city, int firstRace) {
    if (city.isEmpty) return;
    final rs = TjkStore.i.races(city).toList()
      ..sort((a, b) => a.no == firstRace ? -1 : (b.no == firstRace ? 1 : a.no.compareTo(b.no)));
    final now = DateTime.now();
    final seen = <String>{};
    final ids = <String>[];
    final galopIds = <String>[];
    for (final r in rs) {
      for (final h in r.atlar) {
        final id = h.atId;
        if (h.kosmaz || id.isEmpty) continue;
        if (!atGalopHazir(id) && !galopIds.contains(id)) galopIds.add(id);
        if (atHistHazir(id) || !seen.add(id)) continue;
        final f = _fail[id];
        if (f != null && now.difference(f) < const Duration(minutes: 10)) continue;
        ids.add(id);
      }
    }
    // Galop: tüm atlar için hemen, 6'şar atlık paketlerle (seçili koşu önde)
    for (final id in galopIds) {
      getAtGalop(id).then((_) {}, onError: (Object _) {});
    }
    _q
      ..clear()
      ..addAll(ids);
    if (_q.isEmpty) return;
    Future<void>.delayed(const Duration(milliseconds: 400), _pump);
  }

  Future<void> _pump() async {
    if (_run) return;
    _run = true;
    try {
      await Future.wait([_worker(), _worker(), _worker()]); // 3 at aynı anda
    } finally {
      _run = false;
    }
  }

  Future<void> _worker() async {
    while (_q.isNotEmpty) {
      final life = WidgetsBinding.instance.lifecycleState;
      if (life != null && life != AppLifecycleState.resumed) {
        await Future<void>.delayed(const Duration(seconds: 3));
        continue;
      }
      if (DateTime.now().difference(_touch) < const Duration(milliseconds: 600)) {
        await Future<void>.delayed(const Duration(milliseconds: 600));
        continue;
      }
      if (_q.isEmpty) break;
      final id = _q.removeAt(0);
      if (atHistHazir(id)) continue;
      try {
        await getAtHist(id).timeout(const Duration(seconds: 30));
      } catch (_) {
        _fail[id] = DateTime.now();
      }
      await Future<void>.delayed(const Duration(milliseconds: 150));
    }
  }
}
