import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:html/dom.dart';
import 'package:html/parser.dart' as hp;
import 'package:http/http.dart' as http;

const _backend = 'https://tiny-sunset-7f18.bilyoncu001.workers.dev';

String isoToday() {
  final n = DateTime.now();
  return '${n.year}-${n.month.toString().padLeft(2, '0')}-${n.day.toString().padLeft(2, '0')}';
}

String isoAdd(String iso, int days) {
  final p = iso.split('-').map(int.parse).toList();
  final d = DateTime(p[0], p[1], p[2] + days);
  return '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
}

String _tjkDate(String iso) {
  final p = iso.split('-');
  return '${p[2]}/${p[1]}/${p[0]}';
}

String _era(String iso) => iso.compareTo(isoToday()) < 0 ? 'yesterday' : 'today';

Future<String> _fetch(String url, {int sec = 20, int retry = 2}) async {
  Object? last;
  final ep = '$_backend?url=${Uri.encodeComponent(url)}&_cb=${DateTime.now().millisecondsSinceEpoch}';
  for (var i = 0; i <= retry; i++) {
    try {
      final r = await http.get(Uri.parse(ep)).timeout(Duration(seconds: sec));
      if (r.statusCode == 200) return utf8.decode(r.bodyBytes, allowMalformed: true);
      last = 'HTTP ${r.statusCode}';
      if (r.statusCode < 500) break;
    } catch (e) {
      last = e;
    }
    if (i < retry) await Future.delayed(Duration(milliseconds: 1000 + i * 1500));
  }
  throw Exception('TJK bağlantı hatası: $last');
}

/* ---------------- Modeller ---------------- */

class City {
  final String id, name;
  final bool yd;
  City(this.id, this.name, this.yd);
}

class Horse {
  final int no;
  final String name, jockey, yas, kgs;
  final bool kosmaz;
  final int? agf, hp;
  final double? gny, siklet;
  final List<String> son6;
  Horse({
    required this.no,
    required this.name,
    this.jockey = '',
    this.yas = '',
    this.kgs = '',
    this.kosmaz = false,
    this.agf,
    this.hp,
    this.gny,
    this.siklet,
    this.son6 = const [],
  });
}

class Start {
  final int ord, n;
  final String tur; // GANYAN · PLASE · CIFTE
  Start(this.ord, this.n, this.tur);
}

class Race {
  final int no;
  final String saat;
  final String? mesafe, pist;
  final String bilgi;
  final List<Horse> atlar;
  final List<Start> baslar;
  final List<String>? oyun;
  Race({
    required this.no,
    required this.saat,
    this.mesafe,
    this.pist,
    this.bilgi = '',
    required this.atlar,
    this.baslar = const [],
    this.oyun,
  });
}

class Bahis {
  final String tur, detay, tutar;
  Bahis(this.tur, this.detay, this.tutar);
}

class RaceResult {
  final List<int> sira;
  final Map<int, String> gny;
  final List<Bahis> bahis;
  final String video;
  RaceResult(this.sira, this.gny, this.bahis, this.video);
}

/* ---------------- Yardımcılar ---------------- */

String _norm(String s) => s
    .toUpperCase()
    .replaceAll('İ', 'I')
    .replaceAll('Ğ', 'G')
    .replaceAll('Ü', 'U')
    .replaceAll('Ş', 'S')
    .replaceAll('Ö', 'O')
    .replaceAll('Ç', 'C');

String _trLower(String s) => s.replaceAll('İ', 'i').replaceAll('I', 'ı').toLowerCase();
String _clean(String s) => s.replaceAll('\u00a0', ' ').replaceAll(RegExp(r'\s+'), ' ').trim();
String _key(String s) => _norm(s).replaceAll(RegExp(r'[^A-Z0-9]'), '');

final _headRe = RegExp(r'^(\d+)\.\s*Koşu\s+(\d{1,2})[:.](\d{2})');
final _pistRe = RegExp(r'(\d{1,2}[.]\d{3}|\d{3,4})\s*(?:m\b\s*)?(çim|kum|sentetik)');

List<Element> _all(Document d) => d.body?.querySelectorAll('*') ?? <Element>[];

bool _isHead(Element e, {int maxLen = 60}) {
  if (e.children.length > 2) return false;
  final t = e.text.trim();
  return t.length < maxLen && _headRe.hasMatch(t);
}

