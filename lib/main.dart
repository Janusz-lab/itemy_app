import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
// import 'package:wakelock_plus/wakelock_plus.dart'; // odkomentuj po: flutter pub add wakelock_plus
import 'core/providers/app_providers.dart';
import 'features/auth/providers/auth_provider.dart';
import 'features/inventory/providers/storage_providers.dart';
import 'features/inventory/providers/item_providers.dart';
import 'features/inventory/providers/inventory_provider.dart';
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

  void _enableWakelock()  { /* WakelockPlus.enable();  */ }
  void _disableWakelock() { /* WakelockPlus.disable(); */ }

  // ── Snackbar z Undo (4s) ──────────────────────────────────────────────────
  void _showUndoSnackBar(BuildContext context, String message,
      {required Future<void> Function() onUndo}) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
        content: Text(message),
        duration: const Duration(seconds: 4),
        action: SnackBarAction(label: 'Cofnij', onPressed: () async => onUndo()),
      ));
  }

  // ── Symulacja skanera (placeholder) ──────────────────────────────────────
  Future<String?> _simulateScan(BuildContext context) async {
    String? result;
    await showDialog(
      context: context,
      builder: (context) {
        final c = TextEditingController();
        return AlertDialog(
          title: const Text('Skaner'),
          content: TextField(controller: c, autofocus: true,
              decoration: const InputDecoration(hintText: 'Wpisz EAN...'),
              keyboardType: TextInputType.number),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Anuluj')),
            ElevatedButton(
              onPressed: () { result = c.text; Navigator.pop(context); },
              child: const Text('OK'),
            ),
          ],
        );
      },
    );
    return result;
  }

  // ══════════════════════════════════════════════════════════════════════════
  // TRYB INWENTARYZACJI
  // ══════════════════════════════════════════════════════════════════════════

  void _startInventoryMode() {
    ref.read(inventorySessionProvider.notifier).start();
    _enableWakelock();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final storage = ref.read(currentStorageProvider);
      if (storage != null && mounted) _inventoryScan(context, storage.id);
    });
  }

  void _stopInventoryMode(BuildContext context) {
    final session = ref.read(inventorySessionProvider);
    _disableWakelock();
    ref.read(inventorySessionProvider.notifier).stop();
    if (session.changes.isNotEmpty) _showInventorySummary(context, session);
  }

  Future<void> _inventoryScan(BuildContext context, String storageId) async {
    if (!ref.read(inventorySessionProvider).isActive) return;

    final ean = await _simulateScan(context);
    if (!mounted) return;
    if (ean == null || ean.isEmpty) return;

    final items    = ref.read(currentItemsProvider).value ?? [];
    final existing = items.where((i) => i.ean == ean).toList();

    if (existing.isNotEmpty) {
      await _showInventoryQuickActionSheet(context, storageId, existing.first);
    } else {
      await _showInventoryAddSheet(context, storageId, ean: ean);
    }

    if (!mounted) return;
    if (ref.read(inventorySessionProvider).isActive) {
      _inventoryScan(context, storageId);
    }
  }

  Future<void> _showInventoryQuickActionSheet(
      BuildContext context, String storageId, ItemModel item) async {
    double localQty  = item.quantity;
    double qtyAtOpen = item.quantity;

    final storages      = ref.read(userStoragesProvider).value ?? [];
    final otherStorages = storages.where((s) => s.id != storageId).toList();
    bool moveExpanded   = false;

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setState) => SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
            child: Column(mainAxisSize: MainAxisSize.min, children: [

              // ── Etykieta trybu ────────────────────────────────────
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  color: Colors.green[50],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.green.shade200),
                ),
                child: Row(children: [
                  Icon(Icons.inventory, size: 16, color: Colors.green[700]),
                  const SizedBox(width: 6),
                  Text('Tryb inwentaryzacji',
                      style: TextStyle(fontSize: 12, color: Colors.green[700],
                          fontWeight: FontWeight.w600)),
                ]),
              ),

              // ── Nagłówek produktu ─────────────────────────────────
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
                    Text(item.name, overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                    if (item.ean != null && item.ean!.isNotEmpty)
                      Text(item.ean!, style: const TextStyle(fontSize: 12, color: Colors.grey)),
                  ],
                )),
              ]),

              const SizedBox(height: 24),

              // ── Kontrolka ilości ──────────────────────────────────
              Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                Material(
                  color: localQty <= 0 ? Colors.red[50] : Colors.grey[100],
                  shape: const CircleBorder(),
                  child: InkWell(
                    customBorder: const CircleBorder(),
                    onTap: () {
                      if (localQty > 0) {
                        setState(() => localQty -= 1);
                        ref.read(itemRepositoryProvider).updateQuantity(storageId, item.id, -1);
                      }
                    },
                    child: Padding(
                      padding: const EdgeInsets.all(14),
                      child: Icon(Icons.remove,
                          color: localQty <= 0 ? Colors.red[300] : Colors.black87,
                          size: 28),
                    ),
                  ),
                ),
                const SizedBox(width: 28),
                Column(children: [
                  Text('${localQty % 1 == 0 ? localQty.toInt() : localQty}',
                      style: const TextStyle(fontSize: 40, fontWeight: FontWeight.bold)),
                  Text(item.unit, style: const TextStyle(fontSize: 13, color: Colors.grey)),
                ]),
                const SizedBox(width: 28),
                Material(
                  color: Colors.blue[50],
                  shape: const CircleBorder(),
                  child: InkWell(
                    customBorder: const CircleBorder(),
                    onTap: () {
                      setState(() => localQty += 1);
                      ref.read(itemRepositoryProvider).updateQuantity(storageId, item.id, 1);
                    },
                    child: const Padding(
                      padding: EdgeInsets.all(14),
                      child: Icon(Icons.add, color: Colors.blue, size: 28),
                    ),
                  ),
                ),
              ]),

              const SizedBox(height: 20),

              // ── Przenieś (rozwijane) ───────────────────────────────
              if (otherStorages.isNotEmpty) ...[
                const Divider(height: 1),
                ListTile(
                  dense: true,
                  leading: const Icon(Icons.warehouse_outlined, color: Colors.blue),
                  title: const Text('Przenieś do magazynu'),
                  trailing: Icon(moveExpanded ? Icons.expand_less : Icons.expand_more),
                  onTap: () => setState(() => moveExpanded = !moveExpanded),
                ),
                if (moveExpanded)
                  ...otherStorages.map((target) => ListTile(
                    dense: true,
                    contentPadding: const EdgeInsets.only(left: 32, right: 16),
                    leading: const Icon(Icons.subdirectory_arrow_right, size: 18, color: Colors.blue),
                    title: Text(target.name),
                    onTap: () async {
                      Navigator.pop(ctx);
                      await _moveItemWithUndo(ref, context, storageId, target.id, target.name, item);
                      ref.read(inventorySessionProvider.notifier).recordChange(InventoryChange(
                        itemName: item.name, quantityBefore: qtyAtOpen,
                        quantityAfter: localQty, unit: item.unit,
                      ));
                    },
                  )),
              ],

              const SizedBox(height: 12),

              // ── OK / Pomiń ────────────────────────────────────────
              Row(children: [
                Expanded(child: OutlinedButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Pomiń'),
                )),
                const SizedBox(width: 12),
                Expanded(flex: 2, child: ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.green[700]),
                  onPressed: () {
                    Navigator.pop(ctx);
                    final delta = localQty - qtyAtOpen;
                    if (delta != 0) {
                      ref.read(inventorySessionProvider.notifier).recordChange(InventoryChange(
                        itemName: item.name, quantityBefore: qtyAtOpen,
                        quantityAfter: localQty, unit: item.unit,
                      ));
                      _showUndoSnackBar(context,
                        '${item.name}: ${qtyAtOpen.toStringAsFixed(qtyAtOpen % 1 == 0 ? 0 : 1)} → ${localQty.toStringAsFixed(localQty % 1 == 0 ? 0 : 1)} ${item.unit}',
                        onUndo: () async => ref.read(itemRepositoryProvider)
                            .updateQuantity(storageId, item.id, -delta),
                      );
                    }
                  },
                  child: const Text('OK → Następny',
                      style: TextStyle(color: Colors.white, fontSize: 15)),
                )),
              ]),
            ]),
          ),
        ),
      ),
    ).whenComplete(() {
      ref.read(lastScannedItemIdProvider.notifier).update((_) => null);
      Future.delayed(Duration.zero, () =>
          ref.read(lastScannedItemIdProvider.notifier).update((_) => item.id));
    });
  }

  Future<void> _showInventoryAddSheet(BuildContext context, String storageId,
      {String? ean}) async {
    final nameController = TextEditingController();
    final eanController  = TextEditingController(text: ean);
    final descController = TextEditingController();
    final urlController  = TextEditingController();
    final qtyController  = TextEditingController(text: '1');
    String selectedUnit  = 'szt';

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
          child: DraggableScrollableSheet(
            initialChildSize: 0.85, maxChildSize: 0.95, expand: false,
            builder: (context, sc) => SingleChildScrollView(
              controller: sc,
              padding: const EdgeInsets.all(20),
              child: Column(children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  margin: const EdgeInsets.only(bottom: 12),
                  decoration: BoxDecoration(
                    color: Colors.orange[50], borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.orange.shade200),
                  ),
                  child: Row(children: [
                    Icon(Icons.add_circle_outline, size: 16, color: Colors.orange[700]),
                    const SizedBox(width: 6),
                    Text('Nowy produkt — nie znaleziono EAN',
                        style: TextStyle(fontSize: 12, color: Colors.orange[700],
                            fontWeight: FontWeight.w600)),
                  ]),
                ),
                const Text('Dodaj produkt',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
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
                TextField(controller: eanController,
                    decoration: const InputDecoration(labelText: 'Kod EAN', border: OutlineInputBorder())),
                const SizedBox(height: 12),
                TextField(controller: urlController,
                    decoration: const InputDecoration(labelText: 'Link do zdjęcia', border: OutlineInputBorder()),
                    onChanged: (v) => setState(() {})),
                const SizedBox(height: 12),
                TextField(controller: descController, maxLines: 2,
                    decoration: const InputDecoration(labelText: 'Opis', border: OutlineInputBorder())),
                const SizedBox(height: 20),
                Row(children: [
                  Expanded(child: OutlinedButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Pomiń'),
                  )),
                  const SizedBox(width: 12),
                  Expanded(flex: 2, child: ElevatedButton(
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.green[700]),
                    onPressed: () {
                      if (nameController.text.isNotEmpty) {
                        final qty = double.tryParse(qtyController.text) ?? 1.0;
                        final newItem = ItemModel(
                          id: '', name: nameController.text,
                          ean: eanController.text.isEmpty ? null : eanController.text,
                          quantity: qty, unit: selectedUnit,
                          description: descController.text,
                          imageUrl: urlController.text,
                          updatedAt: DateTime.now(),
                        );
                        ref.read(itemRepositoryProvider).upsertItem(storageId, newItem);
                        ref.read(inventorySessionProvider.notifier).recordChange(InventoryChange(
                          itemName: nameController.text, quantityBefore: 0,
                          quantityAfter: qty, unit: selectedUnit, isNew: true,
                        ));
                        Navigator.pop(context);
                      }
                    },
                    child: const Text('Zapisz → Następny',
                        style: TextStyle(color: Colors.white, fontSize: 15)),
                  )),
                ]),
              ]),
            ),
          ),
        ),
      ),
    );
  }

  void _showInventorySummary(BuildContext context, InventorySession session) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(children: [
          Icon(Icons.inventory, color: Colors.green),
          SizedBox(width: 8),
          Text('Podsumowanie inwentaryzacji'),
        ]),
        content: SizedBox(
          width: double.maxFinite,
          child: Column(mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              _statChip('${session.scannedCount}', 'zeskanowane', Colors.blue),
              const SizedBox(width: 8),
              _statChip('${session.addedCount}', 'dodane', Colors.green),
            ]),
            if (session.changes.isNotEmpty) ...[
              const SizedBox(height: 16),
              Text('Zmiany (${session.changes.length}):',
                  style: const TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 280),
                child: ListView.separated(
                  shrinkWrap: true,
                  itemCount: session.changes.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (context, i) {
                    final c = session.changes[i];
                    return ListTile(
                      dense: true,
                      leading: Icon(
                        c.isNew ? Icons.add_circle_outline : Icons.swap_horiz,
                        color: c.isNew ? Colors.green : Colors.blue, size: 20,
                      ),
                      title: Text(c.summary, style: const TextStyle(fontSize: 13)),
                    );
                  },
                ),
              ),
            ],
          ]),
        ),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Zamknij'),
          ),
        ],
      ),
    );
  }

  Widget _statChip(String value, String label, Color color) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
    decoration: BoxDecoration(
      color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(8),
      border: Border.all(color: color.withOpacity(0.3)),
    ),
    child: Column(children: [
      Text(value, style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: color)),
      Text(label, style: TextStyle(fontSize: 11, color: color)),
    ]),
  );

  // ══════════════════════════════════════════════════════════════════════════
  // NORMALNY TRYB — scan / add / move / delete
  // ══════════════════════════════════════════════════════════════════════════

  void _showAddProductSheet(BuildContext context, WidgetRef ref,
      String storageId, {String? ean}) {
    final nameController = TextEditingController();
    final eanController  = TextEditingController(text: ean);
    final descController = TextEditingController();
    final urlController  = TextEditingController();
    final qtyController  = TextEditingController(text: '1');
    String selectedUnit  = 'szt';

    showModalBottomSheet(
      context: context, isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
          child: DraggableScrollableSheet(
            initialChildSize: 0.85, maxChildSize: 0.95, expand: false,
            builder: (context, sc) => SingleChildScrollView(
              controller: sc, padding: const EdgeInsets.all(20),
              child: Column(children: [
                Container(
                  height: 180, width: double.infinity,
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(color: Colors.black12, borderRadius: BorderRadius.circular(12)),
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
                  Expanded(flex: 3, child: TextField(controller: eanController,
                      decoration: const InputDecoration(labelText: 'Kod EAN', border: OutlineInputBorder()))),
                  const SizedBox(width: 12),
                  Expanded(child: SizedBox(height: 56, child: ElevatedButton(
                    onPressed: () async {
                      final s = await _simulateScan(context);
                      if (s != null) { eanController.text = s; setState(() {}); }
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
                SizedBox(width: double.infinity, height: 50,
                  child: ElevatedButton(
                    onPressed: () {
                      if (nameController.text.isNotEmpty) {
                        ref.read(itemRepositoryProvider).upsertItem(storageId, ItemModel(
                          id: '', name: nameController.text,
                          ean: eanController.text.isEmpty ? null : eanController.text,
                          quantity: double.tryParse(qtyController.text) ?? 1.0,
                          unit: selectedUnit, description: descController.text,
                          imageUrl: urlController.text, updatedAt: DateTime.now(),
                        ));
                        Navigator.pop(context);
                      }
                    },
                    child: const Text('Zapisz produkt'),
                  ),
                ),
              ]),
            ),
          ),
        ),
      ),
    );
  }

  void _showScanQuickActionSheet(BuildContext context, WidgetRef ref,
      String storageId, ItemModel item) {
    double localQty  = item.quantity;
    double qtyAtOpen = item.quantity;
    final storages      = ref.read(userStoragesProvider).value ?? [];
    final otherStorages = storages.where((s) => s.id != storageId).toList();

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setState) => SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Row(children: [
                if (item.imageUrl != null && item.imageUrl!.isNotEmpty)
                  ClipRRect(borderRadius: BorderRadius.circular(8),
                    child: Image.network(item.imageUrl!, width: 48, height: 48, fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => const Icon(Icons.inventory_2, size: 40)))
                else
                  const Icon(Icons.inventory_2, size: 40, color: Colors.grey),
                const SizedBox(width: 12),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(item.name, overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  if (item.ean != null && item.ean!.isNotEmpty)
                    Text(item.ean!, style: const TextStyle(fontSize: 12, color: Colors.grey)),
                ])),
              ]),
              const SizedBox(height: 24),
              Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                Material(
                  color: localQty <= 0 ? Colors.red[50] : Colors.grey[100],
                  shape: const CircleBorder(),
                  child: InkWell(
                    customBorder: const CircleBorder(),
                    onTap: () {
                      if (localQty <= 0) {
                        Navigator.pop(ctx);
                        _confirmDeleteFromScan(context, ref, storageId, item);
                      } else {
                        setState(() => localQty -= 1);
                        ref.read(itemRepositoryProvider).updateQuantity(storageId, item.id, -1);
                      }
                    },
                    child: Padding(padding: const EdgeInsets.all(14),
                      child: Icon(localQty <= 0 ? Icons.delete_forever : Icons.remove,
                          color: localQty <= 0 ? Colors.red : Colors.black87, size: 28)),
                  ),
                ),
                const SizedBox(width: 28),
                Column(children: [
                  Text('${localQty % 1 == 0 ? localQty.toInt() : localQty}',
                      style: const TextStyle(fontSize: 40, fontWeight: FontWeight.bold)),
                  Text(item.unit, style: const TextStyle(fontSize: 13, color: Colors.grey)),
                ]),
                const SizedBox(width: 28),
                Material(
                  color: Colors.blue[50], shape: const CircleBorder(),
                  child: InkWell(
                    customBorder: const CircleBorder(),
                    onTap: () {
                      setState(() => localQty += 1);
                      ref.read(itemRepositoryProvider).updateQuantity(storageId, item.id, 1);
                    },
                    child: const Padding(padding: EdgeInsets.all(14),
                      child: Icon(Icons.add, color: Colors.blue, size: 28)),
                  ),
                ),
              ]),
              const SizedBox(height: 20),
              const Divider(height: 1),
              ListTile(
                dense: true,
                leading: const Icon(Icons.delete_outline, color: Colors.red),
                title: const Text('Usuń produkt', style: TextStyle(color: Colors.red)),
                onTap: () { Navigator.pop(ctx); _confirmDeleteFromScan(context, ref, storageId, item); },
              ),
              if (otherStorages.isNotEmpty) ...[
                const Divider(height: 1),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 2),
                  child: Align(alignment: Alignment.centerLeft,
                    child: Text('Przenieś do magazynu',
                        style: TextStyle(fontSize: 12, color: Colors.grey[600], fontWeight: FontWeight.w600))),
                ),
                ...otherStorages.map((target) => ListTile(
                  dense: true,
                  leading: const Icon(Icons.warehouse_outlined, color: Colors.blue),
                  title: Text(target.name),
                  onTap: () {
                    Navigator.pop(ctx);
                    _moveItemWithUndo(ref, context, storageId, target.id, target.name, item);
                  },
                )),
              ],
              const SizedBox(height: 8),
              SizedBox(width: double.infinity, height: 48,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.pop(ctx);
                    final delta = localQty - qtyAtOpen;
                    if (delta != 0) {
                      _showUndoSnackBar(context,
                        '${item.name}: ${qtyAtOpen.toStringAsFixed(qtyAtOpen % 1 == 0 ? 0 : 1)} → ${localQty.toStringAsFixed(localQty % 1 == 0 ? 0 : 1)} ${item.unit}',
                        onUndo: () async => ref.read(itemRepositoryProvider)
                            .updateQuantity(storageId, item.id, -delta),
                      );
                    }
                  },
                  child: const Text('OK', style: TextStyle(fontSize: 16)),
                ),
              ),
            ]),
          ),
        ),
      ),
    ).whenComplete(() {
      ref.read(lastScannedItemIdProvider.notifier).update((_) => null);
      Future.delayed(Duration.zero, () =>
          ref.read(lastScannedItemIdProvider.notifier).update((_) => item.id));
    });
  }

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
              ref.read(itemRepositoryProvider).deleteItem(storageId, item.id);
              _showUndoSnackBar(context, '${item.name} usunięty',
                  onUndo: () async =>
                      ref.read(itemRepositoryProvider).upsertItem(storageId, item));
            },
            child: const Text('Usuń', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Future<void> _moveItemWithUndo(WidgetRef ref, BuildContext context,
      String fromId, String toId, String toName, ItemModel item) async {
    final repo  = ref.read(itemRepositoryProvider);
    final newId = await repo.upsertItem(toId, ItemModel(
      id: '', name: item.name, ean: item.ean, quantity: item.quantity,
      unit: item.unit, description: item.description,
      imageUrl: item.imageUrl, updatedAt: DateTime.now(),
    ));
    await repo.deleteItem(fromId, item.id);
    if (!context.mounted) return;
    _showUndoSnackBar(context, '${item.name} → $toName',
        onUndo: () async {
          await repo.deleteItem(toId, newId);
          await repo.upsertItem(fromId, item);
        });
  }

  void _showScanDialog(BuildContext context, WidgetRef ref, String storageId) {
    final eanController = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Skanowanie kodu EAN'),
        content: TextField(controller: eanController, keyboardType: TextInputType.number,
            autofocus: true,
            decoration: const InputDecoration(hintText: 'Wpisz lub wklej kod')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Anuluj')),
          ElevatedButton(
            onPressed: () {
              final ean = eanController.text.trim();
              if (ean.isNotEmpty) {
                Navigator.pop(context);
                final items    = ref.read(currentItemsProvider).value ?? [];
                final existing = items.where((i) => i.ean == ean).toList();
                if (existing.isNotEmpty) {
                  _showScanQuickActionSheet(context, ref, storageId, existing.first);
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

  // ── Build ──────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final storage       = ref.watch(currentStorageProvider);
    final user          = ref.watch(authStateProvider).value;
    final sortConfig    = ref.watch(itemSortProvider);
    final invSession    = ref.watch(inventorySessionProvider);
    final inventoryMode = invSession.isActive;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: inventoryMode
            ? Colors.green[700]
            : Theme.of(context).colorScheme.inversePrimary,
        title: inventoryMode
            ? Row(children: [
                const Icon(Icons.inventory, color: Colors.white, size: 20),
                const SizedBox(width: 8),
                const Text('Inwentaryzacja', style: TextStyle(color: Colors.white)),
                const SizedBox(width: 12),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                      color: Colors.white24, borderRadius: BorderRadius.circular(12)),
                  child: Text('${invSession.scannedCount + invSession.addedCount}',
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                ),
              ])
            : TextField(
                controller: _searchController,
                decoration: InputDecoration(
                  hintText: storage != null ? 'Szukaj w: ${storage.name}' : 'iteMY',
                  border: InputBorder.none,
                  suffixIcon: _searchController.text.isNotEmpty
                      ? IconButton(icon: const Icon(Icons.clear), onPressed: () {
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
        actions: inventoryMode
            ? [TextButton.icon(
                onPressed: () => _stopInventoryMode(context),
                icon: const Icon(Icons.stop_circle_outlined, color: Colors.white),
                label: const Text('Zakończ', style: TextStyle(color: Colors.white)),
              )]
            : [
                PopupMenuButton<SortOption>(
                  icon: const Icon(Icons.sort),
                  onSelected: (opt) => ref.read(itemSortProvider.notifier)
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
      drawer: inventoryMode ? null : const StorageDrawer(),
      body: storage == null
          ? Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
              const Text('Nie wybrano magazynu.'),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: () => ref.read(storageRepositoryProvider)
                    .createStorage('Mój Magazyn', user!.uid),
                child: const Text('Stwórz pierwszy magazyn'),
              ),
            ]))
          : const ItemListWidget(),

      floatingActionButton: storage == null ? null : inventoryMode
          // ── Pasek inwentaryzacji ────────────────────────────────────────
          ? Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                        color: Colors.green[700], borderRadius: BorderRadius.circular(24)),
                    child: Row(children: [
                      const Icon(Icons.check_circle_outline, color: Colors.white, size: 18),
                      const SizedBox(width: 6),
                      Text('${invSession.scannedCount} skan  •  ${invSession.addedCount} nowe',
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
                    ]),
                  ),
                  FloatingActionButton.extended(
                    onPressed: () => _inventoryScan(context, storage.id),
                    heroTag: 'inv_scan',
                    backgroundColor: Colors.green[700],
                    icon: const Icon(Icons.qr_code_scanner, color: Colors.white),
                    label: const Text('Skanuj', style: TextStyle(color: Colors.white)),
                  ),
                ],
              ),
            )
          // ── Normalny FAB ──────────────────────────────────────────────────
          : Row(mainAxisAlignment: MainAxisAlignment.end, children: [
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
              const SizedBox(width: 12),
              FloatingActionButton.extended(
                onPressed: _startInventoryMode,
                heroTag: 'inventory',
                backgroundColor: Colors.green[700],
                icon: const Icon(Icons.inventory, color: Colors.white),
                label: const Text('Inwentaryzacja', style: TextStyle(color: Colors.white)),
              ),
            ]),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// StorageDrawer
// ══════════════════════════════════════════════════════════════════════════════
class StorageDrawer extends ConsumerWidget {
  const StorageDrawer({super.key});

  void _showStorageDialog(BuildContext context, WidgetRef ref, {StorageModel? existing}) {
    final controller = TextEditingController(text: existing?.name);
    final user       = ref.read(authStateProvider).value;
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(existing == null ? 'Nowy magazyn' : 'Zmień nazwę'),
        content: TextField(controller: controller,
            decoration: const InputDecoration(labelText: 'Nazwa magazynu'), autofocus: true),
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

  void _confirmDeleteStorage(BuildContext context, WidgetRef ref, StorageModel storage) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Usuń magazyn'),
        content: Text('Usunięcie magazynu "${storage.name}" jest nieodwracalne.\n\n'
            'Produkty w magazynie NIE zostaną usunięte z bazy — '
            'tylko powiązanie magazynu zostanie usunięte.'),
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
      child: Column(children: [
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
                final s = list[index];
                final isSelected = currentStorage?.id == s.id;
                return ListTile(
                  leading: Icon(Icons.warehouse, color: isSelected ? Colors.blue : null),
                  title: Text(s.name, style: TextStyle(fontWeight: isSelected ? FontWeight.bold : null)),
                  selected: isSelected,
                  onTap: () {
                    ref.read(activeStorageIdProvider.notifier).setStorage(s.id);
                    Navigator.pop(context);
                  },
                  trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                    IconButton(icon: const Icon(Icons.edit, size: 18),
                        onPressed: () => _showStorageDialog(context, ref, existing: s)),
                    IconButton(icon: const Icon(Icons.delete_outline, size: 18, color: Colors.red),
                        onPressed: () => _confirmDeleteStorage(context, ref, s)),
                  ]),
                );
              },
            ),
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Center(child: Text('Błąd: $e')),
          ),
        ),
        const Divider(),
        ListTile(leading: const Icon(Icons.add), title: const Text('Dodaj nowy magazyn'),
            onTap: () => _showStorageDialog(context, ref)),
        const SizedBox(height: 20),
      ]),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// ItemListWidget
