import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/auth_provider.dart';
import '../../../core/providers/app_providers.dart';
import 'login_screen.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authStateProvider).value;
    final isAnon = user?.isAnonymous ?? true;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Ustawienia'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: ListView(
        children: [

          // ── Sekcja: Konto ─────────────────────────────────────────────────
          _SectionHeader('Konto'),

          if (isAnon) ...[
            // Tryb lokalny
            const ListTile(
              leading: CircleAvatar(
                backgroundColor: Color(0xFFEEEEEE),
                child: Icon(Icons.person_outline, color: Colors.grey),
              ),
              title: Text('Tryb lokalny'),
              subtitle: Text(
                'Dane przechowywane tylko na tym urządzeniu.\n'
                'Zaloguj się żeby synchronizować między urządzeniami.',
              ),
              isThreeLine: true,
            ),
            const Divider(indent: 16, endIndent: 16),
            ListTile(
              leading: const Icon(Icons.login, color: Colors.blue),
              title: const Text('Zaloguj się / Utwórz konto',
                  style: TextStyle(color: Colors.blue)),
              subtitle: const Text('Google lub email + hasło'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const LoginScreen()),
              ),
            ),
          ] else ...[
            // Zalogowany
            ListTile(
              leading: CircleAvatar(
                backgroundColor: Colors.blue[50],
                backgroundImage: user?.photoURL != null
                    ? NetworkImage(user!.photoURL!)
                    : null,
                child: user?.photoURL == null
                    ? const Icon(Icons.person, color: Colors.blue)
                    : null,
              ),
              title: Text(
                user?.displayName ?? user?.email ?? 'Zalogowany użytkownik',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              subtitle: Text(user?.email ?? ''),
            ),
            const Divider(indent: 16, endIndent: 16),
            ListTile(
              leading: const Icon(Icons.phone_android, color: Colors.orange),
              title: const Text('Przejdź do trybu lokalnego'),
              subtitle: const Text('Wyloguje Cię — dane na tym urządzeniu pozostaną'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => _confirmSwitchToLocal(context, ref),
            ),
          ],

          // ── Sekcja: Aplikacja ─────────────────────────────────────────────
          const SizedBox(height: 8),
          _SectionHeader('Skanowanie'),
          Consumer(builder: (context, ref, _) {
            final cameraMode = ref.watch(scannerModeProvider);
            return SwitchListTile(
              secondary: Icon(
                cameraMode ? Icons.qr_code_scanner : Icons.keyboard,
                color: (cameraMode && !kIsWeb) ? Colors.blue : Colors.grey,
              ),
              title: Text(cameraMode && !kIsWeb ? 'Skaner kamerowy' : 'Wpisywanie ręczne'),
              subtitle: Text(kIsWeb
                  ? 'Skaner kamerowy dostępny tylko na telefonie'
                  : cameraMode
                      ? 'Kamera skanuje kod EAN automatycznie'
                      : 'Wpisujesz kod EAN z klawiatury'),
              value: cameraMode,
              onChanged: kIsWeb ? null : (_) => ref.read(scannerModeProvider.notifier).toggle(),
            );
          }),

          // ── Sekcja: Aplikacja ─────────────────────────────────────────────
          const SizedBox(height: 8),
          _SectionHeader('Aplikacja'),
          ListTile(
            leading: const Icon(Icons.info_outline),
            title: const Text('iteMY'),
            subtitle: const Text('Menedżer zapasów'),
          ),
        ],
      ),
    );
  }

  void _confirmSwitchToLocal(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Przejdź do trybu lokalnego'),
        content: const Text(
          'Zostaniesz wylogowany.\n\n'
          'Twoje dane na koncie nie zostaną usunięte — '
          'możesz zalogować się ponownie w dowolnym momencie.\n\n'
          'Na tym urządzeniu zostanie utworzony nowy lokalny profil.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Anuluj'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
            onPressed: () async {
              Navigator.pop(ctx);
              Navigator.pop(context); // zamknij settings
              await ref.read(authControllerProvider).signOut();
              // initializeAuth zaloguje anonimowo automatycznie
              await ref.read(authControllerProvider).initializeAuth();
            },
            child: const Text('Przejdź do trybu lokalnego',
                style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  const _SectionHeader(this.title);

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
    child: Text(title.toUpperCase(),
        style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: Colors.grey[600],
            letterSpacing: 1.0)),
  );
}