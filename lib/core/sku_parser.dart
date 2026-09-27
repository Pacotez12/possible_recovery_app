final _skuRe = RegExp(r'^AF-\d{6}$');

String? parseSku(String raw) {
  var s = raw.trim();
  if (s.isEmpty) return null;
  final uri = Uri.tryParse(s);
  if (uri != null && uri.hasScheme && uri.queryParameters['term'] != null) {
    s = uri.queryParameters['term']!;
  }
  s = s.toUpperCase().replaceAll(' ', '');
  if (RegExp(r'^\d{1,6}$').hasMatch(s)) s = 'AF-${s.padLeft(6, '0')}';
  if (RegExp(r'^AF\d{6}$').hasMatch(s)) s = 'AF-${s.substring(2)}';
  return _skuRe.hasMatch(s) ? s : null;
}