/* ---------------- Şehir listesi ---------------- */

Future<List<City>> getCities(String iso) async {
  final url =
      'https://www.tjk.org/TR/yarissever/Info/Page/GunlukYarisProgrami?QueryParameter_Tarih=${Uri.encodeComponent(_tjkDate(iso))}&Era=${_era(iso)}';
  final doc = hp.parse(await _fetch(url));
  final seen = <String>{};
  final list = <City>[];
  for (final a in doc.querySelectorAll('a[href]')) {
    final href = a.attributes['href'] ?? '';
    if (!RegExp('GunlukYarisProgrami', caseSensitive: false).hasMatch(href)) continue;
    final m = RegExp(r'[?&]SehirId=(\d+)', caseSensitive: false).firstMatch(href);
    if (m == null || !seen.add(m.group(1)!)) continue;
    var adi = '';
    final ma = RegExp(r'[?&]SehirAdi=([^&]+)', caseSensitive: false).firstMatch(href);
    if (ma != null) {
      try {
        adi = Uri.decodeComponent(ma.group(1)!.replaceAll('+', ' '));
      } catch (_) {
        adi = ma.group(1)!;
      }
    }
    adi = _clean(adi.isEmpty ? a.text : adi);
    final first = _key(adi.split(' ').first);
    const yerli = {'ISTANBUL', 'ANKARA', 'IZMIR', 'BURSA', 'ADANA', 'SANLIURFA', 'ELAZIG', 'DIYARBAKIR', 'KOCAELI', 'IZMIT', 'ANTALYA', 'KARMA'};
    final yd = RegExp(r'\(YD\s*\d+\)', caseSensitive: false).hasMatch(adi) ||
        RegExp(r'\bYD\s*\d+\b', caseSensitive: false).hasMatch(a.text) ||
        (first.isNotEmpty && !yerli.contains(first));
    if (adi.isNotEmpty) list.add(City(m.group(1)!, adi, yd));
  }
  if (list.isEmpty) throw Exception("TJK'da bu tarih için yayınlanmış bir koşu programı bulunamadı.");
  final yerli = list.where((c) => !c.yd).toList();
  return yerli.isNotEmpty ? yerli : list;
}

/* ---------------- Program ---------------- */

int? _col(List<String> heads, dynamic key) {
  final keys = key is List ? key.cast<String>() : [key as String];
  for (final k in keys) {
    final i = heads.indexWhere((h) => _clean(h).toLowerCase().contains(k.toLowerCase()));
    if (i >= 0) return i;
  }
  return null;
}

