import 'package:flutter/material.dart';
import 'package:frontend/model/cart_models.dart';

class CartController extends ChangeNotifier {
  bool isLoading = false;
  final List<CartEntry> entries = [];
  final Set<String> _expandedIds = <String>{};

  bool get isEmpty => entries.isEmpty;

  bool isExpanded(String id) => _expandedIds.contains(id);

  CartController() {
    loadDummyData();
  }

  void toggleExpanded(String id) {
    if (_expandedIds.contains(id)) {
      _expandedIds.remove(id);
    } else {
      _expandedIds.add(id);
    }
    notifyListeners();
  }

  void loadDummyData() {
    isLoading = true;
    notifyListeners();
    // Dummy data
    entries.clear();
    entries.addAll([
      CartEntry(
        id: '1',
        title: 'Bulk Energy Drink Pack (48ct)',
        merchant: 'Amazon',
        priceText: '\$42.99',
        quantity: 2,
        dateText: 'Feb 10',
        categoryText: 'Drinks',
        imageUrl: null,
        alternatives: const [
          CartAlternativeEntry(
            id: '1a',
            title: 'Monster Energy 24-Pack',
            merchant: 'Walmart',
            priceText: '\$38.99',
            dateText: 'Feb 11',
            categoryText: 'Drinks',
            imageUrl: null,
          ),
          CartAlternativeEntry(
            id: '1b',
            title: 'Red Bull 48-Pack',
            merchant: 'Costco',
            priceText: '\$56.99',
            dateText: 'Feb 9',
            categoryText: 'Drinks',
            imageUrl: null,
          ),
        ],
      ),
      const CartEntry(
        id: '2',
        title: 'Noise-Cancelling Headphones',
        merchant: 'BestBuy',
        priceText: '\$199.00',
        quantity: 1,
        dateText: 'Feb 12',
        categoryText: 'Electronics',
        imageUrl: null,
        alternatives: [
          CartAlternativeEntry(
            id: '2a',
            title: 'Sony WH-1000XM5',
            merchant: 'Amazon',
            priceText: '\$329.00',
            dateText: 'Feb 13',
            categoryText: 'Electronics',
          ),
          CartAlternativeEntry(
            id: '2b',
            title: 'Bose QC45',
            merchant: 'Bose',
            priceText: '\$299.00',
            dateText: 'Feb 11',
            categoryText: 'Electronics',
          ),
        ],
      ),
    ]);
    isLoading = false;
    notifyListeners();
  }
}
