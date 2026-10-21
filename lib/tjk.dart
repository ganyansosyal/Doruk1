import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:html/dom.dart';
import 'package:html/parser.dart' as hp;
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

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

final Map<String, ({DateTime t, String body})> _htmlCache = {};
Directory? _cacheDir;

int _diskTtl(String iso, int normal) => iso.compareTo(isoToday()) < 0 ? 2592000 : normal;

String _hash(String s) {
  var h = 0xcbf29ce484222325;
  for (final u in s.codeUnits) {
    h = ((h ^ u) * 0x100000001b3) & 0x7fffffffffffffff;
  }
  return h.toRadixString(16);
}

Future<File?> _diskFile(String url) async {
  try {
    var d = _cacheDir;
    if (d == null) {
      d = Directory('${(await getTemporaryDirectory()).path}/tjk');
      if (!await d.exists()) await d.create(recursive: true);
      _cacheDir = d;
    }
    return File('${d.path}/${_hash(url)}.html');
  } catch (_) {
    return null;
  }
}

Future<String> _fetch(String url, {int sec = 20, int retry = 2, int ttl = 0, int disk = 0}) async {
  if (ttl > 0) {
    final hit = _htmlCache[url];
    if (hit != null && DateTime.now().difference(hit.t).inSeconds < ttl) return hit.body;
  }
  File? f;
  if (disk > 0) {
    f = await _diskFile(url);
    try {
      if (f != null && await f.exists() && DateTime.now().difference(await f.lastModified()).inSeconds < disk) {
        final body = await f.readAsString();
        if (body.isNotEmpty) {
          if (ttl > 0) _htmlCache[url] = (t: DateTime.now(), body: body);
          return body;
        }
      }
    } catch (_) {}
  }
  final body = await _fetchRaw(url, sec: sec, retry: retry);
  if (ttl > 0) {
    if (_htmlCache.length > 40) _htmlCache.clear();
    _htmlCache[url] = (t: DateTime.now(), body: body);
  }
  if (f != null) {
    f.writeAsString(body).catchError((_) => f!);
  }
  return body;
}

