class EmbeddingCache {
  static final Map<String, List<double>> _cache = {};
  static const int maxSize = 1000; // ⚡ Increased from 500

  static List<double>? get(String key) => _cache[key];

  static void put(String key, List<double> value) {
    if (_cache.length >= maxSize) {
      final oldestKeys = _cache.keys.take(_cache.length - maxSize + 1);
      for (final oldKey in oldestKeys) {
        _cache.remove(oldKey);
      }
    }
    _cache[key] = value;
  }
}