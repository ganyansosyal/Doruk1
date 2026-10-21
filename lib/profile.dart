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

class ProfileRoute extends StatelessWidget {
  final String uid;
  const ProfileRoute({super.key, required this.uid});

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return Scaffold(
      backgroundColor: c.bg,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
              child: Row(
                children: [
                  IconBox(icon: Icons.arrow_back, onTap: () => Navigator.pop(context)),
                  const SizedBox(width: 8),
                  const Brand(size: 18),
                ],
              ),
            ),
            Expanded(child: ProfileView(uid: uid)),
          ],
        ),
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
    _subs.add(_db.collection('users').doc(uid).snapshots().listen((s) {
      setState(() {
        _u = s.data();
        _loaded = true;
      });
    }));
    _subs.add(_db.collection('grants').doc(uid).snapshots().listen((s) {
      setState(() => _grant = s.data() ?? {});
    }, onError: (_) {}));
    _subs.add(_db.collection('posts').where('uid', isEqualTo: uid).limit(300).snapshots().listen((s) {
      final l = s.docs.map((d) => Post(d.id, d.data())).where((p) => !p.hidden).toList()
        ..sort((a, b) => b.ts.compareTo(a.ts));
      setState(() => _posts = l);
    }, onError: (_) {}));
    _subs.add(_db.collection('users').where('following', arrayContains: uid).limit(300).snapshots().listen(
      (s) => setState(() => _followers = s.docs),
      onError: (_) {},
    ));
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

  Color _hexColor(String hex) {
    hex = hex.replaceAll('#', '');
    if (hex.length == 6) hex = 'FF$hex';
    return Color(int.parse(hex, radix: 16));
  }
  Future<void> _edit() async {
  final p = Profile.fromMap(widget.uid, _u ?? {});
  final name = TextEditingController(text: p.name);
  final bio = TextEditingController(text: p.bio);
  String photo = p.photo;
  String bioColor = p.bioColor ?? '';
  final c = AppColors.of(context);
  const colors = ['', '#0E9F73', '#2563EB', '#7C3AED', '#DB2777', '#E0305A', '#EA580C', '#B87F00', '#0891B2'];

  await showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: c.bg,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setS) {
        return Padding(
          padding: EdgeInsets.fromLTRB(16, 16, 16, 16 + MediaQuery.of(ctx).viewInsets.bottom),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Profili Düzenle', style: jakarta(18, FontWeight.w800, c.tx)),
                  IconButton(onPressed: () => Navigator.pop(ctx), icon: Icon(Icons.close, color: c.tx)),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Stack(
                    children: [
                      Avatar(profile: Profile(uid: p.uid, name: name.text, handle: p.handle, photo: photo), size: 72),
                      Positioned(
                        bottom: 0,
                        right: 0,
                        child: GestureDetector(
                          onTap: () async {
                            final x = await ImagePicker().pickImage(source: ImageSource.gallery, maxWidth: 320, maxHeight: 320, imageQuality: 70);
                            if (x == null) return;
                            final b = await x.readAsBytes();
                            setS(() => photo = 'data:image/jpeg;base64,${base64Encode(b)}');
                          },
                          child: Container(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(color: c.ac, shape: BoxShape.circle, border: Border.all(color: c.bg, width: 2)),
                            child: const Icon(Icons.camera_alt, color: Colors.white, size: 14),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Text('Ad', style: jakarta(12, FontWeight.w700, c.mu)),
              const SizedBox(height: 4),
              TextField(
                controller: name,
                maxLength: nameMax,
                style: jakarta(14, FontWeight.w600, c.tx),
                decoration: InputDecoration(
                  filled: true,
                  fillColor: c.sf2,
                  counterText: '',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                ),
              ),
              const SizedBox(height: 12),
              Text('Kullanıcı adı', style: jakarta(12, FontWeight.w700, c.mu)),
              const SizedBox(height: 4),
              TextField(
                controller: TextEditingController(text: '@${p.handle}'),
                readOnly: true,
                style: jakarta(14, FontWeight.w600, c.mu),
                decoration: InputDecoration(
                  filled: true,
                  fillColor: c.sf2,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                ),
              ),
              const SizedBox(height: 12),
              Text('Biyografi', style: jakarta(12, FontWeight.w700, c.mu)),
              const SizedBox(height: 4),
              TextField(
                controller: bio,
                maxLength: 160,
                maxLines: 3,
                style: jakarta(14, FontWeight.w600, bioColor.isNotEmpty ? _hexColor(bioColor) : c.tx),
                decoration: InputDecoration(
                  filled: true,
                  fillColor: c.sf2,
                  hintText: 'Kendinden kısaca bahset...',
                  counterText: '',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                ),
              ),
              Align(alignment: Alignment.centerRight, child: Text('${bio.text.length}/160', style: jakarta(11, FontWeight.w600, c.mu))),
              const SizedBox(height: 12),
              Text('Biyografi yazı rengi', style: jakarta(12, FontWeight.w700, c.mu)),
              const SizedBox(height: 8),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    for (final col in colors)
                      GestureDetector(
                        onTap: () => setS(() => bioColor = col),
                        child: Container(
                          margin: const EdgeInsets.only(right: 12),
                          width: 32,
                          height: 32,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: col.isEmpty ? null : _hexColor(col),
                            gradient: col.isEmpty ? const LinearGradient(colors: [Colors.black, Colors.grey], begin: Alignment.topCenter, end: Alignment.bottomCenter) : null,
                            border: Border.all(color: bioColor == col ? c.ac : Colors.transparent, width: 2),
                          ),
                          child: bioColor == col ? Icon(Icons.circle, size: 12, color: col.isEmpty ? Colors.white : c.bg) : null,
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(ctx),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        side: BorderSide(color: c.ln),
                      ),
                      child: Text('Vazgeç', style: jakarta(14, FontWeight.w800, c.mu)),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: FilledButton(
                      onPressed: () async {
                        final n = name.text.trim();
                        if (n.length < 2) return;
                        try {
                          await _db.collection('users').doc(widget.uid).update({
                            'name': n,
                            'bio': bio.text.trim(),
                            'bioColor': bioColor,
                            'photo': photo,
                          });
                          profileNotifier.value = await AuthService.loadProfile(widget.uid);
                          if (ctx.mounted) Navigator.pop(ctx);
                        } catch (e) {
                          if (ctx.mounted) ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(content: Text(AuthService.errorText(e))));
                        }
                      },
                      style: FilledButton.styleFrom(
                        backgroundColor: c.ac,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: Text('Kaydet', style: jakarta(14, FontWeight.w800, c.on)),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    ),
  );
  }
  void _people(String title, List<String> uids) {
  final c = AppColors.of(context);
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: c.bg,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
    builder: (ctx) => SizedBox(
      height: MediaQuery.of(ctx).size.height * 0.65,
      child: Column(
        children: [
          const SizedBox(height: 12),
          Text(title, style: jakarta(15, FontWeight.w800, c.tx)),
          const SizedBox(height: 4),
          Expanded(
            child: uids.isEmpty
                ? Center(child: Text('Kimse yok.', style: jakarta(13, FontWeight.w600, c.mu)))
                : ListView(
                    children: [
                      for (final u in uids)
                        PersonTile(
                          uid: u,
                          onOpen: () {
                            Navigator.pop(ctx);
                            Navigator.push(context, MaterialPageRoute(builder: (_) => ProfileRoute(uid: u)));
                          },
                        ),
                    ],
                  ),
          ),
        ],
      ),
    ),
  );
}

@override
Widget build(BuildContext context) {
  final c = AppColors.of(context);
  if (!_loaded) return Center(child: CircularProgressIndicator(color: c.ac));
  if (_u == null) return Center(child: Text('Kullanıcı bulunamadı.', style: jakarta(13, FontWeight.w600, c.mu)));

  final p = Profile.fromMap(widget.uid, _u!);
  final mine = widget.uid == _me;
  final following = ((_u!['following'] as List?) ?? const []).map((e) => e.toString()).toList();
  final coupons = _posts.where((x) => x.coupon != null).toList();
  final shown = _tab == 'k' ? coupons : _tab == 'w' ? coupons.where((x) => postStatus(x) == 'win').toList() : coupons.where((x) => postStatus(x) == 'lose').toList();
  final score = scoreOf(widget.uid, _posts, _u!['hist'] as Map?, ((_grant['pts'] as num?)?.toDouble() ?? 0) + ((_grant['keep'] as num?)?.toDouble() ?? 0));
  final fl = _validFollowers;
  final isAdmin = _u!['isAdmin'] == true;

  return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
    stream: _db.collection('users').doc(_me).snapshots(),
    builder: (context, ms) {
      final mf = ((ms.data?.data()?['following'] as List?) ?? const []).map((e) => e.toString()).toSet();
      return ListView(
        padding: EdgeInsets.zero,
        children: [
          // BANNER
          Container(
            height: 130,
            width: double.infinity,
            margin: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              color: c.ac.withAlpha(20),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: c.ac.withAlpha(40)),
            ),
            child: Stack(
              alignment: Alignment.center,
              children: [
                Positioned(left: -50, top: -50, child: Icon(Icons.waves, size: 250, color: c.ac.withAlpha(15))),
                Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text.rich(
                      TextSpan(
                        children: [
                          TextSpan(text: 'Ganyan', style: jakarta(34, FontWeight.w800, c.tx)),
                          TextSpan(text: 'Sosyal', style: jakarta(34, FontWeight.w800, c.ac)),
                        ],
                      ),
                    ),
                    const SizedBox(height: 4),
                    Container(width: 50, height: 3, color: c.ac),
                    const SizedBox(height: 8),
                    Text('TAHMİN ET  •  PAYLAŞ  •  KAZAN', style: jakarta(9.5, FontWeight.w800, c.mu).copyWith(letterSpacing: 1.5)),
                  ],
                ),
              ],
            ),
          ),
          // AVATAR VE İSİM
          Transform.translate(
            offset: const Offset(0, -45),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Container(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: c.bg, width: 5),
                      boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 10, offset: const Offset(0, 4))],
                    ),
                    child: Avatar(profile: p, size: 90),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.only(bottom: 10.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(child: Text(p.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: jakarta(22, FontWeight.w800, c.tx))),
                              if (isAdmin)
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(color: const Color(0xFF8B3FD9), borderRadius: BorderRadius.circular(10)),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Icon(Icons.lock, size: 10, color: Colors.white),
                                      const SizedBox(width: 4),
                                      Text('Yönetici', style: jakarta(10, FontWeight.w800, Colors.white)),
                                    ],
                                  ),
                                ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(color: c.ac.withAlpha(20), borderRadius: BorderRadius.circular(10)),
                            child: Text('@${p.handle}', style: jakarta(13, FontWeight.w700, c.ac)),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
                      // BİYOGRAFİ VE ALT KISIM
            Transform.translate(
              offset: const Offset(0, -30),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (p.bio.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: Text(p.bio, style: jakarta(14, FontWeight.w500, p.bioColor != null && p.bioColor!.isNotEmpty ? _hexColor(p.bioColor!) : c.tx)),
                      )
                    else if (mine)
                      GestureDetector(
                        onTap: _edit,
                        child: Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: Text('+ Biyografi ekle', style: jakarta(14, FontWeight.w700, c.ac)),
                        ),
                      ),
                    SizedBox(
                      width: double.infinity,
                      height: 44,
                      child: mine
                          ? OutlinedButton(
                              onPressed: _edit,
                              style: OutlinedButton.styleFrom(
                                side: BorderSide(color: c.ln),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                              ),
                              child: Text('Profili Düzenle', style: jakarta(14, FontWeight.w800, c.tx)),
                            )
                          : FilledButton(
                              onPressed: () => toggleFollow(widget.uid, mf.contains(widget.uid)).catchError((e) {
                                if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(AuthService.errorText(e))));
                              }),
                              style: FilledButton.styleFrom(
                                backgroundColor: mf.contains(widget.uid) ? c.sf2 : c.ac,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                              ),
                              child: Text(mf.contains(widget.uid) ? 'Takipte' : 'Takip Et', style: jakarta(14, FontWeight.w800, mf.contains(widget.uid) ? c.mu : c.on)),
                            ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        _stat(c, fmtPts(score.pts), 'Puan', null),
                        const SizedBox(width: 8),
                        _stat(c, '${coupons.length}', 'Kupon', null),
                        const SizedBox(width: 8),
                        _stat(c, '${fl.length}', 'Takipçi', () => _people('Takipçiler', fl.map((e) => e.id).toList())),
                        const SizedBox(width: 8),
                        _stat(c, '${following.length}', 'Takip', () => _people('Takip edilenler', following)),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(5),
                      decoration: BoxDecoration(color: c.sf, borderRadius: BorderRadius.circular(16), border: Border.all(color: c.ln)),
                      child: Row(
                        children: [
                          _tabBtn(c, 'k', 'Kuponlar'),
                          _tabBtn(c, 'w', 'Tutanlar'),
                          _tabBtn(c, 'l', 'Kaybedenler'),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),
                    if (shown.isEmpty)
                      Padding(
                        padding: const EdgeInsets.all(40),
                        child: Center(
                          child: Text(
                            _tab == 'k' ? 'Henüz paylaşılan kupon yok.' : _tab == 'w' ? 'Tutan kupon yok.' : 'Kaybeden kupon yok.',
                            textAlign: TextAlign.center,
                            style: jakarta(14, FontWeight.w600, c.mu),
                          ),
                        ),
                      ),
                    for (final x in shown) PostCard(key: ValueKey(x.id), post: x, following: mf.contains(x.uid)),
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _stat(AppColors c, String v, String l, VoidCallback? onTap) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(color: c.sf, borderRadius: BorderRadius.circular(16), border: Border.all(color: c.ln)),
          child: Column(
            children: [
              Text(v, style: jakarta(17, FontWeight.w800, c.ac)),
              Text(l, style: jakarta(11, FontWeight.w600, c.mu)),
              if (onTap != null) Container(margin: const EdgeInsets.only(top: 4), width: 16, height: 2, color: c.ac.withAlpha(120)),
            ],
          ),
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
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(color: on ? c.ac : Colors.transparent, borderRadius: BorderRadius.circular(12)),
          child: Text(label, textAlign: TextAlign.center, style: jakarta(13, FontWeight.w800, on ? c.on : c.mu)),
        ),
      ),
    );
  }
}

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
        if (p == null) return const SizedBox(height: 48);
        return ListTile(
          onTap: onOpen,
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 0),
          leading: Avatar(profile: p, size: 40),
          title: Text(p.name, style: jakarta(14, FontWeight.w800, c.tx)),
          subtitle: Text('@${p.handle}', style: jakarta(12, FontWeight.w600, c.mu)),
        );
      },
    );
  }
}