List<Horse> _parseHorses(Element table) {
  final rows = table.querySelectorAll('tr');
  if (rows.length < 2) return [];
  var bi = rows.indexWhere((tr) => RegExp(r'At\s*İsmi', caseSensitive: false).hasMatch(tr.text) && RegExp('Jokey', caseSensitive: false).hasMatch(tr.text));
  if (bi < 0) bi = 0;
  final heads = rows[bi].querySelectorAll('th,td').map((e) => e.text.trim()).toList();
  int? exact(String k) {
    final i = heads.indexWhere((h) => _clean(h) == k);
    return i >= 0 ? i : null;
  }

  final iN = exact('N') ?? _col(heads, 'N');
  final iIsim = _col(heads, 'At İsmi');
  final iYas = _col(heads, 'Yaş');
  final iSik = _col(heads, 'Sıklet');
  final iJok = _col(heads, 'Jokey');
  final iHp = _col(heads, 'HP');
  final iS6 = _col(heads, 'Son 6');
  final iKgs = _col(heads, 'KGS');
  final iGny = _col(heads, 'Gny');
  final iAgf = _col(heads, 'AGF');
  final out = <Horse>[];
  for (var i = bi + 1; i < rows.length; i++) {
    final tds = rows[i].querySelectorAll('td');
    if (tds.length < 4) continue;
    String? al(int? idx) => idx != null && idx < tds.length ? tds[idx].text.trim() : null;
    final isimHam = al(iIsim);
    if (isimHam == null || isimHam.isEmpty) continue;
    final rowText = rows[i].outerHtml;
    final kosmaz = RegExp(r'ko[sş]maz|kosmaz|cekil|çekil|iptal|withdraw|scratch', caseSensitive: false).hasMatch(rows[i].className + rows[i].querySelectorAll('[class]').map((e) => e.className).join(' ')) ||
        RegExp(r'\(\s*K\s*\)').hasMatch(isimHam) ||
        RegExp(r'\bko[şs]maz\b', caseSensitive: false).hasMatch(rows[i].text) ||
        rows[i].querySelector('s, strike, del, [style*="line-through"]') != null ||
        rowText.contains('line-through');
    final isim = isimHam.split('\n').first.replaceAll(RegExp(r'\s{2,}.*$'), '').trim();
    final no = int.tryParse((al(iN) ?? '').replaceAll(RegExp(r'[^0-9]'), ''));
    if (no == null) continue;
    String jok = '';
    if (iJok != null && iJok < tds.length) {
      final a = tds[iJok].querySelector('a');
      jok = _clean((a?.text.trim().isNotEmpty ?? false) ? a!.text : tds[iJok].text).replaceAll(RegExp(r'\s*AP\s*Apranti.*$', caseSensitive: false), '').replaceAll(RegExp(r'\s+AP$'), '').trim();
    }
    final s6 = <String>[];
    if (iS6 != null && iS6 < tds.length) {
      for (final m in RegExp(r'[0-9A-Za-z\-]').allMatches(tds[iS6].text)) {
        s6.add(m.group(0)!);
      }
    }
    out.add(Horse(
      no: no,
      name: isim.isEmpty ? isimHam.substring(0, isimHam.length.clamp(0, 40)) : isim,
      jockey: jok,
      yas: _clean(al(iYas) ?? ''),
      kgs: _clean(al(iKgs) ?? ''),
      kosmaz: kosmaz,
      agf: int.tryParse(RegExp(r'(\d+)').firstMatch(al(iAgf) ?? '')?.group(1) ?? ''),
      hp: int.tryParse((al(iHp) ?? '').trim()),
      gny: double.tryParse((al(iGny) ?? '').replaceAll(',', '.')),
      siklet: double.tryParse((al(iSik) ?? '').replaceAll(',', '.')),
      son6: s6.length > 6 ? s6.sublist(s6.length - 6) : s6,
    ));
  }
  return out;
}

String _bilgiAyikla(String ham) {
  final t = _clean(ham);
  final l = _trLower(t);
  final m = _pistRe.firstMatch(l);
  if (m == null) return '';
  var end = m.end;
  final eid = RegExp(r'^\s*,?\s*E\.?\s*[İIi]\.?\s*D\.?\s*:\s*[\d.]+').firstMatch(t.substring(end.clamp(0, t.length)));
  if (eid != null) end += eid.group(0)!.length;
  if (end > t.length) end = t.length;
  var head = t.substring(0, end).replaceFirst(RegExp(r'^[\s\S]*Koşu\s+\d{1,2}[:.]\d{2}\s*'), '');
  head = head.replaceFirst(RegExp(r'^[\s\S]*(?:Birinci Primi|Koşu İkramiyesi|İkramiye|Primi)[^,]*?(?:\d\s*TL|₺)\s*', caseSensitive: false), '').trim();
  if (head.length < 12 || head.length > 320) return '';
  final lh = _trLower(head);
  final ok = RegExp(r'yaş|\bkg\b|yukarı|araplar|ingilizler|handikap|maiden|şartlı|dişi|erkek').hasMatch(lh) || ','.allMatches(lh).length >= 2;
  return ok ? head : '';
}

