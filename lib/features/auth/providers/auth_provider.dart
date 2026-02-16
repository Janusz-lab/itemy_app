
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/providers/firebase_providers.dart';

final authStateProvider = StreamProvider<User?>((ref) => ref.watch(firebaseAuthProvider).authStateChanges());

final authControllerProvider = Provider((ref) => AuthController(ref.read(firebaseAuthProvider)));

class AuthController {
  final FirebaseAuth _auth;
  AuthController(this._auth);

  Future<void> initializeAuth() async {
    if (_auth.currentUser == null) {
      await _auth.signInAnonymously();
    }
  }
}
