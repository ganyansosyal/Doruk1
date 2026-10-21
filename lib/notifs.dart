import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

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

/* ---------------- Bildirimler ---------------- */

class NotificationsPage extends StatelessWidget {
  const NotificationsPage({super.key});

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
