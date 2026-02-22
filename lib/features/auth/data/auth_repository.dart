import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';

class AuthRepository {
  final FirebaseAuth _auth;
  final GoogleSignIn _googleSignIn;

  AuthRepository(this._auth)
      : _googleSignIn = GoogleSignIn(
          clientId: '384317417835-4ng5mq2kfltau00lgree1g3l9mu5287h.apps.googleusercontent.com',
        );

  Stream<User?> get authStateChanges => _auth.authStateChanges();
  User? get currentUser => _auth.currentUser;

  Future<UserCredential> signInAnonymously() => _auth.signInAnonymously();

  // ── Google Sign-In ────────────────────────────────────────────────────────
  Future<UserCredential?> signInWithGoogle() async {
    final googleUser = await _googleSignIn.signIn();
    if (googleUser == null) return null; // użytkownik anulował

    final googleAuth = await googleUser.authentication;
    final credential = GoogleAuthProvider.credential(
      accessToken: googleAuth.accessToken,
      idToken: googleAuth.idToken,
    );
    return await _auth.signInWithCredential(credential);
  }

  // ── Email + hasło ─────────────────────────────────────────────────────────
  Future<UserCredential> signInWithEmail(String email, String password) async {
    return await _auth.signInWithEmailAndPassword(
        email: email, password: password);
  }

  Future<UserCredential> registerWithEmail(String email, String password) async {
    return await _auth.createUserWithEmailAndPassword(
        email: email, password: password);
  }

  Future<void> sendPasswordReset(String email) async {
    await _auth.sendPasswordResetEmail(email: email);
  }

  // ── Wylogowanie ───────────────────────────────────────────────────────────
  Future<void> signOut() async {
    try {
      await _googleSignIn.signOut();
    } catch (e) {
      // Google Sign-In na web wymaga clientId w web/index.html —
      // ignorujemy błąd inicjalizacji, Firebase signOut i tak zadziała
      debugPrint('GoogleSignIn signOut error (ignorowane): $e');
    }
    await _auth.signOut();
  }
}