import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';

import 'auth_service.dart';
import 'feed.dart';
import 'profile.dart';
import 'shell.dart' show IconBox;
import 'theme.dart';

Widget _page(BuildContext context, String title, Widget body) {
  final c = AppColors.of(context);
  return Scaffold(
    backgroundColor: c.bg,
    body: SafeArea(
      child: Column(children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 6),
          child: Row(children: [
            IconBox(icon: Icons.arrow_back, onTap: () => Navigator.pop(context)),
            const SizedBox(width: 12),
            Text(title, style: jakarta(20, FontWeight.w800, c.tx)),
          ]),
        ),
        Expanded(child: body),
      ]),
    ),
  );
}

/* ---------------- Zil rozeti (okunmamış bildirim sayısı) ---------------- */

// Son bildirim sayfası açılış zamanı (cihazda saklanır). -1 = henüz yüklenmedi
final ValueNotifier<int> _nfSeen = ValueNotifier<int>(-1);
String _nfLoadedFor = '';

Future<File> _nfFile(String uid) async {
  final d = await getApplicationSupportDirectory();
  return File('${d.path}/nf_seen_$uid.txt');
}

Future<void> _nfMark(String uid) async {
  final now = DateTime.now().millisecondsSinceEpoch;
  _nfSeen.value = now;
  try {
    await (await _nfFile(uid)).writeAsString('$now');
  } catch (_) {}
}

Future<void> _nfLoad(String uid) async {
  if (uid.isEmpty || _nfLoadedFor == uid) return;
  _nfLoadedFor = uid;
  try {
    final f = await _nfFile(uid);
    if (await f.exists()) {
      _nfSeen.value = int.tryParse(await f.readAsString()) ?? 0;
    } else {
      await _nfMark(uid); // ilk kurulum: eskiler okunmamış sayılmasın
    }
  } catch (_) {
    _nfSeen.value = DateTime.now().millisecondsSinceEpoch;
  }
}

class NotifBell extends StatefulWidget {
  final VoidCallback onTap;
  const NotifBell({super.key, required this.onTap});
  @override
  State<NotifBell> createState() => _NotifBellState();
}

class _NotifBellState extends State<NotifBell> {
  late final String _me = profileNotifier.value?.uid ?? '';
  late final Stream<QuerySnapshot<Map<String, dynamic>>> _s =
      FirebaseFirestore.instance.collection('notifs').where('to', isEqualTo: _me).limit(100).snapshots();

  @override
  void initState() {
    super.initState();
    _nfLoad(_me);
  }

  @override
  Widget build(BuildContext context) {
    final bell = IconBox(icon: Icons.notifications_none, onTap: widget.onTap);
    if (_me.isEmpty) return bell;
    return ValueListenableBuilder<int>(
      valueListenable: _nfSeen,
      builder: (context, seen, _) => StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: _s,
        builder: (context, snap) {
          var n = 0;
          if (seen >= 0 && snap.hasData) {
            final now = DateTime.now().millisecondsSinceEpoch;
            for (final d in snap.data!.docs) {
              final m = d.data();
              final e = m['exp'];
              if (e is Timestamp && e.millisecondsSinceEpoch <= now) continue;
              if (((m['ts'] as num?) ?? 0) > seen) n++;
            }
          }
          return Stack(clipBehavior: Clip.none, children: [
            bell,
            if (n > 0)
              Positioned(
                right: -4,
                top: -4,
                child: Container(
                  constraints: const BoxConstraints(minWidth: 18, minHeight: 18),
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(color: const Color(0xFFE0305A), borderRadius: BorderRadius.circular(9), border: Border.all(color: AppColors.of(context).bg, width: 1.5)),
                  child: Text(n > 9 ? '9+' : '$n', style: jakarta(10.5, FontWeight.w800, Colors.white)),
                ),
              ),
          ]);
        },
      ),
    );
  }
}

/* ---------------- Bildirimler ---------------- */

class NotificationsPage extends StatefulWidget {
  const NotificationsPage({super.key});
  @override
  State<NotificationsPage> createState() => _NotificationsPageState();
}

class _NotificationsPageState extends State<NotificationsPage> {
  String get _uid => profileNotifier.value?.uid ?? '';

  @override
  void initState() {
    super.initState();
    _nfMark(_uid);
  }

  @override
  void dispose() {
    _nfMark(_uid); // sayfa açıkken gelenler de okunmuş sayılsın
    super.dispose();
  }

