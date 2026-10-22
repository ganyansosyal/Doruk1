import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import 'auth_service.dart';
import 'feed.dart';
import 'ikramiye.dart';
import 'scoring.dart';
import 'tjk.dart';

final ValueNotifier<bool> isAdminNotifier = ValueNotifier(false);

/// Arka planda: yönetici bilgisini izler, benim kuponlarımın sonuçlarını Firestore'a işler.
class Settler {
  static StreamSubscription? _a, _b;
  static List<Post> _mine = [];
  static bool _busy = false;
  static String _uid = '';

  static void start(String uid) {
    if (_uid == uid) return;
    stop();
    _uid = uid;
    final db = FirebaseFirestore.instance;
    _a = db.collection('users').doc(uid).snapshots().listen((s) => isAdminNotifier.value = s.data()?['isAdmin'] == true, onError: (_) {});
    _b = db.collection('posts').where('uid', isEqualTo: uid).limit(100).snapshots().listen((s) {
      _mine = s.docs.map((d) => Post(d.id, d.data())).toList();
      _run();
    }, onError: (_) {});
    TjkStore.i.addListener(_run);
    TjkStore.i.ensureLoaded();
  }

  static void stop() {
    _a?.cancel();
    _b?.cancel();
    TjkStore.i.removeListener(_run);
    _uid = '';
  }

  static Future<void> _run() async {
    if (_busy) return;
    _busy = true;
    try {
      final db = FirebaseFirestore.instance;
      for (final p in _mine) {
        final c = p.coupon;
        if (c == null) continue;
        final legs = ((c['legs'] as List?) ?? const []).whereType<Map>().map((l) => Map<String, dynamic>.from(l)).toList();
        final m = liveRes['${c['iso']}|${c['city']}'];
        if (m != null) {
          var changed = false;
          for (final l in legs) {
            final r = (l['r'] as num?)?.toInt();
            if (l['res'] is List || r == null || m[r] == null) continue;
            l['res'] = m[r];
            changed = true;
          }
          if (changed) {
            c['legs'] = legs;
            try {
              await db.collection('posts').doc(p.id).update({'coupon.legs': legs});
              final st = couponStatus(c).k;
              if (st == 'win' || st == 'lose') {
                final ex = DateTime.now();
                await db.collection('notifs').doc('${st}_${p.id}').set({
                  'to': _uid,
                  'from': _uid,
                  'fn': profileNotifier.value?.name ?? '',
                  'type': st,
                  'pid': p.ts,
                  'pd': p.id,
                  'ts': DateTime.now().millisecondsSinceEpoch,
                  'exp': Timestamp.fromMillisecondsSinceEpoch(DateTime(ex.year, ex.month, ex.day + 1).millisecondsSinceEpoch),
                  'tx': '${c['type'] ?? ''}',
                });
              }
            } catch (_) {}
          }
        }
        // TJK ikramiyesi kesinleşince kuponun kendi kaydına yaz: gün atlayınca kaybolmasın
        try {
          if (Ikr.fromMap(c['ikrD']) == null) {
            // Bugünün kuponu: yüklü veriden; geçmiş günün kuponu: o günün sonuçları TJK'dan çekilerek
            final k = ikramiyeLive(c) ?? (ikramiyeFetchGerek(c) ? await ikramiyeFetch(c) : null);
            if (k != null && k.ready) await db.collection('posts').doc(p.id).update(ikrPatch(c, k));
          }
        } catch (_) {}
      }
    } finally {
      _busy = false;
    }
  }
}
