import 'dart:async';
import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import 'auth_service.dart';
import 'feed.dart';
import 'scoring.dart';
import 'shell.dart' show IconBox;
import 'theme.dart';

FirebaseFirestore get _db => FirebaseFirestore.instance;
String get _me => profileNotifier.value?.uid ?? '';

/// Başka ekrandan açılan profil (geri düğmeli).
class ProfileRoute extends StatelessWidget {
  final String uid;
  const ProfileRoute({super.key, required this.uid});
  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return Scaffold(
      backgroundColor: c.bg,
      body: SafeArea(
        child: Column(children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 6),
            child: Row(children: [
              IconBox(icon: Icons.arrow_back, onTap: () => Navigator.pop(context)),
              const SizedBox(width: 10),
              const Brand(size: 19),
            ]),
          ),
          Expanded(child: ProfileView(uid: uid)),
        ]),
      ),
    );
  }
}

class ProfileView extends StatefulWidget {
  final String uid;
  const ProfileView({super.key, required this.uid});
  @override
  State<ProfileView> createState() => _ProfileViewState();
}

class _ProfileViewState extends State<ProfileView> {
  final _subs = <StreamSubscription>[];
  Map<String, dynamic>? _u;
  Map<String, dynamic> _grant = {};
  List<Post> _posts = [];
  List<QueryDocumentSnapshot<Map<String, dynamic>>> _followers = [];
  String _tab = 'k';
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    final uid = widget.uid;
    _subs.add(_db.collection('users').doc(uid).snapshots().listen((s) => setState(() {
          _u = s.data();
          _loaded = true;
        })));
    _subs.add(_db.collection('grants').doc(uid).snapshots().listen((s) => setState(() => _grant = s.data() ?? {}), onError: (_) {}));
    _subs.add(_db.collection('posts').where('uid', isEqualTo: uid).limit(300).snapshots().listen((s) {
      final l = s.docs.map((d) => Post(d.id, d.data())).where((p) => !p.hidden).toList()..sort((a, b) => b.ts.compareTo(a.ts));
      setState(() => _posts = l);
    }, onError: (_) {}));
    _subs.add(_db.collection('users').where('following', arrayContains: uid).limit(300).snapshots().listen(
        (s) => setState(() => _followers = s.docs), onError: (_) {}));
  }

  @override
  void dispose() {
    for (final s in _subs) {
      s.cancel();
    }
    super.dispose();
  }

  List<QueryDocumentSnapshot<Map<String, dynamic>>> get _validFollowers {
    final rem = (_u?['remFol'] as Map?) ?? const {};
    return _followers.where((d) {
      if (d.id == widget.uid) return false;
      final r = (rem[d.id] as num?) ?? 0;
      final f = ((d.data()['fts'] as Map?)?[widget.uid] as num?) ?? 0;
      return r == 0 || f > r;
    }).toList();
  }

  Future<void> _edit() async {
    final p = Profile.fromMap(widget.uid, _u ?? {});
    final name = TextEditingController(text: p.name);
    final bio = TextEditingController(text: p.bio);
    String photo = p.photo;
    final c = AppColors.of(context);
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: c.bg,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(26))),
      builder: (ctx) => StatefulBuilder(builder: (ctx, setS) {
        return Padding(
          padding: EdgeInsets.fromLTRB(18, 18, 18, 18 + MediaQuery.of(ctx).viewInsets.bottom),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Profili Düzenle', style: jakarta(18, FontWeight.w800, c.tx)),
            const SizedBox(height: 14),
            Row(children: [
              Avatar(profile: Profile(uid: p.uid, name: name.text, handle: p.handle, photo: photo), size: 64),
              const SizedBox(width: 12),
              TextButton(
                onPressed: () async {
                  final x = await ImagePicker().pickImage(source: ImageSource.gallery, maxWidth: 320, maxHeight: 320, imageQuality: 70);
                  if (x == null) return;
                  final b = await x.readAsBytes();
                  setS(() => photo = 'data:image/jpeg;base64,${base64Encode(b)}');
                },
                child: Text('Fotoğraf seç', style: jakarta(14, FontWeight.w800, c.ac)),
              ),
              if (photo.isNotEmpty)
                TextButton(onPressed: () => setS(() => photo = ''), child: Text('Kaldır', style: jakarta(14, FontWeight.w700, c.red))),
            ]),
            const SizedBox(height: 10),
            TextField(
              controller: name,
              maxLength: nameMax,
              decoration: const InputDecoration(labelText: 'Ad', border: OutlineInputBorder()),
            ),
            const SizedBox(height: 6),
            TextField(
              controller: bio,
              maxLength: 150,
              maxLines: 3,
              decoration: const InputDecoration(labelText: 'Biyografi', border: OutlineInputBorder()),
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                style: FilledButton.styleFrom(backgroundColor: c.ac, padding: const EdgeInsets.symmetric(vertical: 14)),
                onPressed: () async {
                  final n = name.text.trim();
                  if (n.length < 2) return;
                  try {
                    await _db.collection('users').doc(widget.uid).update({'name': n, 'bio': bio.text.trim(), 'photo': photo});
                    profileNotifier.value = await AuthService.loadProfile(widget.uid);
                    if (ctx.mounted) Navigator.pop(ctx);
                  } catch (e) {
                    if (ctx.mounted) {
                      ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(content: Text(AuthService.errorText(e))));
                    }
                  }
                },
                child: Text('Kaydet', style: jakarta(15, FontWeight.w800, c.on)),
              ),
            ),
          ]),
        );
      }),
    );
  }

  void _people(String title, List<String> uids) {
    final c = AppColors.of(context);
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: c.bg,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(26))),
      builder: (ctx) => SizedBox(
        height: MediaQuery.of(ctx).size.height * 0.65,
        child: Column(children: [
          const SizedBox(height: 14),
          Text(title, style: jakarta(16, FontWeight.w800, c.tx)),
          const SizedBox(height: 6),
          Expanded(
            child: uids.isEmpty
                ? Center(child: Text('Kimse yok.', style: jakarta(14, FontWeight.w600, c.mu)))
                : ListView(children: [for (final u in uids) PersonTile(uid: u, onOpen: () {
                    Navigator.pop(ctx);
                    Navigator.push(context, MaterialPageRoute(builder: (_) => ProfileRoute(uid: u)));
                  })]),
          ),
        ]),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    if (!_loaded) return Center(child: CircularProgressIndicator(color: c.ac));
    if (_u == null) return Center(child: Text('Kullanıcı bulunamadı.', style: jakarta(14, FontWeight.w600, c.mu)));
    final p = Profile.fromMap(widget.uid, _u!);
    final mine = widget.uid == _me;
        final following = ((_u!['following'] as List?) ?? const []).map((e) => e.toString()).toList();
    final coupons = _posts.where((x) => x.coupon != null).toList();
    final shown = _tab == 'k'
        ? coupons
        : _tab == 'w'
            ? coupons.where((x) => postStatus(x) == 'win').toList()
            : coupons.where((x) => postStatus(x) == 'lose').toList();
    final score = scoreOf(widget.uid, _posts, _u!['hist'] as Map?, ((_grant['pts'] as num?)?.toDouble() ?? 0) + ((_grant['keep'] as num?)?.toDouble() ?? 0));
    final fl = _validFollowers;
    final isAdmin = _u!['isAdmin'] == true;
    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: _db.collection('users').doc(_me).snapshots(),
      builder: (context, ms) {
        final mf = ((ms.data?.data()?['following'] as List?) ?? const []).map((e) => e.toString()).toSet();
        return ListView(padding: const EdgeInsets.fromLTRB(16, 8, 16, 24), children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: c.sf, borderRadius: BorderRadius.circular(24), border: Border.all(color: c.ln)),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Avatar(profile: p, size: 78),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(p.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: jakarta(22, FontWeight.w800, c.tx)),
                    Text('@${p.handle}', style: jakarta(14, FontWeight.w700, c.ac)),
                  ]),
                ),
                if (isAdmin)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(color: const Color(0xFF8B3FD9), borderRadius: BorderRadius.circular(14)),
                    child: Text('Yönetici', style: jakarta(12, FontWeight.w800, Colors.white)),
                  ),
              ]),
              if (p.bio.isNotEmpty) ...[const SizedBox(height: 10), Text(p.bio, style: jakarta(14, FontWeight.w500, c.tx))],
              const SizedBox(height: 12),
              if (mine)
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton(
                    onPressed: _edit,
                    style: OutlinedButton.styleFrom(side: BorderSide(color: c.ln), padding: const EdgeInsets.symmetric(vertical: 12)),
                    child: Text('Profili Düzenle', style: jakarta(14, FontWeight.w800, c.tx)),
                  ),
                )
              else
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: () => toggleFollow(widget.uid, mf.contains(widget.uid)).catchError((e) {
                      if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(AuthService.errorText(e))));
                    }),
                    style: FilledButton.styleFrom(
                        backgroundColor: mf.contains(widget.uid) ? c.sf2 : c.ac, padding: const EdgeInsets.symmetric(vertical: 12)),
                    child: Text(mf.contains(widget.uid) ? 'Takipte' : 'Takip Et',
                        style: jakarta(14, FontWeight.w800, mf.contains(widget.uid) ? c.mu : c.on)),
                  ),
                ),
            ]),
          ),
          const SizedBox(height: 12),
          Row(children: [
            _stat(c, fmtPts(score.pts), 'Puan', null),
            const SizedBox(width: 8),
            _stat(c, '${coupons.length}', 'Kupon', null),
            const SizedBox(width: 8),
            _stat(c, '${fl.length}', 'Takipçi', () => _people('Takipçiler', fl.map((e) => e.id).toList())),
            const SizedBox(width: 8),
            _stat(c, '${following.length}', 'Takip', () => _people('Takip edilenler', following)),
          ]),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(5),
            decoration: BoxDecoration(color: c.sf, borderRadius: BorderRadius.circular(18), border: Border.all(color: c.ln)),
            child: Row(children: [_tabBtn(c, 'k', 'Kuponlar'), _tabBtn(c, 'w', 'Tutanlar'), _tabBtn(c, 'l', 'Kaybedenler')]),
          ),
          const SizedBox(height: 14),
          if (shown.isEmpty)
            Padding(
              padding: const EdgeInsets.all(28),
              child: Text(_tab == 'k' ? 'Henüz paylaşılan kupon yok.' : _tab == 'w' ? 'Tutan kupon yok.' : 'Kaybeden kupon yok.',
                  textAlign: TextAlign.center, style: jakarta(14, FontWeight.w600, c.mu)),
            ),
          for (final x in shown) PostCard(key: ValueKey(x.id), post: x, following: mf.contains(x.uid)),
        ]);
      },
    );
  }

  Widget _stat(AppColors c, String v, String l, VoidCallback? onTap) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(color: c.sf, borderRadius: BorderRadius.circular(18), border: Border.all(color: c.ln)),
          child: Column(children: [
            Text(v, style: jakarta(20, FontWeight.w800, c.ac)),
            Text(l, style: jakarta(12, FontWeight.w600, c.mu)),
            if (onTap != null) Container(margin: const EdgeInsets.only(top: 4), width: 18, height: 2, color: c.ac.withAlpha(120)),
          ]),
        ),
      ),
    );
  }

  Widget _tabBtn(AppColors c, String k, String label) {
    final on = _tab == k;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _tab = k),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 11),
          decoration: BoxDecoration(color: on ? c.ac : Colors.transparent, borderRadius: BorderRadius.circular(14)),
          child: Text(label, textAlign: TextAlign.center, style: jakarta(14, FontWeight.w800, on ? c.on : c.mu)),
        ),
      ),
    );
  }
}

/// Kişi satırı (takipçi listesi, arama).
class PersonTile extends StatelessWidget {
  final String uid;
  final VoidCallback onOpen;
  const PersonTile({super.key, required this.uid, required this.onOpen});
  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return FutureBuilder<Profile?>(
      future: AuthService.loadProfile(uid),
      builder: (context, s) {
        final p = s.data;
        if (p == null) return const SizedBox(height: 56);
        return ListTile(
          onTap: onOpen,
          leading: Avatar(profile: p, size: 44),
          title: Text(p.name, style: jakarta(15, FontWeight.w800, c.tx)),
          subtitle: Text('@${p.handle}', style: jakarta(13, FontWeight.w600, c.mu)),
        );
      },
    );
  }
}
