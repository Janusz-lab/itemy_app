
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/providers/firebase_providers.dart';
import '../models/item_model.dart';

final itemRepositoryProvider = Provider<ItemRepository>((ref) {
  return ItemRepository(ref.read(firestoreProvider));
});

class ItemRepository {
  final FirebaseFirestore _firestore;
  ItemRepository(this._firestore);

  Stream<List<ItemModel>> watchItems(String storageId) {
    return _firestore
        .collection('storages')
        .doc(storageId)
        .collection('items')
        .orderBy('name', descending: false) 
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => ItemModel.fromFirestore(doc))
            .toList());
  }

  Future<void> upsertItem(String storageId, ItemModel item) async {
    final collection = _firestore.collection('storages').doc(storageId).collection('items');
    final docRef = item.id.isEmpty ? collection.doc() : collection.doc(item.id);
    await docRef.set(item.toFirestore(), SetOptions(merge: true));
  }

  Future<void> updateQuantity(String storageId, String itemId, double change) async {
    await _firestore.collection('storages').doc(storageId).collection('items').doc(itemId).update({
      'quantity': FieldValue.increment(change),
      'updated_at': FieldValue.serverTimestamp(),
    });
  }

  Future<void> deleteItem(String storageId, String itemId) async {
    await _firestore.collection('storages').doc(storageId).collection('items').doc(itemId).delete();
  }
}
