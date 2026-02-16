
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'firebase_options.dart';
import 'features/auth/providers/auth_provider.dart';
import 'features/inventory/providers/storage_providers.dart';
import 'features/inventory/providers/item_providers.dart';
import 'features/inventory/data/storage_repository.dart';
import 'features/inventory/data/item_repository.dart';
import 'features/inventory/models/item_model.dart';
import 'features/inventory/presentation/item_card.dart';

// Provider do lokalnej pamięci (SharedPreferences)
final sharedPrefsProvider = Provider<SharedPreferences>((ref) => throw UnimplementedError());

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final prefs = await SharedPreferences.getInstance();
  
  // Inicjalizacja Firebase
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  runApp(ProviderScope(
    overrides: [sharedPrefsProvider.overrideWithValue(prefs)],
    child: const IteMYApp(),
  ));
}

class IteMYApp extends ConsumerWidget {
  const IteMYApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authStateProvider);
    return MaterialApp(
      title: 'iteMY',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true, 
        colorSchemeSeed: Colors.blue,
        brightness: Brightness.light,
      ),
      home: authState.when(
        data: (user) => user == null ? const LoadingScreen() : const HomeScreen(),
        loading: () => const LoadingScreen(),
        error: (e, s) => Scaffold(body: Center(child: Text('Błąd: $e'))),
      ),
    );
  }
}

class LoadingScreen extends ConsumerStatefulWidget {
  const LoadingScreen({super.key});
  @override
  ConsumerState<LoadingScreen> createState() => _LoadingScreenState();
}

class _LoadingScreenState extends ConsumerState<LoadingScreen> {
  @override
  void initState() {
    super.initState();
    // Automatyczne logowanie anonimowe przy starcie
    Future.microtask(() => ref.read(authControllerProvider).initializeAuth());
  }
  @override
  Widget build(BuildContext context) => const Scaffold(body: Center(child: CircularProgressIndicator()));
}

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  void _showManualEanEntry(BuildContext context, WidgetRef ref, String storageId) {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Wpisz kod EAN'),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          autofocus: true,
          decoration: const InputDecoration(
            hintText: 'Np. 5901234567890',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Anuluj'),
          ),
          ElevatedButton(
            onPressed: () {
              if (controller.text.isNotEmpty) {
                final newItem = ItemModel(
                  id: '', 
                  name: 'Produkt ${controller.text.substring(controller.text.length - 4)}', 
                  ean: controller.text,
                  quantity: 1, 
                  updatedAt: DateTime.now()
                );
                ref.read(itemRepositoryProvider).upsertItem(storageId, newItem);
                Navigator.pop(context);
              }
            },
            child: const Text('Dodaj'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final storage = ref.watch(currentStorageProvider);
    final user = ref.watch(authStateProvider).value;

    return Scaffold(
      appBar: AppBar(
        title: Text(storage?.name ?? 'iteMY'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        actions: [
          if (user != null)
            IconButton(
              icon: const Icon(Icons.person_outline),
              onPressed: () {},
            ),
        ],
      ),
      body: storage == null 
        ? Center(child: ElevatedButton(
            onPressed: () => ref.read(storageRepositoryProvider).createStorage('Mój Magazyn', user!.uid),
            child: const Text('Stwórz magazyn')))
        : const ItemListWidget(),
      floatingActionButton: storage == null ? null : FloatingActionButton.extended(
        onPressed: () => _showManualEanEntry(context, ref, storage.id),
        label: const Text('Skanuj (Manual)'),
        icon: const Icon(Icons.qr_code_scanner),
      ),
    );
  }
}

class ItemListWidget extends ConsumerWidget {
  const ItemListWidget({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final itemsAsync = ref.watch(currentItemsProvider);
    
    return itemsAsync.when(
      data: (items) => items.isEmpty 
          ? const Center(child: Text('Brak produktów w tym magazynie.'))
          : ListView.builder(
              padding: const EdgeInsets.only(top: 8, bottom: 80),
              itemCount: items.length,
              itemBuilder: (context, index) => ItemCard(item: items[index]),
            ),
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, s) => Center(child: Text('Błąd bazy: $e')),
    );
  }
}
