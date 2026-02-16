
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/item_model.dart';
import '../data/item_repository.dart';
import '../providers/storage_providers.dart';

class ItemCard extends ConsumerWidget {
  final ItemModel item;
  const ItemCard({super.key, required this.item});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final storageId = ref.watch(currentStorageProvider)?.id;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: ListTile(
        title: Text(item.name, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text(item.ean ?? 'Brak kodu EAN'),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: const Icon(Icons.remove_circle_outline),
              onPressed: () {
                if (storageId != null) {
                  ref.read(itemRepositoryProvider).updateQuantity(storageId, item.id, -1);
                }
              },
            ),
            Text(
              '${item.quantity.toInt()}',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            IconButton(
              icon: const Icon(Icons.add_circle_outline, color: Colors.blue),
              onPressed: () {
                if (storageId != null) {
                  ref.read(itemRepositoryProvider).updateQuantity(storageId, item.id, 1);
                }
              },
            ),
          ],
        ),
      ),
    );
  }
}