List<Race> _parseRaces(Document doc, Map<int, List<Start>> bas, Map<int, List<String>> oyun) {
  final all = _all(doc);
  final idx = <Element, int>{for (var i = 0; i < all.length; i++) all[i]: i};
  final heads = all.where(_isHead).toList();
  final tables = doc.querySelectorAll('table');
  final cand = <int, List<({String saat, String bilgi, List<Horse> atlar})>>{};
  for (var h = 0; h < heads.length; h++) {
    final he = heads[h];
    final m = _headRe.firstMatch(he.text.trim())!;
    final no = int.parse(m.group(1)!);
    final saat = '${m.group(2)!.padLeft(2, '0')}:${m.group(3)}';
    final start = idx[he]!;
    final end = h + 1 < heads.length ? idx[heads[h + 1]]! : all.length;
    Element? tablo;
    for (final t in tables) {
      final ti = idx[t];
      if (ti != null && ti > start && ti < end) {
        tablo = t;
        break;
      }
    }
    var bilgi = '';
    final stop = tablo != null ? idx[tablo]! : end;
    for (var i = start + 1; i < stop && i < all.length; i++) {
      final ay = _bilgiAyikla(all[i].text);
      if (ay.isEmpty) continue;
      if (all[i].children.any((c) => _bilgiAyikla(c.text).isNotEmpty)) continue;
      bilgi = ay;
      break;
    }
    if (bilgi.isEmpty && he.parent != null) bilgi = _bilgiAyikla(he.parent!.text);
    bilgi = bilgi.replaceFirst(RegExp(r'\s*(?:Birinci Primi|Koşu İkramiyesi|İkramiye|Primi)[\s\S]*$', caseSensitive: false), '').replaceAll(RegExp(r'\s+,'), ',').replaceAll(RegExp(r'[\s,]+$'), '').trim();
    final atlar = tablo != null ? _parseHorses(tablo) : <Horse>[];
    cand.putIfAbsent(no, () => []).add((saat: saat, bilgi: bilgi, atlar: atlar));
  }
  final out = <Race>[];
  final nos = cand.keys.toList()..sort();
  for (final no in nos) {
    final c = cand[no]!;
    var pick = c.last;
    for (var i = c.length - 1; i >= 0; i--) {
      if (c[i].atlar.isNotEmpty) {
        pick = c[i];
        break;
      }
    }
    if (pick.atlar.isEmpty) continue;
    String? mesafe, pist;
    final mp = _pistRe.firstMatch(_trLower(pick.bilgi));
    if (mp != null) {
      mesafe = '${int.parse(mp.group(1)!.replaceAll('.', ''))} m';
      final p = mp.group(2)!;
      pist = p == 'çim' ? 'Çim' : p == 'kum' ? 'Kum' : 'Sentetik';
    }
    out.add(Race(no: no, saat: pick.saat, mesafe: mesafe, pist: pist, bilgi: pick.bilgi, atlar: pick.atlar, baslar: bas[no] ?? const [], oyun: oyun[no]));
  }
  return out;
}

String _pageText(Document doc) {
  var t = _norm((doc.body?.text ?? '').replaceAll('\u00a0', ' ')).replaceAll(RegExp(r"['’`]"), '').replaceAll(RegExp(r'\s+'), ' ');
  return t;
}

Map<int, List<Start>> _ayakBaslangic(Document doc) {
  final out = <int, List<Start>>{};
  var txt = _pageText(doc)
      .replaceAll(RegExp(r'\bYEDILI\b'), '7LI')
      .replaceAll(RegExp(r'\bALTILI\b'), '6LI')
      .replaceAll(RegExp(r'\bBESLI\b'), '5LI')
      .replaceAll(RegExp(r'\bDORTLU\b'), '4LI')
      .replaceAllMapped(RegExp(r'\bUCLU\b(?= (?:GANYAN|PLASE))'), (m) => '3LI');
  final heads = RegExp(r'(\d{1,2})\. KOSU\s+\d{1,2}[:.]\d{2}').allMatches(txt).toList();
  for (final m in RegExp('KOSUDAN BASLAR').allMatches(txt)) {
    final hs = heads.where((x) => x.end <= m.start).toList();
    if (hs.isEmpty) continue;
    final h = hs.last;
    final seg = txt.substring((m.start - 400).clamp(h.end, m.start), m.start);
    for (final x in RegExp(r'(?:(\d)\. ?)?(\d) ?L[IU] ?(GANYAN|PLASE)|CIFTE').allMatches(seg)) {
      final it = x.group(0) == 'CIFTE' ? Start(0, 2, 'CIFTE') : Start(x.group(1) != null ? int.parse(x.group(1)!) : 0, int.parse(x.group(2)!), x.group(3)!);
      final no = int.parse(h.group(1)!);
      final l = out.putIfAbsent(no, () => []);
      if (!l.any((y) => y.ord == it.ord && y.n == it.n && y.tur == it.tur)) l.add(it);
    }
  }
  return out;
}

