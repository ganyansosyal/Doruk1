import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';

import 'auth_service.dart';
import 'firebase_options.dart';
import 'shell.dart';
import 'theme.dart';

/* ---------------- Oturum kapısı ---------------- */

class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    if (!firebaseReady) {
      return _Message(title: 'Sunucuya bağlanılamadı', text: firebaseProblem);
    }
    return ValueListenableBuilder<bool>(
      valueListenable: AuthService.busy,
      builder: (_, busy, __) => StreamBuilder<User?>(
        stream: FirebaseAuth.instance.authStateChanges(),
        builder: (_, snap) {
          if (snap.connectionState == ConnectionState.waiting) return const _Loading();
          final user = snap.data;
          if (user == null || busy) return const AuthPage();
          return _ProfileGate(key: ValueKey(user.uid), user: user);
        },
      ),
    );
  }
}

class _ProfileGate extends StatefulWidget {
  final User user;
  const _ProfileGate({super.key, required this.user});

  @override
  State<_ProfileGate> createState() => _ProfileGateState();
}

class _ProfileGateState extends State<_ProfileGate> {
  late Future<Profile> _f = AuthService.bootstrap(widget.user);

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return FutureBuilder<Profile>(
      future: _f,
      builder: (_, s) {
        if (s.hasData) {
          // Profil fotoğrafı olmayan herkes (e-posta / Google, yeni / eski hesap) fotoğraf ekleyene kadar uygulamaya geçemez
          return ValueListenableBuilder<Profile?>(
            valueListenable: profileNotifier,
            builder: (_, pn, __) {
              final p = (pn != null && pn.uid == widget.user.uid) ? pn : s.data!;
              if (p.photo.isEmpty) return _PhotoGate(profile: p);
              return const Shell();
            },
          );
        }
        if (s.hasError) {
          return _Message(
            title: 'Profil yüklenemedi',
            text: AuthService.errorText(s.error!),
            actions: [
              TextButton(
                onPressed: () => setState(() => _f = AuthService.bootstrap(widget.user)),
                child: Text('Tekrar dene', style: jakarta(14, FontWeight.w800, c.ac)),
              ),
              TextButton(
                onPressed: AuthService.signOut,
                child: Text('Çıkış yap', style: jakarta(14, FontWeight.w800, c.red)),
              ),
            ],
          );
        }
        return const _Loading();
      },
    );
  }
}

/* ---------------- Profil fotoğrafı zorunlu ---------------- */

class _PhotoGate extends StatefulWidget {
  final Profile profile;
  const _PhotoGate({required this.profile});

  @override
  State<_PhotoGate> createState() => _PhotoGateState();
}

class _PhotoGateState extends State<_PhotoGate> {
  String _photo = '';
  Uint8List? _bytes;
  bool _busy = false, _bad = false;
  String? _err;

  Future<void> _pick() async {
    try {
      final x = await ImagePicker().pickImage(
        source: ImageSource.gallery,
        maxWidth: 400,
        maxHeight: 400,
        imageQuality: 75,
      );
      if (x == null) return;
      final bytes = await x.readAsBytes();
      if (!mounted) return;
      setState(() {
        _bytes = bytes;
        _photo = 'data:image/jpeg;base64,${base64Encode(bytes)}';
        _bad = false;
        _err = null;
      });
    } catch (_) {
      if (mounted) setState(() => _err = 'Fotoğraf yüklenemedi, başka bir tane dene.');
    }
  }

