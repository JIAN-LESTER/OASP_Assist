import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:capstone_project/modules/admin/announcement/fb_storage.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

class FbSyncConfig {
  static const String projectId = 'cmu-oasp-assist';
  static const String region = 'asia-southeast1';

  static String get exchangeTokenUrl =>
      'https://exchangetokenhttp-kt3rxdstza-uc.a.run.app';

  static String get syncPostsUrl =>
      'https://manualsyncfacebookpostshttp-kt3rxdstza-uc.a.run.app';

  static String get testConnectionUrl =>
      'https://testfacebookconnectionhttp-kt3rxdstza-uc.a.run.app';
}

class TokenStatus {
  final bool configured;
  final int? expiresAt;
  final int? daysLeft;
  final bool expired;
  final bool expirationWarning;
  final String? pageId;
  final bool needsRenewal;
  final String? message;

  TokenStatus({
    required this.configured,
    this.expiresAt,
    this.daysLeft,
    this.expired = false,
    this.expirationWarning = false,
    this.pageId,
    this.needsRenewal = false,
    this.message,
  });

  factory TokenStatus.fromMap(Map<String, dynamic> map) {
    return TokenStatus(
      configured: map['configured'] ?? false,
      expiresAt: map['expiresAt'],
      daysLeft: map['daysLeft'],
      expired: map['expired'] ?? false,
      expirationWarning: map['expirationWarning'] ?? false,
      pageId: map['pageId'],
      needsRenewal: map['needsRenewal'] ?? false,
      message: map['message'],
    );
  }
}

class FacebookSyncService {
  static bool get _shouldUseHttp {
    if (kIsWeb) return true;
    if (!kIsWeb && Platform.isWindows) return true;
    return false;
  }

