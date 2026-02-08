import 'package:flutter/material.dart';
import 'package:frontend/model/chat_models.dart';

/// Manages cart state built from `CartChunk` and provides UI helpers.
class CartController extends ChangeNotifier {
  bool isLoading = false;
  String? errorMessage;
  CartChunk? _cart;
  final Set<String> _expandedIds = <String>{};
  final Map<int, CartItem> _selectedMainByIndex = <int, CartItem>{};
  final Set<int> _expandedGroups = <int>{};
  final Map<int, Map<String, String>> _reasonsByIndex =
      <int, Map<String, String>>{};

  bool get isEmpty => (_cart?.items.isEmpty ?? true);

  /// All items currently in the cart (displayed mains, honoring selection overrides).
  List<CartItem> get items {
    final groups = _cart?.items ?? const <RecommendedItem>[];
    final List<CartItem> out = <CartItem>[];
    for (int i = 0; i < groups.length; i++) {
      out.add(_selectedMainByIndex[i] ?? groups[i].main);
    }
    return out;
  }

  /// Dynamic total computed from items (price x amount).
  double get totalPrice =>
      items.fold<double>(0.0, (sum, it) => sum + (it.price * it.amount));
  int get itemCount => items.length;
  int get retailerCount => items.map((e) => e.retailer).toSet().length;

  /// Whether a specific item (by id) is expanded in the UI.
  bool isExpanded(String id) => _expandedIds.contains(id);

  /// Whether a specific group index is expanded (stable across selection changes).
  bool isExpandedGroup(int index) => _expandedGroups.contains(index);

  /// Removes an item by id (or name fallback) and cleans related state.
  void deleteItem(String itemId) {
    if (_cart == null) return;
    // Determine index based on displayed mains so deletion matches UI.
    final current = items;
    final idx = current.indexWhere((m) => (m.id ?? m.name) == itemId);
    if (idx < 0) return;
    final updated = List<RecommendedItem>.from(_cart!.items)..removeAt(idx);
    _cart = CartChunk(items: updated, price: totalPrice);
    _expandedIds.remove(itemId);
    // Reindex selection overrides after removal
    final Map<int, CartItem> next = {};
    _selectedMainByIndex.forEach((k, v) {
      if (k < idx) next[k] = v;
      if (k > idx) next[k - 1] = v;
    });
    _selectedMainByIndex
      ..clear()
      ..addAll(next);
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

  /// Toggles expansion using stable group index.
  void toggleExpandedGroup(int index) {
    if (_expandedGroups.contains(index)) {
      _expandedGroups.remove(index);
    } else {
      _expandedGroups.add(index);
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

  /// Returns the currently displayed main for a group (after overrides).
  CartItem? getDisplayedMain(int index) {
    if (_cart == null) return null;
    if (index < 0 || index >= _cart!.items.length) return null;
    return _selectedMainByIndex[index] ?? _cart!.items[index].main;
  }

  /// Returns an explanation for why the displayed main was suggested.
  String getDisplayedReason(int index) {
    final group = getGroup(index);
    if (group == null) return 'Suggested by the agent.';
    final displayed = getDisplayedMain(index) ?? group.main;
    final reasons = _reasonsByIndex[index] ?? const {};
    bool same(CartItem a, CartItem b) => (a.id ?? a.name) == (b.id ?? b.name);
    if (same(displayed, group.cheapest))
      return reasons['cheapest'] ?? 'Cheapest available option.';
    if (same(displayed, group.bestReviewed))
      return reasons['best'] ?? 'Best reviewed option.';
    if (same(displayed, group.fastest))
      return reasons['fastest'] ?? 'Fastest delivery option.';
    return reasons['main'] ?? 'Recommended main option.';
  }

  /// Updates the quantity for a given item (min 1). Recomputes totals.
  void updateQuantity(String itemId, int quantity) {
    if (_cart == null) return;
    final q = quantity < 1 ? 1 : quantity;
    // Find by current displayed mains
    final current = items;
    final idx = current.indexWhere((m) => (m.id ?? m.name) == itemId);
    if (idx < 0) return;
    final prev = _selectedMainByIndex[idx] ?? _cart!.items[idx].main;
    _selectedMainByIndex[idx] = CartItem(
      id: prev.id,
      name: prev.name,
      price: prev.price,
      amount: q,
      retailer: prev.retailer,
      deliveryTime: prev.deliveryTime,
    );
    notifyListeners();
  }

  /// Swaps currently selected item with the chosen alternative.
  /// The previous selection becomes an alternative entry.
  void selectRecommendation(int groupIndex, CartItem chosen) {
    if (_cart == null) return;
    if (groupIndex < 0 || groupIndex >= _cart!.items.length) return;
    // Do not mutate group buckets; only override displayed main.
    _selectedMainByIndex[groupIndex] = chosen;
    notifyListeners();
  }

  /// Loads a dummy list of items and computes the total price.
  Future<void> loadDummyData() async {
    isLoading = true;
    errorMessage = null;
    _selectedMainByIndex.clear();
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
      // Seed short explanations per category for each group.
      _reasonsByIndex
        ..clear()
        ..addAll({
          0: {
            'main': 'Balanced pick with good value and availability.',
            'cheapest': 'This one saves you the most money.',
            'best': 'Customers rated this the highest overall.',
            'fastest': 'This will arrive the soonest.',
          },
          1: {
            'main': 'Solid feature set for the price.',
            'cheapest': 'Lowest cost among similar models.',
            'best': 'Top reviews for comfort and sound.',
            'fastest': 'Quickest delivery window right now.',
          },
        });
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
