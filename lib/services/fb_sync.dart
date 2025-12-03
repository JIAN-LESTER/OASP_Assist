import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:cloud_firestore/cloud_firestore.dart';

// ============================================================================
// CONFIGURATION
// ============================================================================
class FbSyncConfig {
  static const String projectId = 'capstone-project-1703b';
  static const String region = 'us-central1';
  
  static String get exchangeTokenUrl => 
      'https://exchangetokenhttp-kt3rxdstza-uc.a.run.app';
  
  static String get syncPostsUrl => 
      'https://manualsyncfacebookpostshttp-kt3rxdstza-uc.a.run.app';
  
  static String get testConnectionUrl =>
      'https://testfacebookconnectionhttp-kt3rxdstza-uc.a.run.app';
}

// ============================================================================
// ✅ NEW: Token Status Model
// ============================================================================
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

// ============================================================================
// FACEBOOK SYNC SERVICE
// ============================================================================
class FacebookSyncService {
  // Determine which method to use based on platform
  static bool get _shouldUseHttp {
    if (!kIsWeb && Platform.isWindows) {
      return true;
    }
    if (kIsWeb) {
      return true;
    }
    return false;
  }

  // Get authentication token
  static Future<String?> _getAuthToken() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        return await user.getIdToken();
      }
    } catch (e) {
      print('❌ Error getting auth token: $e');
    }
    return null;
  }

  // ============================================================================
  // ✅ UPDATED: Exchange Token with Page ID
  // ============================================================================
  
