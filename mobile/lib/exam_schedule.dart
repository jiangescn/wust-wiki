class ScheduledExam {
  ScheduledExam.fromRow(Map<String, dynamic> row)
    : name = row['title']?.toString().trim() ?? '',
      fields = {
        for (final field
            in (row['fields'] is List ? row['fields'] as List : const [])
                .whereType<Map<String, dynamic>>())
          if (field['name'] is String && field['value'] != null)
            field['name'] as String: field['value'].toString().trim(),
      };

  final String name;
  final Map<String, String> fields;
  String get time => fields['时间'] ?? '';

  String get room => [
    if (fields['校区']?.isNotEmpty == true) fields['校区']!,
    if (fields['场地']?.isNotEmpty == true) fields['场地']!,
    if (fields['座位号']?.isNotEmpty == true) '座位 ${fields['座位号']}',
  ].join(' · ');

  late final DateTime? startsAt = _startTime(time);

  String get key => [
    fields['学年学期'],
    fields['课程编号'],
    name,
    time,
    room,
    fields['周次'],
    fields['星期'],
    fields['节次'],
  ].join('\u0000');

  static DateTime? _startTime(String text) {
    final match = RegExp(
      r'^(\d{4})[-/](\d{1,2})[-/](\d{1,2})[\sT]+(\d{1,2}):(\d{2})(?!\d)',
    ).firstMatch(text);
    if (match == null) return null;
    final year = int.parse(match[1]!),
        month = int.parse(match[2]!),
        day = int.parse(match[3]!);
    final hour = int.parse(match[4]!), minute = int.parse(match[5]!);
    final date = DateTime.utc(year, month, day, hour, minute);
    if (date.month != month ||
        date.day != day ||
        date.hour != hour ||
        date.minute != minute)
      return null;
    return date.subtract(const Duration(hours: 8));
  }
}

List<ScheduledExam> readScheduledExams(Object? rows) {
  if (rows is! List) return const [];
  final unique = <String, ScheduledExam>{};
  for (final row in rows.whereType<Map<String, dynamic>>()) {
    final exam = ScheduledExam.fromRow(row);
    if (exam.name.isNotEmpty) unique[exam.key] = exam;
  }
  return List.unmodifiable(unique.values);
}

List<ScheduledExam> upcomingExams(
  List<ScheduledExam> exams,
  DateTime now, {
  Duration? within,
}) {
  final end = within == null ? null : now.add(within);
  return [
    for (final exam in exams)
      if (exam.startsAt case final startsAt?)
        if (!startsAt.isBefore(now) && (end == null || startsAt.isBefore(end)))
          exam,
  ]..sort((a, b) => a.startsAt!.compareTo(b.startsAt!));
}
