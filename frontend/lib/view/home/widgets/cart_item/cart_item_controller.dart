import 'package:flutter/material.dart';
import 'package:frontend/model/chat_models.dart';

/// Manages the CartItem widget's state and logic, and provides UI helpers.
class CartItemController extends ChangeNotifier {
  bool isExpanded = false;

  CartItemController({required this.item});

  final CartItem item;

  void toggleExpanded() {
    isExpanded = !isExpanded;
    notifyListeners();
  }
}