static Future<Map<String, dynamic>> exchangeToken(
  String shortToken, {
  String? pageId,
  String? appId, // ✅ NEW: Optional appId parameter
}) async {
  print('🔄 Exchanging Facebook token...');
  if (pageId != null) {
    print('📍 With Page ID: $pageId');
  }
  if (appId != null) {
    print('📱 With App ID: $appId');
  }
  print('📱 Platform: ${_getPlatformName()}');
  print('🔧 Using: ${_shouldUseHttp ? "HTTP" : "Cloud Functions SDK"}');
  
  try {
    if (_shouldUseHttp) {
      return await _exchangeTokenViaHttp(shortToken, pageId: pageId, appId: appId);
    } else {
      return await _exchangeTokenViaCloudFunctions(shortToken, pageId: pageId, appId: appId);
    }
  } catch (e) {
    print('❌ Token exchange failed: $e');
    rethrow;
  }
}

 static Future<Map<String, dynamic>> _exchangeTokenViaHttp(
  String shortToken, {
  String? pageId,
  String? appId, // ✅ NEW
}) async {
  print('📡 Using HTTP endpoint...');
  
  final authToken = await _getAuthToken();
  if (authToken == null) {
    throw Exception('Not authenticated. Please log in first.');
  }
  
  try {
    final response = await http.post(
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
          if (appId != null) 'appId': appId, // ✅ Include appId if provided
        }
      }),
    ).timeout(Duration(seconds: 30));
      print('📦 Response: ${response.statusCode}');
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final result = data['result'] ?? data;
        
        if (result['success'] == true || result['ok'] == true) {
          print('✅ Token exchanged successfully');
          if (pageId != null) {
            print('✅ Page ID saved: $pageId');
          }
          return result;
        }
        
        throw Exception(result['message'] ?? result['error'] ?? 'Token exchange failed');
      } else if (response.statusCode == 401) {
        throw Exception('Authentication failed. Please log in again.');
      } else if (response.statusCode == 403) {
        throw Exception('Permission denied. Admin access required.');
      } else {
        final errorData = json.decode(response.body);
        throw Exception(errorData['message'] ?? 'Server error (${response.statusCode})');
      }
    } catch (e) {
      if (e is TimeoutException) {
        throw Exception('Request timed out. Please try again.');
      }
      rethrow;
    }
  }

 static Future<Map<String, dynamic>> _exchangeTokenViaCloudFunctions(
  String shortToken, {
  String? pageId,
  String? appId, // ✅ NEW
}) async {
  print('📞 Using Cloud Functions SDK...');
  
  try {
    final callable = FirebaseFunctions.instance.httpsCallable('exchangeToken');
    
    final result = await callable.call(<String, dynamic>{
      'uid': 'facebook_admin',
      'short_token': shortToken,
      if (pageId != null) 'pageId': pageId,
      if (appId != null) 'appId': appId, // ✅ Include appId if provided
    }).timeout(Duration(seconds: 30));
      
      final data = result.data as Map<String, dynamic>;
      
      if (data['success'] == true || data['ok'] == true) {
        print('✅ Token exchanged successfully');
        return data;
      }
      
      throw Exception(data['message'] ?? data['error'] ?? 'Token exchange failed');
    } catch (e) {
      print('❌ Cloud Functions call failed: $e');
      print('🔄 Falling back to HTTP...');
      return await _exchangeTokenViaHttp(shortToken, pageId: pageId);
    }
  }

  // ============================================================================
  // ✅ NEW: Get Token Status
  // ============================================================================
  
  static Future<TokenStatus> getTokenStatus() async {
    print('🔍 Checking token status...');
    
    try {
      if (_shouldUseHttp) {
        // Use direct Firestore access for HTTP platforms
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
      } else {
        // Use Cloud Functions for mobile
        final callable = FirebaseFunctions.instance.httpsCallable('getTokenStatus');
        final result = await callable.call();
        return TokenStatus.fromMap(result.data as Map<String, dynamic>);
      }
    } catch (e) {
      print('❌ Error getting token status: $e');
      return TokenStatus(
        configured: false,
        message: 'Error checking token status',
      );
    }
  }

  // ============================================================================
  // SYNC POSTS (unchanged)
  // ============================================================================
  
  static Future<Map<String, dynamic>> syncPosts() async {
    print('🔄 Starting Facebook sync...');
    print('📱 Platform: ${_getPlatformName()}');
    print('🔧 Using: ${_shouldUseHttp ? "HTTP" : "Cloud Functions SDK"}');
    
    try {
      if (_shouldUseHttp) {
        return await _syncViaHttp();
      } else {
        return await _syncViaCloudFunctions();
      }
    } catch (e) {
      print('❌ Sync failed: $e');
      rethrow;
    }
  }

  static Future<Map<String, dynamic>> _syncViaHttp() async {
    print('📡 Using HTTP endpoint...');
    
    final authToken = await _getAuthToken();
    if (authToken == null) {
      throw Exception('Not authenticated. Please log in first.');
    }
    
    try {
      final response = await http.post(
        Uri.parse(FbSyncConfig.syncPostsUrl),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $authToken',
        },
        body: json.encode({'data': {}}),
      ).timeout(Duration(seconds: 60));
      
      print('📦 Response: ${response.statusCode}');
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final result = data['result'] ?? data;
        
        if (result['success'] == true) {
          print('✅ Sync completed successfully');
          return result;
        }
        
        throw Exception(result['message'] ?? result['error'] ?? 'Sync failed');
      } else if (response.statusCode == 401) {
        throw Exception('Authentication failed. Please log in again.');
      } else if (response.statusCode == 403) {
        throw Exception('Permission denied. Admin access required.');
      } else {
        final errorData = json.decode(response.body);
        throw Exception(errorData['message'] ?? 'Server error (${response.statusCode})');
      }
    } catch (e) {
      if (e is TimeoutException) {
        throw Exception('Request timed out. The sync may still be running in the background.');
      }
      rethrow;
    }
  }

  static Future<Map<String, dynamic>> _syncViaCloudFunctions() async {
    print('📞 Using Cloud Functions SDK...');
    
    try {
      final callable = FirebaseFunctions.instance
          .httpsCallable('manualSyncFacebookPosts');
      
      final result = await callable.call(<String, dynamic>{})
          .timeout(Duration(seconds: 60));
      
      final data = result.data as Map<String, dynamic>;
      
      if (data['success'] == true) {
        print('✅ Sync completed successfully');
        return data;
      }
      
      throw Exception(data['message'] ?? data['error'] ?? 'Sync failed');
    } catch (e) {
      print('❌ Cloud Functions call failed: $e');
      print('🔄 Falling back to HTTP...');
      return await _syncViaHttp();
    }
  }

  // ============================================================================
  // TEST CONNECTION (unchanged)
  // ============================================================================
  
  static Future<Map<String, dynamic>> testConnection() async {
    print('🧪 Testing Facebook connection...');
    print('📱 Platform: ${_getPlatformName()}');
    print('🔧 Using: ${_shouldUseHttp ? "HTTP" : "Cloud Functions SDK"}');
    
    try {
      if (_shouldUseHttp) {
        return await _testViaHttp();
      } else {
        return await _testViaCloudFunctions();
      }
    } catch (e) {
      print('❌ Test failed: $e');
      rethrow;
    }
  }

  static Future<Map<String, dynamic>> _testViaHttp() async {
    print('📡 Using HTTP endpoint...');
    
    final authToken = await _getAuthToken();
    if (authToken == null) {
      throw Exception('Not authenticated. Please log in first.');
    }
    
    try {
      final response = await http.post(
        Uri.parse(FbSyncConfig.testConnectionUrl),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $authToken',
        },
        body: json.encode({'data': {}}),
      ).timeout(Duration(seconds: 30));
      
      print('📦 Response: ${response.statusCode}');
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return data['result'] ?? data;
      } else {
        final errorData = json.decode(response.body);
        throw Exception(errorData['message'] ?? 'Server error (${response.statusCode})');
      }
    } catch (e) {
      if (e is TimeoutException) {
        throw Exception('Request timed out. Please try again.');
      }
      rethrow;
    }
  }

  static Future<Map<String, dynamic>> _testViaCloudFunctions() async {
    print('📞 Using Cloud Functions SDK...');
    
    try {
      final callable = FirebaseFunctions.instance
          .httpsCallable('testFacebookConnection');
      
      final result = await callable.call(<String, dynamic>{})
          .timeout(Duration(seconds: 30));
      
      print('📦 Test result: ${json.encode(result.data)}');
      return result.data as Map<String, dynamic>;
    } catch (e) {
      print('❌ Cloud Functions call failed: $e');
      print('🔄 Falling back to HTTP...');
      return await _testViaHttp();
    }
  }

  // ============================================================================
  // UTILITY METHODS
  // ============================================================================
  
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
    String errorMessage = error.toString();
    
    errorMessage = errorMessage.replaceFirst('Exception: ', '');
    
    if (errorMessage.contains('[firebase_functions/')) {
      final match = RegExp(r'\] (.+)$').firstMatch(errorMessage);
      if (match != null) {
        errorMessage = match.group(1) ?? errorMessage;
      }
    }
    
    if (errorMessage.contains('unauthenticated')) {
      return 'Please log in to continue.';
    } else if (errorMessage.contains('permission-denied')) {
      return 'Permission denied. Only admins can perform this action.';
    } else if (errorMessage.contains('No Facebook token configured')) {
      return 'Please configure Facebook token using the key (🔑) button';
    } else if (errorMessage.contains('token expired')) {
      return 'Facebook token expired. Please refresh using the key (🔑) button';
    } else if (errorMessage.contains('DEADLINE_EXCEEDED') || 
               errorMessage.contains('timeout') ||
               errorMessage.contains('timed out')) {
      return 'Request timed out. Please try again.';
    } else if (errorMessage.contains('UNAVAILABLE')) {
      return 'Service temporarily unavailable. Please try again.';
    } else if (errorMessage.contains('ClientException') || 
               errorMessage.contains('SocketException')) {
      return 'Network error. Please check your internet connection.';
    } else if (errorMessage.contains('Facebook API Error')) {
      return errorMessage;
    } else if (errorMessage.contains('Unable to establish connection')) {
      return 'Connection error. Please try again.';
    }
    
    return errorMessage;
  }
}