import 'package:flutter/material.dart';
import 'package:frontend/model/chat_models.dart';

/// Manages cart state built from `CartChunk` and provides UI helpers.
class CartController extends ChangeNotifier {
  bool isLoading = false;
  CartChunk? _cart;
  final Set<String> _expandedIds = <String>{};

  bool get isEmpty => (_cart?.items.isEmpty ?? true);
  List<CartItem> get items => _cart?.items ?? const [];
  double get totalPrice => _cart?.price ?? 0.0;
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
        retailer: 'Amazon',
        deliveryTime: const Duration(days: 14),
      ),
      CartItem(
        id: '6',
        name: 'Tablet',
        price: 1499.99,
        amount: 1,
        retailer: 'BestBuy',
        deliveryTime: const Duration(days: 18),
      ),
      CartItem(
        id: '7',
        name: 'Smart Home Hub',
        price: 299.99,
        amount: 1,
        retailer: 'Amazon',
        deliveryTime: const Duration(days: 21),
      ),
      CartItem(
        id: '8',
        name: 'Smart TV',
        price: 1499.99,
        amount: 1,
        retailer: 'BestBuy',
        deliveryTime: const Duration(days: 24),
      ),
      CartItem(
        id: '9',
        name: 'Smart Speaker',
        price: 199.99,
        amount: 1,
        retailer: 'Amazon',
        deliveryTime: const Duration(days: 27),
      ),
    ];
    final total = items.fold<double>(
      0,
      (sum, it) => sum + it.price * it.amount,
    );
    _cart = CartChunk(items: items, price: total);
    isLoading = false;
    notifyListeners();
  }
}
