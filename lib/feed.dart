import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import 'auth_service.dart';
import 'bets.dart';
import 'scoring.dart';
import 'profile.dart';
import 'shell.dart' show IconBox;
import 'theme.dart';

FirebaseFirestore get _db => FirebaseFirestore.instance;
String get _myUid => profileNotifier.value?.uid ?? '';

const _aylar = ['Oca', 'Şub', 'Mar', 'Nis', 'May', 'Haz', 'Tem', 'Ağu', 'Eyl', 'Eki', 'Kas', 'Ara'];
String fmtStamp(int ts) {
  if (ts <= 0) return '';
  final d = DateTime.fromMillisecondsSinceEpoch(ts);
  String two(int n) => n.toString().padLeft(2, '0');
  return '${d.day} ${_aylar[d.month - 1]} ${d.year} · ${two(d.hour)}:${two(d.minute)}';
}

void _toast(BuildContext c, String t) {
  ScaffoldMessenger.of(c)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(t)));
}

/* ---------------- Veri ---------------- */

class Post {
  final String id;
  final Map<String, dynamic> d;
  Post(this.id, this.d);

  String get uid => (d['uid'] ?? '').toString();
  String get authorName => (d['authorName'] ?? '').toString();
  int get ts => (d['ts'] as num?)?.toInt() ?? 0;
  String get text => (d['text'] ?? '').toString();
  bool get hidden => d['adminHidden'] == true;
  List<String> get likedBy => ((d['likedBy'] as List?) ?? const []).map((e) => e.toString()).toList();
  int get likes => likedBy.length;
  List<Map<String, dynamic>> get comments =>
      ((d['comments'] as List?) ?? const []).whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();
  Map<String, dynamic>? get coupon {
    if (d['coupon'] is! Map) return null;
    final m = Map<String, dynamic>.from(d['coupon'] as Map);
    if ((m['iso'] ?? '').toString().isEmpty && ts > 0) {
      final t = DateTime.fromMillisecondsSinceEpoch(ts);
      m['iso'] = '${t.year}-${t.month.toString().padLeft(2, '0')}-${t.day.toString().padLeft(2, '0')}';
    }
    return m;
  }
}

class _Profiles {
  static final Map<String, Future<Profile?>> _m = {};
  static Future<Profile?> of(String uid) {
    if (uid.isEmpty) return Future.value(null);
    return _m.putIfAbsent(uid, () => AuthService.loadProfile(uid));
  }
}

String _ckey(Map<String, dynamic> m) => '${m['uid'] ?? ''}|${m['ts']}';

/* ---------------- İşlemler ---------------- */

int _nextMidnight() {
  final n = DateTime.now();
  return DateTime(n.year, n.month, n.day + 1).millisecondsSinceEpoch;
}

/// Web ile aynı bildirim belgesi (notifs koleksiyonu).
Future<void> _notifSet(String id, String type, String to, Post? p, String tx) async {
  final me = profileNotifier.value;
  if (me == null || to.isEmpty || to == me.uid) return;
  if (type != 'follow' && p == null) return;
  try {
    await _db.collection('notifs').doc(id.replaceAll('/', '_')).set({
      'to': to,
      'from': me.uid,
      'fn': me.name,
      'type': type,
      'pid': p?.ts ?? '',
      'pd': p?.id ?? '',
      'ts': DateTime.now().millisecondsSinceEpoch,
      'exp': Timestamp.fromMillisecondsSinceEpoch(_nextMidnight()),
      'tx': tx.length > 80 ? tx.substring(0, 80) : tx,
    });
  } catch (_) {}
}

Future<void> _notifDel(String id) async {
  try {
    await _db.collection('notifs').doc(id.replaceAll('/', '_')).delete();
  } catch (_) {}
}

Future<void> _toggleLike(Post p) async {
  final on = !p.likedBy.contains(_myUid);
  await _db.collection('posts').doc(p.id).update({
    'likedBy': on ? FieldValue.arrayUnion([_myUid]) : FieldValue.arrayRemove([_myUid]),
  });
  final nid = 'like_${p.id}_$_myUid';
  if (on) {
    _notifSet(nid, 'like', p.uid, p, '');
  } else {
    _notifDel(nid);
  }
}

