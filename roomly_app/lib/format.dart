// Small helpers for money, dates and numbers coming from the API.

num toNum(dynamic v) {
  if (v is num) return v;
  return num.tryParse(v?.toString() ?? '') ?? 0;
}

// 1234567 becomes ₹12,34,567, the Indian way of grouping digits.
String money(num value) {
  final v = value.round();
  final neg = v < 0;
  final s = v.abs().toString();
  var out = s;
  if (s.length > 3) {
    final last3 = s.substring(s.length - 3);
    var rest = s.substring(0, s.length - 3);
    final parts = <String>[];
    while (rest.length > 2) {
      parts.insert(0, rest.substring(rest.length - 2));
      rest = rest.substring(0, rest.length - 2);
    }
    if (rest.isNotEmpty) parts.insert(0, rest);
    out = '${parts.join(',')},$last3';
  }
  final sign = neg ? '-' : '';
  return '$sign₹$out';
}

String two(int n) => n < 10 ? '0$n' : '$n';

String isoDate(DateTime d) => '${d.year}-${two(d.month)}-${two(d.day)}';

DateTime parseDay(String iso) {
  final p = iso.split('-');
  return DateTime(int.parse(p[0]), int.parse(p[1]), int.parse(p[2]));
}

const _months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];

String prettyDay(DateTime d) => '${d.day} ${_months[d.month - 1]}';

String prettyDayYear(DateTime d) => '${d.day} ${_months[d.month - 1]} ${d.year}';

DateTime today() {
  final n = DateTime.now();
  return DateTime(n.year, n.month, n.day);
}

int nightsBetween(DateTime a, DateTime b) => DateTime.utc(b.year, b.month, b.day).difference(DateTime.utc(a.year, a.month, a.day)).inDays;

String plural(int n, String word) => '$n $word${n == 1 ? '' : 's'}';
