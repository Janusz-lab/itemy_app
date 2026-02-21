import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../providers/auth_provider.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _emailController    = TextEditingController();
  final _passwordController = TextEditingController();
  final _formKey            = GlobalKey<FormState>();

  bool _isLogin    = true;  // true = logowanie, false = rejestracja
  bool _isLoading  = false;
  bool _obscure    = true;
  String? _errorMessage;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _setError(String? msg) => setState(() => _errorMessage = msg);
  void _setLoading(bool v)    => setState(() => _isLoading = v);

  String _friendlyError(FirebaseAuthException e) {
    switch (e.code) {
      case 'user-not-found':      return 'Nie znaleziono konta z tym adresem email.';
      case 'wrong-password':      return 'Nieprawidłowe hasło.';
      case 'email-already-in-use':return 'Ten email jest już zarejestrowany.';
      case 'weak-password':       return 'Hasło musi mieć co najmniej 6 znaków.';
      case 'invalid-email':       return 'Nieprawidłowy format adresu email.';
      case 'invalid-credential':  return 'Nieprawidłowy email lub hasło.';
      case 'too-many-requests':   return 'Za dużo prób. Spróbuj za chwilę.';
      case 'network-request-failed': return 'Brak połączenia z internetem.';
      default: return 'Błąd: ${e.message}';
    }
  }

  // ── Google ────────────────────────────────────────────────────────────────
  Future<void> _signInWithGoogle() async {
    _setError(null);
    _setLoading(true);
    try {
      await ref.read(authRepositoryProvider).signInWithGoogle();
    } on FirebaseAuthException catch (e) {
      _setError(_friendlyError(e));
    } catch (e) {
      _setError('Błąd logowania przez Google.');
    } finally {
      _setLoading(false);
    }
  }

  // ── Email / hasło ─────────────────────────────────────────────────────────
  Future<void> _submitEmailForm() async {
    if (!_formKey.currentState!.validate()) return;
    _setError(null);
    _setLoading(true);
    try {
      final repo  = ref.read(authRepositoryProvider);
      final email = _emailController.text.trim();
      final pass  = _passwordController.text;
      if (_isLogin) {
        await repo.signInWithEmail(email, pass);
      } else {
        await repo.registerWithEmail(email, pass);
      }
    } on FirebaseAuthException catch (e) {
      _setError(_friendlyError(e));
    } catch (e) {
      _setError('Nieoczekiwany błąd. Spróbuj ponownie.');
    } finally {
      _setLoading(false);
    }
  }

  // ── Reset hasła ───────────────────────────────────────────────────────────
  Future<void> _resetPassword() async {
    final email = _emailController.text.trim();
    if (email.isEmpty) {
      _setError('Wpisz adres email żeby zresetować hasło.');
      return;
    }
    _setLoading(true);
    try {
      await ref.read(authRepositoryProvider).sendPasswordReset(email);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Link do resetowania hasła wysłany na email.'),
        ));
      }
    } on FirebaseAuthException catch (e) {
      _setError(_friendlyError(e));
    } finally {
      _setLoading(false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(28),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [

                // ── Logo / tytuł ──────────────────────────────────────────
                const Icon(Icons.inventory_2_outlined, size: 72, color: Colors.blue),
                const SizedBox(height: 12),
                const Text('iteMY',
                    style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                Text(
                  _isLogin ? 'Zaloguj się' : 'Utwórz konto',
                  style: TextStyle(fontSize: 16, color: Colors.grey[600]),
                ),
                const SizedBox(height: 36),

                // ── Przycisk Google ───────────────────────────────────────
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: OutlinedButton.icon(
                    onPressed: _isLoading ? null : _signInWithGoogle,
                    icon: Image.network(
                      'https://www.gstatic.com/firebasejs/ui/2.0.0/images/auth/google.svg',
                      width: 22, height: 22,
                      errorBuilder: (_, __, ___) => const Icon(Icons.login, size: 22),
                    ),
                    label: const Text('Kontynuuj z Google',
                        style: TextStyle(fontSize: 16)),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: Colors.grey),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                ),

                const SizedBox(height: 20),

                // ── Separator ─────────────────────────────────────────────
                Row(children: [
                  const Expanded(child: Divider()),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: Text('lub', style: TextStyle(color: Colors.grey[500])),
                  ),
                  const Expanded(child: Divider()),
                ]),

                const SizedBox(height: 20),

                // ── Formularz email ───────────────────────────────────────
                Form(
                  key: _formKey,
                  child: Column(children: [
                    TextFormField(
                      controller: _emailController,
                      keyboardType: TextInputType.emailAddress,
                      decoration: const InputDecoration(
                        labelText: 'Adres email',
                        prefixIcon: Icon(Icons.email_outlined),
                        border: OutlineInputBorder(),
                      ),
                      validator: (v) {
                        if (v == null || v.isEmpty) return 'Podaj adres email';
                        if (!v.contains('@')) return 'Nieprawidłowy email';
                        return null;
                      },
                    ),
                    const SizedBox(height: 14),
                    TextFormField(
                      controller: _passwordController,
                      obscureText: _obscure,
                      decoration: InputDecoration(
                        labelText: 'Hasło',
                        prefixIcon: const Icon(Icons.lock_outline),
                        border: const OutlineInputBorder(),
                        suffixIcon: IconButton(
                          icon: Icon(_obscure ? Icons.visibility_off : Icons.visibility),
                          onPressed: () => setState(() => _obscure = !_obscure),
                        ),
                      ),
                      validator: (v) {
                        if (v == null || v.isEmpty) return 'Podaj hasło';
                        if (!_isLogin && v.length < 6) {
                          return 'Hasło musi mieć co najmniej 6 znaków';
                        }
                        return null;
                      },
                    ),
                  ]),
                ),

                // ── Reset hasła ───────────────────────────────────────────
                if (_isLogin)
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(
                      onPressed: _isLoading ? null : _resetPassword,
                      child: const Text('Zapomniałem hasła'),
                    ),
                  )
                else
                  const SizedBox(height: 8),

                // ── Błąd ──────────────────────────────────────────────────
                if (_errorMessage != null) ...[
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.red[50],
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.red.shade200),
                    ),
                    child: Text(_errorMessage!,
                        style: TextStyle(color: Colors.red[700], fontSize: 13)),
                  ),
                  const SizedBox(height: 12),
                ],

                // ── Przycisk główny ───────────────────────────────────────
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _submitEmailForm,
                    style: ElevatedButton.styleFrom(
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10)),
                    ),
                    child: _isLoading
                        ? const SizedBox(width: 22, height: 22,
                            child: CircularProgressIndicator(strokeWidth: 2))
                        : Text(_isLogin ? 'Zaloguj się' : 'Utwórz konto',
                            style: const TextStyle(fontSize: 16)),
                  ),
                ),

                const SizedBox(height: 16),

                // ── Przełącznik logowanie/rejestracja ─────────────────────
                Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                  Text(_isLogin ? 'Nie masz konta?' : 'Masz już konto?',
                      style: TextStyle(color: Colors.grey[600])),
                  TextButton(
                    onPressed: () => setState(() {
                      _isLogin = !_isLogin;
                      _errorMessage = null;
                    }),
                    child: Text(_isLogin ? 'Zarejestruj się' : 'Zaloguj się'),
                  ),
                ]),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
