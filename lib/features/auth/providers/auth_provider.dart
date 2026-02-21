import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/providers/firebase_providers.dart';
import '../data/auth_repository.dart';

export '../data/auth_repository.dart';

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return AuthRepository(ref.watch(firebaseAuthProvider));
});

final authStateProvider = StreamProvider<User?>((ref) {
  return ref.watch(authRepositoryProvider).authStateChanges;
});

final authControllerProvider = Provider((ref) {
  return AuthController(ref.read(authRepositoryProvider));
});

class AuthController {
  final AuthRepository _repo;
  AuthController(this._repo);

  /// Przy starcie — jeśli nikt nie jest zalogowany, NIE logujemy anonimowo.
  /// Użytkownik musi się zalogować przez ekran logowania.
  Future<void> initializeAuth() async {
    // Nic nie robimy — czekamy aż użytkownik się zaloguje
  }

  Future<void> signOut() => _repo.signOut();
}
