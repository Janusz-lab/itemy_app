import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/providers/firebase_providers.dart';
import '../models/item_model.dart';

final itemRepositoryProvider = Provider<ItemRepository>(
    (ref) => ItemRepository(ref.read(firestoreProvider)));

class ItemRepository {
  final FirebaseFirestore _db;
  ItemRepository(this._db);

  Stream<List<ItemModel>> watchItems(String storageId) {
    return _db
        .collection('storages')
        .doc(storageId)
        .collection('items')
        .orderBy('name')
        .snapshots()
        .map((s) => s.docs.map((d) => ItemModel.fromFirestore(d)).toList());
  }

  /// Zapisuje lub aktualizuje produkt.
  /// Zwraca ID dokumentu (przydatne przy tworzeniu nowego — do Undo przenoszenia).
  Future<String> upsertItem(String storageId, ItemModel item) async {
    final col = _db.collection('storages').doc(storageId).collection('items');
    final ref = item.id.isEmpty ? col.doc() : col.doc(item.id);
    await ref.set(item.toFirestore(), SetOptions(merge: true));
    return ref.id;
  }

  Future<void> updateQuantity(
      String storageId, String itemId, double change) async {
    await _db
        .collection('storages')
        .doc(storageId)
        .collection('items')
        .doc(itemId)
        .update({
      'quantity': FieldValue.increment(change),
      'updated_at': FieldValue.serverTimestamp(),
    });
  }

  Future<void> deleteItem(String storageId, String itemId) async {
    await _db
        .collection('storages')
        .doc(storageId)
        .collection('items')
        .doc(itemId)
        .delete();
  }
}