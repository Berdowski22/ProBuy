// KVKK: businesses only see masked personal data.

/// "Ahmet Yılmaz" -> "A*** Y***"
String maskName(String fullName) {
  final parts = fullName.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty);
  if (parts.isEmpty) return '-';
  return parts.map((p) => '${p.substring(0, 1)}***').join(' ');
}

/// Keeps only the coarse location (last two segments, e.g. district/city).
String maskAddress(String address) {
  final text = address.trim();
  if (text.isEmpty) return '-';
  final segments = text
      .split(RegExp(r'[,/\n]'))
      .map((s) => s.trim())
      .where((s) => s.isNotEmpty)
      .toList();
  if (segments.length >= 2) {
    return '*** ${segments.sublist(segments.length - 2).join(', ')}';
  }
  final words = text.split(RegExp(r'\s+'));
  if (words.length >= 2) return '*** ${words.sublist(words.length - 2).join(' ')}';
  return '***';
}
