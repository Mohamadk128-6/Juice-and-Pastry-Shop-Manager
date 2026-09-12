import 'package:firebase_auth/firebase_auth.dart';

class FirebaseAuthService {
  static final FirebaseAuthService _instance = FirebaseAuthService._internal();
  factory FirebaseAuthService() => _instance;
  FirebaseAuthService._internal();

  final FirebaseAuth _auth = FirebaseAuth.instance;

  Future<User?> signInAnonymously() async {
    try {
      final cred = await _auth.signInAnonymously();
      return cred.user;
    } catch (e) {
      return null;
    }
  }
}
