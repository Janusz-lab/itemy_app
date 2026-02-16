import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/providers/firebase_providers.dart';

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return AuthRepository(ref.read(firebaseAuthProvider));
});

class AuthRepository {
  final FirebaseAuth _auth;
  AuthRepository(this._auth);

  // Naprawione: dodano () do wywołania metody, aby zwracała Stream a nie funkcję
  Stream<User?> get authStateChanges => _auth.authStateChanges();
  User? get currentUser => _auth.currentUser;

  Future<UserCredential> signInAnonymously() async {
    return await _auth.signInAnonymously();
  }
}
