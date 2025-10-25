import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

class FirebaseFunctionsService {
  static final FirebaseFunctionsService _instance = FirebaseFunctionsService._internal();
  factory FirebaseFunctionsService() => _instance;
  FirebaseFunctionsService._internal() {
    _autoInitialize();
  }

  FirebaseFunctions? _functions;
  bool _initialized = false;

  void _autoInitialize() {
    if (!_initialized) {
      try {
        _functions = FirebaseFunctions.instanceFor(region: 'us-central1');
        _initialized = true;
        print('✅ Cloud Functions auto-initialized with region: us-central1');
      } catch (e) {
        print('⚠️ Auto-initialization failed: $e');
      }
    }
  }

  void initialize({String region = 'us-central1', bool useEmulator = false}) {
    if (_initialized && _functions != null) {
      print('⚠️ Cloud Functions already initialized');
      return;
    }
    
    try {
      _functions = FirebaseFunctions.instanceFor(region: region);
      
      if (useEmulator && kDebugMode) {
        _functions!.useFunctionsEmulator('localhost', 5001);
        print('🔧 Cloud Functions configured to use local emulator');
      }
      
      _initialized = true;
      print('✅ Cloud Functions initialized for region: $region');
    } catch (e) {
      print('❌ Failed to initialize Cloud Functions: $e');
      rethrow;
    }
  }

  void _ensureInitialized() {
    if (!_initialized || _functions == null) {
      _autoInitialize();
      
      if (!_initialized || _functions == null) {
        throw Exception('FirebaseFunctionsService not initialized');
      }
    }
  }

