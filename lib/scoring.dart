import 'feed.dart' show Post;
import 'tjk.dart' show liveRes;

/// Web'deki puan/kupon durumu mantığının Dart karşılığı (kuponda kayıtlı sonuçlara göre).
const gunlukTavan = 20.0;

const _typePts = <String, double>{
  "7'li Ganyan": 15, "6'lı Ganyan": 10, "5'li Ganyan": 5, "7'li Plase": 4, "4'lü Ganyan": 3,
  'Sıralı Üçlü': 3, 'Sıralı Beşli': 8, 'Tabela': 4, 'Tabela Bahis': 4, "3'lü Ganyan": 2,
  'Çifte Bahis': 1, 'Sıralı İkili': 1, 'İkili Bahis': 0.5, 'Plase İkili': 0.5,
  'Ganyan': 0.5, 'Ganyan & Plase': 0.5, 'Plase': 0.25,
};

double typePts(String t) => _typePts[t.replaceAll(RegExp(r'\s*\(.*\)\s*$'), '').trim()] ?? 0.5;

String fmtPts(double n) {
  final s = (n == n.roundToDouble()) ? n.toInt().toString() : n.toStringAsFixed(2).replaceFirst(RegExp(r'0+$'), '');
  return s.replaceAll('.', ',');
}

List<int> _ints(dynamic v) => ((v as List?) ?? const []).whereType<num>().map((e) => e.toInt()).toList();
List<Map> _maps(dynamic v) => ((v as List?) ?? const []).whereType<Map>().toList();
String ruleOf(Map c) => (c['rule'] ?? 'win').toString();

List<int>? _resOfC(Map c, Map l) {
  final r = _resOf(l);
  if (r != null) return r;
  final m = liveRes['${c['iso'] ?? ''}|${c['city'] ?? ''}'];
  final n = (l['r'] as num?)?.toInt();
  return (m != null && n != null) ? m[n] : null;
}

List<int>? _resOf(Map l) {
  if (l['res'] is List) return _ints(l['res']);
  if (l['win'] is num) return [(l['win'] as num).toInt()];
  return null;
}

Set<String> _setPairs(dynamic sets) {
  final ss = _maps(sets);
  final a = ss.isNotEmpty ? _ints(ss[0]['p']) : <int>[];
  final b = ss.length > 1 ? _ints(ss[1]['p']) : <int>[];
  final out = <String>{};
  for (final x in a) {
    for (final y in b) {
      if (x != y) out.add('${x < y ? x : y}-${x < y ? y : x}');
    }
  }
  return out;
}

/// 'p' bekliyor · 'h' tuttu · 'm' kaçtı
String legSt(Map c, Map l) {
  final res = _resOfC(c, l);
  if (res == null || res.isEmpty) return 'p';
  final picks = _ints(l['picks']);
  final vir = c['vir'];
  if (vir is num && vir > 0) {
    final top = res.take(vir.toInt()).toList();
    return (picks.isNotEmpty && top.contains(picks.first)) ? 'h' : 'm';
  }
  final rule = ruleOf(c);
  final p = rule == 'pl2' ? 3 : 2;
  bool hit;
  if (rule == 'win') {
    hit = picks.contains(res[0]);
  } else if (rule == 'place' || rule == 'gp') {
    hit = picks.any(res.take(p).contains);
  } else if (rule == 'slots') {
    final i = (l['slot'] as num?)?.toInt() ?? 0;
    hit = i < res.length && picks.contains(res[i]);
  } else if (rule == 'any2') {
    final top = res.take(2).toList();
    if (l['sets'] != null) {
      hit = top.length == 2 && _setPairs(l['sets']).contains('${top[0] < top[1] ? top[0] : top[1]}-${top[0] < top[1] ? top[1] : top[0]}');
    } else {
      hit = top.every(picks.contains);
    }
  } else if (rule == 'any4') {
    final top = res.take(4).toList();
    hit = top.length == 4 && top.every(picks.contains);
  } else {
    final top = res.take(p).toList();
    if (l['sets'] != null) {
      hit = _setPairs(l['sets']).any((x) => x.split('-').every((n) => top.contains(int.parse(n))));
    } else {
      hit = picks.where(top.contains).length >= 2;
    }
  }
  return hit ? 'h' : 'm';
}

class CouponStatus {
  final String k; // win · lose · wait · live
  final int h;
  const CouponStatus(this.k, this.h);
}

