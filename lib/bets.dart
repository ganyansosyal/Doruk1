import 'tjk.dart';

class BetType {
  final String k, name, mode, rule, sub, desc, hint;
  final int n, slots, tabs, exact;
  final bool one, vir, per;
  final int? si;
  const BetType(this.k, this.name, this.mode, this.rule,
      {this.n = 0, this.slots = 0, this.tabs = 0, this.exact = 0, this.one = false, this.vir = false, this.per = false, this.si, this.sub = '', this.desc = '', this.hint = ''});
}

const kTypes = <BetType>[
  BetType('p7', "7'li Plase", 'legs', 'place', n: 7, sub: '7 ayak', desc: "7 ayakta plase'ye girecek atları bul"),
  BetType('g7', "7'li Ganyan", 'legs', 'win', n: 7, sub: '7 ayak'),
  BetType('g6', "6'lı Ganyan", 'legs', 'win', n: 6, sub: '6 ayak', si: 0),
  BetType('g6b', "6'lı Ganyan", 'legs', 'win', n: 6, sub: '6 ayak', si: 1),
  BetType('g5', "5'li Ganyan", 'legs', 'win', n: 5, sub: '5 ayak', si: 0),
  BetType('g5b', "5'li Ganyan", 'legs', 'win', n: 5, sub: '5 ayak', si: 1),
  BetType('g4', "4'lü Ganyan", 'legs', 'win', n: 4, sub: '4 ayak', si: 0),
  BetType('g4b', "4'lü Ganyan", 'legs', 'win', n: 4, sub: '4 ayak', si: 1),
  BetType('g3', "3'lü Ganyan", 'legs', 'win', n: 3, sub: '3 ayak', si: 0),
  BetType('g3b', "3'lü Ganyan", 'legs', 'win', n: 3, sub: '3 ayak', si: 1),
  BetType('g1', 'Ganyan', 'race', 'win', sub: '1. gelen', desc: 'Tek koşuda kazananı bul'),
  BetType('pl', 'Plase', 'race', 'place', sub: 'plase', desc: "Seçtiğin at plase'ye girer mi?", hint: 'Bir veya daha fazla at seç. Plase: birinci veya ikinci gelen at tutar (en az 7 atlı koşu).'),
  BetType('gp', 'Ganyan & Plase', 'race', 'gp', sub: '1. + plase', desc: 'Hem ganyan hem plase oyna', hint: 'Seçtiğin her at hem ganyan hem plase oynar.'),
  BetType('si', 'Sıralı İkili', 'race', 'slots', slots: 2, sub: 'sıralı ilk 2', desc: 'İlk iki atı sırasıyla bul', hint: 'Üstteki sekmeden sırayı seç (1. At / 2. At), her sıra için at işaretle.'),
  BetType('siv', 'Sıralı İkili (Virgüllü)', 'race', 'slots', slots: 2, one: true, vir: true, sub: 'sıralı ilk 2', desc: 'En az 2 at seç, sıran önemli (virgüllü)', hint: 'Atlara sırayla dokun (en az 2). Dokunma sırası = sıralaman.'),
  BetType('ik', 'İkili Bahis', 'race', 'any2', tabs: 2, sub: 'ilk 2', desc: 'İlk iki atı sırasız bul', hint: '1. At ve 2. At sekmelerinden birer veya daha fazla at seç.'),
  BetType('ik1', 'İkili Bahis (Tek kolon)', 'race', 'any2', sub: 'tek kolon', desc: 'İlk iki at, tek kolon', hint: 'En az 2 at seç. Olası tüm ikili çiftler oynanır.'),
  BetType('c2', 'Çifte Bahis', 'legs', 'win', n: 2, sub: '2 ayak', si: 0),
  BetType('c2b', 'Çifte Bahis', 'legs', 'win', n: 2, sub: '2 ayak', si: 1),
  BetType('pi', 'Plase İkili', 'race', 'pl2', tabs: 2, sub: 'plase 2 at', desc: "Plase'ye girecek iki atı bul", hint: '1. At ve 2. At sekmelerinden at seç.'),
  BetType('pi1', 'Plase İkili (Tek kolon)', 'race', 'pl2', exact: 2, sub: 'tek kolon', desc: 'Plase ikili, tek kolon', hint: 'Tam 2 at seç.'),
  BetType('su', 'Sıralı Üçlü', 'race', 'slots', slots: 3, sub: 'sıralı ilk 3', desc: 'İlk üç atı sırasıyla bul', hint: 'Üstteki sekmeden sırayı seç (1. / 2. / 3. At).'),
  BetType('suv', 'Sıralı Üçlü (Virgüllü)', 'race', 'slots', slots: 3, one: true, vir: true, sub: 'sıralı ilk 3', desc: 'En az 3 at seç, sıran önemli (virgüllü)', hint: 'Atlara sırayla dokun (en az 3).'),
  BetType('tb', 'Tabela Bahis', 'race', 'any4', exact: 4, tabs: 4, per: true, sub: 'ilk 4', desc: 'İlk dört atı sırasız bul', hint: 'Her sekmeye bir at seç (1.–4. At).'),
  BetType('tbv', 'Tabela (Virgüllü)', 'race', 'any4', sub: 'ilk 4', desc: 'İlk dört atı sırasız bul, çoklu seçim', hint: 'İlk dörde girebilecek atları seç (en az 4).'),
  BetType('s5', 'Sıralı Beşli', 'race', 'slots', slots: 5, sub: 'sıralı ilk 5', desc: 'İlk beş atı sırasıyla bul', hint: 'Üstteki sekmeden sırayı seç (1.–5. At).'),
  BetType('s5v', 'Sıralı Beşli (Virgüllü)', 'race', 'slots', slots: 5, one: true, vir: true, sub: 'sıralı ilk 5', desc: 'En az 5 at seç, sıran önemli (virgüllü)', hint: 'Atlara sırayla dokun (en az 5).'),
];

