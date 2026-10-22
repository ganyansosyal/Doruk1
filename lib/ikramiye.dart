import 'dart:convert';

import 'scoring.dart';
import 'tjk.dart';

/// Web'deki ikramiye kutusunun (03-feed.js) Dart karşılığı.
/// - Hesaplanan ikramiye kuponun kendi kaydına (coupon.ikrD) yazılır: gün atlayınca da kaybolmaz.
/// - Kuponun günü ekranda yüklü değilse (geçmiş gün) o günün sonuçları TJK'dan ayrıca çekilir.

final _tutRe = RegExp(r',\d{1,2}$');
bool _valid(String v) => _tutRe.hasMatch(v);

typedef IkrItem = ({String d, String t});

class Ikr {
  final String ad;
  final List<IkrItem> items;
  final bool noPub; // TJK bu bahsin ikramiyesini yayınlamadı
  const Ikr(this.ad, this.items, {this.noPub = false});
  bool get ready => items.isNotEmpty;

  Map<String, dynamic> toMap() => {
        'ad': ad,
        'it': [
          for (final i in items) {'d': i.d, 't': i.t}
        ],
      };

  static Ikr? fromMap(dynamic m) {
    if (m is! Map) return null;
    final it = <IkrItem>[];
    for (final x in ((m['it'] as List?) ?? const [])) {
      if (x is Map && _valid((x['t'] ?? '').toString())) {
        it.add((d: (x['d'] ?? '').toString(), t: x['t'].toString()));
      }
    }
    if (it.isEmpty) return null;
    return Ikr((m['ad'] ?? '').toString(), it);
  }
}

/// Bir günün (bir hipodromun) programı ve sonuçları: bugün TjkStore'dan, geçmiş gün TJK'dan.
class _Day {
  final List<Race> races;
  final Map<int, RaceResult> res;
  const _Day(this.races, this.res);
  List<Bahis> bh(int no) => res[no]?.bahis ?? const <Bahis>[];
}

List<Map> _legs(Map c) => ((c['legs'] as List?) ?? const []).whereType<Map>().toList();
String _city(Map c) => (c['city'] ?? '').toString();
String _iso(Map c) => (c['iso'] ?? '').toString();
int _r(Map l) => (l['r'] as num?)?.toInt() ?? 0;
String _fam(Map c) => (c['type'] ?? '').toString().replaceAll(RegExp(r'\s*\((Tek kolon|Virgüllü)\)\s*$', caseSensitive: false), '').trim();

Bahis? _odeme(_Day d, int ord, int n, String tur) {
  final pre = ord > 0 ? '$ord\\. ' : '';
  final re = RegExp('^$pre$n\'li $tur\$');
  for (final k in d.races) {
    for (final b in d.bh(k.no)) {
      if (re.hasMatch(b.tur)) return b;
    }
  }
  return null;
}

const _tekMap = <String, List<String>>{
  'Plase': ['Plase'],
  'Ganyan & Plase': ['Ganyan', 'Plase'],
  'İkili Bahis': ['İkili'],
  'Sıralı İkili': ['Sıralı İkili'],
  'Plase İkili': ['Plase İkili'],
  'Sıralı Üçlü': ['Üçlü Bahis', 'Sıralı Üçlü'],
  'Ganyan': ['Ganyan'],
  'Tabela Bahis': ['Tabela Bahis'],
  'Tabela': ['Tabela Bahis'],
  'Sıralı Beşli': ['Sıralı Beşli'],
};

bool _isMulti(Map c, List<Map> legs) => !legs.any((l) => l['slot'] != null) && legs.length >= 3 && ruleOf(c) == 'win';
bool _isCokAyak(Map c, List<Map> legs) {
  final t = (c['type'] ?? '').toString();
  return (t == 'Çifte Bahis' || t == "7'li Plase") && !legs.any((l) => l['slot'] != null);
}

/// İkramiye kutusu bu kupon için geçerli mi? (tutan tek Ganyan'da kazanç ayrı gösterilir)
bool _applies(Map c, List<Map> legs) {
  if (legs.isEmpty || _city(c).isEmpty) return false;
  if (_isMulti(c, legs) || _isCokAyak(c, legs)) return true;
  final ad = _fam(c);
  if (!_tekMap.containsKey(ad)) return false;
  final r0 = _r(legs[0]);
  if (!legs.every((l) => _r(l) == r0)) return false;
  if (ad == 'Ganyan' && couponStatus(c).k != 'lose') return false;
  return true;
}

