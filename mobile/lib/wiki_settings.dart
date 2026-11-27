import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'blog_surface.dart';

class WikiAppearance extends ChangeNotifier {
  static const _platform = MethodChannel('wiki/native');
  ThemeMode theme = ThemeMode.system;
  bool lowPerformance = false;
  bool openScheduleOnLaunch = false;
  bool _edited = false;
  bool _disposed = false;

  Future<void> restore() async {
    try {
      final values = await _platform.invokeMapMethod<String, dynamic>(
        'loadAppearance',
      );
      if (_edited || _disposed || values == null) return;
      theme = ThemeMode.values.firstWhere(
        (mode) => mode.name == values['theme'],
        orElse: () => ThemeMode.system,
      );
      lowPerformance = values['lowPerformance'] == true;
      openScheduleOnLaunch = values['openScheduleOnLaunch'] == true;
      notifyListeners();
    } on Exception {
      return;
    }
  }

  Future<void> change({
    ThemeMode? theme,
    bool? lowPerformance,
    bool? openScheduleOnLaunch,
  }) async {
    _edited = true;
    this.theme = theme ?? this.theme;
    this.lowPerformance = lowPerformance ?? this.lowPerformance;
    this.openScheduleOnLaunch =
        openScheduleOnLaunch ?? this.openScheduleOnLaunch;
    notifyListeners();
    try {
      await _platform.invokeMethod<void>('saveAppearance', {
        'theme': this.theme.name,
        'lowPerformance': this.lowPerformance,
        'openScheduleOnLaunch': this.openScheduleOnLaunch,
      });
    } on Exception {
      return;
    }
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}

class WikiSettingsPage extends StatelessWidget {
  const WikiSettingsPage(this.appearance, {this.mark, super.key});

  final WikiAppearance appearance;
  final WikiPageMark? mark;

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: WikiPageTitle('设置', mark: mark)),
    body: SafeArea(
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          ListenableBuilder(
            listenable: appearance,
            builder: (context, _) => BlogPanel(
              Column(
                children: [
                  ListTile(
                    leading: const BlogIcon(Icons.palette_outlined),
                    title: const Text('主题'),
                    trailing: DropdownButton<ThemeMode>(
                      value: appearance.theme,
                      underline: const SizedBox.shrink(),
                      items: const [
                        DropdownMenuItem(
                          value: ThemeMode.system,
                          child: Text('跟随系统'),
                        ),
                        DropdownMenuItem(
                          value: ThemeMode.light,
                          child: Text('浅色'),
                        ),
                        DropdownMenuItem(
                          value: ThemeMode.dark,
                          child: Text('深色'),
                        ),
                      ],
                      onChanged: (value) {
                        if (value != null) appearance.change(theme: value);
                      },
                    ),
                  ),
                  const Divider(height: 1, indent: 64, endIndent: 16),
                  SwitchListTile(
                    secondary: const BlogIcon(Icons.speed_rounded),
                    title: const Text('低性能模式'),
                    value: appearance.lowPerformance,
                    onChanged: (value) =>
                        appearance.change(lowPerformance: value),
                  ),
                  const Divider(height: 1, indent: 64, endIndent: 16),
                  SwitchListTile(
                    secondary: const BlogIcon(Icons.calendar_month_outlined),
                    title: const Text('启动时打开课表'),
                    value: appearance.openScheduleOnLaunch,
                    onChanged: (value) =>
                        appearance.change(openScheduleOnLaunch: value),
                  ),
                ],
              ),
              padding: EdgeInsets.zero,
              quiet: true,
            ),
          ),
        ],
      ),
    ),
  );
}
