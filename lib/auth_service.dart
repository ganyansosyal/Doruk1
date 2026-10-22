import 'dart:convert';
import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'theme.dart';

const handleMin = 3, handleMax = 20, nameMax = 30;

String cleanHandle(String s) {
  const map = {'ç': 'c', 'ğ': 'g', 'ı': 'i', 'ö': 'o', 'ş': 's', 'ü': 'u'};
  final b = StringBuffer();
  for (final ch in s.toLowerCase().split('')) {
    b.write(map[ch] ?? ch);
  }
  return b.toString().replaceAll(RegExp(r'[^a-z0-9_]'), '');
}

class Profile {
  final String uid, name, handle, bio, photo, cover, bioColor;
  final bool isAdmin;
  Profile({
    required this.uid,
    required this.name,
    required this.handle,
    this.bio = '',
    this.photo = '',
    this.cover = '',
    this.bioColor = '',
    this.isAdmin = false,
  });

  factory Profile.fromMap(String uid, Map<String, dynamic> m) => Profile(
        uid: uid,
        name: (m['name'] ?? '').toString(),
        handle: (m['handle'] ?? '').toString(),
        bio: (m['bio'] ?? '').toString(),
        photo: (m['photo'] ?? '').toString(),
        cover: (m['cover'] ?? '').toString(),
        bioColor: (m['bioColor'] ?? '').toString(),
        isAdmin: m['isAdmin'] == true,
      );

  late final ImageProvider? image = _imageOf(photo);
}

// Aynı fotoğraf her yeniden çizimde tekrar çözülmesin (avatar titremesi/yavaşlık)
final Map<String, ImageProvider?> _imgCache = {};

ImageProvider? _imageOf(String s) {
  if (s.isEmpty) return null;
  final hit = _imgCache[s];
  if (hit != null || _imgCache.containsKey(s)) return hit;
  ImageProvider? r;
  try {
    if (s.startsWith('http')) {
      r = NetworkImage(s);
    } else {
      final i = s.indexOf('base64,');
      if (i >= 0) r = MemoryImage(base64Decode(s.substring(i + 7)));
    }
  } catch (_) {}
  if (_imgCache.length > 150) _imgCache.clear();
  _imgCache[s] = r;
  return r;
}

final ValueNotifier<Profile?> profileNotifier = ValueNotifier<Profile?>(null);

class Avatar extends StatelessWidget {
  final Profile? profile;
  final double size;
  const Avatar({super.key, required this.profile, this.size = 40});

  @override
  Widget build(BuildContext context) {
    final raw = profile?.image;
    // Fotoğraf tam boyutta çözülmesin: küçük avatar için küçültülmüş kopya (kaydırma kasmasının ana sebebi)
    final px = (size * MediaQuery.devicePixelRatioOf(context)).round();
    final ImageProvider? img = raw == null ? null : ResizeImage.resizeIfNeeded(px, null, raw);
    final name = (profile?.name ?? '').trim();
    final letter = name.isEmpty ? '?' : name.substring(0, 1).toUpperCase();
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: const Color(0xFFFFD66B),
        image: img == null ? null : DecorationImage(image: img, fit: BoxFit.cover),
      ),
      child: img == null
          ? Text(letter, style: jakarta(size * 0.42, FontWeight.w800, const Color(0xFF7A4B00)))
          : null,
    );
  }
}

class AuthException implements Exception {
  final String message;
  const AuthException(this.message);
  @override
  String toString() => message;
}

const _badLogin = 'Kullanıcı adı / e-posta veya şifre hatalı.';

const _codes = {
  'invalid-credential': _badLogin,
  'wrong-password': _badLogin,
  'user-not-found': _badLogin,
  'email-already-in-use': 'Bu e-posta zaten kayıtlı.',
  'weak-password': 'Şifre çok zayıf.',
  'invalid-email': 'Geçerli bir e-posta adresi yaz.',
  'too-many-requests': 'Çok fazla deneme yapıldı. Biraz sonra tekrar dene.',
  'network-request-failed': 'Bağlantı kurulamadı. İnternetini kontrol et.',
  'permission-denied': 'Yetki hatası: Firestore kuralları yayınlandı mı?',
  'unavailable': 'Bağlantı kurulamadı. İnternetini kontrol et.',
};

String _taken(String h) => '@$h kullanılmakta. Başka bir kullanıcı adı dene.';

class AuthService {
  static final ValueNotifier<bool> busy = ValueNotifier<bool>(false);

  static FirebaseAuth get _auth => FirebaseAuth.instance;
  static FirebaseFirestore get _db => FirebaseFirestore.instance;

  static String errorText(Object e) {
    if (e is AuthException) return e.message;
    if (e is FirebaseException) return _codes[e.code] ?? e.message ?? 'İşlem başarısız.';
    return 'İşlem başarısız.';
  }

  static Future<Profile?> loadProfile(String uid) async {
    final d = await _db.collection('users').doc(uid).get();
    final data = d.data();
    if (!d.exists || data == null) return null;
    return Profile.fromMap(uid, data);
  }

  static Future<bool> handleTaken(String handle) async {
    final d = await _db.collection('handles').doc(handle).get();
    return d.exists;
  }