Map<int, List<String>> _kosuOyunlari(Document doc) {
  final out = <int, List<String>>{};
  final txt = _pageText(doc).replaceAll(RegExp(r'\bBESLI\b'), '5LI');
  final heads = RegExp(r'(\d{1,2})\. KOSU\s+\d{1,2}[:.]\d{2}').allMatches(txt).toList();
  for (var i = 0; i < heads.length; i++) {
    final h = heads[i];
    final end = i + 1 < heads.length ? heads[i + 1].start : txt.length;
    var seg = txt.substring(h.end, end);
    if (seg.length > 900) seg = seg.substring(seg.length - 900);
    seg = ' $seg '
        .replaceAll(RegExp(r'SABIT [^,]*'), ' ')
        .replaceAll(RegExp(r'\d ?L[IU] ?(?:GANYAN|PLASE)'), ' ')
        .replaceAll('SIRALI IKILI', ' @SI ')
        .replaceAll('PLASE IKILI', ' @PI ')
        .replaceAll(RegExp(r'SIRALI (?:UCLU|3LU)'), ' @SU ')
        .replaceAll(RegExp(r'SIRALI 5 ?LI'), ' @S5 ');
    final set = <String>{};
    if (RegExp(r'\bGANYAN\b').hasMatch(seg)) set.add('g1');
    if (seg.contains('@SI')) set.add('si');
    if (seg.contains('@PI')) set.add('pi');
    if (seg.contains('@SU') || RegExp(r'\bUCLU BAHIS').hasMatch(seg)) set.add('su');
    if (seg.contains('@S5')) set.add('s5');
    if (seg.contains('TABELA')) set.add('tb');
    final rest = seg.replaceAll(RegExp(r'@\w+'), ' ');
    if (RegExp(r'\bIKILI\b').hasMatch(rest)) set.add('ik');
    if (RegExp(r'\bPLASE\b').hasMatch(rest)) {
      set.add('pl');
      set.add('gp');
    }
    if (set.contains('g1') && set.length >= 2) out[int.parse(h.group(1)!)] = set.toList();
  }
  return out;
}

Future<List<Race>> getProgram(City c, String iso) async {
  final url =
      'https://www.tjk.org/TR/yarissever/Info/Sehir/GunlukYarisProgrami?SehirId=${c.id}&QueryParameter_Tarih=${Uri.encodeComponent(_tjkDate(iso))}&SehirAdi=${Uri.encodeComponent(c.name)}&Era=${_era(iso)}';
  final html = await _fetch(url, sec: 45);
  final doc = hp.parse(html);
  var races = _parseRaces(doc, _ayakBaslangic(doc), _kosuOyunlari(doc));
  if (races.isEmpty) {
    // yedek: tablo başlıklarından koşu numarası bul
    var sira = 0;
    for (final t in doc.querySelectorAll('table')) {
      final head = t.querySelectorAll('tr').take(3).map((e) => e.text).join(' ');
      if (!RegExp(r'At\s*İsmi', caseSensitive: false).hasMatch(head) || !RegExp('Jokey', caseSensitive: false).hasMatch(head)) continue;
      final atlar = _parseHorses(t);
      if (atlar.isEmpty) continue;
      sira++;
      races.add(Race(no: sira, saat: '—', atlar: atlar));
    }
  }
  return races;
}

/* ---------------- Sonuçlar ---------------- */

