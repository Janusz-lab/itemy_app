import 'package:cloud_firestore/cloud_firestore.dart';

class InventoryItem {
  final String id;
  final String ean;
  final String name;
  final int quantity;
  final int minStock;
  final DateTime lastUpdated;

  InventoryItem({
    required this.id,
    required this.ean,
    required this.name,
    this.quantity = 0,
    this.minStock = 0,
    required this.lastUpdated,
  });

  // Konwersja z Firestore
  factory InventoryItem.fromFirestore(DocumentSnapshot doc) {
    Map data = doc.data() as Map<String, dynamic>;
    return InventoryItem(
      id: doc.id,
      ean: data['ean'] ?? '',
      name: data['name'] ?? 'Nieznany produkt',
      quantity: data['quantity'] ?? 0,
      minStock: data['min_stock'] ?? 0,
      lastUpdated: (data['last_updated'] as Timestamp).toDate(),
    );
  }

  // Konwersja do Firestore
  Map<String, dynamic> toFirestore() => {
    'ean': ean,
    'name': name,
    'quantity': quantity,
    'min_stock': minStock,
    'last_updated': FieldValue.serverTimestamp(),
  };
}