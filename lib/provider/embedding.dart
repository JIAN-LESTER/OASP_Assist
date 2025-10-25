import 'package:cloud_firestore/cloud_firestore.dart';

class EmbeddingCache {
  static final Map<String, List<double>> _cache = {};
  static const int maxCacheSize = 1000;
  
  static List<double>? get(String text) => _cache[text];
  
  static void put(String text, List<double> embedding) {
    if (_cache.length >= maxCacheSize) {
      _cache.remove(_cache.keys.first);
    }
    _cache[text] = embedding;
  }
}

class FAQCache {
  static final Map<String, Map<String, dynamic>> _cache = {};
  static DateTime lastCacheUpdate = DateTime.fromMillisecondsSinceEpoch(0);
  static const Duration cacheExpiry = Duration(minutes: 30);
  
  static bool get isExpired => 
    DateTime.now().difference(lastCacheUpdate) > cacheExpiry;
  
  static void updateCache(List<QueryDocumentSnapshot> docs) {
    _cache.clear();
    for (var doc in docs) {
      final data = doc.data() as Map<String, dynamic>;
      final question = data['question'] as String?;
      if (question != null) {
        _cache[question] = data;
      }
    }
    lastCacheUpdate = DateTime.now();
  }
  
  static Map<String, Map<String, dynamic>> get cache => _cache;
}
