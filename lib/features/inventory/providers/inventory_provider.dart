import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Pojedynczy wpis w historii sesji inwentaryzacji
class InventoryChange {
  final String itemName;
  final double quantityBefore;
  final double quantityAfter;
  final String unit;
  final bool isNew; // true = dodano nowy produkt

  const InventoryChange({
    required this.itemName,
    required this.quantityBefore,
    required this.quantityAfter,
    required this.unit,
    this.isNew = false,
  });

  String get summary {
    if (isNew) return '$itemName — dodano (${quantityAfter.toStringAsFixed(quantityAfter % 1 == 0 ? 0 : 1)} $unit)';
    final before = quantityBefore.toStringAsFixed(quantityBefore % 1 == 0 ? 0 : 1);
    final after  = quantityAfter.toStringAsFixed(quantityAfter % 1 == 0 ? 0 : 1);
    return '$itemName: $before → $after $unit';
  }
}

class InventorySession {
  final bool isActive;
  final List<InventoryChange> changes;

  const InventorySession({
    this.isActive = false,
    this.changes = const [],
  });

  int get scannedCount => changes.where((c) => !c.isNew).length;
  int get addedCount   => changes.where((c) => c.isNew).length;

  InventorySession copyWith({bool? isActive, List<InventoryChange>? changes}) =>
      InventorySession(
        isActive: isActive ?? this.isActive,
        changes:  changes  ?? this.changes,
      );

  InventorySession addChange(InventoryChange change) =>
      copyWith(changes: [...changes, change]);
}

class InventorySessionNotifier extends StateNotifier<InventorySession> {
  InventorySessionNotifier() : super(const InventorySession());

  void start() => state = const InventorySession(isActive: true);

  void stop() => state = state.copyWith(isActive: false);

  void clear() => state = const InventorySession();

  void recordChange(InventoryChange change) =>
      state = state.addChange(change);
}

final inventorySessionProvider =
    StateNotifierProvider<InventorySessionNotifier, InventorySession>(
  (ref) => InventorySessionNotifier(),
);