Ikr? _multi(Map c, List<Map> legs, _Day d) {
  final cols = legs.length;
  var ord = (c['ord'] as num?)?.toInt() ?? 0;
  final r0 = _r(legs[0]);
  for (final k in d.races) {
    if (k.no != r0) continue;
    for (final s in k.baslar) {
      if (s.tur == 'GANYAN' && s.n == cols) {
        ord = s.ord;
        break;
      }
    }
  }
  var od = _odeme(d, ord, cols, 'Ganyan');
  if (od == null && c['ord'] == null) od = _odeme(d, 0, cols, 'Ganyan');
  final ad = _fam(c);
  if (od != null && _valid(od.tutar)) return Ikr(ad, [(d: '', t: od.tutar)]);
  return Ikr(ad, const []);
}

Ikr? _tek(Map c, List<Map> legs, _Day d) {
  final ad = _fam(c);
  final tur = _tekMap[ad];
  if (tur == null) return null;
  final r0 = _r(legs[0]);
  final picks = ((legs[0]['picks'] as List?) ?? const []).whereType<num>().map((e) => e.toInt()).toList();
  final bh = d.bh(r0);
  final items = <IkrItem>[];
  for (final tr in tur) {
    var es = bh.where((x) => x.tur == tr && _valid(x.tutar)).toList();
    if (tr == 'Plase' || tr == 'Ganyan') {
      final mine = es.where((x) {
        final n = int.tryParse(RegExp(r'^\d+').firstMatch(x.detay)?.group(0) ?? '');
        return n != null && picks.contains(n);
      }).toList();
      if (mine.isNotEmpty) es = mine;
    }
    for (final x in es) {
      items.add((d: (ad == 'Ganyan & Plase' ? '$tr ' : '') + x.detay.trim(), t: x.tutar));
    }
  }
  if (items.isEmpty) return Ikr(ad, const [], noPub: bh.isNotEmpty);
  return Ikr(ad, items);
}

Ikr? _cokAyak(Map c, List<Map> legs, _Day d) {
  final type = (c['type'] ?? '').toString();
  final isC = type == 'Çifte Bahis';
  var ad = isC ? 'Çifte Bahis' : "7'li Plase";
  var ord = (c['ord'] as num?)?.toInt() ?? 0;
  final r0 = _r(legs[0]);
  for (final k in d.races) {
    if (k.no != r0) continue;
    for (final s in k.baslar) {
      if (isC ? s.tur == 'CIFTE' : (s.tur == 'PLASE' && s.n == 7)) {
        if (s.ord > 0) ord = s.ord;
        break;
      }
    }
  }
  Bahis? od;
  if (isC) {
    final cifteRe = RegExp(r'^\d+\. Çifte$');
    final all = <Bahis>[];
    for (final k in d.races) {
      for (final x in d.bh(k.no)) {
        if (cifteRe.hasMatch(x.tur) && _valid(x.tutar) && !all.any((y) => y.tur == x.tur)) all.add(x);
      }
    }
    final byR = all.where((x) => x.tur == '$r0. Çifte');
    if (byR.isNotEmpty) {
      od = byR.first;
    } else if (ord > 0) {
      final byO = all.where((x) => x.tur == '$ord. Çifte');
      od = byO.isNotEmpty ? byO.first : null;
    } else if (all.length == 1) {
      od = all.first;
    }
    if (od != null && all.length > 1) ad = od.tur;
    if (ord > 0 && !(od != null && cifteRe.hasMatch(od.tur))) ad = '$ord. Çifte';
  } else {
    od = _odeme(d, ord, 7, 'Plase') ?? (c['ord'] == null ? _odeme(d, 0, 7, 'Plase') : null);
  }
  if (od != null && _valid(od.tutar)) return Ikr(ad, [(d: '', t: od.tutar)]);
  return Ikr(ad, const []);
}

/// Verilen günün verisiyle ikramiyeyi hesapla. null → ikramiye kutusu bu kupon için yok / ayaklar bitmedi.
Ikr? _calc(Map c, _Day d) {
  final legs = _legs(c);
  if (!_applies(c, legs)) return null;
  if (!legs.every((l) => legSt(c, l) != 'p')) return null; // tüm ayaklar bitmeden gösterme
  if (_isMulti(c, legs)) return _multi(c, legs, d);
  if (_isCokAyak(c, legs)) return _cokAyak(c, legs, d);
  return _tek(c, legs, d);
}

