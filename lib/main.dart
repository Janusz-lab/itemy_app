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

final sharedPrefsProvider = Provider<SharedPreferences>((ref) => throw UnimplementedError());

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  try {
    await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  } catch (e) {
    debugPrint("Firebase init error: $e");
  }

  final prefs = await SharedPreferences.getInstance();

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
        error: (e, s) => Scaffold(body: Center(child: Text('Błąd Auth: $e'))),
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
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(authControllerProvider).initializeAuth();
    });
  }
  @override
  Widget build(BuildContext context) => const Scaffold(body: Center(child: CircularProgressIndicator()));
}

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  void _showAddProductSheet(BuildContext context, WidgetRef ref, String storageId, {String? ean}) {
    final nameController = TextEditingController();
    final eanController = TextEditingController(text: ean);
    final descController = TextEditingController();
    final urlController = TextEditingController();
    final qtyController = TextEditingController(text: '1');
    String selectedUnit = 'szt';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
          child: DraggableScrollableSheet(
            initialChildSize: 0.8,
            maxChildSize: 0.95,
            expand: false,
            builder: (context, scrollController) => SingleChildScrollView(
              controller: scrollController,
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  Text(ean != null ? 'Nowy produkt (EAN: $ean)' : 'Dodaj produkt', 
                    style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 20),
                  TextField(controller: nameController, decoration: const InputDecoration(labelText: 'Nazwa produktu *', border: OutlineInputBorder()), autofocus: true),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        flex: 2,
                        child: TextField(controller: qtyController, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Ilość', border: OutlineInputBorder())),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          value: selectedUnit,
                          decoration: const InputDecoration(labelText: 'Jedn.', border: OutlineInputBorder()),
                          items: ['szt', 'kpl', 'g', 'kg', 'm', 'cm', 'm2', 'm3'].map((u) => DropdownMenuItem(value: u, child: Text(u))).toList(),
                          onChanged: (v) => setState(() => selectedUnit = v!),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  TextField(controller: eanController, decoration: const InputDecoration(labelText: 'Kod EAN', border: OutlineInputBorder())),
                  const SizedBox(height: 12),
                  TextField(controller: urlController, decoration: const InputDecoration(labelText: 'Link do zdjęcia', border: OutlineInputBorder())),
                  const SizedBox(height: 12),
                  TextField(controller: descController, maxLines: 2, decoration: const InputDecoration(labelText: 'Opis', border: OutlineInputBorder())),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      onPressed: () {
                        if (nameController.text.isNotEmpty) {
                          final newItem = ItemModel(
                            id: '', 
                            name: nameController.text, 
                            ean: eanController.text.isEmpty ? null : eanController.text,
                            quantity: double.tryParse(qtyController.text) ?? 1.0,
                            unit: selectedUnit,
                            description: descController.text,
                            imageUrl: urlController.text,
                            updatedAt: DateTime.now()
                          );
                          ref.read(itemRepositoryProvider).upsertItem(storageId, newItem);
                          Navigator.pop(context);
                        }
                      },
                      child: const Text('Zapisz produkt'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _showScanDialog(BuildContext context, WidgetRef ref, String storageId) {
    final eanController = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Skanowanie kodu EAN'),
        content: TextField(
          controller: eanController,
          keyboardType: TextInputType.number,
          autofocus: true,
          decoration: const InputDecoration(hintText: 'Wpisz lub wklej kod'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Anuluj')),
          ElevatedButton(
            onPressed: () {
              final ean = eanController.text.trim();
              if (ean.isNotEmpty) {
                Navigator.pop(context);
                final items = ref.read(currentItemsProvider).value ?? [];
                final existing = items.where((i) => i.ean == ean).toList();

                if (existing.isNotEmpty) {
                  ref.read(itemRepositoryProvider).updateQuantity(storageId, existing.first.id, 1);
                } else {
                  _showAddProductSheet(context, ref, storageId, ean: ean);
                }
              }
            },
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final storage = ref.watch(currentStorageProvider);
    final user = ref.watch(authStateProvider).value;
    final sortConfig = ref.watch(itemSortProvider);

    return Scaffold(
      appBar: AppBar(
        title: storage == null ? const Text('iteMY') : TextField(
          decoration: const InputDecoration(
            hintText: 'Szukaj produktów...',
            border: InputBorder.none,
          ),
          onChanged: (val) => ref.read(itemSearchQueryProvider.notifier).state = val,
        ),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        actions: [
          PopupMenuButton<SortOption>(
            icon: const Icon(Icons.sort),
            onSelected: (opt) => ref.read(itemSortProvider.notifier).state = sortConfig.copyWith(option: opt),
            itemBuilder: (context) => [
              const PopupMenuItem(value: SortOption.name, child: Text('Sortuj po nazwie')),
              const PopupMenuItem(value: SortOption.ean, child: Text('Sortuj po EAN')),
              const PopupMenuItem(value: SortOption.date, child: Text('Sortuj po dacie')),
              const PopupMenuItem(value: SortOption.quantity, child: Text('Sortuj po ilości')),
            ],
          ),
          IconButton(
            icon: Icon(sortConfig.ascending ? Icons.arrow_upward : Icons.arrow_downward),
            onPressed: () => ref.read(itemSortProvider.notifier).state = sortConfig.copyWith(ascending: !sortConfig.ascending),
          ),
        ],
      ),
      body: storage == null 
        ? Center(child: ElevatedButton(
            onPressed: () => ref.read(storageRepositoryProvider).createStorage('Mój Magazyn', user!.uid),
            child: const Text('Inicjalizuj Magazyn')))
        : const ItemListWidget(),
      floatingActionButton: storage == null ? null : Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          FloatingActionButton(
            onPressed: () => _showAddProductSheet(context, ref, storage.id),
            heroTag: 'manual_add',
            child: const Icon(Icons.add),
          ),
          const SizedBox(width: 12),
          FloatingActionButton.extended(
            onPressed: () => _showScanDialog(context, ref, storage.id),
            heroTag: 'ean_scan',
            label: const Text('Skanuj EAN'),
            icon: const Icon(Icons.qr_code_scanner),
          ),
        ],
      ),
    );
  }
}

class ItemListWidget extends ConsumerWidget {
  const ItemListWidget({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final itemsAsync = ref.watch(filteredItemsProvider);
    return itemsAsync.when(
      data: (items) => items.isEmpty 
        ? const Center(child: Text('Brak wyników.'))
        : ListView.builder(
            padding: const EdgeInsets.only(bottom: 100, top: 8),
            itemCount: items.length,
            itemBuilder: (context, index) => ItemCard(item: items[index]),
          ),
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, s) => Center(child: Text('Błąd: $e')),
    );
  }
}