  static Future<String?> _getAuthToken() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        return user.getIdToken(true);
      }
    } catch (e) {
      print('Error getting auth token: $e');
    }
    return null;
  }

  static Future<Map<String, dynamic>> exchangeToken(
    String shortToken, {
    String? pageId,
    String? appId,
  }) async {
    print('Exchanging Facebook token...');
    print('Platform: ${_getPlatformName()}');
    print('Using: Cloud Functions SDK');

    try {
      return await _exchangeTokenViaCloudFunctions(
        shortToken,
        pageId: pageId,
        appId: appId,
      );
    } catch (e) {
      print('Token exchange failed: $e');
      rethrow;
    }
  }

  static Future<Map<String, dynamic>> _exchangeTokenViaHttp(
    String shortToken, {
    String? pageId,
    String? appId,
  }) async {
    final authToken = await _getAuthToken();
    if (authToken == null) {
      throw Exception('Not authenticated. Please log in first.');
    }

    try {
      final response = await http
          .post(
            Uri.parse(FbSyncConfig.exchangeTokenUrl),
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $authToken',
            },
            body: json.encode({
              'data': {
                'uid': 'facebook_admin',
                'short_token': shortToken,
                if (pageId != null) 'pageId': pageId,
                if (appId != null) 'appId': appId,
              },
            }),
          )
          .timeout(const Duration(seconds: 30));

      return _parseHttpResponse(response, action: 'Token exchange');
    } on TimeoutException {
      throw Exception('Request timed out. Please try again.');
    }
  }

  static Future<Map<String, dynamic>> _exchangeTokenViaCloudFunctions(
    String shortToken, {
    String? pageId,
    String? appId,
  }) async {
    try {
      final callable = FirebaseFunctions.instance.httpsCallable('exchangeToken');
      final result = await callable
          .call(<String, dynamic>{
            'uid': 'facebook_admin',
            'short_token': shortToken,
            if (pageId != null) 'pageId': pageId,
            if (appId != null) 'appId': appId,
          })
          .timeout(const Duration(seconds: 30));

      return _parseCallableData(result.data, fallbackMessage: 'Token exchange failed');
    } catch (e) {
      if (_shouldFallbackToHttp(e)) {
        print('Cloud Functions call failed: $e');
        print('Falling back to HTTP...');
        return _exchangeTokenViaHttp(shortToken, pageId: pageId, appId: appId);
      }
      rethrow;
    }
  }

  static Future<TokenStatus> getTokenStatus() async {
    try {
      if (_shouldUseHttp) {
        final doc = await FirebaseFirestore.instance
            .collection('fb_tokens')
            .doc('facebook_admin')
            .get();

        if (!doc.exists) {
          return TokenStatus(
            configured: false,
            message: 'No Facebook token configured',
          );
        }

        final data = doc.data()!;
        final expiresAt = data['expires_at'] as int?;
        final now = DateTime.now().millisecondsSinceEpoch;
        final daysLeft = expiresAt != null
            ? ((expiresAt - now) / (1000 * 60 * 60 * 24)).round()
            : null;

        return TokenStatus(
          configured: true,
          expiresAt: expiresAt,
          daysLeft: daysLeft,
          expired: expiresAt != null && expiresAt <= now,
          expirationWarning: data['expirationWarning'] ?? false,
          pageId: data['pageId'],
          needsRenewal: daysLeft != null && daysLeft <= 60 && daysLeft > 0,
        );
      }

      final callable = FirebaseFunctions.instance.httpsCallable('getTokenStatus');
      final result = await callable.call();
      return TokenStatus.fromMap(result.data as Map<String, dynamic>);
    } catch (e) {
      print('Error getting token status: $e');
      return TokenStatus(
        configured: false,
        message: 'Error checking token status',
      );
    }
  }

  static Future<Map<String, dynamic>> syncPosts() async {
    print('Starting Facebook sync...');
    print('Platform: ${_getPlatformName()}');
    print('Using: Cloud Functions SDK');

    try {
      return await _syncViaCloudFunctions();
    } catch (e) {
      print('Sync failed: $e');
      rethrow;
    }
  }

  static Future<Map<String, dynamic>> _syncViaHttp() async {
    final authToken = await _getAuthToken();
    if (authToken == null) {
      throw Exception('Not authenticated. Please log in first.');
    }

    try {
      final response = await http
          .post(
            Uri.parse(FbSyncConfig.syncPostsUrl),
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $authToken',
            },
            body: json.encode({'data': {}}),
          )
          .timeout(const Duration(seconds: 60));

      return _parseHttpResponse(response, action: 'Sync');
    } on TimeoutException {
      throw Exception('Facebook sync failed. Please try again.');
    }
  }

  static Future<Map<String, dynamic>> _syncViaCloudFunctions() async {
    try {
      final callable = FirebaseFunctions.instance.httpsCallable(
        'manualSyncFacebookPosts',
      );

      final result = await callable
          .call(<String, dynamic>{})
          .timeout(const Duration(seconds: 60));

      return _parseCallableData(result.data, fallbackMessage: 'Sync failed');
    } catch (e) {
      if (_shouldFallbackToHttp(e)) {
        print('Cloud Functions call failed: $e');
        print('Falling back to HTTP...');
        return _syncViaHttp();
      }
      rethrow;
    }
  }

  static Future<Map<String, dynamic>> syncPostsWithStorage() async {
    try {
      final syncResult = await syncPosts();
      if (syncResult['success'] != true) {
        return syncResult;
      }

      final posts = syncResult['posts'] as List<dynamic>? ?? const [];
      var imagesProcessed = 0;
      var imagesFailed = 0;

      for (final post in posts) {
        final postId = post['id']?.toString();
        if (postId == null || postId.isEmpty) {
          continue;
        }

        final imageUrls = _extractImageUrls(post);
        if (imageUrls.isEmpty) {
          continue;
        }

        final uploadResult =
            await FacebookImageStorageService.processPostImages(
              postId: postId,
              facebookImageUrls: imageUrls,
            );

        if (uploadResult['success'] == true) {
          imagesProcessed += (uploadResult['successCount'] as int?) ?? 0;
          imagesFailed += (uploadResult['failedCount'] as int?) ?? 0;

          await FirebaseFirestore.instance
              .collection('announcements')
              .doc(postId)
              .update({
                'images': uploadResult['firebaseUrls'],
                'original_fb_urls': imageUrls,
                'images_migrated': true,
                'migration_date': FieldValue.serverTimestamp(),
              });
        }
      }

      return {
        'success': true,
        'count': syncResult['count'],
        'failed': syncResult['failed'],
        'imagesProcessed': imagesProcessed,
        'imagesFailed': imagesFailed,
      };
    } catch (e) {
      print('Error in sync with storage: $e');
      return {'success': false, 'error': e.toString()};
    }
  }

  static List<String> _extractImageUrls(Map<String, dynamic> post) {
    final imageUrls = <String>[];
    final attachments = post['attachments']?['data'] as List<dynamic>?;

    if (attachments != null) {
      for (final attachment in attachments) {
        final type = attachment['type'];
        if (type == 'photo' || type == 'album') {
          final image = attachment['media']?['image']?['src'];
          if (image is String && image.isNotEmpty) {
            imageUrls.add(image);
          }

          final subAttachments =
              attachment['subattachments']?['data'] as List<dynamic>?;
          if (subAttachments != null) {
            for (final subAttachment in subAttachments) {
              final subImage = subAttachment['media']?['image']?['src'];
              if (subImage is String && subImage.isNotEmpty) {
                imageUrls.add(subImage);
              }
            }
          }
        }
      }
    }

    final fullPicture = post['full_picture'];
    if (fullPicture is String &&
        fullPicture.isNotEmpty &&
        !imageUrls.contains(fullPicture)) {
      imageUrls.add(fullPicture);
    }

    return imageUrls;
  }

  static Map<String, dynamic> _parseHttpResponse(
    http.Response response, {
    required String action,
  }) {
    print('$action response: ${response.statusCode}');

    var body = <String, dynamic>{};
    if (response.body.isNotEmpty) {
      try {
        final decoded = json.decode(response.body);
        if (decoded is Map<String, dynamic>) {
          body = decoded;
        }
      } catch (e) {
        print('$action response body was not JSON: ${response.body}');
      }
    }
    final result = body is Map<String, dynamic>
        ? (body['result'] is Map<String, dynamic> ? body['result'] : body)
        : <String, dynamic>{};

    if (response.statusCode == 200) {
      return _parseCallableData(result, fallbackMessage: '$action failed');
    }

    if (response.statusCode == 401) {
      throw Exception(
        (result['message'] ?? 'Authentication failed. Please log in again.')
            .toString(),
      );
    }
    if (response.statusCode == 403) {
      throw Exception(
        (result['message'] ?? 'Permission denied. Admin access required.')
            .toString(),
      );
    }

    throw Exception(
      (result['message'] ?? result['error'] ?? 'Server error (${response.statusCode})')
          .toString(),
    );
  }

  static Map<String, dynamic> _parseCallableData(
    dynamic rawData, {
    required String fallbackMessage,
  }) {
    final data = Map<String, dynamic>.from(rawData as Map);
    if (data['success'] == true || data['ok'] == true) {
      return data;
    }

    throw Exception(data['message'] ?? data['error'] ?? fallbackMessage);
  }

  static bool _shouldFallbackToHttp(dynamic error) {
    if (error is FirebaseFunctionsException) {
      return error.code == 'unavailable' ||
          error.code == 'not-found' ||
          error.code == 'deadline-exceeded';
    }

    final message = error.toString();
    return message.contains('UNAVAILABLE') ||
        message.contains('Unable to establish connection') ||
        message.contains('Failed to fetch') ||
        message.contains('XMLHttpRequest error') ||
        message.contains('SocketException');
  }

  static String _getPlatformName() {
    if (kIsWeb) return 'Web';
    if (Platform.isAndroid) return 'Android';
    if (Platform.isIOS) return 'iOS';
    if (Platform.isWindows) return 'Windows';
    if (Platform.isMacOS) return 'macOS';
    if (Platform.isLinux) return 'Linux';
    return 'Unknown';
  }

  static String parseErrorMessage(dynamic error) {
    var errorMessage = error.toString().replaceFirst('Exception: ', '');

    if (errorMessage.contains('[firebase_functions/')) {
      final match = RegExp(r'\] (.+)$').firstMatch(errorMessage);
      if (match != null) {
        errorMessage = match.group(1) ?? errorMessage;
      }
    }

    if (errorMessage.contains('unauthenticated')) {
      return 'Please log in to continue.';
    }
    if (errorMessage.contains('permission-denied')) {
      return 'Permission denied. Only admins can perform this action.';
    }
    if (errorMessage.contains('No Facebook token configured')) {
      return 'Please configure Facebook token using the key () button';
    }
    if (errorMessage.contains('token expired')) {
      return 'Facebook token expired. Please refresh using the key () button';
    }
    if (errorMessage.contains('DEADLINE_EXCEEDED') ||
        errorMessage.contains('timeout') ||
        errorMessage.contains('timed out')) {
      return 'Request timed out. Please try again.';
    }
    if (errorMessage.contains('UNAVAILABLE')) {
      return 'Service temporarily unavailable. Please try again.';
    }
    if (errorMessage.contains('ClientException') ||
        errorMessage.contains('SocketException')) {
      return 'Network error. Please check your internet connection.';
    }
    if (errorMessage.contains('Facebook API Error')) {
      return errorMessage;
    }
    if (errorMessage.contains('Unable to establish connection')) {
      return 'Connection error. Please try again.';
    }

    return errorMessage;
  }
}
