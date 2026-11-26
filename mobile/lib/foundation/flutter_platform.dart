import 'package:flutter/services.dart';
import 'platform.dart';
import 'transport.dart';

class AndroidFoundationPlatform implements FoundationPlatform {
  const AndroidFoundationPlatform();
  static const channel = MethodChannel('wiki/native');
  @override
  Future<Map<String, dynamic>> invoke(
    String operation, [
    Map<String, dynamic> arguments = const {},
  ]) async {
    try {
      final result = await channel.invokeMapMethod<String, dynamic>(
        'foundationCapability',
        {'operation': operation, ...arguments},
      );
      return result ?? <String, dynamic>{};
    } on PlatformException catch (error) {
      throw FoundationException(
        error.code,
        error.code == 'cancelled' ? '操作已取消。' : '安卓系统能力暂不可用。',
      );
    }
  }

  @override
  Future<String?> load(String key) async =>
      (await invoke('load', {'key': key}))['value'] as String?;
  @override
  Future<void> save(String key, String value) async {
    await invoke('save', {'key': key, 'value': value});
  }

  @override
  Future<void> clear(String key) async {
    await invoke('clear', {'key': key});
  }
}
