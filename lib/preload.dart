import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'firebase_options.dart';

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

  static Future<void> start() => _f ??= _run();

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
      done = true;
    } catch (_) {
      // alınamadıysa akış kendi yükleme yoluna döner
    }
  }
}