Future<void> _toggleFollow(String targetUid, bool following) async {
  final on = !following;
  await _db.collection('users').doc(_myUid).update({
    'following': on ? FieldValue.arrayUnion([targetUid]) : FieldValue.arrayRemove([targetUid]),
    'fts.$targetUid': on ? DateTime.now().millisecondsSinceEpoch : FieldValue.delete(),
  });
  if (on) _notifSet('follow_${_myUid}_${targetUid}_${DateTime.now().millisecondsSinceEpoch}', 'follow', targetUid, null, '');
}

Future<void> _editComments(String postId, List<dynamic> Function(List<dynamic>) fn) async {
  final ref = _db.collection('posts').doc(postId);
  await _db.runTransaction((t) async {
    final s = await t.get(ref);
    if (!s.exists) return;
    final arr = ((s.data()!['comments'] as List?) ?? const []).toList();
    t.update(ref, {'comments': fn(arr)});
  });
}

Future<void> toggleFollow(String t, bool f) => _toggleFollow(t, f);

/* ---------------- Akış sayfası ---------------- */

class FeedPage extends StatefulWidget {
  const FeedPage({super.key});
  @override
  State<FeedPage> createState() => _FeedPageState();
}

class _FeedPageState extends State<FeedPage> {
  String _filter = 'all';
  final _ctl = TextEditingController();
  bool _busy = false;

  late final Stream<QuerySnapshot<Map<String, dynamic>>> _posts =
      _db.collection('posts').orderBy('ts', descending: true).limit(100).snapshots();
  late final Stream<DocumentSnapshot<Map<String, dynamic>>> _me = _db.collection('users').doc(_myUid).snapshots();

  @override
  void dispose() {
    _ctl.dispose();
    super.dispose();
  }

  Future<void> _share() async {
    final t = _ctl.text.trim();
    final me = profileNotifier.value;
    if (t.isEmpty || _busy || me == null) return;
    setState(() => _busy = true);
    try {
      final ts = DateTime.now().millisecondsSinceEpoch;
      await _db.collection('posts').doc('${ts}_${me.uid}').set({
        'uid': me.uid,
        'authorName': me.name,
        'handle': me.handle,
        'ts': ts,
        'text': t.length > 500 ? t.substring(0, 500) : t,
        'coupon': null,
        'likedBy': <String>[],
        'comments': <Map<String, dynamic>>[],
      });
      _ctl.clear();
      if (mounted) FocusScope.of(context).unfocus();
    } catch (e) {
      if (mounted) _toast(context, AuthService.errorText(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: _me,
      builder: (context, meSnap) {
        final following = ((meSnap.data?.data()?['following'] as List?) ?? const []).map((e) => e.toString()).toSet();
        return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: _posts,
          builder: (context, snap) {
            if (snap.hasError) {
              return Center(child: Text(AuthService.errorText(snap.error!), style: jakarta(14, FontWeight.w600, c.mu)));
            }
            if (!snap.hasData) return Center(child: CircularProgressIndicator(color: c.ac));
            var list = snap.data!.docs.map((d) => Post(d.id, d.data())).where((p) => !p.hidden).toList();
            if (_filter == 'mine') list = list.where((p) => p.uid == _myUid).toList();
            if (_filter == 'follow') list = list.where((p) => following.contains(p.uid)).toList();
            final head = <Widget>[
              _composer(c),
              const SizedBox(height: 12),
              Row(children: [
                _chip(c, 'all', 'Akış', Icons.home_outlined),
                const SizedBox(width: 8),
                _chip(c, 'mine', 'Paylaştıklarım', Icons.person_outline),
                const SizedBox(width: 8),
                _chip(c, 'follow', 'Takip', Icons.favorite_border),
              ]),
              const SizedBox(height: 14),
              if (list.isEmpty)
                Padding(
                  padding: const EdgeInsets.all(28),
                  child: Text(
                    _filter == 'follow'
                        ? 'Takip ettiğin kimsenin paylaşımı yok.'
                        : _filter == 'mine'
                            ? 'Henüz bir şey paylaşmadın.'
                            : 'Henüz paylaşım yok. İlk paylaşımı sen yap!',
                    textAlign: TextAlign.center,
                    style: jakarta(14, FontWeight.w600, c.mu),
                  ),
                ),
            ];
            // Tembel liste: yalnızca ekrandaki kartlar oluşturulur
            return ListView.builder(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 24),
              cacheExtent: 600,
              itemCount: head.length + list.length,
              itemBuilder: (context, i) {
                if (i < head.length) return head[i];
                final p = list[i - head.length];
                return RepaintBoundary(
                  key: ValueKey(p.id),
                  child: PostCard(key: ValueKey(p.id), post: p, following: following.contains(p.uid)),
                );
              },
            );
          },
        );
      },
    );
  }

