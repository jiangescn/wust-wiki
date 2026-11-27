import 'dart:convert';
import 'dart:math';

import 'academic.dart' show Json, Lesson;

const maxPersonalWeeks = 30;
const weekDays = ['周一', '周二', '周三', '周四', '周五', '周六', '周日'];

String newScheduleId() {
  final random = Random.secure();
  return base64UrlEncode(List.generate(16, (_) => random.nextInt(256)));
}

DateTime calendarDate(DateTime date) =>
    DateTime.utc(date.year, date.month, date.day);

String dateLabel(DateTime date) => date.toIso8601String().split('T').first;

int? weekAt(DateTime monday, DateTime date) {
  final offset = calendarDate(date).difference(monday).inDays;
  return offset < 0 ? null : offset ~/ 7 + 1;
}

class PersonalTime {
  const PersonalTime({
    required this.id,
    required this.day,
    required this.first,
    required this.last,
    required this.weeks,
    this.date,
    this.place = '',
    this.teacher = '',
  });

  final String id, place, teacher;
  final int day, first, last;
  final List<int> weeks;
  final DateTime? date;

  Json toJson() => {
    'id': id,
    'day': day,
    'first': first,
    'last': last,
    'weeks': weeks,
    if (date case final date?) 'date': dateLabel(date),
    'place': place,
    'teacher': teacher,
  };

  static PersonalTime? read(Json json) {
    final Object? id = json['id'];
    final Object? day = json['day'], first = json['first'], last = json['last'];
    final Object? weeks = json['weeks'], date = json['date'];
    final parsedDate = date is String ? DateTime.tryParse(date) : null;
    if (id is! String ||
        id.isEmpty ||
        day is! int ||
        day < 1 ||
        day > 7 ||
        first is! int ||
        last is! int ||
        first < 1 ||
        last < first ||
        last > 60 ||
        weeks is! List ||
        (date != null && parsedDate == null)) {
      return null;
    }
    final validWeeks =
        weeks
            .whereType<int>()
            .where((w) => w >= 1 && w <= maxPersonalWeeks)
            .toSet()
            .toList()
          ..sort();
    if (parsedDate == null && validWeeks.isEmpty) return null;
    return PersonalTime(
      id: id,
      day: day,
      first: first,
      last: last,
      weeks: validWeeks,
      date: parsedDate == null ? null : calendarDate(parsedDate),
      place: json['place']?.toString() ?? '',
      teacher: json['teacher']?.toString() ?? '',
    );
  }
}

class PersonalCourse {
  const PersonalCourse({
    required this.id,
    required this.term,
    required this.owner,
    required this.name,
    required this.times,
    this.note = '',
    this.supplement = false,
  });

  final String id, term, owner, name, note;
  final bool supplement;
  final List<PersonalTime> times;

  PersonalCourse withTimes(List<PersonalTime> times) => PersonalCourse(
    id: id,
    term: term,
    owner: owner,
    name: name,
    times: times,
    note: note,
    supplement: supplement,
  );

  Json toJson() => {
    'id': id,
    'term': term,
    'owner': owner,
    'name': name,
    'note': note,
    'supplement': supplement,
    'times': times.map((time) => time.toJson()).toList(),
  };

  static PersonalCourse? read(Json json) {
    final Object? id = json['id'], term = json['term'], owner = json['owner'];
    final Object? name = json['name'], times = json['times'];
    if (id is! String ||
        id.isEmpty ||
        term is! String ||
        owner is! String ||
        name is! String ||
        name.trim().isEmpty ||
        times is! List)
      return null;
    final valid = times
        .whereType<Json>()
        .map(PersonalTime.read)
        .nonNulls
        .toList();
    if (valid.isEmpty) return null;
    return PersonalCourse(
      id: id,
      term: term,
      owner: owner,
      name: name,
      times: valid,
      note: json['note']?.toString() ?? '',
      supplement: json['supplement'] == true,
    );
  }

  Iterable<PersonalLesson> lessons(DateTime? monday) sync* {
    for (final time in times) {
      final date = time.date;
      final week = date == null || monday == null ? null : weekAt(monday, date);
      if (date != null && (week == null || week > maxPersonalWeeks)) continue;
      yield PersonalLesson(this, time, week);
    }
  }
}

class PersonalLesson extends Lesson {
  PersonalLesson(this.course, this.time, int? week)
    : super({
        'name': course.name,
        'location': time.place,
        'teacher': time.teacher,
        'day': time.date?.weekday ?? time.day,
        'sections': '${time.first}-${time.last}',
        'weeks': week?.toString() ?? time.weeks.join(','),
      });

  final PersonalCourse course;
  final PersonalTime time;
  String get sourceLabel => course.supplement ? '本机补充' : '自定义';
}

List<String> courseConflicts(
  Iterable<Lesson> existing,
  Iterable<PersonalLesson> proposed,
) {
  final available = existing.where((lesson) => lesson.placed).toList();
  final conflicts = <String>{};
  for (final lesson in proposed) {
    for (final other in available) {
      if (lesson.day != other.day) continue;
      final sections = lesson.sections!
          .where(other.sections!.contains)
          .toList();
      if (sections.isEmpty) continue;
      final weeks = lesson.weeks!.where(other.weeks!.contains).toList();
      if (weeks.isEmpty) continue;
      conflicts.add(
        '${other.name} · ${weekDays[lesson.day - 1]} · '
        '第 ${sections.join('、')} 节 · 第 ${weeks.join('、')} 周',
      );
    }
    available.add(lesson);
  }
  return conflicts.toList();
}
