import 'package:flutter/material.dart';

void main() => runApp(const GanyanApp());

class GanyanApp extends StatelessWidget {
  const GanyanApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'GanyanSosyal',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorSchemeSeed: const Color(0xFF0F9D6E),
        scaffoldBackgroundColor: const Color(0xFFF1F4FB),
      ),
      home: const HomePage(),
    );
  }
}

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: RichText(
          text: const TextSpan(
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
            children: [
              TextSpan(text: 'Ganyan', style: TextStyle(color: Color(0xFF0F172A))),
              TextSpan(text: 'Sosyal', style: TextStyle(color: Color(0xFF0F9D6E))),
            ],
          ),
        ),
      ),
      body: const Center(
        child: Text(
          'Native uygulama çalışıyor ✅',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
        ),
      ),
    );
  }
}
