import 'package:flutter/material.dart';

/* Profil çerçeveleri (sitedeki FRAMES listesiyle aynı: id, ad, fiyat, açıklama).
   Görseller assets/frames/<id>.png — avatarın üstüne ayrı katman olarak biner. */

class FrameDef {
  final String id, name, desc;
  final double price;
  const FrameDef(this.id, this.name, this.price, this.desc);
  String get asset => 'assets/$id.png';
}

const List<FrameDef> kFrames = [
  FrameDef('bronz', 'Bronz Defne', 15, 'Bronz defne dalları'),
  FrameDef('gumus', 'Gümüş Defne', 40, 'Gümüş defne, safir taş'),
  FrameDef('altin', 'Altın Taç', 120, 'Altın defne ve taç'),
  FrameDef('yakut', 'Yakut', 300, 'Defne kanatlar, yakut taş'),
  FrameDef('sampiyon', 'Şampiyon', 600, 'Taç, yıldızlar, kırmızı kurdele'),
  FrameDef('kraliyet', 'Kraliyet', 1500, 'Altın taç, defne ve ametist'),
];

FrameDef? frameById(String? id) {
  if (id == null || id.isEmpty) return null;
  for (final f in kFrames) {
    if (f.id == id) return f;
  }
  return null;
}

/// Avatarı çerçeveyle sarar. Yer kaplamaz: defne yanlara, taç yukarı taşar (sitedeki .fi ile aynı oranlar).
Widget framedAvatar(Widget avatar, double size, FrameDef fr) {
  return SizedBox(
    width: size,
    height: size,
    child: Stack(
      clipBehavior: Clip.none,
      alignment: Alignment.center,
      children: [
        Transform.scale(scale: 0.948, child: avatar),
        Positioned(
          left: -size * 0.1579,
          top: -size * 0.2895,
          width: size * 1.3158,
          height: size * 1.4474,
          child: IgnorePointer(child: Image.asset(fr.asset, fit: BoxFit.fill, filterQuality: FilterQuality.medium, gaplessPlayback: true)),
        ),
      ],
    ),
  );
}
