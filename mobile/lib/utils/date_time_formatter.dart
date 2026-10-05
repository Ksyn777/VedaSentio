class DateTimeFormatter {
  DateTimeFormatter._();

  static String compact(String rawValue) {
    if (rawValue.trim().isEmpty) return 'brak daty';

    final normalized = rawValue.trim().replaceFirst(' ', 'T');
    final parsed = DateTime.tryParse(normalized);
    if (parsed == null) return rawValue;

    final local = parsed.toLocal();
    String two(int value) => value.toString().padLeft(2, '0');

    return '${two(local.day)}.${two(local.month)}.${local.year} '
        '${two(local.hour)}:${two(local.minute)}';
  }
}