  Widget _chip(AppColors c, String k, String label, IconData ic) {
    final on = _filter == k;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _filter = k),
        child: Container(
          height: 42,
          decoration: BoxDecoration(
            color: on ? c.ac.withAlpha(30) : c.sf,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: on ? c.ac : c.ln),
          ),
          child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            Icon(ic, size: 17, color: c.ac),
            const SizedBox(width: 5),
            Flexible(
              child: Text(label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: jakarta(12.5, FontWeight.w700, on ? c.ac : c.tx)),
            ),
          ]),
        ),
      ),
    );
  }

  Widget _composer(AppColors c) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 6, 8, 6),
      decoration: BoxDecoration(
        color: c.sf,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: c.ln),
      ),
      child: Row(children: [
        Expanded(
          child: TextField(
            controller: _ctl,
            maxLength: 500,
            maxLines: 3,
            minLines: 1,
            style: jakarta(14, FontWeight.w600, c.tx),
            decoration: InputDecoration(
              border: InputBorder.none,
              counterText: '',
              hintText: 'Bankonu yaz...',
              hintStyle: jakarta(14, FontWeight.w500, c.mu),
            ),
          ),
        ),
        TextButton(
          onPressed: _busy ? null : _share,
          child: Text('Paylaş', style: jakarta(14, FontWeight.w800, c.ac)),
        ),
      ]),
    );
  }
}

/* ---------------- Paylaşım kartı ---------------- */

class PostCard extends StatelessWidget {
  final Post post;
  final bool following;
  const PostCard({super.key, required this.post, required this.following});

  Future<void> _delete(BuildContext context) async {
    final c = AppColors.of(context);
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: c.sf,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
        title: Text('Paylaşımı sil', style: jakarta(17, FontWeight.w800, c.tx)),
        content: Text('Bu paylaşımı silmek istediğine emin misin?', style: jakarta(14, FontWeight.w500, c.mu)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text('Vazgeç', style: jakarta(14, FontWeight.w700, c.mu))),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: Text('Sil', style: jakarta(14, FontWeight.w800, c.red))),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await _db.collection('posts').doc(post.id).delete();
    } catch (e) {
      if (context.mounted) _toast(context, AuthService.errorText(e));
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final p = post;
    final liked = p.likedBy.contains(_myUid);
    final mine = p.uid == _myUid;
    final cp = p.coupon;
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: c.sf,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: c.ln),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        FutureBuilder<Profile?>(
          future: _Profiles.of(p.uid),
          builder: (context, s) {
            final pr = s.data;
            void open() {
              if (p.uid.isNotEmpty) Navigator.push(context, MaterialPageRoute(builder: (_) => ProfileRoute(uid: p.uid)));
            }
            return Row(children: [
              GestureDetector(onTap: open, child: Avatar(profile: pr, size: 44)),
              const SizedBox(width: 10),
              Expanded(
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: open,
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(p.authorName.isNotEmpty ? p.authorName : (pr?.name ?? '...'),
                      maxLines: 1, overflow: TextOverflow.ellipsis, style: jakarta(15, FontWeight.w800, c.tx)),
                  Text(fmtStamp(p.ts), style: jakarta(12, FontWeight.w500, c.mu)),
                ]),
                ),
              ),
              if (!mine && p.uid.isNotEmpty)
                GestureDetector(
                  onTap: () => _toggleFollow(p.uid, following).catchError((e) {
                    if (context.mounted) _toast(context, AuthService.errorText(e));
                  }),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
                    decoration: BoxDecoration(
                      color: following ? c.sf2 : c.ac,
                      borderRadius: BorderRadius.circular(14),
                      border: following ? Border.all(color: c.ln) : null,
                    ),
                    child: Text(following ? 'Takipte' : 'Takip Et',
                        style: jakarta(13, FontWeight.w800, following ? c.mu : c.on)),
                  ),
                ),
              if (mine && cp == null) ...[
                const SizedBox(width: 6),
                IconBox(icon: Icons.delete_outline, size: 38, onTap: () => _delete(context)),
              ],
            ]);
          },
        ),
        if (p.text.isNotEmpty) ...[
          const SizedBox(height: 10),
          Text(p.text, style: jakarta(15, FontWeight.w700, c.tx)),
        ],
        if (cp != null) ...[const SizedBox(height: 10), _CouponView(cp)],
        const SizedBox(height: 10),
        Row(children: [
          _act(c, liked ? Icons.favorite : Icons.favorite_border, '${p.likes}', liked ? c.red : c.mu, () {
            _toggleLike(p).catchError((e) {
              if (context.mounted) _toast(context, AuthService.errorText(e));
            });
          }),
          const SizedBox(width: 18),
          _act(c, Icons.chat_bubble_outline, '${p.comments.length}', c.mu, () => openComments(context, p.id, p.uid)),
        ]),
      ]),
    );
  }

  Widget _act(AppColors c, IconData ic, String n, Color col, VoidCallback onTap) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(children: [
          Icon(ic, size: 22, color: col),
          const SizedBox(width: 5),
          Text(n, style: jakarta(14, FontWeight.w700, col)),
        ]),
      ),
    );
  }
}

