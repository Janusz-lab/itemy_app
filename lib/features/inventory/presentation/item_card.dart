import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/item_model.dart';
import '../data/item_repository.dart';
import '../providers/storage_providers.dart';

class ItemCard extends ConsumerWidget {
  final ItemModel item;
  const ItemCard({super.key, required this.item});

  void _showEditSheet(BuildContext context, WidgetRef ref, String storageId) {
    final nameController = TextEditingController(text: item.name);
    final eanController = TextEditingController(text: item.ean);
    final qtyController = TextEditingController(text: item.quantity.toString());
    final descController = TextEditingController(text: item.description);
    final urlController = TextEditingController(text: item.imageUrl);
    String selectedUnit = item.unit;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('Edytuj produkt', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 16),
                TextField(controller: nameController, decoration: const InputDecoration(labelText: 'Nazwa', border: OutlineInputBorder())),
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
                TextField(controller: eanController, decoration: const InputDecoration(labelText: 'EAN', border: OutlineInputBorder())),
                const SizedBox(height: 12),
                TextField(controller: urlController, decoration: const InputDecoration(labelText: 'Link do zdjęcia', border: OutlineInputBorder())),
                const SizedBox(height: 12),
                TextField(controller: descController, maxLines: 2, decoration: const InputDecoration(labelText: 'Opis', border: OutlineInputBorder())),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () {
                          ref.read(itemRepositoryProvider).deleteItem(storageId, item.id);
                          Navigator.pop(context);
                        },
                        style: OutlinedButton.styleFrom(foregroundColor: Colors.red),
                        icon: const Icon(Icons.delete),
                        label: const Text('Usuń'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () {
                          final updated = ItemModel(
                            id: item.id,
                            name: nameController.text,
                            ean: eanController.text,
                            quantity: double.tryParse(qtyController.text) ?? item.quantity,
                            unit: selectedUnit,
                            description: descController.text,
                            imageUrl: urlController.text,
                            updatedAt: DateTime.now(),
                          );
                          ref.read(itemRepositoryProvider).upsertItem(storageId, updated);
                          Navigator.pop(context);
                        },
                        child: const Text('Zapisz'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final storageId = ref.watch(currentStorageProvider)?.id;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      elevation: 0.5,
      child: ListTile(
        onTap: () => storageId != null ? _showEditSheet(context, ref, storageId) : null,
        // ZDJĘCIE Z LEWEJ
        leading: ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: Container(
            width: 50, height: 50, color: Colors.grey[200],
            child: item.imageUrl != null 
              ? Image.network(item.imageUrl!, fit: BoxFit.cover, errorBuilder: (_,__,___) => const Icon(Icons.inventory_2))
              : const Icon(Icons.inventory_2, color: Colors.grey),
          ),
        ),
        title: Text(item.name, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text(item.ean ?? 'Brak EAN', style: const TextStyle(fontSize: 12)),
        // KONTROLA ILOŚCI Z PRAWEJ
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: item.quantity <= 0 ? const Icon(Icons.delete_forever, color: Colors.red) : const Icon(Icons.remove_circle_outline),
              onPressed: () {
                if (storageId != null) {
                  if (item.quantity <= 0) {
                    ref.read(itemRepositoryProvider).deleteItem(storageId, item.id);
                  } else {
                    ref.read(itemRepositoryProvider).updateQuantity(storageId, item.id, -1);
                  }
                }
              },
            ),
            Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text('${item.quantity % 1 == 0 ? item.quantity.toInt() : item.quantity}', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                Text(item.unit, style: const TextStyle(fontSize: 10, color: Colors.grey)),
              ],
            ),
            IconButton(
              icon: const Icon(Icons.add_circle_outline, color: Colors.blue),
              onPressed: () => storageId != null ? ref.read(itemRepositoryProvider).updateQuantity(storageId, item.id, 1) : null,
            ),
          ],
        ),
      ),
    );
  }
}