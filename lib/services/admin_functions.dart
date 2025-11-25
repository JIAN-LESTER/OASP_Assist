  import 'dart:convert';
  import 'package:firebase_auth/firebase_auth.dart';
  import 'package:flutter/foundation.dart';
  import 'package:http/http.dart' as http;
  import 'package:cloud_functions/cloud_functions.dart';

  class FirebaseFunctionsService {
    // Your Firebase project ID - UPDATE THIS!
    static const String projectId = 'capstone-project-1703b'; // ⚠️ CHANGE THIS
    static const String region = 'us-central1';
    
    // Try plugin method first, fallback to HTTP
    static bool _useHttpFallback = false;
    static FirebaseFunctions? _functionsInstance;
    
    FirebaseFunctions get _functions {
      _functionsInstance ??= FirebaseFunctions.instanceFor(region: region);
      return _functionsInstance!;
    }

    FirebaseFunctionsService() {
      if (kDebugMode) {
        print('✅ FirebaseFunctionsService created (HTTP fallback: $_useHttpFallback)');
      }
    }

    /// Call a Cloud Function - tries plugin first, falls back to HTTP
    Future<Map<String, dynamic>> _callFunction(
      String functionName,
      Map<String, dynamic> data,
    ) async {
      // Try plugin method first (if not already failed)
      if (!_useHttpFallback) {
        try {
          final callable = _functions.httpsCallable(
            functionName,
            options: HttpsCallableOptions(
              timeout: const Duration(seconds: 60),
            ),
          );
          
          final result = await callable.call(data);
          return result.data as Map<String, dynamic>;
        } on FirebaseFunctionsException catch (e) {
          // If it's a platform channel error, switch to HTTP permanently
          if (e.code == 'unknown' && e.message?.contains('channel') == true) {
            print('⚠️ Platform channel error detected, switching to HTTP fallback');
            _useHttpFallback = true;
          } else {
            rethrow;
          }
        } catch (e) {
          // Any other error with plugin, try HTTP as fallback
          print('⚠️ Plugin call failed, trying HTTP fallback: $e');
          _useHttpFallback = true;
        }
      }

      // HTTP fallback
      return await _callFunctionViaHttp(functionName, data);
    }

    /// Call Cloud Function via direct HTTP request
    Future<Map<String, dynamic>> _callFunctionViaHttp(
      String functionName,
      Map<String, dynamic> data,
    ) async {
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) {
        throw Exception('You must be logged in.');
      }

      final token = await currentUser.getIdToken(true);
      if (token == null) {
        throw Exception('Failed to get authentication token');
      }

      final url = Uri.parse(
        'https://$region-$projectId.cloudfunctions.net/$functionName'
      );

      print('📡 HTTP Request to: $url');
      print('📦 Payload: ${data.keys.toList()}');

      final response = await http.post(
        url,
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: json.encode({'data': data}),
      ).timeout(
        const Duration(seconds: 60),
        onTimeout: () => throw Exception('Request timed out'),
      );

      print('📥 HTTP Response status: ${response.statusCode}');
      print('📥 HTTP Response body: ${response.body}');

      if (response.statusCode == 200) {
        final responseData = json.decode(response.body);
        
        // Handle different response formats
        if (responseData is Map<String, dynamic>) {
          // Cloud Functions v2 wraps response in 'result'
          if (responseData.containsKey('result')) {
            return responseData['result'] as Map<String, dynamic>;
          }
          return responseData;
        }
        
        throw Exception('Unexpected response format');
      } else {
        // Handle error response
        try {
          final errorData = json.decode(response.body);
          final errorMessage = errorData['error']?['message'] ?? 
                              errorData['message'] ?? 
                              'Unknown error';
          throw Exception(errorMessage);
        } catch (e) {
          throw Exception('HTTP ${response.statusCode}: ${response.body}');
        }
      }
    }

    /// Create a new user account via Cloud Function
    Future<String> createUserAuth({
      required String email,
      required String password,
      String? displayName,
      String? affiliation,
      String? scholarship,
    }) async {
      try {
        final currentUser = FirebaseAuth.instance.currentUser;
        if (currentUser == null) {
          throw Exception('You must be logged in as an admin.');
        }

        print('🔄 Calling createUser function');
        print('👤 Current user: ${currentUser.email}');
        print('📧 Creating: $email');

        final data = {
          'email': email,
          'password': password,
          if (displayName != null && displayName.isNotEmpty) 
            'displayName': displayName,
          if (affiliation != null && affiliation.isNotEmpty) 
            'affiliation': affiliation,
          if (scholarship != null && scholarship.isNotEmpty) 
            'scholarship': scholarship,
        };

        print('📦 Request payload: ${data.keys.toList()}');
        
        final responseData = await _callFunction('createUser', data);
        print('✅ Success: $responseData');

        if (responseData['success'] == true) {
          return responseData['uid'] as String;
        }

        throw Exception(responseData['message'] ?? 'User creation failed');
        
      } on FirebaseFunctionsException catch (e) {
        print('❌ FunctionsException:');
        print('  Code: ${e.code}');
        print('  Message: ${e.message}');
        print('  Details: ${e.details}');
        _handleFunctionsException(e);
        rethrow;
      } catch (e, stackTrace) {
        print('❌ Unexpected error: $e');
        print('📍 Stack trace: $stackTrace');
        rethrow;
      }
    }

    /// Delete a user account via Cloud Function
    Future<void> deleteUserAuth(String uid) async {
      try {
        final currentUser = FirebaseAuth.instance.currentUser;
        if (currentUser == null) {
          throw Exception('You must be logged in as an admin.');
        }

        print('🔄 Calling deleteUser for: $uid');

        final responseData = await _callFunction('deleteUser', {'uid': uid});
        print('✅ User deleted: $responseData');
        
      } on FirebaseFunctionsException catch (e) {
        print('❌ FunctionsException:');
        print('  Code: ${e.code}');
        print('  Message: ${e.message}');
        print('  Details: ${e.details}');
        _handleFunctionsException(e);
        rethrow;
      } catch (e, stackTrace) {
        print('❌ Error deleting user: $e');
        print('📍 Stack trace: $stackTrace');
        rethrow;
      }
    }

    /// Update a user account via Cloud Function
    Future<void> updateUserAuth({
      required String uid,
      String? email,
      String? password,
      String? displayName,
    }) async {
      try {
        print('🔄 Calling updateUser for: $uid');

        final currentUser = FirebaseAuth.instance.currentUser;
        if (currentUser == null) {
          throw Exception('You must be logged in.');
        }

        final data = {
          'uid': uid,
          if (email != null && email.isNotEmpty) 'email': email,
          if (password != null && password.isNotEmpty) 'password': password,
          if (displayName != null && displayName.isNotEmpty) 
            'displayName': displayName,
        };

        final responseData = await _callFunction('updateUser', data);
        print('✅ User updated: $responseData');
        
      } on FirebaseFunctionsException catch (e) {
        print('❌ FunctionsException:');
        print('  Code: ${e.code}');
        print('  Message: ${e.message}');
        print('  Details: ${e.details}');
        _handleFunctionsException(e);
        rethrow;
      } catch (e, stackTrace) {
        print('❌ Error updating user: $e');
        print('📍 Stack trace: $stackTrace');
        rethrow;
      }
    }

    /// Set or remove admin role for a user
    Future<void> setAdminRole({
      required String uid,
      required bool isAdmin,
    }) async {
      try {
        print('🔄 Calling setAdminRole for: $uid (isAdmin: $isAdmin)');

        final currentUser = FirebaseAuth.instance.currentUser;
        if (currentUser == null) {
          throw Exception('You must be logged in as an admin.');
        }

        final responseData = await _callFunction('setAdminRole', {
          'uid': uid,
          'isAdmin': isAdmin,
        });
        
        print('✅ Admin role updated: $responseData');
        
      } on FirebaseFunctionsException catch (e) {
        print('❌ FunctionsException:');
        print('  Code: ${e.code}');
        print('  Message: ${e.message}');
        print('  Details: ${e.details}');
        _handleFunctionsException(e);
        rethrow;
      } catch (e, stackTrace) {
        print('❌ Error setting admin role: $e');
        print('📍 Stack trace: $stackTrace');
        rethrow;
      }
    }

    /// Handle Firebase Functions exceptions with user-friendly messages
    void _handleFunctionsException(FirebaseFunctionsException e) {
      String message;
      
      switch (e.code) {
        case 'unauthenticated':
          message = 'You must be logged in as an admin.';
          break;
        case 'permission-denied':
          message = 'Only admins can perform this action.';
          break;
        case 'invalid-argument':
          message = e.message ?? 'Invalid data provided.';
          break;
        case 'already-exists':
          message = e.message ?? 'This email is already registered.';
          break;
        case 'not-found':
          message = 'User not found.';
          break;
        case 'unavailable':
          message = 'Service unavailable. Check your internet connection.';
          break;
        case 'deadline-exceeded':
          message = 'Request timed out. Please try again.';
          break;
        case 'internal':
          message = 'Server error: ${e.message ?? "Unknown error"}';
          break;
        case 'failed-precondition':
          message = 'Function not ready. ${e.message ?? ""}';
          break;
        default:
          message = 'Error (${e.code}): ${e.message ?? "Unknown error"}';
      }
      
      throw Exception(message);
    }
    
    static void dispose() {
      _functionsInstance = null;
    }
  }