/* ---------------- Kupon görünümü ---------------- */

class _CouponView extends StatelessWidget {
  final Map<String, dynamic> cp;
  const _CouponView(this.cp);

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final legs = ((cp['legs'] as List?) ?? const []).whereType<Map>().toList();
    final ord = (cp['ord'] ?? '').toString();
    final head = '${cp['city'] ?? ''} · ${ord.isNotEmpty && ord != '0' ? '$ord. ' : ''}${cp['type'] ?? ''}';
    final st = couponStatus(cp).k;
    final stCol = st == 'win' ? const Color(0xFF16A34A) : st == 'lose' ? c.red : c.mu;
    final stTxt = st == 'win' ? 'Tuttu' : st == 'lose' ? 'Yattı' : st == 'live' ? 'Sürüyor' : 'Bekliyor';
    final k = kolon(cp);
    final misli = ((cp['misli'] as num?) ?? 1).toInt();
    final bf = birimFiyat((cp['type'] ?? '').toString(), (cp['city'] ?? '').toString());
    final slotted = legs.any((l) => l['slot'] != null);
    return Container(
      decoration: BoxDecoration(color: c.sf2, borderRadius: BorderRadius.circular(16), border: Border.all(color: c.ln)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 8),
          child: Row(children: [
            Expanded(child: Text(head, style: jakarta(14, FontWeight.w800, c.ac))),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
              decoration: BoxDecoration(color: stCol.withAlpha(30), borderRadius: BorderRadius.circular(10)),
              child: Text(stTxt, style: jakarta(11.5, FontWeight.w800, stCol)),
            ),
          ]),
        ),
        if (legs.isNotEmpty)
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              for (final l in legs)
                Container(
                  width: 58,
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  decoration: BoxDecoration(border: Border(top: BorderSide(color: c.ln))),
                  child: Column(children: [
                    Text(slotted ? '${((l['slot'] as num?) ?? 0).toInt() + 1}. At' : '${l['r'] ?? ''}. Koşu', style: jakarta(11, FontWeight.w800, c.tx)),
                    Text('${l['t'] ?? ''}', style: jakarta(10.5, FontWeight.w500, c.mu)),
                    const SizedBox(height: 4),
                    for (final n in ((l['picks'] as List?) ?? const []))
                      Builder(builder: (_) {
                        final r = legSt(cp, l);
                        final res = (l['res'] as List?)?.whereType<num>().map((e) => e.toInt()).toList();
                        final hit = r != 'p' && res != null ? res.take(cp['rule'] == 'pl2' ? 3 : (cp['rule'] == 'place' || cp['rule'] == 'gp') ? 2 : 1).contains(n) : false;
                        return Container(
                          margin: const EdgeInsets.only(bottom: 4),
                          width: 30,
                          height: 26,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: hit ? const Color(0xFF16A34A) : c.sf,
                            borderRadius: BorderRadius.circular(13),
                            border: Border.all(color: hit ? const Color(0xFF16A34A) : c.ln),
                          ),
                          child: Text('$n', style: jakarta(13, FontWeight.w800, hit ? Colors.white : c.tx)),
                        );
                      }),
                  ]),
                ),
            ]),
          ),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 10),
          decoration: BoxDecoration(border: Border(top: BorderSide(color: c.ln))),
          child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            Flexible(child: Text('$k kolon × ${money(bf)} × $misli misli', style: jakarta(12.5, FontWeight.w700, c.ac))),
            Text(money(k * bf * misli), style: jakarta(14.5, FontWeight.w800, c.tx)),
          ]),
        ),
      ]),
    );
  }
}

