/// Formats the time remaining until [expiresAt] as a human-readable string.
/// e.g. "2d 3h remaining", "4h 12m remaining", "Trial expired"
String formatTimeRemaining(DateTime expiresAt) {
  final remaining = expiresAt.difference(DateTime.now());
  if (remaining.isNegative) return 'Trial expired';
  if (remaining.inDays >= 1) {
    final h = remaining.inHours % 24;
    return '${remaining.inDays}d ${h}h remaining';
  }
  if (remaining.inHours >= 1) {
    final m = remaining.inMinutes % 60;
    return '${remaining.inHours}h ${m}m remaining';
  }
  return '${remaining.inMinutes}m remaining';
}
