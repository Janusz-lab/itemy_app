
import 'package:cloud_firestore/cloud_firestore.dart';

class StorageModel {
  final String id;
  final String name;
  final List<String> accessUids;

  StorageModel({required this.id, required this.name, required this.accessUids});

  factory StorageModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return StorageModel(
      id: doc.id,
      name: data['name'] ?? '',
      accessUids: List<String>.from(data['access_uids'] ?? []),
    );
  }
}