/* ---------------- Yorumlar ---------------- */

void openComments(BuildContext context, String postId, String postOwner) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: AppColors.of(context).bg,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(26))),
    builder: (_) => _CommentsSheet(postId: postId, postOwner: postOwner),
  );
}

class _CommentsSheet extends StatefulWidget {
  final String postId, postOwner;
  const _CommentsSheet({required this.postId, required this.postOwner});
  @override
  State<_CommentsSheet> createState() => _CommentsSheetState();
}

class _CommentsSheetState extends State<_CommentsSheet> {
  final _ctl = TextEditingController();
  Map<String, String>? _reply; // {key, name}
  late final Stream<DocumentSnapshot<Map<String, dynamic>>> _s = _db.collection('posts').doc(widget.postId).snapshots();

  @override
  void dispose() {
    _ctl.dispose();
    super.dispose();
  }

  Post _post([Map<String, dynamic>? d]) => Post(widget.postId, d ?? {'uid': widget.postOwner, 'ts': int.tryParse(widget.postId.split('_').first) ?? 0});

  Future<void> _add() async {
    final txt = _ctl.text.trim();
    final me = profileNotifier.value;
    if (txt.isEmpty || me == null) return;
    final t = txt.length > 500 ? txt.substring(0, 500) : txt;
    final ts = DateTime.now().millisecondsSinceEpoch;
    final rp = _reply?['key'] ?? '';
    final rn = _reply?['name'] ?? '';
    _ctl.clear();
    setState(() => _reply = null);
    try {
      await _db.collection('posts').doc(widget.postId).update({
        'comments': FieldValue.arrayUnion([
          {
            'uid': me.uid,
            'n': me.name,
            't': t,
            'ts': ts,
            'likedBy': <String>[],
            if (rp.isNotEmpty) 'rp': rp,
            if (rp.isNotEmpty) 'rn': rn.length > 60 ? rn.substring(0, 60) : rn,
          }
        ]),
      });
      final p = _post();
      final base = 'cm_${widget.postId}_${ts}_${me.uid}';
      final rTo = rp.isEmpty ? '' : rp.split('|').first;
      if (rTo.isNotEmpty) _notifSet('${base}_r', 'reply', rTo, p, t);
      if (widget.postOwner.isNotEmpty && widget.postOwner != rTo) _notifSet(base, 'comment', widget.postOwner, p, t);
    } catch (e) {
      if (mounted) _toast(context, AuthService.errorText(e));
    }
  }

  Future<void> _like(Map<String, dynamic> cm) async {
    final key = _ckey(cm);
    final on = !((cm['likedBy'] as List?) ?? const []).map((e) => e.toString()).contains(_myUid);
    await _editComments(widget.postId, (arr) => arr.map((x) {
          if (x is! Map || _ckey(Map<String, dynamic>.from(x)) != key) return x;
          final m = Map<String, dynamic>.from(x);
          final lb = ((m['likedBy'] as List?) ?? const []).map((e) => e.toString()).where((u) => u != _myUid).toList();
          if (on) lb.add(_myUid);
          m['likedBy'] = lb;
          return m;
        }).toList());
    final nid = 'cl_${widget.postId}_${key.replaceAll('|', '-')}_$_myUid';
    final to = (cm['uid'] ?? '').toString();
    if (on) {
      _notifSet(nid, 'cmlike', to, _post(), (cm['t'] ?? '').toString());
    } else {
      _notifDel(nid);
    }
  }

  Future<void> _del(Map<String, dynamic> cm) {
    final key = _ckey(cm);
    return _editComments(widget.postId, (arr) => arr.where((x) {
          if (x is! Map) return true;
          final m = Map<String, dynamic>.from(x);
          return _ckey(m) != key && (m['rp'] ?? '') != key;
        }).toList());
  }

