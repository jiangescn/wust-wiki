import 'package:flutter_test/flutter_test.dart';
import 'package:wust_wiki/academic.dart';

void main() {
  test('逐段单双周与整组单双周兼容', () {
    expect(Lesson.parseWeeks('1–6周（单），8～12周（双）'), [1, 3, 5, 8, 10, 12]);
    expect(Lesson.parseWeeks('1-4,7-10（双）'), [2, 4, 8, 10]);
    expect(Lesson.parseWeeks('1-6单,待定'), isNull);
  });

  test('有缺口的节次按原记录保留，未知节次仍待确认', () {
    expect(Lesson.parseSections({'sections': '第1～2、5至6节'}), [1, 2, 5, 6]);
    expect(Lesson.parseSections({'sections': '第1节或第2节'}), isNull);
  });
}
