import 'package:cloud_functions/cloud_functions.dart';

class FirebaseUsageLogger {
  static Future<void> logRead({
    required String collection,
    required int count,
    String source = 'data_display',
  }) async {
    try {
      final callable = FirebaseFunctions.instance.httpsCallable(
        'logFirebaseRead',
      );
      await callable.call({
        'collection': collection,
        'count': count,
        'source': source,
      });
    } catch (e) {
      print('Firebase read usage logging failed: $e');
    }
  }
}
