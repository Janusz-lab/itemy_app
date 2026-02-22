import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/providers/firebase_providers.dart';
import '../../inventory/models/storage_model.dart';

final migrationServiceProvider = Provider<MigrationService>(
  (ref) => MigrationService(ref.read(firestoreProvider)),
);

class StorageToMigrate {
  final StorageModel storage;
  bool selected;
  StorageToMigrate(this.storage, {this.selected = true});
}

class MigrationService {
  final FirebaseFirestore _db;
  MigrationService(this._db);

  /// Zwraca listę magazynów należących do anonimowego UID.
  Future<List<StorageModel>> getAnonStorages(String anonUid) async {
    final snap = await _db
        .collection('storages')
        .where('access_uids', arrayContains: anonUid)
        .get();
    return snap.docs.map((d) => StorageModel.fromFirestore(d)).toList();
  }

  /// Kopiuje wybrane magazyny (wraz z produktami) z anonUid → targetUid.
  /// Stare dokumenty anonimowe pozostają — nie usuwamy (użytkownik może
  /// wrócić do trybu lokalnego i nadal je mieć).
  Future<void> migrateStorages({
    required List<StorageModel> storages,
    required String targetUid,
  }) async {
    for (final storage in storages) {
      // 1. Utwórz nowy dokument magazynu pod targetUid
      final newStorageRef = await _db.collection('storages').add({
        'name': storage.name,
        'access_uids': [targetUid],
        'created_at': FieldValue.serverTimestamp(),
      });

      // 2. Skopiuj wszystkie produkty
      final itemsSnap = await _db
          .collection('storages')
          .doc(storage.id)
          .collection('items')
          .get();

      final batch = _db.batch();
      for (final itemDoc in itemsSnap.docs) {
        final newItemRef = newStorageRef.collection('items').doc();
        batch.set(newItemRef, {
          ...itemDoc.data(),
          'updated_at': FieldValue.serverTimestamp(),
        });
      }
      await batch.commit();
    }
  }
}