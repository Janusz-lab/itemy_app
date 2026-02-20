import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/item_repository.dart';
import '../models/item_model.dart';
import 'storage_providers.dart';

enum SortOption { name, ean, date, quantity }

class SortConfig {
  final SortOption option;
  final bool ascending;
  SortConfig({required this.option, required this.ascending});
  SortConfig copyWith({SortOption? option, bool? ascending}) =>
      SortConfig(option: option ?? this.option, ascending: ascending ?? this.ascending);
}

final itemSearchQueryProvider = StateProvider<String>((ref) => "");
final itemSortProvider = StateProvider<SortConfig>(
    (ref) => SortConfig(option: SortOption.name, ascending: true));

/// ID ostatnio zeskanowanego produktu — używane do podświetlenia na liście.
/// Ustawiane po skanie, czyszczone automatycznie po 6s przez widget.
final lastScannedItemIdProvider = StateProvider<String?>((ref) => null);

final currentItemsProvider = StreamProvider<List<ItemModel>>((ref) {
  final storage = ref.watch(currentStorageProvider);
  if (storage == null) return Stream.value([]);
  return ref.watch(itemRepositoryProvider).watchItems(storage.id);
});

final filteredItemsProvider = Provider<AsyncValue<List<ItemModel>>>((ref) {
  final itemsAsync = ref.watch(currentItemsProvider);
  final query      = ref.watch(itemSearchQueryProvider).toLowerCase();
  final sort       = ref.watch(itemSortProvider);

  return itemsAsync.whenData((items) {
    var list = items.where((i) =>
        i.name.toLowerCase().contains(query) ||
        (i.ean ?? "").contains(query) ||
        (i.description ?? "").contains(query)).toList();

    list.sort((a, b) {
      int c;
      switch (sort.option) {
        case SortOption.name:     c = a.name.compareTo(b.name); break;
        case SortOption.ean:      c = (a.ean ?? "").compareTo(b.ean ?? ""); break;
        case SortOption.date:     c = a.updatedAt.compareTo(b.updatedAt); break;
        case SortOption.quantity: c = a.quantity.compareTo(b.quantity); break;
      }
      return sort.ascending ? c : -c;
    });
    return list;
  });
});