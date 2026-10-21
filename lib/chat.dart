import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'auth_service.dart';
import 'feed.dart' show fmtStamp;
import 'settle.dart';
import 'theme.dart';

void openChat(BuildContext context) {
  final c = AppColors.of(context);
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: c.bg,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(26))),
    builder: (_) => const _ChatSheet(),
  );
}

class _ChatSheet extends StatefulWidget {
  const _ChatSheet();
  @override
  State<_ChatSheet> createState() => _ChatSheetState();
}

class _ChatSheetState extends State<_ChatSheet> {
  final _ctl = TextEditingController();
  Map<String, dynamic>? _reply;
  String? _editId;
  int _last = 0;
  final _db = FirebaseFirestore.instance;
  late final Stream<QuerySnapshot<Map<String, dynamic>>> _s = _db.collection('chat').orderBy('ts', descending: true).limit(150).snapshots();
  late final Stream<DocumentSnapshot<Map<String, dynamic>>> _lock = _db.collection('config').doc('chat').snapshots();
  String get _me => profileNotifier.value?.uid ?? '';

  @override
  void dispose() {
    _ctl.dispose();
    super.dispose();
  }

  void _toast(String t) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(t)));

  Future<void> _send() async {
    final t = _ctl.text.trim();
    final me = profileNotifier.value;
    if (t.isEmpty || me == null) return;
    final txt = t.length > 300 ? t.substring(0, 300) : t;
    try {
      if (_editId != null) {
        final id = _editId!;
        setState(() => _editId = null);
        _ctl.clear();
        await _db.collection('chat').doc(id).update({'t': txt, 'ed': true});
        return;
      }
      final now = DateTime.now().millisecondsSinceEpoch;
      if (now - _last < 1500) {
        _toast('Biraz yavaş yaz.');
        return;
      }
      _last = now;
      final rp = _reply;
      _ctl.clear();
      setState(() => _reply = null);
      await _db.collection('chat').add({
        'uid': me.uid,
        'n': me.name,
        't': txt,
        'ts': now,
        if (rp != null) 'r': {'id': rp['id'], 'n': rp['n'], 't': (rp['t'] ?? '').toString().length > 120 ? (rp['t'] as String).substring(0, 120) : rp['t']},
      });
    } catch (e) {
      _toast(AuthService.errorText(e));
    }
  }

  void _menu(String id, Map<String, dynamic> m, bool admin) {
    final c = AppColors.of(context);
    final mine = m['uid'] == _me;
    showModalBottomSheet(
      context: context,
      backgroundColor: c.bg,
      builder: (ctx) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          ListTile(
            leading: const Icon(Icons.reply),
            title: const Text('Yanıtla'),
            onTap: () {
              Navigator.pop(ctx);
              setState(() => _reply = {'id': id, 'n': m['n'], 't': m['t']});
            },
          ),
          ListTile(leading: const Icon(Icons.copy), title: const Text('Kopyala'), onTap: () {
            Clipboard.setData(ClipboardData(text: '${m['t'] ?? ''}'));
            Navigator.pop(ctx);
          }),
          if (mine)
            ListTile(
              leading: const Icon(Icons.edit_outlined),
              title: const Text('Düzenle'),
              onTap: () {
                Navigator.pop(ctx);
                setState(() {
                  _editId = id;
                  _reply = null;
                  _ctl.text = '${m['t'] ?? ''}';
                });
              },
            ),
          if (mine || admin)
            ListTile(
              leading: Icon(Icons.delete_outline, color: c.red),
              title: Text('Sil', style: TextStyle(color: c.red)),
              onTap: () {
                Navigator.pop(ctx);
                _db.collection('chat').doc(id).delete().catchError((e) => _toast(AuthService.errorText(e)));
              },
            ),
        ]),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final mqx = MediaQuery.of(context);
    // Klavye kapalıyken telefonun alt çubuğu kadar boşluk bırak (yazı alanı altında kalmasın)
    final kb = mqx.viewInsets.bottom > 0 ? mqx.viewInsets.bottom : mqx.viewPadding.bottom;
    return Padding(
      padding: EdgeInsets.only(bottom: kb),
      child: Column(children: [
        const SizedBox(height: 12),
        Row(children: [
          const SizedBox(width: 16),
          Text('Sohbet', style: jakarta(18, FontWeight.w800, c.tx)),
          const Spacer(),
          IconButton(onPressed: () => Navigator.pop(context), icon: Icon(Icons.close, color: c.mu)),
        ]),
        Expanded(
          child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: _s,
            builder: (context, snap) {
              if (snap.hasError) return Center(child: Text(AuthService.errorText(snap.error!), style: jakarta(14, FontWeight.w600, c.mu)));
              if (!snap.hasData) return Center(child: CircularProgressIndicator(color: c.ac));
              final docs = snap.data!.docs;
              if (docs.isEmpty) return Center(child: Text('Henüz mesaj yok. İlk mesajı sen yaz!', style: jakarta(14, FontWeight.w600, c.mu)));
              return ValueListenableBuilder<bool>(
                valueListenable: isAdminNotifier,
                builder: (context, admin, _) => ListView.builder(
                  reverse: true,
                  padding: const EdgeInsets.fromLTRB(12, 6, 12, 6),
                  itemCount: docs.length,
                  itemBuilder: (_, i) {
                    final d = docs[i];
                    final m = d.data();
                    final mine = m['uid'] == _me;
                    final rp = m['r'] is Map ? Map<String, dynamic>.from(m['r'] as Map) : null;
                    return GestureDetector(
                      onLongPress: () => _menu(d.id, m, admin),
                      child: Align(
                        alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
                        child: Container(
                          constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.78),
                          margin: const EdgeInsets.symmetric(vertical: 4),
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          decoration: BoxDecoration(color: mine ? c.ac.withAlpha(40) : c.sf, borderRadius: BorderRadius.circular(16), border: Border.all(color: c.ln)),
                          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            if (!mine) Text('${m['n'] ?? 'Kullanıcı'}', style: jakarta(12.5, FontWeight.w800, c.ac)),
                            if (rp != null)
                              Container(
                                margin: const EdgeInsets.only(bottom: 4),
                                padding: const EdgeInsets.all(6),
                                decoration: BoxDecoration(color: c.sf2, borderRadius: BorderRadius.circular(8)),
                                child: Text('${rp['n'] ?? ''}: ${rp['t'] ?? ''}', maxLines: 2, overflow: TextOverflow.ellipsis, style: jakarta(12, FontWeight.w600, c.mu)),
                              ),
                            Text('${m['t'] ?? ''}', style: jakarta(14.5, FontWeight.w600, c.tx)),
                            Text('${fmtStamp(((m['ts'] as num?) ?? 0).toInt())}${m['ed'] == true ? ' · düzenlendi' : ''}', style: jakarta(10.5, FontWeight.w500, c.mu)),
                          ]),
                        ),
                      ),
                    );
                  },
                ),
              );
            },
          ),
        ),
        if (_reply != null || _editId != null)
          Container(
            width: double.infinity,
            color: c.sf2,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            child: Row(children: [
              Expanded(child: Text(_editId != null ? 'Mesaj düzenleniyor' : '${_reply!['n']}: ${_reply!['t']}', maxLines: 1, overflow: TextOverflow.ellipsis, style: jakarta(12.5, FontWeight.w600, c.mu))),
              GestureDetector(onTap: () => setState(() {
                    _reply = null;
                    if (_editId != null) _ctl.clear();
                    _editId = null;
                  }), child: Icon(Icons.close, size: 18, color: c.mu)),
            ]),
          ),
        StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
          stream: _lock,
          builder: (context, ls) {
            final locked = ls.data?.data()?['locked'] == true && !isAdminNotifier.value;
            return Container(
              padding: const EdgeInsets.fromLTRB(14, 6, 6, 10),
              decoration: BoxDecoration(border: Border(top: BorderSide(color: c.ln))),
              child: Row(children: [
                Expanded(
                  child: TextField(
                    controller: _ctl,
                    enabled: !locked,
                    maxLength: 300,
                    minLines: 1,
                    maxLines: 4,
                    style: jakarta(14.5, FontWeight.w600, c.tx),
                    decoration: InputDecoration(border: InputBorder.none, counterText: '', hintText: locked ? 'Sohbet kilitli' : 'Mesaj yaz...', hintStyle: jakarta(14, FontWeight.w500, c.mu)),
                  ),
                ),
                IconButton(onPressed: locked ? null : _send, icon: Icon(Icons.send_rounded, color: c.ac)),
              ]),
            );
          },
        ),
      ]),
    );
  }
}
