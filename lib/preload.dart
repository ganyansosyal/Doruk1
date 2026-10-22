import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'auth_service.dart';
import 'firebase_options.dart';
import 'tjk.dart';

/// Açılış ekranı (splash) sürerken akışın verilerini (paylaşımlar, kullanıcılar, puanlar, moderatörler, ben)
/// birlikte önceden alır. Splash bitince akış hazır açılır: tahminciler satırı, sıralama ve rozetler oynamaz.
class Preload {
  static Future<void>? _f;
  static bool done = false;
  static String uid = '';
  static List<QueryDocumentSnapshot<Map<String, dynamic>>> users = const [];
  static Map<String, double> bonus = {};
  static Set<String> mods = {};
  static Map<String, dynamic>? me;

  static Future<void> start() {
    TjkStore.i.ensureLoaded(); // koşu programı da splash sırasında gelsin
    return _f ??= _run();
  }

  static Future<void> _run() async {
    try {
      if (!firebaseReady) return;
      final auth = FirebaseAuth.instance;
      final u = await auth.authStateChanges().first.timeout(const Duration(seconds: 4), onTimeout: () => auth.currentUser);
      if (u == null) return; // giriş yok: beklenecek bir şey yok
      const srv = GetOptions(source: Source.server);
      final db = FirebaseFirestore.instance;
      final fu = db.collection('users').limit(300).get(srv);
      final fg = db.collection('grants').limit(500).get(srv);
      final fm = db.collection('mods').limit(100).get(srv);
      final fme = db.collection('users').doc(u.uid).get(srv);
      final fp = db.collection('posts').orderBy('ts', descending: true).limit(100).get(srv);
      await Future.wait<Object?>([fp, fu, fg, fm, fme]).timeout(const Duration(seconds: 8));
      users = (await fu).docs;
      bonus = {for (final d in (await fg).docs) d.id: ((d.data()['pts'] as num?)?.toDouble() ?? 0) + ((d.data()['keep'] as num?)?.toDouble() ?? 0)};
      mods = (await fm).docs.map((d) => d.id).toSet();
      me = (await fme).data();
      uid = u.uid;
      // Bekleyen kuponların (herkesin) sonuçları splash sırasında çekilsin: akış açılınca durumlar hazır olur
      try {
        final today = isoToday(), keys = <String>{};
        for (final d in (await fp).docs) {
          final c = d.data()['coupon'];
          if (c is! Map) continue;
          final legs = ((c['legs'] as List?) ?? const []).whereType<Map>();
          if (!legs.any((l) => l['res'] is! List && l['win'] is! num)) continue;
          final iso = '${c['iso'] ?? ''}', city = '${c['city'] ?? ''}';
          if (iso.isEmpty || city.isEmpty || iso.compareTo(today) > 0) continue;
          keys.add('$iso|$city');
        }
        await Future.wait(keys.map((k) => pullLiveRes(k.substring(0, k.indexOf('|')), k.substring(k.indexOf('|') + 1)))).timeout(const Duration(seconds: 4), onTimeout: () => const []);
      } catch (_) {}
      // Avatar fotoğraflarını splash sırasında çöz: akış açılınca tahminciler satırı boş/harf görünmesin
      final photos = <String>[for (final d in users) (d.data()['photo'] ?? '').toString()].where((x) => x.isNotEmpty).take(60);
      await warmAvatars(photos, const [48, 36]).timeout(const Duration(seconds: 3), onTimeout: () {});
      done = true;
    } catch (_) {
      // alınamadıysa akış kendi yükleme yoluna döner
    }
  }
}