// ══════════════════════════════════════════════════════════════════════════════
class ItemListWidget extends ConsumerStatefulWidget {
  const ItemListWidget({super.key});
  @override
  ConsumerState<ItemListWidget> createState() => _ItemListWidgetState();
}

class _ItemListWidgetState extends ConsumerState<ItemListWidget> {
  final ScrollController _scrollController = ScrollController();
  static const double _kItemHeight = 88.0;
  static const double _kTopPadding = 8.0;

  @override
  void dispose() { _scrollController.dispose(); super.dispose(); }

  void _scrollToIndex(int index) {
    final offset = (_kTopPadding + index * _kItemHeight)
        .clamp(0.0, _scrollController.position.maxScrollExtent);
    _scrollController.animateTo(offset,
        duration: const Duration(milliseconds: 450), curve: Curves.easeInOut);
  }

  @override
  Widget build(BuildContext context) {
    final itemsAsync = ref.watch(filteredItemsProvider);

    ref.listen<String?>(lastScannedItemIdProvider, (_, scannedId) {
      if (scannedId == null) return;
      final items = ref.read(filteredItemsProvider).value;
      if (items == null) return;
      final index = items.indexWhere((i) => i.id == scannedId);
      if (index < 0) return;
      Future.delayed(const Duration(milliseconds: 100), () {
        if (_scrollController.hasClients) _scrollToIndex(index);
      });
    });

    return itemsAsync.when(
      data: (items) => items.isEmpty
          ? const Center(child: Text('Pusto tutaj. Dodaj coś!'))
          : ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.only(bottom: 120, top: _kTopPadding),
              itemCount: items.length,
              itemBuilder: (context, index) => ItemCard(item: items[index]),
            ),
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, s) => Center(child: Text('Błąd: $e')),
    );
  }
}