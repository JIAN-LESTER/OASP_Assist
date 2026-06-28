import 'package:cloud_functions/cloud_functions.dart';

class AuthEmailService {
  AuthEmailService()
    : _functions = FirebaseFunctions.instanceFor(region: 'asia-southeast1');

  final FirebaseFunctions _functions;

  Future<void> sendEmailVerification() async {
    await _functions.httpsCallable('sendCustomEmailVerification').call();
  }

  Future<void> sendPasswordReset(String email) async {
    await _functions.httpsCallable('sendCustomPasswordReset').call({
      'email': email,
    });
  }

  Future<void> sendEmailChangeVerification(String newEmail) async {
    await _functions.httpsCallable('sendCustomEmailChangeVerification').call({
      'newEmail': newEmail,
    });
  }
}
