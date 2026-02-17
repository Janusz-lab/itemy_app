import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'features/auth/providers/auth_provider.dart';
import 'features/inventory/providers/storage_providers.dart';
import 'features/inventory/providers/item_providers.dart';
import 'features/inventory/data/storage_repository.dart';
import 'features/inventory/data/item_repository.dart';
import 'features/inventory/models/item_model.dart';
import 'features/inventory/models/storage_model.dart'; // NAPRAWIONO: Dodano brakujący import
import 'features/inventory/presentation/item_card.dart';

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform => const FirebaseOptions(
    apiKey: 'AIzaSyD3w-CM32p3pqul9Ucc8nS4n62sYrKyFoU',
    appId: '1:776937770544:web:2a149f4b8f56848a56a7f5',
    messagingSenderId: '776937770544',
    projectId: 'itemy-63118',
    authDomain: 'itemy-63118.firebaseapp.com',
    storageBucket: 'itemy-63118.firebasestorage.app',
  );
}

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

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});
  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  final TextEditingController _searchController = TextEditingController();

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
                      Expanded(flex: 2, child: TextField(controller: qtyController, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Ilość', border: OutlineInputBorder()))),
                      const SizedBox(width: 12),
                      Expanded(child: DropdownButtonFormField<String>(
                        value: selectedUnit,
                        decoration: const InputDecoration(labelText: 'Jedn.', border: OutlineInputBorder()),
                        items: ['szt', 'kpl', 'g', 'kg', 'm', 'cm', 'm2', 'm3'].map((u) => DropdownMenuItem(value: u, child: Text(u))).toList(),
                        onChanged: (v) => setState(() => selectedUnit = v!),
                      )),
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
                            id: '', name: nameController.text, ean: eanController.text.isEmpty ? null : eanController.text,
                            quantity: double.tryParse(qtyController.text) ?? 1.0, unit: selectedUnit,
                            description: descController.text, imageUrl: urlController.text, updatedAt: DateTime.now()
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
        content: TextField(controller: eanController, keyboardType: TextInputType.number, autofocus: true, decoration: const InputDecoration(hintText: 'Wpisz lub wklej kod')),
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
  Widget build(BuildContext context) {
    final storage = ref.watch(currentStorageProvider);
    final user = ref.watch(authStateProvider).value;
    final sortConfig = ref.watch(itemSortProvider);

    return Scaffold(
      appBar: AppBar(
        title: TextField(
          controller: _searchController,
          decoration: InputDecoration(
            hintText: storage != null ? 'Szukaj w: ${storage.name}' : 'iteMY',
            border: InputBorder.none,
            suffixIcon: _searchController.text.isNotEmpty 
              ? IconButton(icon: const Icon(Icons.clear), onPressed: () { _searchController.clear(); ref.read(itemSearchQueryProvider.notifier).state = ""; setState(() {}); })
              : null,
          ),
          onChanged: (val) { ref.read(itemSearchQueryProvider.notifier).state = val; setState(() {}); },
        ),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        actions: [
          PopupMenuButton<SortOption>(
            icon: const Icon(Icons.sort),
            onSelected: (opt) => ref.read(itemSortProvider.notifier).state = sortConfig.copyWith(option: opt),
            itemBuilder: (context) => [
              const PopupMenuItem(value: SortOption.name, child: Text('Nazwa')),
              const PopupMenuItem(value: SortOption.ean, child: Text('EAN')),
              const PopupMenuItem(value: SortOption.date, child: Text('Data')),
              const PopupMenuItem(value: SortOption.quantity, child: Text('Ilość')),
            ],
          ),
          IconButton(
            icon: Icon(sortConfig.ascending ? Icons.arrow_upward : Icons.arrow_downward),
            onPressed: () => ref.read(itemSortProvider.notifier).state = sortConfig.copyWith(ascending: !sortConfig.ascending),
          ),
        ],
      ),
      drawer: const StorageDrawer(),
      body: storage == null 
        ? Center(child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text('Nie wybrano magazynu.'),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: () => ref.read(storageRepositoryProvider).createStorage('Mój Magazyn', user!.uid),
                child: const Text('Stwórz pierwszy magazyn'))
            ],
          ))
        : const ItemListWidget(),
      floatingActionButton: storage == null ? null : Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          FloatingActionButton(onPressed: () => _showAddProductSheet(context, ref, storage.id), heroTag: 'add', child: const Icon(Icons.add)),
          const SizedBox(width: 12),
          FloatingActionButton.extended(onPressed: () => _showScanDialog(context, ref, storage.id), heroTag: 'scan', label: const Text('Skanuj'), icon: const Icon(Icons.qr_code_scanner)),
        ],
      ),
    );
  }
}

class StorageDrawer extends ConsumerWidget {
  const StorageDrawer({super.key});

  void _showStorageDialog(BuildContext context, WidgetRef ref, {StorageModel? existing}) {
    final controller = TextEditingController(text: existing?.name);
    final user = ref.read(authStateProvider).value;
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(existing == null ? 'Nowy magazyn' : 'Zmień nazwę'),
        content: TextField(controller: controller, decoration: const InputDecoration(labelText: 'Nazwa magazynu'), autofocus: true),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Anuluj')),
          ElevatedButton(
            onPressed: () {
              if (controller.text.isNotEmpty && user != null) {
                if (existing == null) {
                  ref.read(storageRepositoryProvider).createStorage(controller.text, user.uid);
                } else {
                  ref.read(storageRepositoryProvider).renameStorage(existing.id, controller.text);
                }
                Navigator.pop(context);
              }
            },
            child: const Text('Zapisz'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final storagesAsync = ref.watch(userStoragesProvider);
    final currentStorage = ref.watch(currentStorageProvider);

    return Drawer(
      child: Column(
        children: [
          DrawerHeader(
            decoration: BoxDecoration(color: Theme.of(context).colorScheme.primaryContainer),
            child: const Center(child: Text('Twoje Magazyny', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold))),
          ),
          Expanded(
            child: storagesAsync.when(
              data: (list) => ListView.builder(
                itemCount: list.length,
                itemBuilder: (context, index) {
                  final s = list[index];
                  final isSelected = currentStorage?.id == s.id;
                  return ListTile(
                    leading: Icon(Icons.warehouse, color: isSelected ? Colors.blue : null),
                    title: Text(s.name, style: TextStyle(fontWeight: isSelected ? FontWeight.bold : null)),
                    selected: isSelected,
                    onTap: () {
                      ref.read(activeStorageIdProvider.notifier).state = s.id;
                      Navigator.pop(context);
                    },
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(icon: const Icon(Icons.edit, size: 18), onPressed: () => _showStorageDialog(context, ref, existing: s)),
                        IconButton(
                          icon: const Icon(Icons.delete_outline, size: 18, color: Colors.red), 
                          onPressed: () => ref.read(storageRepositoryProvider).deleteStorage(s.id)
                        ),
                      ],
                    ),
                  );
                },
              ),
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text('Błąd: $e')),
            ),
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.add),
            title: const Text('Dodaj nowy magazyn'),
            onTap: () => _showStorageDialog(context, ref),
          ),
          const SizedBox(height: 20),
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
        ? const Center(child: Text('Pusto tutaj. Dodaj coś!'))
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