  Future<void> _save() async {
    if (_photo.isEmpty) {
      setState(() {
        _bad = true;
        _err = 'Profil fotoğrafı eklemeden devam edemezsin.';
      });
      return;
    }
    setState(() {
      _busy = true;
      _err = null;
    });
    try {
      await AuthService.savePhoto(widget.profile.uid, _photo);
    } catch (e) {
      if (mounted) setState(() => _err = AuthService.errorText(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final has = _bytes != null;
    return Scaffold(
      backgroundColor: c.bg,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 360),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text('Profil fotoğrafı ekle', textAlign: TextAlign.center, style: jakarta(22, FontWeight.w800, c.tx)),
                  const SizedBox(height: 8),
                  Text(
                    'Merhaba ${widget.profile.name}! Devam etmek için profil fotoğrafı eklemelisin.',
                    textAlign: TextAlign.center,
                    style: jakarta(14, FontWeight.w500, c.mu).copyWith(height: 1.45),
                  ),
                  const SizedBox(height: 18),
                  Center(
                    child: GestureDetector(
                      onTap: _busy ? null : _pick,
                      child: Container(
                        width: 150,
                        height: 150,
                        clipBehavior: Clip.antiAlias,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: c.sf,
                          border: Border.all(color: _bad ? c.red : (has ? c.ac : c.ln), width: 3),
                        ),
                        child: has
                            ? Image.memory(_bytes!, fit: BoxFit.cover)
                            : Icon(Icons.camera_alt_outlined, size: 54, color: c.mu),
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),
                  SizedBox(
                    height: 20,
                    child: Text(_err ?? '', textAlign: TextAlign.center, style: jakarta(13, FontWeight.w700, c.red)),
                  ),
                  const SizedBox(height: 10),
                  SizedBox(
                    height: 48,
                    child: OutlinedButton(
                      onPressed: _busy ? null : _pick,
                      style: OutlinedButton.styleFrom(
                        side: BorderSide(color: c.ln, width: 1.4),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                      child: Text(has ? 'Başka fotoğraf seç' : 'Fotoğraf seç', style: jakarta(14.5, FontWeight.w800, c.tx)),
                    ),
                  ),
                  const SizedBox(height: 10),
                  SizedBox(
                    height: 48,
                    child: FilledButton(
                      onPressed: _busy ? null : _save,
                      style: FilledButton.styleFrom(
                        backgroundColor: c.ac,
                        foregroundColor: c.on,
                        disabledBackgroundColor: c.ac.withAlpha(150),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                      child: _busy
                          ? SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2.4, color: c.on))
                          : Text('Kaydet ve devam et', style: jakarta(14.5, FontWeight.w800, c.on)),
                    ),
                  ),
                  const SizedBox(height: 6),
                  TextButton(
                    onPressed: _busy ? null : AuthService.signOut,
                    child: Text('Çıkış yap', style: jakarta(13, FontWeight.w700, c.mu)),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Loading extends StatelessWidget {
  const _Loading();

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return Scaffold(backgroundColor: c.bg, body: Center(child: CircularProgressIndicator(color: c.ac)));
  }
}

class _Message extends StatelessWidget {
  final String title, text;
  final List<Widget> actions;
  const _Message({required this.title, required this.text, this.actions = const []});

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return Scaffold(
      backgroundColor: c.bg,
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.cloud_off_outlined, size: 40, color: c.mu),
              const SizedBox(height: 12),
              Text(title, textAlign: TextAlign.center, style: jakarta(18, FontWeight.w800, c.tx)),
              const SizedBox(height: 8),
              Text(text, textAlign: TextAlign.center, style: jakarta(14, FontWeight.w500, c.mu)),
              if (actions.isNotEmpty) ...[
                const SizedBox(height: 12),
                Wrap(alignment: WrapAlignment.center, children: actions),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/* ---------------- Giriş / Kayıt ekranı ---------------- */

class AuthPage extends StatefulWidget {
  const AuthPage({super.key});

  @override
  State<AuthPage> createState() => _AuthPageState();
}

class _AuthPageState extends State<AuthPage> {
  bool _reg = false, _busy = false, _show = false;
  String? _err;
  String _photo = '';
  Uint8List? _bytes;
  String _hint = '';
  bool? _hintOk;
  Timer? _deb;

  final _id = TextEditingController();
  final _lpw = TextEditingController();
  final _name = TextEditingController();
  final _handle = TextEditingController();
  final _email = TextEditingController();
  final _rpw = TextEditingController();
  final _rpw2 = TextEditingController();

  @override
  void dispose() {
    _deb?.cancel();
    for (final t in [_id, _lpw, _name, _handle, _email, _rpw, _rpw2]) {
      t.dispose();
    }
    super.dispose();
  }

  void _toast(String t) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(t)));
  }

  void _setReg(bool v) => setState(() {
        _reg = v;
        _err = null;
      });

  Future<void> _pick() async {
    try {
      final x = await ImagePicker().pickImage(
        source: ImageSource.gallery,
        maxWidth: 400,
        maxHeight: 400,
        imageQuality: 75,
      );
      if (x == null) return;
      final bytes = await x.readAsBytes();
      if (!mounted) return;
      setState(() {
        _bytes = bytes;
        _photo = 'data:image/jpeg;base64,${base64Encode(bytes)}';
      });
    } catch (_) {
      if (mounted) _toast('Fotoğraf seçilemedi.');
    }
  }

  void _onHandle(String v) {
    _deb?.cancel();
    final h = cleanHandle(v);
    if (h.isEmpty) {
      setState(() {
        _hint = '';
        _hintOk = null;
      });
      return;
    }
    if (h.length < handleMin) {
      setState(() {
        _hint = 'En az $handleMin karakter.';
        _hintOk = false;
      });
      return;
    }
    setState(() {
      _hint = 'Kontrol ediliyor…';
      _hintOk = null;
    });
    _deb = Timer(const Duration(milliseconds: 500), () async {
      try {
        final taken = await AuthService.handleTaken(h);
        if (!mounted || cleanHandle(_handle.text) != h) return;
        setState(() {
          _hint = taken ? '@$h kullanılmakta.' : '@$h müsait.';
          _hintOk = !taken;
        });
      } catch (_) {
        if (mounted) {
          setState(() {
            _hint = '';
            _hintOk = null;
          });
        }
      }
    });
  }

  String? _validate() {
    if (!_reg) {
      if (_id.text.trim().isEmpty) return 'Kullanıcı adı veya e-posta yaz.';
      if (_lpw.text.isEmpty) return 'Şifreni yaz.';
      return null;
    }
    if (_photo.isEmpty) return 'Profil fotoğrafı zorunlu.';
    if (_name.text.trim().length < 2) return 'Görünen ad en az 2 karakter olmalı.';
    final h = cleanHandle(_handle.text);
    if (h.length < handleMin) return 'Kullanıcı adı en az $handleMin karakter olmalı.';
    if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(_email.text.trim())) {
      return 'Geçerli bir e-posta adresi yaz.';
    }
    if (_rpw.text.length < 6) return 'Şifre en az 6 karakter olmalı.';
    if (_rpw.text != _rpw2.text) return 'Şifreler aynı değil.';
    return null;
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    final err = _validate();
    if (err != null) {
      setState(() => _err = err);
      return;
    }
    setState(() {
      _err = null;
      _busy = true;
    });
    try {
      if (_reg) {
        await AuthService.register(
          name: _name.text.trim().replaceAll(RegExp(r'\s+'), ' '),
          handle: cleanHandle(_handle.text),
          email: _email.text.trim(),
          password: _rpw.text,
          photo: _photo,
        );
      } else {
        await AuthService.login(_id.text.trim(), _lpw.text);
      }
    } on AuthException catch (e) {
      if (mounted) setState(() => _err = e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _google() async {
    FocusScope.of(context).unfocus();
    setState(() {
      _err = null;
      _busy = true;
    });
    try {
      await AuthService.loginWithGoogle();
    } on AuthException catch (e) {
      if (mounted) setState(() => _err = e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _forgot() async {
    final id = _id.text.trim();
    if (id.isEmpty) {
      setState(() => _err = 'Önce kullanıcı adını veya e-postanı yaz.');
      return;
    }
    setState(() {
      _busy = true;
      _err = null;
    });
    try {
      await AuthService.resetPassword(id);
      if (mounted) _toast('Şifre sıfırlama bağlantısı e-postana gönderildi.');
    } on AuthException catch (e) {
      if (mounted) setState(() => _err = e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  /* ---- parçalar ---- */

  OutlineInputBorder _ob(Color col) => OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: col, width: 1.2),
      );

  Widget _field(
    AppColors c, {
    required String label,
    required TextEditingController ctl,
    required String hint,
    required IconData icon,
    bool pw = false,
    TextInputType? type,
    ValueChanged<String>? onChanged,
    List<TextInputFormatter>? formatters,
    Widget? below,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: jakarta(13, FontWeight.w700, c.tx)),
        const SizedBox(height: 6),
        TextField(
          controller: ctl,
          obscureText: pw && !_show,
          keyboardType: type,
          onChanged: onChanged,
          inputFormatters: formatters,
          autocorrect: false,
          enableSuggestions: !pw,
          style: jakarta(14, FontWeight.w600, c.tx),
          decoration: InputDecoration(
            isDense: true,
            filled: true,
            fillColor: c.sf2,
            hintText: hint,
            hintStyle: jakarta(14, FontWeight.w500, c.mu),
            prefixIcon: Icon(icon, size: 18, color: c.mu),
            suffixIcon: pw
                ? GestureDetector(
                    onTap: () => setState(() => _show = !_show),
                    child: Center(
                      widthFactor: 1,
                      child: Padding(
                        padding: const EdgeInsets.only(right: 12),
                        child: Text(_show ? 'Gizle' : 'Göster', style: jakarta(13, FontWeight.w800, c.ac)),
                      ),
                    ),
                  )
                : null,
            contentPadding: const EdgeInsets.symmetric(vertical: 13, horizontal: 12),
            border: _ob(c.ln),
            enabledBorder: _ob(c.ln),
            focusedBorder: _ob(c.ac),
          ),
        ),
        if (below != null) below,
      ],
    );
  }

  Widget _segBtn(AppColors c, String label, bool on, VoidCallback onTap) {
    return Expanded(
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          height: 38,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: on ? c.ac : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(label, style: jakarta(14, FontWeight.w800, on ? c.on : c.mu)),
        ),
      ),
    );
  }

  Widget _photoPicker(AppColors c) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Profil fotoğrafı (zorunlu)', style: jakarta(13, FontWeight.w700, c.tx)),
        const SizedBox(height: 8),
        GestureDetector(
          onTap: _busy ? null : _pick,
          child: Row(
            children: [
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: c.sf2,
                  border: Border.all(color: c.ln, width: 1.5),
                  image: _bytes == null ? null : DecorationImage(image: MemoryImage(_bytes!), fit: BoxFit.cover),
                ),
                child: _bytes == null ? Icon(Icons.photo_camera_outlined, color: c.mu) : null,
              ),
              const SizedBox(width: 14),
              Text(_bytes == null ? 'Fotoğraf seç' : 'Fotoğrafı değiştir',
                  style: jakarta(14, FontWeight.w700, c.tx)),
            ],
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    const gap = SizedBox(height: 12);
    return Scaffold(
      backgroundColor: c.bg,
      body: Container(
        decoration: BoxDecoration(
          gradient: RadialGradient(
            center: const Alignment(0, -0.8),
            radius: 1.0,
            colors: [c.ac.withAlpha(46), Colors.transparent],
          ),
        ),
        child: SafeArea(
          child: Align(
            alignment: Alignment.topCenter,
            child: SingleChildScrollView(
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              padding: EdgeInsets.fromLTRB(20, MediaQuery.sizeOf(context).height * 0.1, 20, 28),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 420),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Brand(size: 30),
                    const SizedBox(height: 6),
                    Text(
                      _reg ? 'Hesap oluştur, tahminlerini paylaş.' : 'Tekrar hoş geldin! Hesabına giriş yap.',
                      textAlign: TextAlign.center,
                      style: jakarta(14, FontWeight.w500, c.mu),
                    ),
                    const SizedBox(height: 18),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: c.sf,
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(color: c.ln),
                        boxShadow: const [BoxShadow(color: Color(0x14000000), blurRadius: 24, offset: Offset(0, 8))],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(4),
                            decoration: BoxDecoration(color: c.sf2, borderRadius: BorderRadius.circular(16)),
                            child: Row(children: [
                              _segBtn(c, 'Giriş Yap', !_reg, () => _setReg(false)),
                              _segBtn(c, 'Kayıt Ol', _reg, () => _setReg(true)),
                            ]),
                          ),
                          const SizedBox(height: 14),
                          if (!_reg) ...[
                            _field(c,
                                label: 'Kullanıcı adı veya e-posta',
                                ctl: _id,
                                hint: 'kullanici_adi veya e-posta',
                                icon: Icons.person_outline,
                                type: TextInputType.emailAddress),
                            gap,
                            _field(c, label: 'Şifre', ctl: _lpw, hint: 'Şifre', icon: Icons.lock_outline, pw: true),
                            Align(
                              alignment: Alignment.centerRight,
                              child: TextButton(
                                onPressed: _busy ? null : _forgot,
                                child: Text('Şifremi unuttum', style: jakarta(13, FontWeight.w800, c.ac)),
                              ),
                            ),
                          ] else ...[
                            _photoPicker(c),
                            gap,
                            _field(c,
                                label: 'Görünen ad',
                                ctl: _name,
                                hint: 'Adın nasıl görünsün?',
                                icon: Icons.person_outline,
                                formatters: [LengthLimitingTextInputFormatter(nameMax)]),
                            gap,
                            _field(
                              c,
                              label: 'Kullanıcı adı',
                              ctl: _handle,
                              hint: 'kullanici_adi',
                              icon: Icons.alternate_email,
                              onChanged: _onHandle,
                              formatters: [
                                FilteringTextInputFormatter.allow(RegExp(r'[a-zA-Z0-9_]')),
                                LengthLimitingTextInputFormatter(handleMax),
                              ],
                              below: Padding(
                                      padding: const EdgeInsets.only(top: 6, left: 4),
                                      child: SizedBox(
                                        height: 16,
                                        child: Text(
                                        _hint,
                                        style: jakarta(
                                          12,
                                          FontWeight.w600,
                                          _hintOk == true ? c.ac : (_hintOk == false ? c.red : c.mu),
                                        ),
                                      ),
                                      ),
                                    ),
                            ),
                            gap,
                            _field(c,
                                label: 'E-posta',
                                ctl: _email,
                                hint: 'ornek@mail.com',
                                icon: Icons.mail_outline,
                                type: TextInputType.emailAddress),
                            gap,
                            _field(c, label: 'Şifre', ctl: _rpw, hint: 'Şifre', icon: Icons.lock_outline, pw: true),
                            gap,
                            _field(c,
                                label: 'Şifre (tekrar)',
                                ctl: _rpw2,
                                hint: 'Şifreyi tekrar yaz',
                                icon: Icons.lock_outline,
                                pw: true),
                            const SizedBox(height: 6),
                          ],
                          if (_err != null)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 10, top: 4),
                              child: Text(_err!, style: jakarta(13, FontWeight.w700, c.red)),
                            ),
                          SizedBox(
                            height: 48,
                            child: FilledButton(
                              onPressed: _busy ? null : _submit,
                              style: FilledButton.styleFrom(
                                backgroundColor: c.ac,
                                foregroundColor: c.on,
                                disabledBackgroundColor: c.ac.withAlpha(150),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                              ),
                              child: _busy
                                  ? SizedBox(
                                      width: 20,
                                      height: 20,
                                      child: CircularProgressIndicator(strokeWidth: 2.4, color: c.on),
                                    )
                                  : Text(_reg ? 'Kayıt Ol' : 'Giriş Yap', style: jakarta(15, FontWeight.w800, c.on)),
                            ),
                          ),
                          const SizedBox(height: 14),
                          Row(children: [
                            Expanded(child: Divider(color: c.ln)),
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 12),
                              child: Text('veya', style: jakarta(13, FontWeight.w600, c.mu)),
                            ),
                            Expanded(child: Divider(color: c.ln)),
                          ]),
                          const SizedBox(height: 14),
                          SizedBox(
                            height: 48,
                            child: OutlinedButton(
                              onPressed: _busy ? null : _google,
                              style: OutlinedButton.styleFrom(
                                side: BorderSide(color: c.ln, width: 1.2),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text('G', style: jakarta(18, FontWeight.w800, const Color(0xFF4285F4))),
                                  const SizedBox(width: 10),
                                  Text('Google ile devam et', style: jakarta(14, FontWeight.w700, c.tx)),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