/// Bugünün (TjkStore'da yüklü günün) verisinden hesapla. Gün yüklü değilse null.
Ikr? ikramiyeLive(Map c) {
  if (_iso(c) != TjkStore.i.iso) return null;
  final city = _city(c);
  if (city.isEmpty) return null;
  return _calc(c, _Day(TjkStore.i.races(city), TjkStore.i.results[city] ?? const <int, RaceResult>{}));
}

// ---- Geçmiş gün: o günün sonuçlarını TJK'dan ayrıca çek (ekrandaki günü bozmaz) ----
final Map<String, Future<_Day?>> _dayMem = {};
final Map<String, Future<Ikr?>> _fetchMem = {};
final Map<String, Ikr> _fetched = {}; // çekilip hesaplananlar: sonraki çizimlerde anında gelsin

String _key(Map c) => jsonEncode([_iso(c), _city(c), c['type'], c['ord'], _legs(c).map((l) => [l['r'], l['picks']]).toList()]);

Future<_Day?> _loadDay(String iso, String city) {
  final k = '$iso|$city';
  return _dayMem.putIfAbsent(k, () async {
    try {
      final cs = await getCities(iso);
      City? ct;
      for (final x in cs) {
        if (x.name == city) ct = x;
      }
      if (ct == null) return null;
      final rs = await getProgram(ct, iso);
      final res = await getResults(ct, iso, rs);
      return _Day(rs, res);
    } catch (_) {
      _dayMem.remove(k);
      return null;
    }
  });
}

/// Kuponun günü ekranda yüklü değilse o günün sonuçlarını çekip ikramiyeyi hesaplar (aynı kupon için tek kez).
Future<Ikr?> ikramiyeFetch(Map c) {
  final iso = _iso(c), city = _city(c);
  if (iso.isEmpty || city.isEmpty) return Future.value(null);
  return _fetchMem.putIfAbsent(_key(c), () async {
    final d = await _loadDay(iso, city);
    if (d == null) {
      _fetchMem.remove(_key(c));
      return null;
    }
    final k = _calc(c, d);
    if (k != null && k.ready) _fetched[_key(c)] = k;
    return k;
  });
}

/// Geçmiş günden çekilmesi gereken kupon mu? (günü yüklü değil, kayıtlı ikramiye yok, ayaklar bitmiş)
bool ikramiyeFetchGerek(Map c) {
  if (_iso(c).isEmpty || _iso(c) == TjkStore.i.iso) return false;
  if (Ikr.fromMap(c['ikrD']) != null || _fetched.containsKey(_key(c))) return false;
  final legs = _legs(c);
  return _applies(c, legs) && legs.every((l) => legSt(c, l) != 'p');
}

/// Ekranda gösterilecek ikramiye: önce kuponda saklı olan, sonra çekilmiş/canlı hesap, yoksa "bekleniyor".
/// null → ikramiye kutusu gösterilmez.
Ikr? ikramiyeOf(Map c) {
  final legs = _legs(c);
  if (legs.isEmpty) return null;
  final saved = Ikr.fromMap(c['ikrD']);
  if (saved != null) return saved;
  final ad = _fam(c);
  final a = (c['ikr'] ?? '').toString(), b = (c['ikr2'] ?? '').toString(); // web'in yazdığı alanlar
  if (_valid(a)) return Ikr(ad, [(d: '', t: a)]);
  if (_valid(b)) return Ikr(ad, [(d: '', t: b)]);
  if (!legs.every((l) => legSt(c, l) != 'p')) return null;
  if (!_applies(c, legs)) return null;
  final f = _fetched[_key(c)];
  if (f != null) return f;
  final live = ikramiyeLive(c);
  return live ?? Ikr(ad, const []);
}

/// Firestore'a yazılacak alanlar (web ile uyumlu ikr / ikr2 de eklenir).
Map<String, dynamic> ikrPatch(Map c, Ikr k) {
  final p = <String, dynamic>{'coupon.ikrD': k.toMap()};
  final legs = _legs(c);
  if (k.items.length == 1) {
    if (_isMulti(c, legs)) p['coupon.ikr'] = k.items.first.t;
    if (_isCokAyak(c, legs)) p['coupon.ikr2'] = k.items.first.t;
  }
  return p;
}