const _legMap = <String, (String, int)>{
  'p7': ('PLASE', 7), 'g7': ('GANYAN', 7), 'g6': ('GANYAN', 6), 'g6b': ('GANYAN', 6), 'g5': ('GANYAN', 5), 'g5b': ('GANYAN', 5),
  'g4': ('GANYAN', 4), 'g4b': ('GANYAN', 4), 'g3': ('GANYAN', 3), 'g3b': ('GANYAN', 3), 'c2': ('CIFTE', 2), 'c2b': ('CIFTE', 2),
};

const oyunKey = <String, String>{'g1': 'g1', 'pl': 'pl', 'gp': 'gp', 'si': 'si', 'siv': 'si', 'ik': 'ik', 'ik1': 'ik', 'pi': 'pi', 'pi1': 'pi', 'su': 'su', 'suv': 'su', 'tb': 'tb', 'tbv': 'tb', 's5': 's5', 's5v': 's5'};
const oyunMin = <String, int>{'pl': 7, 'gp': 7, 'ik': 7, 'si': 4, 'pi': 10, 'su': 7, 'tb': 7, 's5': 12};

const asgari = 20.0;
const altiliMax = 1500.0;
const tahminLimit = 2;

bool limitliMi(String t) => t == "6'lı Ganyan" || t == "7'li Ganyan";

String tLabelBase(BetType t) => t.name;

List<int> legStarts(BetType t, String city) {
  final mp = _legMap[t.k];
  if (mp == null) return [];
  return TjkStore.i.races(city).where((k) => k.baslar.any((x) => x.tur == mp.$1 && x.n == mp.$2)).map((k) => k.no).toList();
}

bool _legBilgiVar(String city) => TjkStore.i.races(city).any((k) => k.baslar.isNotEmpty);

/// Ayak grubunun başlangıç koşusu (null = bu şehirde oynanamaz).
int? legStart(BetType t, String city, {int? picked, bool admin = false}) {
  final s = TjkStore.i;
  final n = s.races(city).length;
  bool open(int r) => admin || s.isPast || !s.raceDone(city, r);
  if (_legBilgiVar(city)) {
    final st0 = legStarts(t, city);
    if (picked != null && st0.contains(picked) && open(picked)) return picked;
  }
  if (t.si != null) {
    if (_legBilgiVar(city)) {
      final st = legStarts(t, city);
      return t.si! < st.length ? st[t.si!] : null;
    }
    return t.si == 1 ? null : (n >= t.n ? n - t.n + 1 : null);
  }
  if (_legBilgiVar(city)) {
    final st = legStarts(t, city);
    if (st.isEmpty) return null;
    return st.firstWhere(open, orElse: () => st.last);
  }
  return n >= t.n ? n - t.n + 1 : null;
}

List<int> allRaces(String city) => TjkStore.i.races(city).map((k) => k.no).toList();

bool oyunMusait(BetType t, String city, int r) {
  final key = oyunKey[t.k];
  if (key == null || key == 'g1') return true;
  final k = TjkStore.i.race(city, r);
  if (k == null) return false;
  if (k.oyun != null && k.oyun!.isNotEmpty) return k.oyun!.contains(key);
  return k.atlar.where((a) => !a.kosmaz).length >= (oyunMin[key] ?? 0);
}

class Musait {
  final bool ok;
  final String why;
  const Musait(this.ok, [this.why = '']);
}

Musait typeMusait(BetType t, String city, {bool admin = false, int? picked}) {
  final s = TjkStore.i;
  final n = s.races(city).length;
  if (n == 0) return const Musait(true);
  bool open(int r) => admin || s.isPast || !s.raceDone(city, r);
  if (t.mode == 'race') {
    final key = oyunKey[t.k];
    if (key == null || key == 'g1') return const Musait(true);
    final kos = allRaces(city).where((r) => oyunMusait(t, city, r) && open(r));
    if (kos.isNotEmpty) return const Musait(true);
    return Musait(false, allRaces(city).any((r) => oyunMusait(t, city, r)) ? 'koşular bitti' : '$city programında yok');
  }
  final ilk = legStart(t, city, picked: picked, admin: admin);
  if (ilk == null) return Musait(false, _legBilgiVar(city) ? '$city programında yok' : "$city'da $n koşu var");
  if (ilk + t.n - 1 > n) return Musait(false, '$city programında yok');
  if (!admin && !s.isPast && s.raceDone(city, ilk)) return Musait(false, '$ilk. koşu başladı');
  return const Musait(true);
}

