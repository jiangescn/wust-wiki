abstract interface class FoundationPlatform {
  Future<Map<String, dynamic>> invoke(
    String operation, [
    Map<String, dynamic> arguments = const {},
  ]);
  Future<String?> load(String key);
  Future<void> save(String key, String value);
  Future<void> clear(String key);
}
