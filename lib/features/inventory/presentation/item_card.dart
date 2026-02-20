import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/item_model.dart';
import '../data/item_repository.dart';
import '../providers/storage_providers.dart';
import '../providers/item_providers.dart';

class ItemCard extends ConsumerStatefulWidget {
  final ItemModel item;
  const ItemCard({super.key, required this.item});

  @override
  ConsumerState<ItemCard> createState() => _ItemCardState();
}

class _ItemCardState extends ConsumerState<ItemCard>
    with SingleTickerProviderStateMixin {
  Timer? _highlightTimer;
  bool _highlighted = false;
  bool _highlightScheduled = false; // blokuje rejestrację wielu callbacków

  @override
  void dispose() {
    _highlightTimer?.cancel();
    super.dispose();
  }

  /// Podświetla kartę przez [seconds] sekund po zeskanowaniu.
  void _startHighlight(int seconds) {
    _highlightTimer?.cancel();
    setState(() => _highlighted = true);
    _highlightTimer = Timer(Duration(seconds: seconds), () {
      if (mounted) setState(() => _highlighted = false);
      // Provider czyści whenComplete w main.dart — nie ruszamy go tutaj
    });
  }

  // ── Symulacja skanera (placeholder — zastąpiony mobile_scanner w Etapie 2) ─
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
            decoration: const InputDecoration(hintText: 'Zeskanowano...'),
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

  // ── Modal pełnej edycji ────────────────────────────────────────────────────
  void _showEditSheet(BuildContext context, WidgetRef ref, String storageId) {
    final nameController = TextEditingController(text: widget.item.name);
    final eanController  = TextEditingController(text: widget.item.ean);
    final qtyController  = TextEditingController(text: widget.item.quantity.toString());
    final descController = TextEditingController(text: widget.item.description);
    final urlController  = TextEditingController(text: widget.item.imageUrl);
    String selectedUnit  = widget.item.unit;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // ── Podgląd obrazu ──────────────────────────────────────
                  Container(
                    height: 180,
                    width: double.infinity,
                    margin: const EdgeInsets.only(bottom: 16),
                    decoration: BoxDecoration(
                        color: Colors.black12,
                        borderRadius: BorderRadius.circular(12)),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: urlController.text.isNotEmpty
                          ? Image.network(
                              urlController.text,
                              fit: BoxFit.contain,
                              errorBuilder: (_, __, ___) =>
                                  const Icon(Icons.broken_image, size: 50),
                              loadingBuilder: (context, child, loadingProgress) {
                                if (loadingProgress == null) return child;
                                return const Center(child: CircularProgressIndicator());
                              },
                            )
                          : const Icon(Icons.image, size: 50, color: Colors.grey),
                    ),
                  ),
                  const Text('Edytuj produkt',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 16),
                  TextField(controller: nameController,
                      decoration: const InputDecoration(labelText: 'Nazwa', border: OutlineInputBorder())),
                  const SizedBox(height: 12),
                  Row(children: [
                    Expanded(flex: 2, child: TextField(
                      controller: qtyController,
                      keyboardType: TextInputType.number,
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
                      decoration: const InputDecoration(labelText: 'EAN', border: OutlineInputBorder()),
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
                  Row(children: [
                    Expanded(child: OutlinedButton.icon(
                      onPressed: () => _confirmDelete(context, ref, storageId, thenPop: true),
                      style: OutlinedButton.styleFrom(foregroundColor: Colors.red),
                      icon: const Icon(Icons.delete),
                      label: const Text('Usuń'),
                    )),
                    const SizedBox(width: 12),
                    Expanded(child: ElevatedButton(
                      onPressed: () {
                        final updated = ItemModel(
                          id: widget.item.id,
                          name: nameController.text,
                          ean: eanController.text,
                          quantity: double.tryParse(qtyController.text) ?? widget.item.quantity,
                          unit: selectedUnit,
                          description: descController.text,
                          imageUrl: urlController.text,
                          updatedAt: DateTime.now(),
                        );
                        ref.read(itemRepositoryProvider).upsertItem(storageId, updated);
                        Navigator.pop(context);
                      },
                      child: const Text('Zapisz'),
                    )),
                  ]),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ── Menu kontekstowe po przytrzymaniu ──────────────────────────────────────
  void _showContextMenu(BuildContext context, WidgetRef ref, String storageId) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) {
        final storages = ref.read(userStoragesProvider).value ?? [];
        final otherStorages = storages.where((s) => s.id != storageId).toList();
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 4),
                  child: Row(children: [
                    const Icon(Icons.inventory_2_outlined, size: 18, color: Colors.grey),
                    const SizedBox(width: 8),
                    Expanded(child: Text(widget.item.name,
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                        overflow: TextOverflow.ellipsis)),
                  ]),
                ),
                const Divider(),
                ListTile(
                  leading: const Icon(Icons.delete_outline, color: Colors.red),
                  title: const Text('Usuń produkt', style: TextStyle(color: Colors.red)),
                  onTap: () {
                    Navigator.pop(context);
                    _confirmDelete(context, ref, storageId);
                  },
                ),
                if (otherStorages.isNotEmpty) ...[
                  const Divider(height: 1),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 10, 16, 2),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Text('Przenieś do magazynu',
                          style: TextStyle(fontSize: 12, color: Colors.grey[600],
                              fontWeight: FontWeight.w600)),
                    ),
                  ),
                  ...otherStorages.map((target) => ListTile(
                    leading: const Icon(Icons.warehouse_outlined, color: Colors.blue),
                    title: Text(target.name),
                    onTap: () {
                      Navigator.pop(context);
                      _moveItem(ref, storageId, target.id, target.name, context);
                    },
                  )),
                ] else ...[
                  const Divider(height: 1),
                  const Padding(
                    padding: EdgeInsets.all(16),
                    child: Text('Brak innych magazynów do przeniesienia.',
                        style: TextStyle(color: Colors.grey, fontSize: 13)),
                  ),
                ],
                const SizedBox(height: 4),
              ],
            ),
          ),
        );
      },
    );
  }

  // ── Potwierdzenie usunięcia ────────────────────────────────────────────────
  void _confirmDelete(BuildContext context, WidgetRef ref, String storageId,
      {bool thenPop = false}) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Usuń produkt'),
        content: Text('Czy na pewno chcesz usunąć "${widget.item.name}"?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Anuluj')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () {
              Navigator.pop(context);
              if (thenPop) Navigator.pop(context);

              // Zapamiętaj stan przed usunięciem (do Undo)
              final deletedItem = widget.item;
              ref.read(itemRepositoryProvider).deleteItem(storageId, widget.item.id);

              _showUndoSnackBar(
                context,
                '${deletedItem.name} usunięty',
                onUndo: () async {
                  // Przywróć produkt z oryginalnym ID
                  await ref.read(itemRepositoryProvider).upsertItem(storageId, deletedItem);
                },
              );
            },
            child: const Text('Usuń', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  // ── Przenoszenie produktu z Undo ──────────────────────────────────────────
  Future<void> _moveItem(WidgetRef ref, String fromId, String toId,
      String toName, BuildContext context) async {
    final repo     = ref.read(itemRepositoryProvider);
    final snapshot = widget.item;

    // upsertItem zwraca ID nowego dokumentu w magazynie docelowym
    final newId = await repo.upsertItem(toId, ItemModel(
      id: '',
      name: snapshot.name,
      ean: snapshot.ean,
      quantity: snapshot.quantity,
      unit: snapshot.unit,
      description: snapshot.description,
      imageUrl: snapshot.imageUrl,
      updatedAt: DateTime.now(),
    ));
    await repo.deleteItem(fromId, snapshot.id);

    if (!context.mounted) return;
    _showUndoSnackBar(
      context,
      '${snapshot.name} → $toName',
      onUndo: () async {
        // Usuń z docelowego (znamy ID) i przywróć w źródłowym
        await repo.deleteItem(toId, newId);
        await repo.upsertItem(fromId, snapshot);
      },
    );
  }

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
          onPressed: () async {
            await onUndo();
          },
        ),
      ));
  }

  // ── Build ──────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final storageId = ref.watch(currentStorageProvider)?.id;

    // ref.watch zamiast ref.listen — watch zawsze odzwierciedla aktualny stan,
    // nie może przegapić zmiany podczas rebuilda.
    // addPostFrameCallback żeby nie wywoływać setState podczas budowania drzewa.
    final scannedId = ref.watch(lastScannedItemIdProvider);
    if (scannedId == widget.item.id && !_highlightScheduled) {
      _highlightScheduled = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _startHighlight(10);
          ref.read(lastScannedItemIdProvider.notifier).update((_) => null);
        }
        _highlightScheduled = false;
      });
    }

    return AnimatedContainer(
      duration: const Duration(milliseconds: 400),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        color: _highlighted
            ? Colors.amber.withOpacity(0.18)
            : Colors.transparent,
        border: _highlighted
            ? Border.all(color: Colors.amber.shade400, width: 2)
            : Border.all(color: Colors.transparent, width: 2),
      ),
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: Card(
        margin: EdgeInsets.zero,
        elevation: _highlighted ? 3 : 0.5,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        child: ListTile(
          onTap: () => storageId != null
              ? _showEditSheet(context, ref, storageId)
              : null,
          onLongPress: () => storageId != null
              ? _showContextMenu(context, ref, storageId)
              : null,
          leading: ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Container(
              width: 50, height: 50, color: Colors.grey[100],
              child: widget.item.imageUrl != null && widget.item.imageUrl!.isNotEmpty
                  ? Image.network(widget.item.imageUrl!,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => const Icon(Icons.inventory_2))
                  : const Icon(Icons.inventory_2, color: Colors.grey),
            ),
          ),
          title: Text(widget.item.name,
              style: const TextStyle(fontWeight: FontWeight.bold)),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (widget.item.ean != null && widget.item.ean!.isNotEmpty)
                Text(widget.item.ean!,
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
              if (widget.item.description != null && widget.item.description!.isNotEmpty)
                Text(widget.item.description!,
                    style: const TextStyle(fontSize: 11, color: Colors.grey),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis),
            ],
          ),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Przycisk minus — jeśli qty <= 0 pyta o usunięcie
              IconButton(
                icon: widget.item.quantity <= 0
                    ? const Icon(Icons.delete_forever, color: Colors.red)
                    : const Icon(Icons.remove_circle_outline),
                onPressed: storageId == null ? null : () {
                  if (widget.item.quantity <= 0) {
                    _confirmDelete(context, ref, storageId);
                  } else {
                    final oldQty = widget.item.quantity;
                    ref.read(itemRepositoryProvider)
                        .updateQuantity(storageId, widget.item.id, -1);
                    _showUndoSnackBar(
                      context,
                      '${widget.item.name}: ${oldQty.toStringAsFixed(oldQty % 1 == 0 ? 0 : 1)} → ${(oldQty - 1).toStringAsFixed((oldQty - 1) % 1 == 0 ? 0 : 1)} ${widget.item.unit}',
                      onUndo: () async {
                        await ref.read(itemRepositoryProvider)
                            .updateQuantity(storageId, widget.item.id, 1);
                      },
                    );
                  }
                },
              ),
              Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    '${widget.item.quantity % 1 == 0 ? widget.item.quantity.toInt() : widget.item.quantity}',
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  Text(widget.item.unit,
                      style: const TextStyle(fontSize: 10, color: Colors.grey)),
                ],
              ),
              // Przycisk plus z Undo
              IconButton(
                icon: const Icon(Icons.add_circle_outline, color: Colors.blue),
                onPressed: storageId == null ? null : () {
                  final oldQty = widget.item.quantity;
                  ref.read(itemRepositoryProvider)
                      .updateQuantity(storageId, widget.item.id, 1);
                  _showUndoSnackBar(
                    context,
                    '${widget.item.name}: ${oldQty.toStringAsFixed(oldQty % 1 == 0 ? 0 : 1)} → ${(oldQty + 1).toStringAsFixed((oldQty + 1) % 1 == 0 ? 0 : 1)} ${widget.item.unit}',
                    onUndo: () async {
                      await ref.read(itemRepositoryProvider)
                          .updateQuantity(storageId, widget.item.id, -1);
                    },
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}