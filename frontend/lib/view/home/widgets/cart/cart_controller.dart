import 'package:flutter/material.dart';
import 'package:frontend/model/chat_models.dart';

/// Manages cart state built from `CartChunk` and provides UI helpers.
class CartController extends ChangeNotifier {
  bool isLoading = false;
  String? errorMessage;
  CartChunk? _cart;
  final Set<String> _expandedIds = <String>{};

  bool get isEmpty => (_cart?.items.isEmpty ?? true);

  /// All items currently in the cart.
  List<CartItem> get items =>
      _cart?.items.map((g) => g.main).toList() ?? const [];

  /// Dynamic total computed from items (price x amount).
  double get totalPrice => (_cart?.items ?? const [])
      .map((g) => g.main)
      .fold<double>(0.0, (sum, it) => sum + (it.price * it.amount));
  int get itemCount => items.length;
  int get retailerCount => items.map((e) => e.retailer).toSet().length;

  /// Whether a specific item (by id) is expanded in the UI.
  bool isExpanded(String id) => _expandedIds.contains(id);

  /// Removes an item by id (or name fallback) and cleans related state.
  void deleteItem(String itemId) {
    if (_cart == null) return;
    final idx = _cart!.items.indexWhere(
      (g) => (g.main.id ?? g.main.name) == itemId,
    );
    if (idx < 0) return;
    final updated = List<RecommendedItem>.from(_cart!.items)..removeAt(idx);
    _cart = CartChunk(items: updated, price: totalPrice);
    _expandedIds.remove(itemId);
    notifyListeners();
  }

  /// Creates a controller and seeds it with development dummy data.
  CartController() {
    loadDummyData();
  }

  /// Toggles the expansion state for a cart item in the UI.
  void toggleExpanded(String id) {
    if (_expandedIds.contains(id)) {
      _expandedIds.remove(id);
    } else {
      _expandedIds.add(id);
    }
    notifyListeners();
  }

  /// Returns recommendation group by index.
  RecommendedItem? getGroup(int index) {
    final list = _cart?.items;
    if (list == null) return null;
    if (index < 0 || index >= list.length) return null;
    return list[index];
  }

  /// Updates the quantity for a given item (min 1). Recomputes totals.
  void updateQuantity(String itemId, int quantity) {
    if (_cart == null) return;
    final q = quantity < 1 ? 1 : quantity;
    final idx = _cart!.items.indexWhere(
      (g) => (g.main.id ?? g.main.name) == itemId,
    );
    if (idx < 0) return;
    final group = _cart!.items[idx];
    final main = group.main;
    final updatedMain = CartItem(
      id: main.id,
      name: main.name,
      price: main.price,
      amount: q,
      retailer: main.retailer,
      deliveryTime: main.deliveryTime,
    );
    final newGroups = List<RecommendedItem>.from(_cart!.items);
    newGroups[idx] = RecommendedItem(
      main: updatedMain,
      cheapest: group.cheapest,
      bestReviewed: group.bestReviewed,
      fastest: group.fastest,
    );
    _cart = CartChunk(items: newGroups, price: totalPrice);
    notifyListeners();
  }

  /// Swaps currently selected item with the chosen alternative.
  /// The previous selection becomes an alternative entry.
  void selectRecommendation(int groupIndex, CartItem chosen) {
    if (_cart == null) return;
    if (groupIndex < 0 || groupIndex >= _cart!.items.length) return;
    final group = _cart!.items[groupIndex];
    // Set chosen as the new main, but KEEP category buckets unchanged.
    final newGroup = RecommendedItem(
      main: chosen,
      cheapest: group.cheapest,
      bestReviewed: group.bestReviewed,
      fastest: group.fastest,
    );

    final groups = List<RecommendedItem>.from(_cart!.items);
    groups[groupIndex] = newGroup;
    _cart = CartChunk(items: groups, price: totalPrice);
    notifyListeners();
  }

  /// Loads a dummy list of items and computes the total price.
  Future<void> loadDummyData() async {
    isLoading = true;
    errorMessage = null;
    notifyListeners();
    try {
      // Simulate network/search latency so the skeleton can be seen.
      await Future.delayed(const Duration(milliseconds: 1200));
      final groups = <RecommendedItem>[
        RecommendedItem(
          main: CartItem(
            id: '1',
            name: 'Bulk Energy Drink Pack (48ct)',
            price: 42.99,
            amount: 2,
            retailer: 'Amazon',
            deliveryTime: const Duration(days: 3),
          ),
          cheapest: CartItem(
            id: '1a',
            name: 'Monster Energy 24‑Pack',
            price: 38.99,
            amount: 1,
            retailer: 'Walmart',
            deliveryTime: const Duration(days: 4),
          ),
          bestReviewed: CartItem(
            id: '1b',
            name: 'Red Bull 48‑Pack',
            price: 56.99,
            amount: 1,
            retailer: 'Costco',
            deliveryTime: const Duration(days: 2),
          ),
          fastest: CartItem(
            id: '1c',
            name: 'Celsius 24‑Pack',
            price: 44.99,
            amount: 1,
            retailer: 'Target',
            deliveryTime: const Duration(days: 1),
          ),
        ),
        RecommendedItem(
          main: CartItem(
            id: '2',
            name: 'Noise‑Cancelling Headphones',
            price: 199.00,
            amount: 1,
            retailer: 'BestBuy',
            deliveryTime: const Duration(days: 5),
          ),
          cheapest: CartItem(
            id: '2a',
            name: 'Sony WH‑1000XM5',
            price: 329.00,
            amount: 1,
            retailer: 'Amazon',
            deliveryTime: const Duration(days: 3),
          ),
          bestReviewed: CartItem(
            id: '2b',
            name: 'Bose QC45',
            price: 299.00,
            amount: 1,
            retailer: 'Bose',
            deliveryTime: const Duration(days: 2),
          ),
          fastest: CartItem(
            id: '2c',
            name: 'AirPods Max',
            price: 549.00,
            amount: 1,
            retailer: 'Apple',
            deliveryTime: const Duration(days: 1),
          ),
        ),
      ];
      final total = groups
          .map((g) => g.main)
          .fold<double>(0, (sum, it) => sum + it.price * it.amount);
      _cart = CartChunk(items: groups, price: total);
      errorMessage = null;
    } catch (e) {
      errorMessage =
          "We couldn't fetch product data. This might be a network issue.";
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }
}