Future<String> _fetchRaw(String url, {int sec = 20, int retry = 2}) async {
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

class City {
  final String id, name;
  final bool yd;
  City(this.id, this.name, this.yd);
  Map<String, dynamic> toJson() => {'id': id, 'name': name, 'yd': yd};
  factory City.fromJson(Map<String, dynamic> json) => City(json['id'], json['name'], json['yd']);
}

class Horse {
  final int no;
  final String name, jockey, yas, kgs;
  final bool kosmaz;
  final int? agf, hp;
  final double? gny, siklet;
  final List<String> son6;
  final List<String> son6p;
  final List<({String k, String a})> taki;
  final String st, s20, orijin, sahip, antrenor, eid;
  final String idmHref, idmK, idmA, atId;
  Horse({required this.no, required this.name, this.jockey = '', this.yas = '', this.kgs = '', this.kosmaz = false, this.agf, this.hp, this.gny, this.siklet, this.son6 = const [], this.son6p = const [], this.taki = const [], this.st = '', this.s20 = '', this.orijin = '', this.sahip = '', this.antrenor = '', this.eid = '', this.idmHref = '', this.idmK = '', this.idmA = '', this.atId = ''});
  Map<String, dynamic> toJson() => {'no': no, 'name': name, 'jockey': jockey, 'yas': yas, 'kgs': kgs, 'kosmaz': kosmaz, 'agf': agf, 'hp': hp, 'gny': gny, 'siklet': siklet, 'son6': son6, 'son6p': son6p, 'taki': taki.map((t) => {'k': t.k, 'a': t.a}).toList(), 'st': st, 's20': s20, 'orijin': orijin, 'sahip': sahip, 'antrenor': antrenor, 'eid': eid, 'idmHref': idmHref, 'idmK': idmK, 'idmA': idmA, 'atId': atId};
  factory Horse.fromJson(Map<String, dynamic> j) => Horse(no: j['no'], name: j['name'], jockey: j['jockey'] ?? '', yas: j['yas'] ?? '', kgs: j['kgs'] ?? '', kosmaz: j['kosmaz'] ?? false, agf: j['agf'], hp: j['hp'], gny: j['gny'] != null ? (j['gny'] as num).toDouble() : null, siklet: j['siklet'] != null ? (j['siklet'] as num).toDouble() : null, son6: List<String>.from(j['son6'] ?? []), son6p: List<String>.from(j['son6p'] ?? []), taki: (j['taki'] as List? ?? []).map((e) => (k: e['k'] as String, a: e['a'] as String)).toList(), st: j['st'] ?? '', s20: j['s20'] ?? '', orijin: j['orijin'] ?? '', sahip: j['sahip'] ?? '', antrenor: j['antrenor'] ?? '', eid: j['eid'] ?? '', idmHref: j['idmHref'] ?? '', idmK: j['idmK'] ?? '', idmA: j['idmA'] ?? '', atId: j['atId'] ?? '');
}

class Start {
  final int ord, n;
  final String tur;
  Start(this.ord, this.n, this.tur);
  Map<String, dynamic> toJson() => {'ord': ord, 'n': n, 'tur': tur};
  factory Start.fromJson(Map<String, dynamic> j) => Start(j['ord'], j['n'], j['tur']);
}

class Race {
  final int no;
  final String saat;
  final String? mesafe, pist;
  final String bilgi;
  final List<Horse> atlar;
  final List<Start> baslar;
  final List<String>? oyun;
  Race({required this.no, required this.saat, this.mesafe, this.pist, this.bilgi = '', required this.atlar, this.baslar = const [], this.oyun});
  Map<String, dynamic> toJson() => {'no': no, 'saat': saat, 'mesafe': mesafe, 'pist': pist, 'bilgi': bilgi, 'atlar': atlar.map((a) => a.toJson()).toList(), 'baslar': baslar.map((b) => b.toJson()).toList(), 'oyun': oyun};
  factory Race.fromJson(Map<String, dynamic> j) => Race(no: j['no'], saat: j['saat'], mesafe: j['mesafe'], pist: j['pist'], bilgi: j['bilgi'] ?? '', atlar: (j['atlar'] as List).map((a) => Horse.fromJson(a)).toList(), baslar: (j['baslar'] as List).map((b) => Start.fromJson(b)).toList(), oyun: j['oyun'] != null ? List<String>.from(j['oyun']) : null);
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

String _norm(String s) => s.toUpperCase().replaceAll('İ', 'I').replaceAll('Ğ', 'G').replaceAll('Ü', 'U').replaceAll('Ş', 'S').replaceAll('Ö', 'O').replaceAll('Ç', 'C');
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
}Future<List<City>> getCities(String iso) async {
  final url = 'https://www.tjk.org/TR/yarissever/Info/Page/GunlukYarisProgrami?QueryParameter_Tarih=${Uri.encodeComponent(_tjkDate(iso))}&Era=${_era(iso)}';
  final html = await _fetch(url, ttl: 300, disk: _diskTtl(iso, 600));
  final list = await compute(_citiesIso, html);
  if (list.isEmpty) throw Exception("TJK'da bu tarih için yayınlanmış bir koşu programı bulunamadı.");
  return list;
}

List<City> _citiesIso(String html) {
  final doc = hp.parse(html);
  final seen = <String>{};
  final list = <City>[];
  for (final a in doc.querySelectorAll('a[href]')) {
    final href = a.attributes['href'] ?? '';
    if (!RegExp('GunlukYarisProgrami', caseSensitive: false).hasMatch(href)) continue;
    final m = RegExp(r'[?&]SehirId=(\d+)', caseSensitive: false).firstMatch(href);
    if (m == null || !seen.add(m.group(1)!)) continue;
    var adi = '';
    final ma = RegExp(r'[?&]SehirAdi=([^&]+)', caseSensitive: false).firstMatch(href);
    if (ma != null) { try { adi = Uri.decodeComponent(ma.group(1)!.replaceAll('+', ' ')); } catch (_) { adi = ma.group(1)!; } }
    adi = _clean(adi.isEmpty ? a.text : adi);
    final first = _key(adi.split(' ').first);
    const yerli = {'ISTANBUL', 'ANKARA', 'IZMIR', 'BURSA', 'ADANA', 'SANLIURFA', 'ELAZIG', 'DIYARBAKIR', 'KOCAELI', 'IZMIT', 'ANTALYA', 'KARMA'};
    final yd = RegExp(r'\(YD\s*\d+\)', caseSensitive: false).hasMatch(adi) || RegExp(r'\bYD\s*\d+\b', caseSensitive: false).hasMatch(a.text) || (first.isNotEmpty && !yerli.contains(first));
    if (adi.isNotEmpty) list.add(City(m.group(1)!, adi, yd));
  }
  if (list.isEmpty) return list;
  final yerli = list.where((c) => !c.yd).toList();
  return yerli.isNotEmpty ? yerli : list;
}

int? _col(List<String> heads, dynamic key) {
  final keys = key is List ? key.cast<String>() : [key as String];
  for (final k in keys) { final i = heads.indexWhere((h) => _clean(h).toLowerCase().contains(k.toLowerCase())); if (i >= 0) return i; }
  return null;
}

String _pistHarf(String c) {
  if (c == 'g') return 'Ç'; if (c == 'k') return 'K'; if (c == 's') return 'S'; if (c.isEmpty) return '';
  final t = c.trim().toLowerCase();
  int? r, g, b;
  final hx = RegExp(r'^#([0-9a-f]{3}|[0-9a-f]{6})$').firstMatch(t);
  if (hx != null) { var h = hx.group(1)!; if (h.length == 3) h = h.split('').map((x) => x + x).join(); r = int.parse(h.substring(0, 2), radix: 16); g = int.parse(h.substring(2, 4), radix: 16); b = int.parse(h.substring(4, 6), radix: 16); }
  else { final rg = RegExp(r'^rgba?\(\s*(\d+)[,\s]+(\d+)[,\s]+(\d+)').firstMatch(t); if (rg != null) { r = int.parse(rg.group(1)!); g = int.parse(rg.group(2)!); b = int.parse(rg.group(3)!); } else { if (RegExp(r'green|lime|olive').hasMatch(t)) return 'Ç'; if (RegExp(r'brown|maroon|sienna|chocolate|peru|tan|orange|red').hasMatch(t)) return 'K'; if (RegExp(r'blue|navy|teal|cyan').hasMatch(t)) return 'S'; return ''; } }
  final mx = [r, g, b].reduce((x, y) => x > y ? x : y); final mn = [r, g, b].reduce((x, y) => x < y ? x : y); final d = mx - mn;
  if (d < 25) return '';
  double hue = mx == r ? ((g - b) / d) % 6 : mx == g ? (b - r) / d + 2 : (r - g) / d + 4;
  hue = (hue * 60 + 360) % 360;
  if (hue >= 75 && hue < 170) return 'Ç'; if (hue >= 170 && hue < 270) return 'S'; return 'K';
}

List<({String s, String c})> _son6Ayir(Element? hucre) {
  final out = <({String s, String c})>[];
  if (hucre == null) return out;
  String renk(Element el) {
    final sc = (el.attributes['class'] ?? '').toLowerCase();
    if (RegExp('cim|çim|green|yesil').hasMatch(sc)) return 'g';
    if (RegExp('kum|sand|brown|kahve').hasMatch(sc)) return 'k';
    if (RegExp('sentetik|synth|blue').hasMatch(sc)) return 's';
    final st = RegExp(r'color\s*:\s*([^;]+)', caseSensitive: false).firstMatch(el.attributes['style'] ?? '');
    return (st?.group(1) ?? el.attributes['color'] ?? '').trim();
  }
  void walk(Node n, String c) {
    if (n is Text) { for (final m in RegExp(r'[0-9A-Za-z\-]').allMatches(n.data)) { out.add((s: m.group(0)!, c: c)); } }
    else if (n is Element) { final rc = renk(n); for (final k in n.nodes) { walk(k, rc.isNotEmpty ? rc : c); } }
  }
  walk(hucre, '');
  return out.length > 6 ? out.sublist(out.length - 6) : out;
}

final _takiKod = RegExp(r'^[A-ZÇĞİÖŞÜ]{1,4}$');
const _takiBilinen = ['KGK', 'KDB', 'ÖDB', 'SKG', 'GKR', 'DB', 'KG', 'SK', 'ÖG', 'K'];

List<({String k, String a})> _takiCikar(Element? hucre, String isimHam, Element? atLinki) {
  final out = <({String k, String a})>[];
  void ekle(String k, String a) {
    k = k.replaceAll(RegExp(r'\s+'), ''); if (!_takiKod.hasMatch(k)) return;
    a = a.replaceAll(RegExp(r'\s+'), ' ').trim();
    final i = out.indexWhere((x) => x.k == k);
    if (i >= 0) { if (out[i].a.isEmpty && a.isNotEmpty) out[i] = (k: k, a: a); return; }
    out.add((k: k, a: a));
  }
  if (hucre != null) {
    final linkMetin = atLinki == null ? '' : _clean(atLinki.text);
    for (final el in hucre.querySelectorAll('[title],[data-original-title],[data-title],[data-content],[data-tooltip],[aria-label],[class*="taki"],[class*="ekipman"],[class*="tooltip"],sup,sub')) {
      if (identical(el, atLinki)) continue;
      var inLink = false; for (Element? p = el.parent; p != null; p = p.parent) { if (identical(p, atLinki)) { inLink = true; break; } }
      if (inLink) continue;
      var ta = ''; for (final n in ['title', 'data-original-title', 'data-title', 'data-content', 'data-tooltip', 'aria-label']) { final v = (el.attributes[n] ?? '').trim(); if (v.isNotEmpty) { ta = v; break; } }
      final t = _clean(el.text); if (t.isEmpty || t == linkMetin) continue;
      if (_takiKod.hasMatch(t)) { ekle(t, ta); continue; }
      final m = RegExp(r'^([A-ZÇĞİÖŞÜ]+)([A-ZÇĞİÖŞÜ][a-zçğıöşü][\s\S]*)$').firstMatch(t);
      if (m != null && _takiKod.hasMatch(m.group(1)!)) ekle(m.group(1)!, ta.isNotEmpty ? ta : m.group(2)!);
    }
  }
  if (out.isEmpty && isimHam.isNotEmpty) {
    var t = isimHam.replaceAll('\u00a0', ' '); if (atLinki != null) t = t.replaceAll(atLinki.text.trim(), ' ');
    t = t.replaceAll(RegExp(r'\(\s*\d+\s*\)'), ' ').replaceAll(RegExp(r'\(\s*Ko[şs]maz\s*\)', caseSensitive: false), ' ');
    for (final w in t.split(RegExp(r'\s+'))) { if (_takiBilinen.contains(w)) ekle(w, ''); }
  }
  return out;
}List<Horse> _parseHorses(Element table) {
  final rows = table.querySelectorAll('tr');
  if (rows.length < 2) return [];
  var bi = rows.indexWhere((tr) => RegExp(r'At\s*İsmi', caseSensitive: false).hasMatch(tr.text) && RegExp('Jokey', caseSensitive: false).hasMatch(tr.text));
  if (bi < 0) bi = 0;
  final heads = rows[bi].querySelectorAll('th,td').map((e) => e.text.trim()).toList();
  int? exact(String k) { final i = heads.indexWhere((h) => _clean(h) == k); return i >= 0 ? i : null; }
  final iN = exact('N') ?? _col(heads, 'N'); final iIsim = _col(heads, 'At İsmi'); final iYas = _col(heads, 'Yaş'); final iSik = _col(heads, 'Sıklet'); final iJok = _col(heads, 'Jokey'); final iHp = _col(heads, 'HP'); final iS6 = _col(heads, 'Son 6'); final iKgs = _col(heads, 'KGS'); final iGny = _col(heads, 'Gny'); final iAgf = _col(heads, 'AGF'); final iSt = exact('St') ?? _col(heads, 'St'); final iOri = _col(heads, 'Orijin'); final iSah = _col(heads, 'Sahip'); final iAnt = _col(heads, ['Antrenör', 'Antrenor', 'Antr.']); final iS20 = _col(heads, 's20'); final iEid = _col(heads, 'En İyi D'); final iIdm = _col(heads, ['İdm', 'Idm']);
  final out = <Horse>[];
  for (var i = bi + 1; i < rows.length; i++) {
    final tds = rows[i].querySelectorAll('td'); if (tds.length < 4) continue;
    String? al(int? idx) => idx != null && idx < tds.length ? tds[idx].text.trim() : null;
    String tek(int? idx) => _clean(al(idx) ?? '').replaceAll(RegExp(r'^-$'), '');
    final isimHam = al(iIsim); if (isimHam == null || isimHam.isEmpty) continue;
    final rowText = rows[i].outerHtml;
    final kosmaz = RegExp(r'ko[sş]maz|kosmaz|cekil|çekil|iptal|withdraw|scratch', caseSensitive: false).hasMatch(rows[i].className + rows[i].querySelectorAll('[class]').map((e) => e.className).join(' ')) || RegExp(r'\(\s*K\s*\)').hasMatch(isimHam) || RegExp(r'\bko[şs]maz\b', caseSensitive: false).hasMatch(rows[i].text) || rows[i].querySelector('s, strike, del, [style*="line-through"]') != null || rowText.contains('line-through');
    final isim = isimHam.split('\n').first.replaceAll(RegExp(r'\s{2,}.*$'), '').trim();
    final no = int.tryParse((al(iN) ?? '').replaceAll(RegExp(r'[^0-9]'), '')); if (no == null) continue;
    String jok = '';
    if (iJok != null && iJok < tds.length) { final a = tds[iJok].querySelector('a'); jok = _clean((a?.text.trim().isNotEmpty ?? false) ? a!.text : tds[iJok].text).replaceAll(RegExp(r'\s*AP\s*Apranti.*$', caseSensitive: false), '').replaceAll(RegExp(r'\s+AP$'), '').trim(); }
    final s6x = _son6Ayir(iS6 != null && iS6 < tds.length ? tds[iS6] : null);
    final isimHucre = iIsim != null && iIsim < tds.length ? tds[iIsim] : null;
    final atLinki = isimHucre?.querySelector('a');
    final taki = _takiCikar(isimHucre, isimHam, atLinki);
    var idmHref = '', idmK = '', idmA = '';
    if (iIdm != null && iIdm < tds.length) {
      final hc = tds[iIdm];
      for (final el in [hc, ...hc.querySelectorAll('*')]) {
        final v = el.attributes.values.join(' ');
        final k1 = RegExp(r'KosuKodu=(-?\d+)', caseSensitive: false).firstMatch(v);
        final a1 = RegExp(r'Atkodu=(\d+)', caseSensitive: false).firstMatch(v);
        if (k1 != null && a1 != null) { idmK = k1.group(1)!; idmA = a1.group(1)!; final h = el.attributes['href'] ?? ''; if (h.isNotEmpty) idmHref = h.startsWith('http') ? h : 'https://www.tjk.org${h.startsWith('/') ? '' : '/'}$h'; break; }
      }
    }
    out.add(Horse(no: no, name: isim.isEmpty ? isimHam.substring(0, isimHam.length.clamp(0, 40)) : isim, jockey: jok, yas: _clean(al(iYas) ?? ''), kgs: _clean(al(iKgs) ?? ''), kosmaz: kosmaz, agf: int.tryParse(RegExp(r'(\d+)').firstMatch(al(iAgf) ?? '')?.group(1) ?? ''), hp: int.tryParse((al(iHp) ?? '').trim()), gny: double.tryParse((al(iGny) ?? '').replaceAll(',', '.')), siklet: double.tryParse((al(iSik) ?? '').replaceAll(',', '.')), son6: s6x.map((e) => e.s).toList(), son6p: s6x.map((e) => _pistHarf(e.c)).toList(), taki: taki, st: RegExp(r'^(\d{1,2})(?!\d)').firstMatch(_clean(al(iSt) ?? ''))?.group(1) ?? '', s20: tek(iS20), orijin: tek(iOri), sahip: tek(iSah), antrenor: tek(iAnt), eid: tek(iEid), idmHref: idmHref, idmK: idmK, idmA: idmA, atId: RegExp(r'AtId=(\d+)', caseSensitive: false).firstMatch(atLinki?.attributes['href'] ?? '')?.group(1) ?? ''));
  }
  return out;
}

String _bilgiAyikla(String ham) {
  final t = _clean(ham); final l = _trLower(t); final m = _pistRe.firstMatch(l); if (m == null) return '';
  var end = m.end; final eid = RegExp(r'^\s*,?\s*E\.?\s*[İIi]\.?\s*D\.?\s*:\s*[\d.]+').firstMatch(t.substring(end.clamp(0, t.length))); if (eid != null) end += eid.group(0)!.length; if (end > t.length) end = t.length;
  var head = t.substring(0, end).replaceFirst(RegExp(r'^[\s\S]*Koşu\s+\d{1,2}[:.]\d{2}\s*'), '');
  head = head.replaceFirst(RegExp(r'^[\s\S]*(?:Birinci Primi|Koşu İkramiyesi|İkramiye|Primi)[^,]*?(?:\d\s*TL|₺)\s*', caseSensitive: false), '').trim();
  if (head.length < 12 || head.length > 320) return '';
  final lh = _trLower(head); final ok = RegExp(r'yaş|\bkg\b|yukarı|araplar|ingilizler|handikap|maiden|şartlı|dişi|erkek').hasMatch(lh) || ','.allMatches(lh).length >= 2;
  return ok ? head : '';
}

List<Race> _parseRaces(Document doc, Map<int, List<Start>> bas, Map<int, List<String>> oyun) {
  final all = _all(doc); final idx = <Element, int>{for (var i = 0; i < all.length; i++) all[i]: i};
  final heads = all.where(_isHead).toList(); final tables = doc.querySelectorAll('table');
  final cand = <int, List<({String saat, String bilgi, List<Horse> atlar})>>{};
  for (var h = 0; h < heads.length; h++) {
    final he = heads[h]; final m = _headRe.firstMatch(he.text.trim())!;
    final no = int.parse(m.group(1)!); final saat = '${m.group(2)!.padLeft(2, '0')}:${m.group(3)}';
    final start = idx[he]!; final end = h + 1 < heads.length ? idx[heads[h + 1]]! : all.length;
    Element? tablo; for (final t in tables) { final ti = idx[t]; if (ti != null && ti > start && ti < end) { tablo = t; break; } }
    var bilgi = ''; final stop = tablo != null ? idx[tablo]! : end;
    for (var i = start + 1; i < stop && i < all.length; i++) { final ay = _bilgiAyikla(all[i].text); if (ay.isEmpty) continue; if (all[i].children.any((c) => _bilgiAyikla(c.text).isNotEmpty)) continue; bilgi = ay; break; }
    if (bilgi.isEmpty && he.parent != null) bilgi = _bilgiAyikla(he.parent!.text);
    bilgi = bilgi.replaceFirst(RegExp(r'\s*(?:Birinci Primi|Koşu İkramiyesi|İkramiye|Primi)[\s\S]*$', caseSensitive: false), '').replaceAll(RegExp(r'\s+,'), ',').replaceAll(RegExp(r'[\s,]+$'), '').trim();
    final atlar = tablo != null ? _parseHorses(tablo) : <Horse>[];
    cand.putIfAbsent(no, () => []).add((saat: saat, bilgi: bilgi, atlar: atlar));
  }
  final out = <Race>[]; final nos = cand.keys.toList()..sort();
  for (final no in nos) {
    final c = cand[no]!; var pick = c.last;
    for (var i = c.length - 1; i >= 0; i--) { if (c[i].atlar.isNotEmpty) { pick = c[i]; break; } }
    if (pick.atlar.isEmpty) continue;
    String? mesafe, pist; final mp = _pistRe.firstMatch(_trLower(pick.bilgi));
    if (mp != null) { mesafe = '${int.parse(mp.group(1)!.replaceAll('.', ''))} m'; final p = mp.group(2)!; pist = p == 'çim' ? 'Çim' : p == 'kum' ? 'Kum' : 'Sentetik'; }
    out.add(Race(no: no, saat: pick.saat, mesafe: mesafe, pist: pist, bilgi: pick.bilgi, atlar: pick.atlar, baslar: bas[no] ?? const [], oyun: oyun[no]));
  }
  return out;
}
