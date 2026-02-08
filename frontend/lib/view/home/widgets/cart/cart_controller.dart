import 'package:flutter/material.dart';
import 'package:frontend/model/chat_models.dart';

/// Manages cart state built from `CartChunk` and provides UI helpers.
class CartController extends ChangeNotifier {
  bool isLoading = false;
  CartChunk? _cart;
  final Set<String> _expandedIds = <String>{};
  final Map<String, CartChunk> _alternativesById = <String, CartChunk>{};

  bool get isEmpty => (_cart?.items.isEmpty ?? true);

  /// All items currently in the cart.
  List<CartItem> get items => _cart?.items ?? const [];

  /// Dynamic total computed from items (price x amount).
  double get totalPrice =>
      items.fold<double>(0.0, (sum, it) => sum + (it.price * it.amount));
  int get itemCount => items.length;
  int get retailerCount => items.map((e) => e.retailer).toSet().length;

  /// Whether a specific item (by id) is expanded in the UI.
  bool isExpanded(String id) => _expandedIds.contains(id);

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

  /// Returns alternatives for a given item id, or null if none available.
  CartChunk? getAlternatives(String id) => _alternativesById[id];

  /// Swaps currently selected item with the chosen alternative.
  /// The previous selection becomes an alternative entry.
  void selectAlternative(String itemId, CartItem newSelection) {
    if (_cart == null) return;
    String _keyOf(CartItem it) => it.id ?? it.name;
    final int idx = _cart!.items.indexWhere((e) => _keyOf(e) == itemId);
    if (idx < 0) return;
    final CartItem previous = _cart!.items[idx];

    // Update selected item in cart.
    final updatedItems = List<CartItem>.from(_cart!.items);
    updatedItems[idx] = newSelection;
    _cart = CartChunk(items: updatedItems, price: totalPrice);

    // Update alternatives: take existing list for the CURRENT key
    // and swap chosen alt for previous selection, preserving position.
    final existing = _alternativesById[itemId];
    final altItems = List<CartItem>.from(existing?.items ?? const []);
    final int chosenIndex = altItems.indexWhere(
      (e) => _keyOf(e) == _keyOf(newSelection),
    );
    if (chosenIndex >= 0) {
      altItems.removeAt(chosenIndex);
      altItems.insert(chosenIndex, previous);
    } else {
      // Fallback: prepend previous if the chosen wasn't found.
      altItems.insert(0, previous);
    }

    // Re-key the alternatives under the NEW selection key so UI continues to find them.
    final String newKey = _keyOf(newSelection);
    _alternativesById.remove(itemId);
    _alternativesById[newKey] = CartChunk(items: altItems, price: 0);
    notifyListeners();
  }

  /// Loads a dummy list of items and computes the total price.
  void loadDummyData() {
    isLoading = true;
    notifyListeners();
    final items = <CartItem>[
      CartItem(
        id: '1',
        name: 'Bulk Energy Drink Pack (48ct)',
        price: 42.99,
        amount: 2,
        retailer: 'Amazon',
        deliveryTime: const Duration(days: 3),
      ),
      CartItem(
        id: '2',
        name: 'Noise-Cancelling Headphones',
        price: 199.00,
        amount: 1,
        retailer: 'BestBuy',
        deliveryTime: const Duration(days: 5),
      ),
      CartItem(
        id: '3',
        name: 'Smart Watch',
        price: 199.99,
        amount: 1,
        retailer: 'Amazon',
        deliveryTime: const Duration(days: 7),
      ),
      CartItem(
        id: '4',
        name: 'Laptop',
        price: 1999.99,
        amount: 1,
        retailer: 'Walmart',
        deliveryTime: const Duration(days: 10),
      ),
      CartItem(
        id: '5',
        name: 'Phone',
        price: 999.99,
        amount: 1,
        retailer: 'Costco',
        deliveryTime: const Duration(days: 14),
      ),
    ];
    final total = items.fold<double>(
      0,
      (sum, it) => sum + it.price * it.amount,
    );
    _cart = CartChunk(items: items, price: total);

    // Seed some alternatives
    _alternativesById.clear();
    _alternativesById['1'] = CartChunk(
      items: [
        CartItem(
          id: '1a',
          name: 'Monster Energy 24‑Pack',
          price: 38.99,
          amount: 1,
          retailer: 'Walmart',
          deliveryTime: const Duration(days: 4),
        ),
        CartItem(
          id: '1b',
          name: 'Red Bull 48‑Pack',
          price: 56.99,
          amount: 1,
          retailer: 'Costco',
          deliveryTime: const Duration(days: 2),
        ),
      ],
      price: 0,
    );
    _alternativesById['2'] = CartChunk(
      items: [
        CartItem(
          id: '2a',
          name: 'Sony WH‑1000XM5',
          price: 329.00,
          amount: 1,
          retailer: 'Amazon',
          deliveryTime: const Duration(days: 3),
        ),
        CartItem(
          id: '2b',
          name: 'Bose QC45',
          price: 299.00,
          amount: 1,
          retailer: 'Bose',
          deliveryTime: const Duration(days: 2),
        ),
      ],
      price: 0,
    );
    isLoading = false;
    notifyListeners();
  }
}