final _bahisKalip = <({RegExp re, String Function(RegExpMatch) tur, String Function(RegExpMatch) detay})>[
  (re: RegExp(r"(?:(\d+)\.\s*)?(\d+)\s*['’]?\s*L[İIÜUiıüu]\s*GANYAN\s*(.*)$", caseSensitive: false), tur: (m) => "${m.group(1) != null ? '${m.group(1)}. ' : ''}${m.group(2)}'li Ganyan", detay: (m) => m.group(3) ?? ''),
  (re: RegExp(r"(?:(\d+)\.\s*)?(\d+)\s*['’]?\s*L[İIÜUiıüu]\s*PLASE\s*(.*)$", caseSensitive: false), tur: (m) => "${m.group(1) != null ? '${m.group(1)}. ' : ''}${m.group(2)}'li Plase", detay: (m) => m.group(3) ?? ''),
  (re: RegExp(r'SIRALI\s*[İIi]K[İIi]L[İIi]\s*(.*)$', caseSensitive: false), tur: (m) => 'Sıralı İkili', detay: (m) => m.group(1) ?? ''),
  (re: RegExp(r"SIRALI\s*(?:5\s*['’]?\s*L[İIi]|BE[ŞS]L[İIi])\s*(?:BAH[İIi]S\s*)?(.*)$", caseSensitive: false), tur: (m) => 'Sıralı Beşli', detay: (m) => m.group(1) ?? ''),
  (re: RegExp(r'TABELA\s*(?:BAH[İIi]S\s*)?(.*)$', caseSensitive: false), tur: (m) => 'Tabela Bahis', detay: (m) => m.group(1) ?? ''),
  (re: RegExp(r'SIRALI\s*(?:ÜÇLÜ\s*)?(?:BAH[İIi]S\s*)?(.*)$', caseSensitive: false), tur: (m) => 'Sıralı Üçlü', detay: (m) => m.group(1) ?? ''),
  (re: RegExp(r'PLASE\s*[İIi]K[İIi]L[İIi]\s*(.*)$', caseSensitive: false), tur: (m) => 'Plase İkili', detay: (m) => m.group(1) ?? ''),
  (re: RegExp(r'ÜÇLÜ\s*BAH[İIi]S\s*(.*)$', caseSensitive: false), tur: (m) => 'Üçlü Bahis', detay: (m) => m.group(1) ?? ''),
  (re: RegExp(r'(\d+)\.\s*ÇİFTE\s*(.*)$', caseSensitive: false), tur: (m) => '${m.group(1)}. Çifte', detay: (m) => m.group(2) ?? ''),
  (re: RegExp(r'SAB[İIi]T\s*GANYAN\s*(.*)$', caseSensitive: false), tur: (m) => 'Sabit Ganyan', detay: (m) => m.group(1) ?? ''),
  (re: RegExp(r'PLASE\s+(.*)$', caseSensitive: false), tur: (m) => 'Plase', detay: (m) => m.group(1) ?? ''),
  (re: RegExp(r'[İIi]K[İIi]L[İIi]\s*(.*)$', caseSensitive: false), tur: (m) => 'İkili', detay: (m) => m.group(1) ?? ''),
  (re: RegExp(r'GANYAN\s*(.*)$', caseSensitive: false), tur: (m) => 'Ganyan', detay: (m) => m.group(1) ?? ''),
];

List<Bahis> _bahisler(String metin) {
  metin = metin.replaceAll('\u00a0', ' ').split(RegExp(r'Son\s*800', caseSensitive: false)).first;
  final out = <Bahis>[];
  final seen = <String>{};
  Bahis? son;
  for (final parca in metin.split('₺')) {
    final prev = son;
    son = null;
    final tm = RegExp(r'([\d.,]+)\s*$').firstMatch(parca);
    if (tm == null) continue;
    final tutar = tm.group(1)!;
    if (!((double.tryParse(tutar.replaceAll('.', '').replaceAll(',', '.')) ?? 0) > 0)) continue;
    final et = parca.substring(0, parca.length - tm.group(0)!.length).replaceAll(RegExp(r'\s+'), ' ');
    if (RegExp(r'DA[ĞG]ITILACAK').hasMatch(et.toUpperCase())) continue;
    if (et.trim().isEmpty) continue;
    for (final k in _bahisKalip) {
      final mm = k.re.firstMatch(et);
      if (mm != null) {
        final detay = k.detay(mm).replaceAll(RegExp(r'\s+'), ' ').replaceFirst(RegExp(r'^[İIi]KRAM[İIi]YE(LER)?\s*', caseSensitive: false), '').trim();
        final x = Bahis(k.tur(mm), detay, tutar);
        if (seen.add('${x.tur}|${x.detay}')) {
          out.add(x);
          son = x;
        }
        break;
      }
    }
    // ignore prev (ikramiye ayrımı basitleştirildi)
    if (prev != null) {}
  }
  return out.where((x) => !RegExp(r"'li (Ganyan|Plase)$|Çifte$").hasMatch(x.tur) || RegExp(r',\d{1,2}$').hasMatch(x.tutar)).toList();
}

