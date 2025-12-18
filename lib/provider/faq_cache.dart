import 'package:cloud_firestore/cloud_firestore.dart';

class FAQCache {
  static Map<String, Map<String, dynamic>> cache = {};
  static DateTime lastCacheUpdate = DateTime.fromMillisecondsSinceEpoch(0);
  static const Duration cacheExpiry = Duration(
    hours: 2,
  ); // ⚡ Increased from 1 hour

  static bool get isExpired =>
      DateTime.now().difference(lastCacheUpdate) > cacheExpiry;

  static void updateCache(List<QueryDocumentSnapshot> docs) {
    cache.clear();
    for (var doc in docs) {
      cache[doc.id] = doc.data() as Map<String, dynamic>;
    }
    lastCacheUpdate = DateTime.now();
  }
}
