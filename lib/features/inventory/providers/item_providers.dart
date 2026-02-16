
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/item_repository.dart';
import '../models/item_model.dart';
import 'storage_providers.dart';

final currentItemsProvider = StreamProvider<List<ItemModel>>((ref) {
  final storage = ref.watch(currentStorageProvider);
  if (storage == null) return Stream.value([]);
  return ref.watch(itemRepositoryProvider).watchItems(storage.id);
});
