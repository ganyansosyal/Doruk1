import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

final ValueNotifier<ThemeMode> themeMode = ValueNotifier(ThemeMode.light);

class AppColors {
  final Color bg, sf, sf2, tx, mu, ln, ac, on, gold, red;
  const AppColors({
    required this.bg,
    required this.sf,
    required this.sf2,
    required this.tx,
    required this.mu,
    required this.ln,
    required this.ac,
    required this.on,
    required this.gold,
    required this.red,
  });

  static const light = AppColors(
    bg: Color(0xFFEDF1F7),
    sf: Color(0xFFFFFFFF),
    sf2: Color(0xFFF1F4F9),
    tx: Color(0xFF0E1B2C),
    mu: Color(0xFF5E6B80),
    ln: Color(0xFFE1E6EE),
    ac: Color(0xFF0E9F73),
    on: Color(0xFFFFFFFF),
    gold: Color(0xFFB87F00),
    red: Color(0xFFE0305A),
  );

  static const dark = AppColors(
    bg: Color(0xFF0A0F1E),
    sf: Color(0xFF131A2E),
    sf2: Color(0xFF1B2440),
    tx: Color(0xFFF3F6FC),
    mu: Color(0xFF8E9AB8),
    ln: Color(0xFF252F4D),
    ac: Color(0xFF2DD4A0),
    on: Color(0xFF05281D),
    gold: Color(0xFFFFB627),
    red: Color(0xFFFF5A7A),
  );

  static AppColors of(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark ? dark : light;
}

ThemeData buildTheme(AppColors c, Brightness b) {
  final base = ThemeData(brightness: b, useMaterial3: true);
  return base.copyWith(
    scaffoldBackgroundColor: c.bg,
    colorScheme: ColorScheme.fromSeed(seedColor: c.ac, brightness: b)
        .copyWith(primary: c.ac, surface: c.sf),
    textTheme: GoogleFonts.plusJakartaSansTextTheme(base.textTheme)
        .apply(bodyColor: c.tx, displayColor: c.tx),
  );
}

TextStyle jakarta(double size, FontWeight w, Color color, {double? ls}) {
  return GoogleFonts.plusJakartaSans(
    fontSize: size,
    fontWeight: w,
    color: color,
    letterSpacing: ls,
  );
}

class Brand extends StatelessWidget {
  final double size;
  final AppColors? colors;
  const Brand({super.key, this.size = 22, this.colors});

  @override
  Widget build(BuildContext context) {
    final c = colors ?? AppColors.of(context);
    return Text.rich(
      TextSpan(children: [
        TextSpan(text: 'Ganyan', style: jakarta(size, FontWeight.w800, c.tx, ls: -size * 0.04)),
        TextSpan(text: 'Sosyal', style: jakarta(size, FontWeight.w800, c.ac, ls: -size * 0.04)),
      ]),
      maxLines: 1,
    );
  }
}
