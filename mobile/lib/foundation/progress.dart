import 'dart:async';

class FoundationProgress {
  const FoundationProgress({
    required this.message,
    required this.startedAt,
    required this.activeCount,
    this.resource,
    this.attempt,
  });
  final String message;
  final DateTime startedAt;
  final int activeCount;
  final String? resource;
  final int? attempt;
}

abstract interface class FoundationProgressSource {
  Stream<FoundationProgress?> get progress;
  FoundationProgress? get currentProgress;
}

/// One record per real request prevents a completed or cancelled request from
/// clearing a newer query's status. No URLs, credentials or response text enter it.
class FoundationProgressHub implements FoundationProgressSource {
  final _changes = StreamController<FoundationProgress?>.broadcast(sync: true);
  final _active = <int, FoundationProgress>{};
  int _next = 0;
  @override
  FoundationProgress? get currentProgress {
    if (_active.isEmpty) return null;
    final current = _active.values.last;
    return FoundationProgress(
      message: current.message,
      startedAt: current.startedAt,
      resource: current.resource,
      attempt: current.attempt,
      activeCount: _active.length,
    );
  }

  @override
  Stream<FoundationProgress?> get progress => _changes.stream;
  int begin(String message, {String? resource}) {
    final id = ++_next;
    _active[id] = FoundationProgress(
      message: message,
      resource: resource,
      startedAt: DateTime.now(),
      activeCount: _active.length + 1,
    );
    _emit();
    return id;
  }

  void update(int id, String message, {int? attempt}) {
    final old = _active[id];
    if (old == null) return;
    _active[id] = FoundationProgress(
      message: message,
      resource: old.resource,
      startedAt: old.startedAt,
      activeCount: _active.length,
      attempt: message.startsWith('正在查询') ? null : attempt ?? old.attempt,
    );
    _emit();
  }

  void finish(int id) {
    _active.remove(id);
    _emit();
  }

  void cancel() {
    _active.clear();
    _emit();
  }

  void _emit() {
    _changes.add(currentProgress);
  }
}

String schoolResourceLabel(String resource) => switch (resource) {
  'login' || 'inspect' => '统一认证',
  'academic' => '教务',
  'schedule' => '课表',
  'grades' => '成绩',
  'student' => '学生信息',
  'exams' => '考试安排',
  'credits' => '学分',
  'calendar' => '教学周',
  'training-plan' => '培养方案',
  'raw-schedule' => '原始课表',
  'shuttle' => '校车信息',
  'second-class' => '第二课堂',
  final r when r.startsWith('library') => '图书馆',
  final r when r.startsWith('laundry') => '洗衣服务',
  final r when r.startsWith('notice') => '学校通知',
  _ => '学校服务',
};
