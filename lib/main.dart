import 'package:flutter/material.dart';
import 'firebase_options.dart';
import 'theme.dart';
import 'splash.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  preloadFonts();
  await initFirebase();
  runApp(const GanyanApp());
}

class GanyanApp extends StatelessWidget {
  const GanyanApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: themeMode,
      builder: (_, mode, __) => MaterialApp(
        title: 'GanyanSosyal',
        debugShowCheckedModeBanner: false,
        themeMode: mode,
        scrollBehavior: const NoBounceScroll(),
        // FittedBox kaldırıldı: tüm uygulamayı transform ile ölçeklemek scroll'u kasıyor ve yazıyı bulanıklaştırıyordu.
        // Bunun yerine sadece yazı boyutu 445 px tasarıma göre ölçekleniyor.
        builder: (ctx, child) {
          final mq = MediaQuery.of(ctx);
          final s = (mq.size.width / 445.0).clamp(0.8, 1.0);
          return MediaQuery(
            data: mq.copyWith(textScaler: TextScaler.linear(s)),
            child: child!,
          );
        },
        theme: buildTheme(AppColors.light, Brightness.light),
        darkTheme: buildTheme(AppColors.dark, Brightness.dark),
        home: const SplashPage(),
      ),
    );
  }
}
