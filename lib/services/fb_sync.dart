import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

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
// FACEBOOK SYNC SERVICE
// ============================================================================
class FacebookSyncService {
  // Determine which method to use based on platform
  static bool get _shouldUseHttp {
    // Always use HTTP on Windows
    if (!kIsWeb && Platform.isWindows) {
      return true;
    }
    // Use HTTP on web for reliability
    if (kIsWeb) {
      return true;
    }
    // Use Cloud Functions SDK on mobile
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
  // EXCHANGE TOKEN
  // ============================================================================
  
  static Future<Map<String, dynamic>> exchangeToken(String shortToken) async {
    print('🔄 Exchanging Facebook token...');
    print('📱 Platform: ${_getPlatformName()}');
    print('🔧 Using: ${_shouldUseHttp ? "HTTP" : "Cloud Functions SDK"}');
    
    try {
      if (_shouldUseHttp) {
        return await _exchangeTokenViaHttp(shortToken);
      } else {
        return await _exchangeTokenViaCloudFunctions(shortToken);
      }
    } catch (e) {
      print('❌ Token exchange failed: $e');
      rethrow;
    }
  }

  static Future<Map<String, dynamic>> _exchangeTokenViaHttp(String shortToken) async {
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
          }
        }),
      ).timeout(Duration(seconds: 30));
      
      print('📦 Response: ${response.statusCode}');
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final result = data['result'] ?? data;
        
        if (result['success'] == true || result['ok'] == true) {
          print('✅ Token exchanged successfully');
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

  static Future<Map<String, dynamic>> _exchangeTokenViaCloudFunctions(String shortToken) async {
    print('📞 Using Cloud Functions SDK...');
    
    try {
      final callable = FirebaseFunctions.instance.httpsCallable('exchangeToken');
      
      final result = await callable.call(<String, dynamic>{
        'uid': 'facebook_admin',
        'short_token': shortToken,
      }).timeout(Duration(seconds: 30));
      
      final data = result.data as Map<String, dynamic>;
      
      if (data['success'] == true || data['ok'] == true) {
        print('✅ Token exchanged successfully');
        return data;
      }
      
      throw Exception(data['message'] ?? data['error'] ?? 'Token exchange failed');
    } catch (e) {
      print('❌ Cloud Functions call failed: $e');
      // If Cloud Functions fails, try HTTP as fallback
      print('🔄 Falling back to HTTP...');
      return await _exchangeTokenViaHttp(shortToken);
    }
  }

  // ============================================================================
  // SYNC POSTS
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
      // If Cloud Functions fails, try HTTP as fallback
      print('🔄 Falling back to HTTP...');
      return await _syncViaHttp();
    }
  }

  // ============================================================================
  // TEST CONNECTION
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
      // If Cloud Functions fails, try HTTP as fallback
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
    
    // Remove "Exception: " prefix
    errorMessage = errorMessage.replaceFirst('Exception: ', '');
    
    // Handle Cloud Functions errors
    if (errorMessage.contains('[firebase_functions/')) {
      final match = RegExp(r'\] (.+)$').firstMatch(errorMessage);
      if (match != null) {
        errorMessage = match.group(1) ?? errorMessage;
      }
    }
    
    // Handle specific error types
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