CouponStatus couponStatus(Map c) {
  final legs = _maps(c['legs']);
  final vir = c['vir'];
  if (vir is num && vir > 0) {
    if (legs.isEmpty) return const CouponStatus('wait', 0);
    final res = _resOfC(c, legs[0]);
    if (res == null) return const CouponStatus('wait', 0);
    final v = vir.toInt();
    final top = res.take(v).toList();
    final idx = top.map((n) => legs.indexWhere((l) {
          final pk = _ints(l['picks']);
          return pk.isNotEmpty && pk.first == n;
        })).toList();
    var win = top.length == v;
    for (var i = 0; i < idx.length && win; i++) {
      if (idx[i] < 0 || (i > 0 && idx[i] <= idx[i - 1])) win = false;
    }
    return win ? const CouponStatus('win', 1) : const CouponStatus('lose', 0);
  }
  final st = legs.map((l) => legSt(c, l)).toList();
  final h = st.where((x) => x == 'h').length;
  if (st.contains('m')) return CouponStatus('lose', h);
  if (st.isNotEmpty && h == st.length) return CouponStatus('win', h);
  if (h == 0) return CouponStatus('wait', 0);
  return CouponStatus('live', h);
}

/// Paylaşımın durumu: elle işaret (mark) önceliklidir.
String postStatus(Post p) {
  final c = p.coupon;
  if (c == null) return '';
  final m = (p.d['mark'] ?? '').toString();
  if (m == 'win' || m == 'lose') return m;
  return couponStatus(c).k;
}

bool isAltili(Map c) => c['type'] == "6'lı Ganyan" && !_maps(c['legs']).any((l) => l['slot'] != null);

({double pts, int tot}) couponPts(Map c) {
  double pts = 0;
  int tot = 0;
  final st = couponStatus(c).k;
  if (isAltili(c)) {
    if (st == 'win') {
      pts = 10;
      tot = _maps(c['legs']).length;
    } else {
      for (final l in _maps(c['legs'])) {
        final s = legSt(c, l);
        if (s == 'h') {
          pts++;
          tot++;
        } else if (s == 'm') {
          tot++;
        }
      }
    }
  } else if (st == 'win') {
    pts = typePts((c['type'] ?? '').toString());
    tot = 1;
  } else if (st == 'lose') {
    tot = 1;
  }
  return (pts: pts, tot: tot);
}

String dayKey(int ts) {
  final d = DateTime.fromMillisecondsSinceEpoch(ts);
  return 'd${d.year}${d.month.toString().padLeft(2, '0')}${d.day.toString().padLeft(2, '0')}';
}

class DayScore {
  double pts = 0;
  int tot = 0, hit = 0;
}

Map<String, DayScore> scoreDays(String uid, List<Post> posts) {
  final D = <String, DayScore>{};
  DayScore day(String g) => D.putIfAbsent(g, () => DayScore());
  final mine = posts.where((p) => p.uid == uid && p.coupon != null && p.coupon!['banked'] != true).toList();
  // 6'lı Ganyan: aynı gün+şehir+başlangıç koşusu için yalnızca en çok puan getiren kupon sayılır
  final best = <String, ({Post p, double pt})>{};
  for (final p in mine) {
    final c = p.coupon!;
    if (!isAltili(c)) continue;
    final legs = _maps(c['legs']);
    final d = DateTime.fromMillisecondsSinceEpoch(p.ts);
    final key = '${d.year}-${d.month}-${d.day}|${c['city'] ?? ''}|${legs.isNotEmpty ? legs[0]['r'] : 0}';
    final pt = couponPts(c).pts;
    final cur = best[key];
    if (cur == null || pt > cur.pt || (pt == cur.pt && p.ts < cur.p.ts)) best[key] = (p: p, pt: pt);
  }
  final ok = best.values.map((e) => e.p.id).toSet();
  for (final p in mine) {
    final c = p.coupon!;
    if (isAltili(c) && !ok.contains(p.id)) continue;
    final r = couponPts(c);
    final d = day(dayKey(p.ts));
    d.tot += r.tot;
    d.pts += r.pts;
    if (isAltili(c)) {
      d.hit += _maps(c['legs']).where((l) => legSt(c, l) == 'h').length;
    } else if (r.pts > 0) {
      d.hit++;
    }
  }
  return D;
}

class Score {
  final double pts;
  final int tot, pct;
  const Score(this.pts, this.tot, this.pct);
}

/// hist: users/{uid}.hist · bonus: grants/{uid}.pts + keep
Score scoreOf(String uid, List<Post> posts, Map? hist, double bonus) {
  final D = scoreDays(uid, posts);
  (hist ?? const {}).forEach((g, h) {
    if (h is! Map) return;
    final d = D.putIfAbsent(g.toString(), () => DayScore());
    d.pts += (h['p'] as num?)?.toDouble() ?? 0;
    d.tot += (h['t'] as num?)?.toInt() ?? 0;
    d.hit += (h['h'] as num?)?.toInt() ?? 0;
  });
  var tot = 0, hit = 0;
  double pts = 0;
  for (final d in D.values) {
    tot += d.tot;
    hit += d.hit;
    pts += d.pts < gunlukTavan ? d.pts : gunlukTavan;
  }
  final raw = ((pts + bonus) * 100).round() / 100;
  return Score(raw < 0 ? 0 : raw, tot, tot > 0 ? (hit / tot * 100).round() : 0);
}
