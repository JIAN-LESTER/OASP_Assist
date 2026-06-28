import 'dart:convert';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;
import 'package:cloud_functions/cloud_functions.dart';

class FirebaseFunctionsService {
  static const String projectId = 'cmu-oasp-assist';
  static const String region = 'us-central1';

  static bool _useHttpFallback = false;
  static FirebaseFunctions? _functionsInstance;

  FirebaseFunctions get _functions {
    _functionsInstance ??= FirebaseFunctions.instanceFor(region: region);
    return _functionsInstance!;
  }

  Future<Map<String, dynamic>> _callFunction(
    String functionName,
    Map<String, dynamic> data,
  ) async {
    if (!_useHttpFallback) {
      try {
        final callable = _functions.httpsCallable(
          functionName,
          options: HttpsCallableOptions(timeout: const Duration(seconds: 60)),
        );

        final result = await callable.call(data);
        return result.data as Map<String, dynamic>;
      } on FirebaseFunctionsException catch (e) {
        if (e.code == 'unknown' && e.message?.contains('channel') == true) {
          _useHttpFallback = true;
        } else {
          rethrow;
        }
      } catch (e) {
        _useHttpFallback = true;
      }
    }

    return await _callFunctionViaHttp(functionName, data);
  }

  Future<Map<String, dynamic>> _callFunctionViaHttp(
    String functionName,
    Map<String, dynamic> data,
  ) async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) {
      throw Exception('You must be logged in');
    }

    final token = await currentUser.getIdToken(true);
    if (token == null) {
      throw Exception('Failed to get authentication token');
    }

    final url = Uri.parse(
      'https://$region-$projectId.cloudfunctions.net/$functionName',
    );

    final response = await http
        .post(
          url,
          headers: {
            'Authorization': 'Bearer $token',
            'Content-Type': 'application/json',
          },
          body: json.encode({'data': data}),
        )
        .timeout(
          const Duration(seconds: 60),
          onTimeout: () => throw Exception('Request timed out'),
        );

    if (response.statusCode == 200) {
      final responseData = json.decode(response.body);

      if (responseData is Map<String, dynamic>) {
        if (responseData.containsKey('result')) {
          return responseData['result'] as Map<String, dynamic>;
        }
        return responseData;
      }

      throw Exception('Unexpected response format');
    } else {
      try {
        final errorData = json.decode(response.body);
        final errorMessage =
            errorData['error']?['message'] ??
            errorData['message'] ??
            'Unknown error';
        throw Exception(errorMessage);
      } catch (e) {
        throw Exception('HTTP ${response.statusCode}: ${response.body}');
      }
    }
  }

  Future<String> createUserAuth({
    required String email,
    required String password,
    String? displayName,
    required Map<String, dynamic> userData, 
  }) async {
    try {
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) {
        throw Exception('You must be logged in as an admin');
      }

      //  Merge all data together - Cloud Function will handle timestamps
      final data = {
        'email': email,
        'password': password,
        if (displayName != null && displayName.isNotEmpty)
          'displayName': displayName,
        ...userData,
      };

      final responseData = await _callFunction('createUser', data);

      if (responseData['success'] == true) {
        return responseData['uid'] as String;
      }

      throw Exception(responseData['message'] ?? 'User creation failed');
    } on FirebaseFunctionsException catch (e) {
      _handleFunctionsException(e);
      rethrow;
    }
  }

  Future<void> deleteUserAuth(String uid) async {
    try {
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) {
        throw Exception('You must be logged in as an admin');
      }

      await _callFunction('deleteUser', {'uid': uid});
    } on FirebaseFunctionsException catch (e) {
      _handleFunctionsException(e);
      rethrow;
    }
  }

  Future<void> updateUserAuth({
    required String uid,
    String? email,
    String? password,
    String? displayName,
    String? role,
    String? affiliation,
    String? studentId,
    String? year,
    String? program,
    String? scholarship,
    String? lrn,
    String? serviceUnit,
    bool? isActive,
    String? college,
    String? collegeId,
    String? studentType,
    String? graduateType,
    String? graduatedCollege,
    String? graduatedCollegeId,
    String? graduatedProgram,
  }) async {
    try {
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) {
        throw Exception('You must be logged in');
      }

      final data = {
        'uid': uid,
        if (email != null && email.isNotEmpty) 'email': email,
        if (password != null && password.isNotEmpty) 'password': password,
        if (displayName != null && displayName.isNotEmpty)
          'displayName': displayName,
        if (role != null && role.isNotEmpty) 'role': role,
        if (affiliation != null) 'affiliation': affiliation,
        if (studentId != null) 'studentId': studentId,
        if (year != null) 'year': year,
        if (program != null) 'program': program,
        if (scholarship != null) 'scholarship': scholarship,
        if (lrn != null) 'lrn': lrn,
        if (serviceUnit != null) 'serviceUnit': serviceUnit,
        if (isActive != null) 'isActive': isActive,
        if (college != null) 'college': college,
        if (collegeId != null) 'collegeId': collegeId,
        if (studentType != null) 'studentType': studentType,
        if (graduateType != null) 'graduateType': graduateType,
        if (graduatedCollege != null) 'graduatedCollege': graduatedCollege,
        if (graduatedCollegeId != null)
          'graduatedCollegeId': graduatedCollegeId,
        if (graduatedProgram != null) 'graduatedProgram': graduatedProgram,
      };

      await _callFunction('updateUser', data);
    } on FirebaseFunctionsException catch (e) {
      _handleFunctionsException(e);
      rethrow;
    }
  }

  Future<void> setAdminRole({
    required String uid,
    required bool isAdmin,
  }) async {
    try {
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) {
        throw Exception('You must be logged in as an admin');
      }

      await _callFunction('setAdminRole', {'uid': uid, 'isAdmin': isAdmin});
    } on FirebaseFunctionsException catch (e) {
      _handleFunctionsException(e);
      rethrow;
    }
  }

  void _handleFunctionsException(FirebaseFunctionsException e) {
    String message;

    switch (e.code) {
      case 'unauthenticated':
        message = 'You must be logged in as an admin';
        break;
      case 'permission-denied':
        message = 'Only admins can perform this action';
        break;
      case 'invalid-argument':
        message = e.message ?? 'Invalid data provided';
        break;
      case 'already-exists':
        message = e.message ?? 'This email is already registered';
        break;
      case 'not-found':
        message = 'User not found';
        break;
      case 'unavailable':
        message = 'Service unavailable. Check your internet connection';
        break;
      case 'deadline-exceeded':
        message = 'Request timed out. Please try again';
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