Future<Map<int, RaceResult>> getResults(City c, String iso, List<Race> kosular) async {
  final url =
      'https://www.tjk.org/TR/yarissever/Info/Sehir/GunlukYarisSonuclari?SehirId=${c.id}&QueryParameter_Tarih=${Uri.encodeComponent(_tjkDate(iso))}&SehirAdi=${Uri.encodeComponent(c.name)}&Era=${_era(iso)}';
  final html = await _fetch(url, sec: 30, retry: 1);
  final doc = hp.parse(html);
  final all = _all(doc);
  final idx = <Element, int>{for (var i = 0; i < all.length; i++) all[i]: i};
  final heads = all.where((e) => _isHead(e, maxLen: 400)).toList();
  final out = <int, RaceResult>{};
  var sonNo = 0;
  final goruldu = <int>{};
  for (final tablo in doc.querySelectorAll('table')) {
    try {
      final trs = tablo.querySelectorAll('tr');
      final bi = trs.indexWhere((tr) => RegExp(r'At\s*İsmi', caseSensitive: false).hasMatch(tr.text));
      if (bi < 0) continue;
      final ti = idx[tablo] ?? 0;
      int? no;
      Element? bHead;
      for (final b in heads) {
        if ((idx[b] ?? 0) < ti) {
          no = int.tryParse(RegExp(r'^\d+').firstMatch(b.text.trim())?.group(0) ?? '');
          bHead = b;
        } else {
          break;
        }
      }
      var seq = false;
      if (no == null || goruldu.contains(no) || no <= sonNo) {
        no = sonNo + 1;
        bHead = null;
        seq = true;
      }
      Race? kosu;
      for (final k in kosular) {
        if (k.no == no) kosu = k;
      }
      if (kosu == null) continue;
      final bas = trs[bi].querySelectorAll('th,td').map((e) => _clean(e.text)).toList();
      var iS = bas.indexWhere((h) => RegExp(r'^(S|Sıra|Sira)$', caseSensitive: false).hasMatch(h));
      if (iS < 0) iS = 0;
      final iIsim = bas.indexWhere((h) => RegExp(r'At\s*İsmi', caseSensitive: false).hasMatch(h));
      final iGny = bas.indexWhere((h) => RegExp(r'^Gny$', caseSensitive: false).hasMatch(h));
      if (iIsim < 0) continue;
      final atlar = kosu.atlar.map((a) => (no: a.no, n: _key(a.name))).where((a) => a.n.isNotEmpty).toList();
      final sira = <({int sr, int no})>[];
      final gn = <int, String>{};
      var satir = 0;
      for (final tr in trs.skip(bi + 1)) {
        final td = tr.querySelectorAll('td');
        if (td.length <= (iS > iIsim ? iS : iIsim)) continue;
        final sr = int.tryParse(td[iS].text.trim());
        if (sr == null || sr == 0) continue;
        satir++;
        final rn = _key(td[iIsim].text.replaceAll(RegExp(r'\(\s*\d{1,2}\s*\)'), ' '));
        ({int no, String n})? best;
        for (final a in atlar) {
          if (rn.startsWith(a.n) && (best == null || a.n.length > best.n.length)) best = a;
        }
        if (best == null && rn.length >= 4) {
          for (final a in atlar) {
            if (a.n.startsWith(rn) && (best == null || a.n.length > best.n.length)) best = a;
          }
        }
        if (best == null && !seq) {
          final mN = RegExp(r'\(\s*(\d{1,2})\s*\)').firstMatch(td[iIsim].text);
          if (mN != null) {
            for (final a in atlar) {
              if (a.no == int.parse(mN.group(1)!)) best = a;
            }
          }
        }
        if (best != null) {
          sira.add((sr: sr, no: best.no));
          final g = iGny >= 0 && iGny < td.length ? td[iGny].text.trim() : '';
          if (RegExp(r'^\d+[.,]\d+$').hasMatch(g)) gn[best.no] = g;
        }
      }
      sira.sort((a, b) => a.sr.compareTo(b.sr));
      if (seq && sira.length < (satir * 0.6).ceil().clamp(2, 99)) continue;
      sonNo = no;
      goruldu.add(no);
      // tablo sonrası metin
      Element? nextB;
      for (final b in heads) {
        if ((idx[b] ?? 0) > ti) {
          nextB = b;
          break;
        }
      }
      final end = nextB != null ? idx[nextB]! : all.length;
      final sb = StringBuffer();
      final inTable = tablo.querySelectorAll('*').toSet();
      for (var i = ti + 1; i < end; i++) {
        final e = all[i];
        if (e.children.isEmpty && !inTable.contains(e)) sb.write(' ${e.text}');
      }
      final bahisler = _bahisler(sb.toString());
      var vurl = '';
      final from = bHead != null ? idx[bHead]! : ti;
      for (var i = from; i < end; i++) {
        final href = all[i].localName == 'a' ? (all[i].attributes['href'] ?? '') : '';
        final m = RegExp(r'KosuKodu=(-?\d+)', caseSensitive: false).firstMatch(href);
        if (m != null && RegExp('YarisVideo', caseSensitive: false).hasMatch(href)) {
          vurl = 'https://www.tjk.org/TR/yarissever/Info/YarisVideoKosu/Kosu?KosuKodu=${m.group(1)}';
          break;
        }
      }
      if (seq) vurl = '';
      Bahis? gk;
      for (final b in bahisler) {
        if (b.tur == 'Ganyan') gk = b;
      }
      final gno = gk != null ? int.tryParse(RegExp(r'\d+').firstMatch(gk.detay)?.group(0) ?? '') : null;
      if (gno != null && !gn.containsKey(gno)) gn[gno] = gk!.tutar;
      if (sira.isNotEmpty && sira.first.sr == 1) {
        out[no] = RaceResult(sira.map((e) => e.no).toList(), gn, bahisler, vurl);
      }
    } catch (e) {
      debugPrint('sonuç ayrıştırma: $e');
    }
  }
  return out;
}

