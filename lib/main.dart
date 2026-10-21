import 'package:flutter/material.dart';
import 'firebase_options.dart';
import 'theme.dart';
import 'splash.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
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
        // Site 445 px genişlikte tasarlandı (viewport width=445): her telefonda aynı oranda ölçeklenir.
        builder: (ctx, child) {
          final mq = MediaQuery.of(ctx);
          const baseW = 445.0;
          final s = mq.size.width / baseW;
          final h = mq.size.height / s;
          return FittedBox(
            fit: BoxFit.fill,
            child: SizedBox(
              width: baseW,
              height: h,
              child: MediaQuery(
                data: mq.copyWith(
                  size: Size(baseW, h),
                  padding: mq.padding / s,
                  viewPadding: mq.viewPadding / s,
                  viewInsets: mq.viewInsets / s,
                  textScaler: TextScaler.noScaling,
                ),
                child: child!,
              ),
            ),
          );
        },
        theme: buildTheme(AppColors.light, Brightness.light),
        darkTheme: buildTheme(AppColors.dark, Brightness.dark),
        home: const SplashPage(),
      ),
    );
  }
}
