import 'package:flutter/material.dart';
import 'theme.dart';
import 'splash.dart';

void main() => runApp(const GanyanApp());

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
        theme: buildTheme(AppColors.light, Brightness.light),
        darkTheme: buildTheme(AppColors.dark, Brightness.dark),
        home: const SplashPage(),
      ),
    );
  }
}
