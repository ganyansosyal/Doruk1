import 'package:flutter/material.dart';
import 'theme.dart';
import 'auth_page.dart';

class SplashPage extends StatefulWidget {
  const SplashPage({super.key});

  @override
  State<SplashPage> createState() => _SplashPageState();
}

class _SplashPageState extends State<SplashPage> with SingleTickerProviderStateMixin {
  late final AnimationController _ctl =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 1800));

  @override
  void initState() {
    super.initState();
    _ctl.forward().whenComplete(() {
      if (!mounted) return;
      Navigator.of(context).pushReplacement(PageRouteBuilder(
        transitionDuration: const Duration(milliseconds: 400),
        pageBuilder: (_, __, ___) => const AuthGate(),
        transitionsBuilder: (_, a, __, child) => FadeTransition(opacity: a, child: child),
      ));
    });
  }

  @override
  void dispose() {
    _ctl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const c = AppColors.light;
    return Scaffold(
      backgroundColor: const Color(0xFF0E7A5A),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF0A5F46), Color(0xFF0E7A5A), Color(0xFF095140)],
            stops: [0, .45, 1],
          ),
        ),
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 340),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: double.infinity,
                    height: 150,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(26),
                      gradient: const LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [Color(0xFFFFFFFF), Color(0xFFE9F6F1)],
                      ),
                      border: Border.all(color: const Color(0x4D0E9F73)),
                      boxShadow: const [
                        BoxShadow(color: Color(0x47000000), blurRadius: 44, offset: Offset(0, 18)),
                      ],
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Brand(size: 38, colors: c),
                        const SizedBox(height: 9),
                        Container(
                          width: 50,
                          height: 3,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(3),
                            gradient: const LinearGradient(colors: [Color(0xFF0E9F73), Color(0xFFB87F00)]),
                          ),
                        ),
                        const SizedBox(height: 9),
                        Text('TAHMİN ET • PAYLAŞ • KAZAN',
                            style: jakarta(10.5, FontWeight.w700, c.mu, ls: 1.7)),
                      ],
                    ),
                  ),
                  const SizedBox(height: 26),
                  AnimatedBuilder(
                    animation: _ctl,
                    builder: (_, __) => Column(
                      children: [
                        Container(
                          width: 230,
                          height: 12,
                          padding: const EdgeInsets.all(2),
                          decoration: BoxDecoration(
                            color: const Color(0x38000000),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: const Color(0x47FFFFFF)),
                          ),
                          child: Align(
                            alignment: Alignment.centerLeft,
                            child: FractionallySizedBox(
                              widthFactor: _ctl.value.clamp(0.02, 1.0),
                              child: Container(
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(10),
                                  gradient: const LinearGradient(
                                    colors: [Color(0xFFFFE9A8), Color(0xFFFFD66B), Color(0xFFFFC83D)],
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text('Yükleniyor…',
                                style: jakarta(13, FontWeight.w700, const Color(0xE0FFFFFF), ls: .3)),
                            const SizedBox(width: 8),
                            Text('%${(_ctl.value * 100).round()}',
                                style: jakarta(13, FontWeight.w800, const Color(0xFFFFD66B))),
                          ],
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
    );
  }
}
