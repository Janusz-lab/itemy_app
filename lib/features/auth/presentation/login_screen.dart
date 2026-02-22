import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../providers/auth_provider.dart';
import '../../../core/providers/firebase_providers.dart';
import '../../inventory/data/migration_service.dart';
import '../../inventory/models/storage_model.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _emailController    = TextEditingController();
  final _passwordController = TextEditingController();
  final _formKey            = GlobalKey<FormState>();

  bool _isLogin   = true;
  bool _isLoading = false;
  bool _obscure   = true;
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
      case 'user-not-found':       return 'Nie znaleziono konta z tym adresem email.';
      case 'wrong-password':       return 'Nieprawidłowe hasło.';
      case 'email-already-in-use': return 'Ten email jest już zarejestrowany.';
      case 'weak-password':        return 'Hasło musi mieć co najmniej 6 znaków.';
      case 'invalid-email':        return 'Nieprawidłowy format adresu email.';
      case 'invalid-credential':   return 'Nieprawidłowy email lub hasło.';
      case 'too-many-requests':    return 'Za dużo prób. Spróbuj za chwilę.';
      case 'network-request-failed': return 'Brak połączenia z internetem.';
      default: return 'Błąd: ${e.message}';
    }
  }

  // ── Główna logika po zalogowaniu — sprawdź dane lokalne ──────────────────
  Future<void> _afterLogin(String? anonUid) async {
    if (!mounted) return;
    if (anonUid == null) { Navigator.pop(context); return; }

    // Sprawdź czy anonimowy UID miał jakieś magazyny
    final migService = ref.read(migrationServiceProvider);
    final anonStorages = await migService.getAnonStorages(anonUid);

    if (!mounted) return;
    if (anonStorages.isEmpty) { Navigator.pop(context); return; }

    // Są dane lokalne — pokaż dialog migracji
    await _showMigrationDialog(anonStorages);
    if (mounted) Navigator.pop(context);
  }

  Future<void> _showMigrationDialog(List<StorageModel> storages) async {
    // Lista z checkboxami — kopia żeby setState działał w dialogu
    final items = storages.map((s) => StorageToMigrate(s)).toList();
    bool migrating = false;

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) => AlertDialog(
          title: const Row(children: [
            Icon(Icons.move_up, color: Colors.blue),
            SizedBox(width: 8),
            Text('Przenieś dane lokalne'),
          ]),
          content: SizedBox(
            width: double.maxFinite,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Znaleziono ${storages.length} magazyn${storages.length == 1 ? '' : storages.length < 5 ? 'y' : 'ów'} '
                  'w trybie lokalnym. Wybierz które przenieść na swoje konto:',
                  style: const TextStyle(fontSize: 14),
                ),
                const SizedBox(height: 12),
                ...items.map((item) => CheckboxListTile(
                  dense: true,
                  value: item.selected,
                  onChanged: migrating
                      ? null
                      : (v) => setS(() => item.selected = v ?? false),
                  title: Text(item.storage.name),
                  subtitle: Text('ID: ${item.storage.id.substring(0, 8)}…',
                      style: const TextStyle(fontSize: 11)),
                  controlAffinity: ListTileControlAffinity.leading,
                )),
                if (migrating) ...[
                  const SizedBox(height: 16),
                  const Row(children: [
                    SizedBox(width: 20, height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2)),
                    SizedBox(width: 12),
                    Text('Przenoszenie danych…'),
                  ]),
                ],
              ],
            ),
          ),
          actions: migrating ? [] : [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Pomiń — zacznij od nowa'),
            ),
            ElevatedButton(
                  onPressed: items.any((i) => i.selected)
                      ? () async {
                          setS(() => migrating = true);
                          final selected = items
                              .where((i) => i.selected)
                              .map((i) => i.storage)
                              .toList();
                          final newUid = ref.read(firebaseAuthProvider).currentUser?.uid;
                          if (newUid != null) {
                            await ref.read(migrationServiceProvider).migrateStorages(
                              storages: selected,
                              targetUid: newUid,
                            );
                          }
                          if (ctx.mounted) Navigator.pop(ctx);
                        }
                      : null,
              child: const Text('Przenieś wybrane'),
            ),
          ],
        ),
      ),
    );
  }

  // ── Google ────────────────────────────────────────────────────────────────
  Future<void> _signInWithGoogle() async {
    _setError(null);
    _setLoading(true);
    final anonUid = ref.read(firebaseAuthProvider).currentUser?.uid;
    try {
      await ref.read(authRepositoryProvider).signInWithGoogle();
      await _afterLogin(anonUid);
    } on FirebaseAuthException catch (e) {
      if (mounted) _setError(_friendlyError(e));
    } catch (e) {
      if (mounted) _setError('Błąd logowania przez Google.');
    } finally {
      if (mounted) _setLoading(false);
    }
  }

  // ── Email / hasło ─────────────────────────────────────────────────────────
  Future<void> _submitEmailForm() async {
    if (!_formKey.currentState!.validate()) return;
    _setError(null);
    _setLoading(true);
    final anonUid = ref.read(firebaseAuthProvider).currentUser?.uid;
    try {
      final repo  = ref.read(authRepositoryProvider);
      final email = _emailController.text.trim();
      final pass  = _passwordController.text;
      if (_isLogin) {
        await repo.signInWithEmail(email, pass);
      } else {
        await repo.registerWithEmail(email, pass);
      }
      await _afterLogin(anonUid);
    } on FirebaseAuthException catch (e) {
      if (mounted) _setError(_friendlyError(e));
    } catch (e) {
      if (mounted) _setError('Nieoczekiwany błąd. Spróbuj ponownie.');
    } finally {
      if (mounted) _setLoading(false);
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
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Link do resetowania hasła wysłany na email.'),
      ));
    } on FirebaseAuthException catch (e) {
      if (mounted) _setError(_friendlyError(e));
    } finally {
      if (mounted) _setLoading(false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Zaloguj się'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(28),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [

                // ── Logo ─────────────────────────────────────────────────
                const Icon(Icons.inventory_2_outlined, size: 64, color: Colors.blue),
                const SizedBox(height: 8),
                const Text('iteMY',
                    style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                Text(
                  _isLogin ? 'Zaloguj się' : 'Utwórz konto',
                  style: TextStyle(fontSize: 15, color: Colors.grey[600]),
                ),
                const SizedBox(height: 28),

                // ── Google ────────────────────────────────────────────────
                SizedBox(
                  width: double.infinity, height: 52,
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
                        if (!_isLogin && (v.length < 6)) {
                          return 'Hasło musi mieć co najmniej 6 znaków';
                        }
                        return null;
                      },
                    ),
                  ]),
                ),

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
                  width: double.infinity, height: 52,
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