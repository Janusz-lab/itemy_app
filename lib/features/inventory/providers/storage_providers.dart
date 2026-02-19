// 📄 lib/features/inventory/providers/storage_providers.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/storage_model.dart';
import '../data/storage_repository.dart';
import '../../auth/providers/auth_provider.dart';
import '../../../core/providers/app_providers.dart';

const _kLastStorageKey = 'last_storage_id';

// ---------------------------------------------------------------------------
// StateNotifier — zapamiętuje wybrany magazyn w SharedPreferences
// ---------------------------------------------------------------------------
class ActiveStorageNotifier extends StateNotifier<String?> {
  final SharedPreferences _prefs;

  ActiveStorageNotifier(this._prefs)
      : super(_prefs.getString(_kLastStorageKey)); // ← odczyt przy starcie

  /// Ustawia aktywny magazyn i zapisuje go lokalnie.
  void setStorage(String id) {
    state = id;
    _prefs.setString(_kLastStorageKey, id);
  }
}

final activeStorageIdProvider =
    StateNotifierProvider<ActiveStorageNotifier, String?>((ref) {
  final prefs = ref.watch(sharedPrefsProvider);
  return ActiveStorageNotifier(prefs);
});

// ---------------------------------------------------------------------------
// Aktualnie wybrany magazyn (z fallbackiem na pierwszy z listy)
// ---------------------------------------------------------------------------
final currentStorageProvider = Provider<StorageModel?>((ref) {
  final storages = ref.watch(userStoragesProvider).value ?? [];
  final activeId = ref.watch(activeStorageIdProvider);

  if (storages.isEmpty) return null;
  if (activeId == null) return storages.first;

  return storages.firstWhere(
    (s) => s.id == activeId,
    orElse: () => storages.first,
  );
});

// ---------------------------------------------------------------------------
// Stream magazynów zalogowanego użytkownika
// ---------------------------------------------------------------------------
final userStoragesProvider = StreamProvider<List<StorageModel>>((ref) {
  final user = ref.watch(authStateProvider).value;
  if (user == null) return Stream.value([]);
  return ref.watch(storageRepositoryProvider).watchUserStorages(user.uid);
});