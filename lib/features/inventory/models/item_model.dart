import 'package:cloud_firestore/cloud_firestore.dart';

class ItemModel {
  final String id;
  final String name;
  final String? ean;
  final double quantity;
  final String unit;
  final String? description;
  final String? imageUrl;
  final DateTime updatedAt;

  ItemModel({
    required this.id, required this.name, this.ean, 
    required this.quantity, this.unit = 'szt', 
    this.description, this.imageUrl,
    required this.updatedAt,
  });

  factory ItemModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return ItemModel(
      id: doc.id,
      name: data['name'] ?? '',
      ean: data['ean'],
      quantity: (data['quantity'] ?? 0).toDouble(),
      unit: data['unit'] ?? 'szt',
      description: data['description'],
      imageUrl: data['image_url'],
      updatedAt: (data['updated_at'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toFirestore() => {
    'name': name, 'ean': ean, 'quantity': quantity, 
    'unit': unit, 'description': description, 'image_url': imageUrl,
    'updated_at': FieldValue.serverTimestamp(),
  };
}