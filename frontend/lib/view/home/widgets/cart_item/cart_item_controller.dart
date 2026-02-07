import 'package:flutter/material.dart';
import 'package:frontend/model/cart_models.dart';
class CartItemController extends ChangeNotifier {
  bool isExpanded = false;

  CartItemController({required this.entry});

  final CartEntry entry;

  void toggleExpanded() {
    isExpanded = !isExpanded;
    notifyListeners();
  }
}