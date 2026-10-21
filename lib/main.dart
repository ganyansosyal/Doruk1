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
        builder: (ctx, child) => MediaQuery.withClampedTextScaling(
          minScaleFactor: 1.0,
          maxScaleFactor: 1.0,
          child: child!,
        ),
        theme: buildTheme(AppColors.light, Brightness.light),
        darkTheme: buildTheme(AppColors.dark, Brightness.dark),
        home: const SplashPage(),
      ),
    );
  }
}
