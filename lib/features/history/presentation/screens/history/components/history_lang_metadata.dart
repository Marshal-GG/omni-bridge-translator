/// Metadata for a single language code used by the History screen widgets.
class HistoryLang {
  final String name;
  final String flag;
  const HistoryLang(this.name, this.flag);
}

/// Subset of languages the app actively translates between, plus a few
/// locale fallbacks. Lookup falls back to the bare ISO code with a globe
/// emoji when the entry is in a language we don't have metadata for.
const Map<String, HistoryLang> kHistoryLangs = {
  'en': HistoryLang('English', '🇬🇧'),
  'es': HistoryLang('Spanish', '🇪🇸'),
  'ja': HistoryLang('Japanese', '🇯🇵'),
  'fr': HistoryLang('French', '🇫🇷'),
  'de': HistoryLang('German', '🇩🇪'),
  'hi': HistoryLang('Hindi', '🇮🇳'),
  'ko': HistoryLang('Korean', '🇰🇷'),
  'zh': HistoryLang('Chinese', '🇨🇳'),
  'pt': HistoryLang('Portuguese', '🇵🇹'),
  'ar': HistoryLang('Arabic', '🇸🇦'),
  'it': HistoryLang('Italian', '🇮🇹'),
  'ru': HistoryLang('Russian', '🇷🇺'),
  'tr': HistoryLang('Turkish', '🇹🇷'),
  'auto': HistoryLang('Auto-detect', '🌐'),
};

HistoryLang historyLangFor(String code) =>
    kHistoryLangs[code.toLowerCase()] ?? HistoryLang(code.toUpperCase(), '🌐');

/// Relative timestamp formatter for entry rows. Uses [now] (defaults to
/// `DateTime.now()`) so tests can pin time. Output is small + monospace-friendly.
String historyRelativeTime(DateTime t, {DateTime? now}) {
  final reference = now ?? DateTime.now();
  final diff = reference.difference(t);
  if (diff.inSeconds < 60) return 'just now';
  if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
  if (diff.inHours < 24) return '${diff.inHours}h ago';
  if (diff.inDays < 2) return 'Yesterday';
  if (diff.inDays < 7) return '${diff.inDays}d ago';
  return _shortMonthDay(t);
}

/// "Today" / "Yesterday" / "N days ago" / "Monday, May 6" — used by the
/// day-grouping list header.
String historyDayLabel(DateTime t, {DateTime? now}) {
  final reference = now ?? DateTime.now();
  final today = DateTime(reference.year, reference.month, reference.day);
  final dt = DateTime(t.year, t.month, t.day);
  final days = today.difference(dt).inDays;
  if (days == 0) return 'Today';
  if (days == 1) return 'Yesterday';
  if (days < 7) return '$days days ago';
  return _weekdayMonthDay(t);
}

String _shortMonthDay(DateTime t) {
  const months = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];
  return '${months[t.month - 1]} ${t.day}';
}

String _weekdayMonthDay(DateTime t) {
  const weekdays = [
    'Monday', 'Tuesday', 'Wednesday', 'Thursday',
    'Friday', 'Saturday', 'Sunday',
  ];
  return '${weekdays[t.weekday - 1]}, ${_shortMonthDay(t)}';
}