  static Future<bool> _createProfile(String uid, String name, String handle, String email, String photo) {
    final hRef = _db.collection('handles').doc(handle);
    final uRef = _db.collection('users').doc(uid);
    return _db.runTransaction<bool>((t) async {
      final h = await t.get(hRef);
      if (h.exists) return false;
      t.set(hRef, {'uid': uid, 'email': email});
      t.set(uRef, {
        'name': name,
        'handle': handle,
        'bio': '',
        'photo': photo,
        'cover': '',
        'bioColor': '',
        'following': <String>[],
        'createdAt': DateTime.now().millisecondsSinceEpoch,
      });
      return true;
    });
  }

  static Future<void> register({
    required String name,
    required String handle,
    required String email,
    required String password,
    required String photo,
  }) async {
    busy.value = true;
    try {
      if (await handleTaken(handle)) throw AuthException(_taken(handle));
      final cred = await _auth.createUserWithEmailAndPassword(email: email, password: password);
      final user = cred.user!;
      try {
        final ok = await _createProfile(user.uid, name, handle, email, photo);
        if (!ok) throw AuthException(_taken(handle));
      } catch (e) {
        try {
          await user.delete();
        } catch (_) {}
        rethrow;
      }
    } catch (e) {
      throw AuthException(errorText(e));
    } finally {
      busy.value = false;
    }
  }

  static Future<String> _emailOf(String id) async {
    final s = id.trim();
    if (s.contains('@')) return s;
    final hs = await _db.collection('handles').doc(cleanHandle(s)).get();
    final email = hs.data()?['email'];
    if (!hs.exists || email is! String || email.isEmpty) throw const AuthException(_badLogin);
    return email;
  }

  static Future<void> login(String id, String password) async {
    busy.value = true;
    try {
      final email = await _emailOf(id);
      await _auth.signInWithEmailAndPassword(email: email, password: password);
    } catch (e) {
      throw AuthException(errorText(e));
    } finally {
      busy.value = false;
    }
  }

  static Future<void> resetPassword(String id) async {
    try {
      final email = await _emailOf(id);
      await _auth.sendPasswordResetEmail(email: email);
    } catch (e) {
      final m = errorText(e);
      throw AuthException(m == _badLogin ? 'Bu kullanıcı bulunamadı.' : m);
    }
  }

  static Future<Profile> bootstrap(User u) async {
    final p = await loadProfile(u.uid) ?? await _ensureProfile(u);
    profileNotifier.value = p;
    return p;
  }

  static Future<Profile> _ensureProfile(User u) async {
    final email = u.email ?? '';
    var base = cleanHandle(email.split('@').first);
    if (base.length < handleMin) base = 'kullanici';
    if (base.length > handleMax) base = base.substring(0, handleMax);
    var name = (u.displayName ?? base).trim().replaceAll(RegExp(r'\s+'), ' ');
    if (name.length > nameMax) name = name.substring(0, nameMax);
    if (name.length < 2) name = base;
    final rnd = Random();
    for (var i = 0; i < 6; i++) {
      final h = i == 0
          ? base
          : base.substring(0, min(base.length, handleMax - 4)) + (1000 + rnd.nextInt(9000)).toString();
      if (await _createProfile(u.uid, name, h, email, '')) {
        final p = await loadProfile(u.uid);
        if (p != null) return p;
      }
    }
    throw const AuthException('Kullanıcı adı oluşturulamadı.');
  }

  static Future<void> signOut() async {
    profileNotifier.value = null;
    await _auth.signOut();
  }
}

Future<void> confirmSignOut(BuildContext context) async {
  final c = AppColors.of(context);
  final ok = await showDialog<bool>(
    context: context,
    builder: (ctx) => Dialog(
      backgroundColor: c.sf,
      insetPadding: const EdgeInsets.symmetric(horizontal: 28),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(26)),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(22, 24, 22, 22),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Text('Oturumu kapat', textAlign: TextAlign.center, style: jakarta(20, FontWeight.w800, c.tx)),
          const SizedBox(height: 10),
          Text('Oturumunu kapatmak istediğine emin misin? Verilerin bu cihazda saklanır.', textAlign: TextAlign.center, style: jakarta(14.5, FontWeight.w500, c.mu).copyWith(height: 1.35)),
          const SizedBox(height: 20),
          Row(children: [
            Expanded(
              child: GestureDetector(
                onTap: () => Navigator.pop(ctx, false),
                child: Container(
                  height: 50,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(color: c.sf, borderRadius: BorderRadius.circular(16), border: Border.all(color: c.ln, width: 1.4)),
                  child: Text('Vazgeç', style: jakarta(15, FontWeight.w800, c.tx)),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: GestureDetector(
                onTap: () => Navigator.pop(ctx, true),
                child: Container(
                  height: 50,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(color: c.red, borderRadius: BorderRadius.circular(16)),
                  child: Text('Çıkış Yap', style: jakarta(15, FontWeight.w800, Colors.white)),
                ),
              ),
            ),
          ]),
        ]),
      ),
    ),
  );
  if (ok == true) await AuthService.signOut();
}