  /// Create a new user in Firebase Authentication with auto-verified email
  Future<String> createUserAuth({
    required String email,
    required String password, 
    String? displayName,
    String? affiliation,
    String? scholarship,
  }) async {
    _ensureInitialized();
    
    try {
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) {
        throw Exception('You must be logged in as an admin to create users.');
      }
      
      print('========================================');
      print('🔄 Calling createUser Cloud Function');
      print('👤 Current user: ${currentUser.email}');
      print('📧 Creating account for: $email');
      print('========================================');
      
      // Get fresh ID token to ensure authentication
      await currentUser.getIdToken(true);
      print('🔑 Fresh ID token obtained');
      
      final callable = _functions!.httpsCallable(
        'createUser',
        options: HttpsCallableOptions(
          timeout: const Duration(seconds: 60),
        ),
      );
      
      final data = <String, dynamic>{
        'email': email,
        'password': password,
      };
      
      if (displayName != null) data['displayName'] = displayName;
      if (affiliation != null) data['affiliation'] = affiliation;
      if (scholarship != null) data['scholarship'] = scholarship;
      
      print('📦 Sending data: ${data.keys.toList()}');
      
      final result = await callable.call(data);
      
      print('========================================');
      print('✅ Cloud Function returned successfully');
      print('📊 Response: ${result.data}');
      print('========================================');
      
      if (result.data is Map) {
        final responseData = result.data as Map<String, dynamic>;
        
        if (responseData['success'] == true) {
          final uid = responseData['uid'] as String?;
          if (uid == null) {
            throw Exception('No UID returned from createUser function');
          }
          print('✅ User created with UID: $uid');
          return uid;
        } else {
          throw Exception(responseData['message'] ?? 'User creation failed');
        }
      } else {
        throw Exception('Invalid response format from createUser function');
      }
    } on FirebaseFunctionsException catch (e) {
      print('========================================');
      print('❌ FirebaseFunctionsException caught');
      print('Code: ${e.code}');
      print('Message: ${e.message}');
      print('Details: ${e.details}');
      print('========================================');
      
      switch (e.code) {
        case 'unauthenticated':
          throw Exception('You must be logged in as an admin to create users.');
        case 'permission-denied':
          throw Exception('Only admins can create users. Please contact your administrator.');
        case 'invalid-argument':
          throw Exception(e.message ?? 'Invalid email or password provided.');
        case 'already-exists':
          throw Exception(e.message ?? 'This email is already registered.');
        case 'unavailable':
          throw Exception('Cloud Functions unavailable. Check your internet connection.');
        case 'deadline-exceeded':
          throw Exception('Request timed out. Please try again.');
        case 'internal':
          // Try to extract more details from the error
          final errorMsg = e.message ?? 'Internal server error';
          print('⚠️ Internal error details: $errorMsg');
          throw Exception('Server error: $errorMsg. Please check the Cloud Functions logs.');
        default:
          throw Exception('Error: ${e.message ?? 'Unknown error (${e.code})'}');
      }
    } catch (e) {
      print('========================================');
      print('❌ General error caught: $e');
      print('Error type: ${e.runtimeType}');
      print('========================================');
      rethrow;
    }
  }

  /// Delete a user from Firebase Authentication
  Future<void> deleteUserAuth(String uid) async {
    _ensureInitialized();
    
    try {
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) {
        throw Exception('You must be logged in as an admin to delete users.');
      }
      
      print('========================================');
      print('🔄 Calling deleteUser Cloud Function');
      print('👤 Current user: ${currentUser.email}');
      print('🗑️ Deleting user: $uid');
      print('========================================');
      
      // Get fresh ID token
      await currentUser.getIdToken(true);
      
      final callable = _functions!.httpsCallable(
        'deleteUser',
        options: HttpsCallableOptions(
          timeout: const Duration(seconds: 60),
        ),
      );
      
      final result = await callable.call({'uid': uid});
      
      print('========================================');
      print('✅ Cloud Function response: ${result.data}');
      print('========================================');
    } on FirebaseFunctionsException catch (e) {
      print('========================================');
      print('❌ FirebaseFunctionsException: ${e.code}');
      print('Message: ${e.message}');
      print('Details: ${e.details}');
      print('========================================');
      
      switch (e.code) {
        case 'unauthenticated':
          throw Exception('You must be logged in as an admin to delete users.');
        case 'permission-denied':
          throw Exception('Only admins can delete users.');
        case 'not-found':
          throw Exception('User not found.');
        case 'unavailable':
          throw Exception('Cloud Functions unavailable. Check your internet connection.');
        case 'deadline-exceeded':
          throw Exception('Request timed out. Please try again.');
        default:
          throw Exception('Error: ${e.message ?? 'Unknown error'}');
      }
    } catch (e) {
      print('❌ Error calling deleteUser function: $e');
      rethrow;
    }
  }

  /// Update user email, password, and display name in Firebase Authentication
  Future<void> updateUserAuth({
    required String uid,
    String? email,
    String? password,
    String? displayName,
  }) async {
    _ensureInitialized();
    
    try {
      print('🔄 Calling updateUser Cloud Function for uid: $uid');
      
      final data = <String, dynamic>{'uid': uid};
      if (email != null) data['email'] = email;
      if (password != null) data['password'] = password;
      if (displayName != null) data['displayName'] = displayName;

      final callable = _functions!.httpsCallable(
        'updateUser',
        options: HttpsCallableOptions(
          timeout: const Duration(seconds: 60),
        ),
      );
      
      final result = await callable.call(data);
      print('✅ Cloud Function response: ${result.data}');
    } on FirebaseFunctionsException catch (e) {
      print('❌ FirebaseFunctionsException: ${e.code}');
      print('Message: ${e.message}');
      
      switch (e.code) {
        case 'unauthenticated':
          throw Exception('You must be logged in to update users.');
        case 'permission-denied':
          throw Exception('Only admins can update users.');
        case 'invalid-argument':
          throw Exception('Invalid user data provided.');
        case 'unavailable':
          throw Exception('Cloud Functions unavailable. Check your internet connection.');
        default:
          throw Exception('Error: ${e.message ?? 'Unknown error'}');
      }
    } catch (e) {
      print('❌ Error calling updateUser function: $e');
      rethrow;
    }
  }

  /// Set admin role for a user
  Future<void> setAdminRole({
    required String uid,
    required bool isAdmin,
  }) async {
    _ensureInitialized();
    
    try {
      print('🔄 Calling setAdminRole Cloud Function for uid: $uid');
      
      final callable = _functions!.httpsCallable(
        'setAdminRole',
        options: HttpsCallableOptions(
          timeout: const Duration(seconds: 60),
        ),
      );
      
      final result = await callable.call({
        'uid': uid,
        'isAdmin': isAdmin,
      });
      
      print('✅ Cloud Function response: ${result.data}');
    } on FirebaseFunctionsException catch (e) {
      print('❌ FirebaseFunctionsException: ${e.code}');
      print('Message: ${e.message}');
      
      switch (e.code) {
        case 'unauthenticated':
          throw Exception('You must be logged in to change admin roles.');
        case 'permission-denied':
          throw Exception('Only admins can change admin roles.');
        case 'unavailable':
          throw Exception('Cloud Functions unavailable. Check your internet connection.');
        default:
          throw Exception('Error: ${e.message ?? 'Unknown error'}');
      }
    } catch (e) {
      print('❌ Error calling setAdminRole function: $e');
      rethrow;
    }
  }

  /// Test Cloud Functions connectivity
  Future<bool> testConnection() async {
    _ensureInitialized();
    
    try {
      print('🔄 Testing Cloud Functions connection...');
      
      // Try calling a simple function to test connectivity
      final callable = _functions!.httpsCallable(
        'createUser',
        options: HttpsCallableOptions(
          timeout: const Duration(seconds: 10),
        ),
      );
      
      // This will fail but we can check if the function is reachable
      try {
        await callable.call({'test': 'connection'});
      } catch (e) {
        // We expect this to fail with unauthenticated or invalid-argument
        // but that means the function is reachable
        if (e is FirebaseFunctionsException) {
          if (e.code == 'unauthenticated' || 
              e.code == 'permission-denied' ||
              e.code == 'invalid-argument') {
            print('✅ Cloud Functions connection successful (function reachable)');
            return true;
          }
        }
        throw e;
      }
      
      print('✅ Cloud Functions connection successful');
      return true;
    } on FirebaseFunctionsException catch (e) {
      print('❌ Connection test failed: ${e.code} - ${e.message}');
      return false;
    } catch (e) {
      print('❌ Connection test failed: $e');
      return false;
    }
  }
}