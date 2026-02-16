
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/storage_model.dart';
import '../data/storage_repository.dart';
import '../../auth/providers/auth_provider.dart';

final currentStorageProvider = Provider<StorageModel?>((ref) {
  final storages = ref.watch(userStoragesProvider).value ?? [];
  return storages.isNotEmpty ? storages.first : null;
});

final userStoragesProvider = StreamProvider<List<StorageModel>>((ref) {
  final user = ref.watch(authStateProvider).value;
  if (user == null) return Stream.value([]);
  return ref.watch(storageRepositoryProvider).watchUserStorages(user.uid);
});