/// 'iso|şehir' -> koşu no -> geliş sırası. Kupon değerlendirmesi buradan okur.
final Map<String, Map<int, List<int>>> liveRes = {};

/* ---------------- Ortak durum ---------------- */

/// Bugünün bülteni + sonuçları; Tahmin Yap, Sonuçlar ve kupon değerlendirme paylaşır.
class TjkStore extends ChangeNotifier {
  static final TjkStore i = TjkStore._();
  TjkStore._();

  String iso = isoToday();
  List<City> cities = [];
  final Map<String, List<Race>> program = {};
  final Map<String, Map<int, RaceResult>> results = {};
  bool loading = false;
  String? error;
  Timer? _timer;

  bool get isToday => iso == isoToday();
  bool get isPast => iso.compareTo(isoToday()) < 0;

  List<Race> races(String city) => program[city] ?? const [];
  Race? race(String city, int no) {
    for (final r in races(city)) {
      if (r.no == no) return r;
    }
    return null;
  }

  DateTime? raceStart(String city, int no) {
    final r = race(city, no);
    final m = RegExp(r'^(\d{1,2}):(\d{2})$').firstMatch(r?.saat ?? '');
    if (m == null) return null;
    final p = iso.split('-').map(int.parse).toList();
    return DateTime(p[0], p[1], p[2], int.parse(m.group(1)!), int.parse(m.group(2)!));
  }

  bool raceDone(String city, int no) {
    final d = raceStart(city, no);
    return d != null && !d.isAfter(DateTime.now());
  }

  List<int>? resOf(String city, int no) => results[city]?[no]?.sira;

  Future<void> load(String newIso) async {
    iso = newIso;
    loading = true;
    error = null;
    cities = [];
    program.clear();
    results.clear();
    notifyListeners();
    try {
      cities = await getCities(iso);
      notifyListeners();
      await Future.wait(cities.map((c) async {
        try {
          program[c.name] = await getProgram(c, iso);
        } catch (_) {
          program[c.name] = [];
        }
      }));
      cities = cities.where((c) => (program[c.name] ?? []).isNotEmpty).toList();
      if (cities.isEmpty) error = 'Bu tarih için koşu programı bulunamadı.';
    } catch (e) {
      error = e.toString().replaceFirst('Exception: ', '');
    }
    loading = false;
    notifyListeners();
    refreshResults();
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(minutes: 3), (_) => refreshResults());
  }

  Future<void> refreshResults({bool force = false}) async {
    for (final c in cities) {
      final rs = races(c.name);
      final need = rs.any((r) => raceDone(c.name, r.no) && (results[c.name]?[r.no] == null || force));
      if (!need && !force) continue;
      try {
        final got = await getResults(c, iso, rs);
        results[c.name] = {...?results[c.name], ...got};
        liveRes['$iso|${c.name}'] = {for (final e in results[c.name]!.entries) e.key: e.value.sira};
        notifyListeners();
      } catch (_) {}
    }
  }

  Future<void> ensureLoaded() async {
    if (cities.isEmpty && !loading) await load(iso);
  }
}