  Widget _item(AppColors c, Map<String, dynamic> m, {required bool reply}) {
    final lb = ((m['likedBy'] as List?) ?? const []).map((e) => e.toString()).toList();
    final liked = lb.contains(_myUid);
    final canDel = (m['uid'] ?? '') == _myUid || widget.postOwner == _myUid;
    final name = (m['n'] ?? 'Kullanıcı').toString();
    return Padding(
      padding: EdgeInsets.only(left: reply ? 28 : 0, top: 8, bottom: 8),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Flexible(child: Text(name, maxLines: 1, overflow: TextOverflow.ellipsis, style: jakarta(13.5, FontWeight.w800, c.tx))),
              const SizedBox(width: 8),
              Text(fmtStamp((m['ts'] as num?)?.toInt() ?? 0), style: jakarta(11, FontWeight.w500, c.mu)),
            ]),
            const SizedBox(height: 2),
            Text.rich(TextSpan(children: [
              if (reply && (m['rn'] ?? '').toString().isNotEmpty)
                TextSpan(text: '@${m['rn']} ', style: jakarta(14, FontWeight.w800, c.ac)),
              TextSpan(text: '${m['t'] ?? ''}', style: jakarta(14, FontWeight.w600, c.tx)),
            ])),
            Row(children: [
              GestureDetector(
                onTap: () {
                  final top = reply ? (m['rp'] ?? '').toString() : _ckey(m);
                  setState(() => _reply = {'key': top, 'name': name});
                },
                child: Padding(
                  padding: const EdgeInsets.only(top: 4, right: 14),
                  child: Text('Yanıtla', style: jakarta(12, FontWeight.w700, c.mu)),
                ),
              ),
              if (canDel)
                GestureDetector(
                  onTap: () => _del(m),
                  child: Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text('Sil', style: jakarta(12, FontWeight.w700, c.red)),
                  ),
                ),
            ]),
          ]),
        ),
        GestureDetector(
          onTap: () => _like(m),
          child: Column(children: [
            Icon(liked ? Icons.favorite : Icons.favorite_border, size: 18, color: liked ? c.red : c.mu),
            if (lb.isNotEmpty) Text('${lb.length}', style: jakarta(11, FontWeight.w700, c.mu)),
          ]),
        ),
      ]),
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final kb = MediaQuery.of(context).viewInsets.bottom;
    return Padding(
      padding: EdgeInsets.only(bottom: kb),
      child: SizedBox(
        height: MediaQuery.of(context).size.height * 0.7,
        child: Column(children: [
          const SizedBox(height: 10),
          Container(width: 40, height: 4, decoration: BoxDecoration(color: c.ln, borderRadius: BorderRadius.circular(2))),
          const SizedBox(height: 10),
          Text('Yorumlar', style: jakarta(16, FontWeight.w800, c.tx)),
          const SizedBox(height: 6),
          Expanded(
            child: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
              stream: _s,
              builder: (context, snap) {
                if (!snap.hasData) return Center(child: CircularProgressIndicator(color: c.ac));
                final all = _post(snap.data!.data() ?? {}).comments;
                final keys = all.map(_ckey).toSet();
                final tops = all.where((m) => !keys.contains((m['rp'] ?? '').toString())).toList();
                if (tops.isEmpty) {
                  return Center(child: Text('Henüz yorum yok.', style: jakarta(14, FontWeight.w600, c.mu)));
                }
                final rows = <Widget>[];
                for (final t in tops) {
                  rows.add(_item(c, t, reply: false));
                  for (final r in all.where((m) => (m['rp'] ?? '').toString() == _ckey(t))) {
                    rows.add(_item(c, r, reply: true));
                  }
                }
                return ListView(padding: const EdgeInsets.symmetric(horizontal: 16), children: rows);
              },
            ),
          ),
          if (_reply != null)
            Container(
              width: double.infinity,
              color: c.sf2,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              child: Row(children: [
                Expanded(child: Text('@${_reply!['name']} kişisine yanıt veriyorsun', style: jakarta(12.5, FontWeight.w600, c.mu))),
                GestureDetector(onTap: () => setState(() => _reply = null), child: Icon(Icons.close, size: 18, color: c.mu)),
              ]),
            ),
          Container(
            padding: const EdgeInsets.fromLTRB(16, 6, 8, 10),
            decoration: BoxDecoration(border: Border(top: BorderSide(color: c.ln))),
            child: Row(children: [
              Expanded(
                child: TextField(
                  controller: _ctl,
                  maxLength: 500,
                  style: jakarta(14, FontWeight.w600, c.tx),
                  decoration: InputDecoration(
                    border: InputBorder.none,
                    counterText: '',
                    hintText: _reply == null ? 'Yorum yaz...' : 'Yanıtını yaz...',
                    hintStyle: jakarta(14, FontWeight.w500, c.mu),
                  ),
                  onSubmitted: (_) => _add(),
                ),
              ),
              IconButton(onPressed: _add, icon: Icon(Icons.send_rounded, color: c.ac)),
            ]),
          ),
        ]),
      ),
    );
  }
}
