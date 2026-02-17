import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/storage_model.dart';
import '../data/storage_repository.dart';
import '../../auth/providers/auth_provider.dart';

// Przechowuje ID wybranego magazynu. Jeśli null, wybieramy pierwszy dostępny.
final activeStorageIdProvider = StateProvider<String?>((ref) => null);

final currentStorageProvider = Provider<StorageModel?>((ref) {
  final storages = ref.watch(userStoragesProvider).value ?? [];
  final activeId = ref.watch(activeStorageIdProvider);
  
  if (storages.isEmpty) return null;
  if (activeId == null) return storages.first;
  
  return storages.firstWhere((s) => s.id == activeId, orElse: () => storages.first);
});

final userStoragesProvider = StreamProvider<List<StorageModel>>((ref) {
  final user = ref.watch(authStateProvider).value;
  if (user == null) return Stream.value([]);
  return ref.watch(storageRepositoryProvider).watchUserStorages(user.uid);
});