List<int> legRaces(BetType t, String city, {int? picked, bool admin = false}) {
  final n = TjkStore.i.races(city).length;
  final nos = allRaces(city);
  if (t.mode != 'legs') return nos;
  final ilk = legStart(t, city, picked: picked, admin: admin);
  if (ilk == null) {
    final m = n < t.n ? n : t.n;
    return List.generate(m, (i) => nos.isEmpty ? i + 1 : nos[n - m + i]);
  }
  final len = (n - ilk + 1) < t.n ? (n - ilk + 1) : t.n;
  return List.generate(len, (i) => ilk + i);
}

/* ---------------- Fiyat / kolon ---------------- */

double birimFiyat(String tur, String sehir) {
  if (tur.startsWith("6'lı Ganyan")) return RegExp(r'diyarbak|elaz|[sş]anl[ıi]urfa', caseSensitive: false).hasMatch(sehir) ? 1 : 1.25;
  if (tur.startsWith("5'li Ganyan")) return 1.5;
  if (tur.startsWith("4'lü Ganyan")) return 1.75;
  if (tur.startsWith("3'lü Ganyan")) return 2;
  if (RegExp(r"^7'li (Plase|Ganyan)").hasMatch(tur)) return 2;
  if (tur.startsWith('Plase İkili')) return 2;
  if (tur.startsWith('Ganyan & Plase')) return 2;
  if (tur.startsWith('Sıralı Üçlü')) return 2;
  if (tur.startsWith('Tabela')) return 1.5;
  if (tur.startsWith('Sıralı Beşli')) return 1.25;
  return 1;
}

String money(double n) {
  final p = n.toStringAsFixed(2).split('.');
  final ip = p[0].replaceAllMapped(RegExp(r'\B(?=(\d{3})+(?!\d))'), (m) => '.');
  return '$ip,${p[1]} ₺';
}

int _comb(int n, int k) {
  if (k < 0 || k > n) return 0;
  double r = 1;
  for (var i = 1; i <= k; i++) {
    r = r * (n - k + i) / i;
  }
  return r.round();
}

List<List<int>> _picksOf(Map c) =>
    ((c['legs'] as List?) ?? const []).whereType<Map>().map((l) => ((l['picks'] as List?) ?? const []).whereType<num>().map((e) => e.toInt()).toList()).toList();

int kolon(Map c) {
  final ps = _picksOf(c);
  if (ps.isEmpty) return 0;
  final rule = (c['rule'] ?? 'win').toString();
  final vir = c['vir'];
  if (vir is num && vir > 0) return ps.length >= vir ? _comb(ps.length, vir.toInt()) : 0;
  if (rule == 'slots') {
    var cnt = 0;
    void rec(int i, List<int> used) {
      if (i == ps.length) {
        cnt++;
        return;
      }
      for (final n in ps[i]) {
        if (!used.contains(n)) rec(i + 1, [...used, n]);
      }
    }

    rec(0, []);
    return cnt;
  }
  final legs = ((c['legs'] as List?) ?? const []).whereType<Map>().toList();
  if ((rule == 'any2' || rule == 'pl2') && legs[0]['sets'] != null) {
    final sets = ((legs[0]['sets'] as List?) ?? const []).whereType<Map>().toList();
    final a = sets.isNotEmpty ? ((sets[0]['p'] as List?) ?? const []).whereType<num>().map((e) => e.toInt()).toList() : <int>[];
    final b = sets.length > 1 ? ((sets[1]['p'] as List?) ?? const []).whereType<num>().map((e) => e.toInt()).toList() : <int>[];
    final seen = <String>{};
    for (final x in a) {
      for (final y in b) {
        if (x != y) seen.add('${x < y ? x : y}-${x < y ? y : x}');
      }
    }
    return seen.length;
  }
  if (rule == 'any2' || rule == 'pl2') {
    final m = ps[0].length;
    return m * (m - 1) ~/ 2;
  }
  if (rule == 'any4') {
    final m = ps[0].length;
    return m < 4 ? 0 : m * (m - 1) * (m - 2) * (m - 3) ~/ 24;
  }
  if (rule == 'gp') return ps[0].length;
  return ps.fold<int>(1, (a, p) => a * p.length);
}

double couponCost(Map c) => kolon(c) * birimFiyat((c['type'] ?? '').toString(), (c['city'] ?? '').toString()) * ((c['misli'] as num?)?.toInt() ?? 1);
