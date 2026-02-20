import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'core/providers/app_providers.dart';
import 'features/auth/providers/auth_provider.dart';
import 'features/inventory/providers/storage_providers.dart';
import 'features/inventory/providers/item_providers.dart';
import 'features/inventory/data/storage_repository.dart';
import 'features/inventory/data/item_repository.dart';
import 'features/inventory/models/item_model.dart';
import 'features/inventory/models/storage_model.dart';
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
  Widget build(BuildContext context) =>
      const Scaffold(body: Center(child: CircularProgressIndicator()));
}

// ══════════════════════════════════════════════════════════════════════════════
// HomeScreen
// ══════════════════════════════════════════════════════════════════════════════
class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});
  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  final TextEditingController _searchController = TextEditingController();

  // ── Snackbar z Undo (4s) ──────────────────────────────────────────────────
  void _showUndoSnackBar(BuildContext context, String message,
      {required Future<void> Function() onUndo}) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
        content: Text(message),
        duration: const Duration(seconds: 4),
        action: SnackBarAction(
          label: 'Cofnij',
          onPressed: () async => await onUndo(),
        ),
      ));
  }

  // ── Symulacja skanera (placeholder — jutro podmieniamy na mobile_scanner) ─
  Future<String?> _simulateScan(BuildContext context) async {
    String? result;
    await showDialog(
      context: context,
      builder: (context) {
        final controller = TextEditingController();
        return AlertDialog(
          title: const Text('Skaner'),
          content: TextField(
            controller: controller,
            autofocus: true,
            decoration: const InputDecoration(hintText: 'Wpisz EAN...'),
            keyboardType: TextInputType.number,
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Anuluj')),
            ElevatedButton(
              onPressed: () { result = controller.text; Navigator.pop(context); },
              child: const Text('OK'),
            ),
          ],
        );
      },
    );
    return result;
  }

  // ── Modal dodawania produktu ───────────────────────────────────────────────
  void _showAddProductSheet(BuildContext context, WidgetRef ref, String storageId,
      {String? ean}) {
    final nameController = TextEditingController();
    final eanController  = TextEditingController(text: ean);
    final descController = TextEditingController();
    final urlController  = TextEditingController();
    final qtyController  = TextEditingController(text: '1');
    String selectedUnit  = 'szt';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
          child: DraggableScrollableSheet(
            initialChildSize: 0.85,
            maxChildSize: 0.95,
            expand: false,
            builder: (context, scrollController) => SingleChildScrollView(
              controller: scrollController,
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  // ── Podgląd obrazu ──────────────────────────────────────
                  Container(
                    height: 180, width: double.infinity,
                    margin: const EdgeInsets.only(bottom: 16),
                    decoration: BoxDecoration(
                        color: Colors.black12, borderRadius: BorderRadius.circular(12)),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: urlController.text.isNotEmpty
                          ? Image.network(urlController.text, fit: BoxFit.contain,
                              errorBuilder: (_, __, ___) => const Icon(Icons.broken_image, size: 50),
                              loadingBuilder: (ctx, child, prog) =>
                                  prog == null ? child : const Center(child: CircularProgressIndicator()))
                          : const Icon(Icons.image, size: 50, color: Colors.grey),
                    ),
                  ),
                  Text(ean != null ? 'Nowy produkt (EAN: $ean)' : 'Dodaj produkt',
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 16),
                  TextField(controller: nameController, autofocus: true,
                      decoration: const InputDecoration(labelText: 'Nazwa produktu *', border: OutlineInputBorder())),
                  const SizedBox(height: 12),
                  Row(children: [
                    Expanded(flex: 2, child: TextField(
                      controller: qtyController, keyboardType: TextInputType.number,
                      decoration: const InputDecoration(labelText: 'Ilość', border: OutlineInputBorder()),
                    )),
                    const SizedBox(width: 12),
                    Expanded(child: DropdownButtonFormField<String>(
                      value: selectedUnit,
                      decoration: const InputDecoration(labelText: 'Jedn.', border: OutlineInputBorder()),
                      items: ['szt', 'kpl', 'g', 'kg', 'm', 'cm', 'm2', 'm3']
                          .map((u) => DropdownMenuItem(value: u, child: Text(u))).toList(),
                      onChanged: (v) => setState(() => selectedUnit = v!),
                    )),
                  ]),
                  const SizedBox(height: 12),
                  Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Expanded(flex: 3, child: TextField(
                      controller: eanController,
                      decoration: const InputDecoration(labelText: 'Kod EAN', border: OutlineInputBorder()),
                    )),
                    const SizedBox(width: 12),
                    Expanded(child: SizedBox(height: 56, child: ElevatedButton(
                      onPressed: () async {
                        final scanned = await _simulateScan(context);
                        if (scanned != null) { eanController.text = scanned; setState(() {}); }
                      },
                      child: const Icon(Icons.qr_code_scanner),
                    ))),
                  ]),
                  const SizedBox(height: 12),
                  TextField(controller: urlController,
                      decoration: const InputDecoration(labelText: 'Link do zdjęcia', border: OutlineInputBorder()),
                      onChanged: (v) => setState(() {})),
                  const SizedBox(height: 12),
                  TextField(controller: descController, maxLines: 2,
                      decoration: const InputDecoration(labelText: 'Opis', border: OutlineInputBorder())),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity, height: 50,
                    child: ElevatedButton(
                      onPressed: () {
                        if (nameController.text.isNotEmpty) {
                          final newItem = ItemModel(
                            id: '', name: nameController.text,
                            ean: eanController.text.isEmpty ? null : eanController.text,
                            quantity: double.tryParse(qtyController.text) ?? 1.0,
                            unit: selectedUnit,
                            description: descController.text,
                            imageUrl: urlController.text,
                            updatedAt: DateTime.now(),
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

  // ── Quick action sheet po skanie (znaleziony produkt) ─────────────────────
  void _showScanQuickActionSheet(
      BuildContext context, WidgetRef ref, String storageId, ItemModel item) {
    // Podświetl kartę na liście
    ref.read(lastScannedItemIdProvider.notifier).update((_) => item.id);

    // ── Lokalna ilość — optymistyczny UI, nie czekamy na Firestore ──────────
    double localQty = item.quantity;
    final double qtyAtOpen = item.quantity; // do Undo przy zamknięciu

    final storages      = ref.read(userStoragesProvider).value ?? [];
    final otherStorages = storages.where((s) => s.id != storageId).toList();

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setState) {
          final isZero = localQty <= 0;

          return SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [

                  // ── Nagłówek ─────────────────────────────────────────
                  Row(children: [
                    if (item.imageUrl != null && item.imageUrl!.isNotEmpty)
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Image.network(item.imageUrl!,
                            width: 48, height: 48, fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) =>
                                const Icon(Icons.inventory_2, size: 40)),
                      )
                    else
                      const Icon(Icons.inventory_2, size: 40, color: Colors.grey),
                    const SizedBox(width: 12),
                    Expanded(child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(item.name,
                            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                            overflow: TextOverflow.ellipsis),
                        if (item.ean != null && item.ean!.isNotEmpty)
                          Text(item.ean!,
                              style: const TextStyle(fontSize: 12, color: Colors.grey)),
                      ],
                    )),
                  ]),

                  const SizedBox(height: 24),

                  // ── Kontrolka ilości (optymistyczna) ─────────────────
                  Row(mainAxisAlignment: MainAxisAlignment.center, children: [

                    // Minus
                    Material(
                      color: isZero ? Colors.red[50] : Colors.grey[100],
                      shape: const CircleBorder(),
                      child: InkWell(
                        customBorder: const CircleBorder(),
                        onTap: () {
                          if (isZero) {
                            Navigator.pop(ctx);
                            _confirmDeleteFromScan(context, ref, storageId, item);
                          } else {
                            // Natychmiastowy UI update
                            setState(() => localQty -= 1);
                            // Firestore w tle
                            ref.read(itemRepositoryProvider)
                                .updateQuantity(storageId, item.id, -1);
                          }
                        },
                        child: Padding(
                          padding: const EdgeInsets.all(14),
                          child: Icon(
                            isZero ? Icons.delete_forever : Icons.remove,
                            color: isZero ? Colors.red : Colors.black87,
                            size: 28,
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(width: 28),

                    // Wyświetlana ilość
                    Column(children: [
                      Text(
                        '${localQty % 1 == 0 ? localQty.toInt() : localQty}',
                        style: const TextStyle(fontSize: 40, fontWeight: FontWeight.bold),
                      ),
                      Text(item.unit,
                          style: const TextStyle(fontSize: 13, color: Colors.grey)),
                    ]),

                    const SizedBox(width: 28),

                    // Plus
                    Material(
                      color: Colors.blue[50],
                      shape: const CircleBorder(),
                      child: InkWell(
                        customBorder: const CircleBorder(),
                        onTap: () {
                          setState(() => localQty += 1);
                          ref.read(itemRepositoryProvider)
                              .updateQuantity(storageId, item.id, 1);
                        },
                        child: const Padding(
                          padding: EdgeInsets.all(14),
                          child: Icon(Icons.add, color: Colors.blue, size: 28),
                        ),
                      ),
                    ),
                  ]),

                  const SizedBox(height: 20),
                  const Divider(height: 1),
                  const SizedBox(height: 4),

                  // ── Usuń ─────────────────────────────────────────────
                  ListTile(
                    dense: true,
                    leading: const Icon(Icons.delete_outline, color: Colors.red),
                    title: const Text('Usuń produkt', style: TextStyle(color: Colors.red)),
                    onTap: () {
                      Navigator.pop(ctx);
                      _confirmDeleteFromScan(context, ref, storageId, item);
                    },
                  ),

                  // ── Przenieś ─────────────────────────────────────────
                  if (otherStorages.isNotEmpty) ...[
                    const Divider(height: 1),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 2),
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: Text('Przenieś do magazynu',
                            style: TextStyle(fontSize: 12, color: Colors.grey[600],
                                fontWeight: FontWeight.w600)),
                      ),
                    ),
                    ...otherStorages.map((target) => ListTile(
                      dense: true,
                      leading: const Icon(Icons.warehouse_outlined, color: Colors.blue),
                      title: Text(target.name),
                      onTap: () {
                        Navigator.pop(ctx);
                        _moveItemWithUndo(ref, context, storageId,
                            target.id, target.name, item);
                      },
                    )),
                  ],

                  const SizedBox(height: 8),

                  // ── Przycisk OK ───────────────────────────────────────
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.pop(ctx);
                        // Undo obejmuje całą zmianę ilości podczas sheeta
                        final delta = localQty - qtyAtOpen;
                        if (delta != 0) {
                          _showUndoSnackBar(
                            context,
                            '${item.name}: ${qtyAtOpen.toStringAsFixed(qtyAtOpen % 1 == 0 ? 0 : 1)} → ${localQty.toStringAsFixed(localQty % 1 == 0 ? 0 : 1)} ${item.unit}',
                            onUndo: () async => ref.read(itemRepositoryProvider)
                                .updateQuantity(storageId, item.id, -delta),
                          );
                        }
                      },
                      child: const Text('OK', style: TextStyle(fontSize: 16)),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  // ── Potwierdzenie usunięcia z kontekstu skanu ──────────────────────────────
  void _confirmDeleteFromScan(BuildContext context, WidgetRef ref,
      String storageId, ItemModel item) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Usuń produkt'),
        content: Text('Czy na pewno chcesz usunąć "${item.name}"?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Anuluj')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () {
              Navigator.pop(context);
              final snapshot = item;
              ref.read(itemRepositoryProvider).deleteItem(storageId, item.id);
              _showUndoSnackBar(context,
                '${snapshot.name} usunięty',
                onUndo: () async =>
                    ref.read(itemRepositoryProvider).upsertItem(storageId, snapshot),
              );
            },
            child: const Text('Usuń', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  // ── Przenoszenie z Undo ────────────────────────────────────────────────────
  Future<void> _moveItemWithUndo(WidgetRef ref, BuildContext context,
      String fromId, String toId, String toName, ItemModel item) async {
    final repo      = ref.read(itemRepositoryProvider);
    final snapshot  = item;
    await repo.upsertItem(toId, ItemModel(
      id: '', name: snapshot.name, ean: snapshot.ean,
      quantity: snapshot.quantity, unit: snapshot.unit,
      description: snapshot.description, imageUrl: snapshot.imageUrl,
      updatedAt: DateTime.now(),
    ));
    await repo.deleteItem(fromId, snapshot.id);

    if (!context.mounted) return;
    _showUndoSnackBar(context,
      '${snapshot.name} → $toName',
      onUndo: () async =>
          ref.read(itemRepositoryProvider).upsertItem(fromId, snapshot),
    );
  }

  // ── Główny dialog skanowania (FAB) ─────────────────────────────────────────
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
                  // Produkt znaleziony → quick action sheet + podświetlenie
                  _showScanQuickActionSheet(context, ref, storageId, existing.first);
                } else {
                  // Nie znaleziono → modal dodawania
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
    final storage    = ref.watch(currentStorageProvider);
    final user       = ref.watch(authStateProvider).value;
    final sortConfig = ref.watch(itemSortProvider);

    return Scaffold(
      appBar: AppBar(
        title: TextField(
          controller: _searchController,
          decoration: InputDecoration(
            hintText: storage != null ? 'Szukaj w: ${storage.name}' : 'iteMY',
            border: InputBorder.none,
            suffixIcon: _searchController.text.isNotEmpty
                ? IconButton(
                    icon: const Icon(Icons.clear),
                    onPressed: () {
                      _searchController.clear();
                      ref.read(itemSearchQueryProvider.notifier).update((_) => "");
                      setState(() {});
                    })
                : null,
          ),
          onChanged: (val) {
            ref.read(itemSearchQueryProvider.notifier).update((_) => val);
            setState(() {});
          },
        ),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        actions: [
          PopupMenuButton<SortOption>(
            icon: const Icon(Icons.sort),
            onSelected: (opt) => ref
                .read(itemSortProvider.notifier)
                .update((_) => sortConfig.copyWith(option: opt)),
            itemBuilder: (context) => [
              const PopupMenuItem(value: SortOption.name,     child: Text('Nazwa')),
              const PopupMenuItem(value: SortOption.ean,      child: Text('EAN')),
              const PopupMenuItem(value: SortOption.date,     child: Text('Data')),
              const PopupMenuItem(value: SortOption.quantity, child: Text('Ilość')),
            ],
          ),
          IconButton(
            icon: Icon(sortConfig.ascending ? Icons.arrow_upward : Icons.arrow_downward),
            onPressed: () => ref.read(itemSortProvider.notifier)
                .update((_) => sortConfig.copyWith(ascending: !sortConfig.ascending)),
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
                  onPressed: () => ref.read(storageRepositoryProvider)
                      .createStorage('Mój Magazyn', user!.uid),
                  child: const Text('Stwórz pierwszy magazyn'),
                ),
              ],
            ))
          : const ItemListWidget(),
      floatingActionButton: storage == null ? null : Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          FloatingActionButton(
            onPressed: () => _showAddProductSheet(context, ref, storage.id),
            heroTag: 'add',
            child: const Icon(Icons.add),
          ),
          const SizedBox(width: 12),
          FloatingActionButton.extended(
            onPressed: () => _showScanDialog(context, ref, storage.id),
            heroTag: 'scan',
            label: const Text('Skanuj'),
            icon: const Icon(Icons.qr_code_scanner),
          ),
        ],
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// StorageDrawer
// ══════════════════════════════════════════════════════════════════════════════
class StorageDrawer extends ConsumerWidget {
  const StorageDrawer({super.key});

  void _showStorageDialog(BuildContext context, WidgetRef ref,
      {StorageModel? existing}) {
    final controller = TextEditingController(text: existing?.name);
    final user = ref.read(authStateProvider).value;
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(existing == null ? 'Nowy magazyn' : 'Zmień nazwę'),
        content: TextField(controller: controller,
            decoration: const InputDecoration(labelText: 'Nazwa magazynu'),
            autofocus: true),
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

  // ── Potwierdzenie usunięcia magazynu ──────────────────────────────────────
  void _confirmDeleteStorage(BuildContext context, WidgetRef ref, StorageModel storage) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Usuń magazyn'),
        content: Text(
          'Usunięcie magazynu "${storage.name}" jest nieodwracalne.\n\n'
          'Produkty w magazynie NIE zostaną usunięte z bazy — '
          'tylko powiązanie magazynu zostanie usunięte.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Anuluj')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () {
              Navigator.pop(context);
              ref.read(storageRepositoryProvider).deleteStorage(storage.id);
            },
            child: const Text('Usuń magazyn', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final storagesAsync  = ref.watch(userStoragesProvider);
    final currentStorage = ref.watch(currentStorageProvider);

    return Drawer(
      child: Column(
        children: [
          DrawerHeader(
            decoration: BoxDecoration(color: Theme.of(context).colorScheme.primaryContainer),
            child: const Center(child: Text('Twoje Magazyny',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold))),
          ),
          Expanded(
            child: storagesAsync.when(
              data: (list) => ListView.builder(
                itemCount: list.length,
                itemBuilder: (context, index) {
                  final s          = list[index];
                  final isSelected = currentStorage?.id == s.id;
                  return ListTile(
                    leading: Icon(Icons.warehouse, color: isSelected ? Colors.blue : null),
                    title: Text(s.name,
                        style: TextStyle(fontWeight: isSelected ? FontWeight.bold : null)),
                    selected: isSelected,
                    onTap: () {
                      ref.read(activeStorageIdProvider.notifier).setStorage(s.id);
                      Navigator.pop(context);
                    },
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.edit, size: 18),
                          onPressed: () => _showStorageDialog(context, ref, existing: s),
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete_outline, size: 18, color: Colors.red),
                          // ZMIENIONO: bezpośrednie usunięcie → potwierdzenie
                          onPressed: () => _confirmDeleteStorage(context, ref, s),
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

// ══════════════════════════════════════════════════════════════════════════════
// ══════════════════════════════════════════════════════════════════════════════
// ItemListWidget — ze ScrollController i auto-scrollem do zeskanowanego elementu
// ══════════════════════════════════════════════════════════════════════════════
class ItemListWidget extends ConsumerStatefulWidget {
  const ItemListWidget({super.key});
  @override
  ConsumerState<ItemListWidget> createState() => _ItemListWidgetState();
}

class _ItemListWidgetState extends ConsumerState<ItemListWidget> {
  final ScrollController _scrollController = ScrollController();

  /// Przybliżona wysokość jednej karty (Card + marginesy).
  static const double _kItemHeight = 88.0;
  /// Padding górny listy.
  static const double _kTopPadding = 8.0;

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  /// Scrolluje do elementu o danym indeksie z animacją.
  void _scrollToIndex(int index) {
    final offset = (_kTopPadding + index * _kItemHeight)
        .clamp(0.0, _scrollController.position.maxScrollExtent);
    _scrollController.animateTo(
      offset,
      duration: const Duration(milliseconds: 450),
      curve: Curves.easeInOut,
    );
  }

  @override
  Widget build(BuildContext context) {
    final itemsAsync = ref.watch(filteredItemsProvider);

    // Słuchaj zmiany zeskanowanego ID — gdy sheet się zamknie i ID się pojawi,
    // znajdź indeks i przewiń listę.
    ref.listen<String?>(lastScannedItemIdProvider, (_, scannedId) {
      if (scannedId == null) return;
      final items = ref.read(filteredItemsProvider).value;
      if (items == null) return;
      final index = items.indexWhere((i) => i.id == scannedId);
      if (index < 0) return;

      // Krótkie opóźnienie — czekamy aż sheet zdąży się zamknąć
      Future.delayed(const Duration(milliseconds: 350), () {
        if (_scrollController.hasClients) _scrollToIndex(index);
      });
    });

    return itemsAsync.when(
      data: (items) => items.isEmpty
          ? const Center(child: Text('Pusto tutaj. Dodaj coś!'))
          : ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.only(bottom: 100, top: _kTopPadding),
              itemCount: items.length,
              itemBuilder: (context, index) => ItemCard(item: items[index]),
            ),
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, s) => Center(child: Text('Błąd: $e')),
    );
  }
}