  static String _text(Map<String, dynamic> n) {
    final fn = (n['fn'] ?? 'Biri').toString(), tx = (n['tx'] ?? '').toString();
    switch (n['type']) {
      case 'like':
        return '$fn paylaşımını beğendi';
      case 'comment':
        return '$fn yorum yaptı: $tx';
      case 'reply':
        return '$fn yorumuna yanıt verdi: $tx';
      case 'cmlike':
        return '$fn yorumunu beğendi';
      case 'follow':
        return '$fn seni takip etmeye başladı';
      case 'newcoupon':
        return '$fn yeni kupon paylaştı${tx.isEmpty ? '' : ' · $tx'}';
      case 'win':
        return 'Kuponun tuttu${tx.isEmpty ? '' : ' · $tx'}';
      case 'lose':
        return 'Kuponun tutmadı${tx.isEmpty ? '' : ' · $tx'}';
      default:
        return fn;
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final me = profileNotifier.value?.uid ?? '';
    return _page(
      context,
      'Bildirimler',
      StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: FirebaseFirestore.instance.collection('notifs').where('to', isEqualTo: me).limit(100).snapshots(),
        builder: (context, s) {
          if (s.hasError) return Center(child: Text(AuthService.errorText(s.error!), style: jakarta(14, FontWeight.w600, c.mu)));
          if (!s.hasData) return Center(child: CircularProgressIndicator(color: c.ac));
          final now = DateTime.now().millisecondsSinceEpoch;
          final l = s.data!.docs.map((d) => d.data()).where((n) {
            final e = n['exp'];
            return e is! Timestamp || e.millisecondsSinceEpoch > now;
          }).toList()
            ..sort((a, b) => ((b['ts'] as num?) ?? 0).compareTo((a['ts'] as num?) ?? 0));
          if (l.isEmpty) return Center(child: Text('Henüz bildirim yok.', style: jakarta(14, FontWeight.w600, c.mu)));
          return ListView.builder(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
            itemCount: l.length,
            itemBuilder: (_, i) {
              final n = l[i];
              return GestureDetector(
                onTap: () {
                  final f = (n['from'] ?? '').toString();
                  if (f.isNotEmpty && f != me) Navigator.push(context, MaterialPageRoute(builder: (_) => ProfileRoute(uid: f)));
                },
                child: Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(color: c.sf, borderRadius: BorderRadius.circular(18), border: Border.all(color: c.ln)),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(_text(n), style: jakarta(14, FontWeight.w700, c.tx)),
                    const SizedBox(height: 3),
                    Text(fmtStamp((n['ts'] as num?)?.toInt() ?? 0), style: jakarta(11.5, FontWeight.w500, c.mu)),
                  ]),
                ),
              );
            },
          );
        },
      ),
    );
  }
}

/* ---------------- Kullanıcı arama ---------------- */

class SearchPage extends StatefulWidget {
  const SearchPage({super.key});
  @override
  State<SearchPage> createState() => _SearchPageState();
}

class _SearchPageState extends State<SearchPage> {
  String _q = '';
  late final Future<QuerySnapshot<Map<String, dynamic>>> _all = FirebaseFirestore.instance.collection('users').limit(300).get();

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return _page(
      context,
      'Kullanıcı ara',
      Column(children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 6, 16, 8),
          child: TextField(
            autofocus: true,
            onChanged: (v) => setState(() => _q = v.trim().toLowerCase()),
            style: jakarta(15, FontWeight.w600, c.tx),
            decoration: InputDecoration(
              prefixIcon: Icon(Icons.search, color: c.ac),
              hintText: 'Ad veya @kullanıcı adı',
              filled: true,
              fillColor: c.sf,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: c.ln)),
            ),
          ),
        ),
        Expanded(
          child: FutureBuilder<QuerySnapshot<Map<String, dynamic>>>(
            future: _all,
            builder: (context, s) {
              if (!s.hasData) return Center(child: CircularProgressIndicator(color: c.ac));
              final q = _q.startsWith('@') ? _q.substring(1) : _q;
              final l = s.data!.docs.where((d) {
                if (q.isEmpty) return true;
                final m = d.data();
                return (m['name'] ?? '').toString().toLowerCase().contains(q) || (m['handle'] ?? '').toString().toLowerCase().contains(q);
              }).toList();
              if (l.isEmpty) return Center(child: Text('Kullanıcı bulunamadı.', style: jakarta(14, FontWeight.w600, c.mu)));
              return ListView(children: [
                for (final d in l)
                  ListTile(
                    onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => ProfileRoute(uid: d.id))),
                    leading: Avatar(profile: Profile.fromMap(d.id, d.data()), size: 44),
                    title: Text((d.data()['name'] ?? '').toString(), style: jakarta(15, FontWeight.w800, c.tx)),
                    subtitle: Text('@${d.data()['handle'] ?? ''}', style: jakarta(13, FontWeight.w600, c.mu)),
                  ),
              ]);
            },
          ),
        ),
      ]),
    );
  }
}
