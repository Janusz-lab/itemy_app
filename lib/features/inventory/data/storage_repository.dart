import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/providers/firebase_providers.dart';
import '../models/storage_model.dart';

final storageRepositoryProvider = Provider<StorageRepository>((ref) => StorageRepository(ref.read(firestoreProvider)));

class StorageRepository {
  final FirebaseFirestore _db;
  StorageRepository(this._db);

  Stream<List<StorageModel>> watchUserStorages(String uid) {
    return _db.collection('storages').where('access_uids', arrayContains: uid)
        .snapshots().map((s) => s.docs.map((d) => StorageModel.fromFirestore(d)).toList());
  }

  Future<void> createStorage(String name, String uid) async {
    await _db.collection('storages').add({
      'name': name,
      'access_uids': [uid],
      'created_at': FieldValue.serverTimestamp(),
    });
  }
}