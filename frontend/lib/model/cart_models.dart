import 'package:flutter/foundation.dart';

@immutable
class CartAlternativeEntry {
  final String id;
  final String title;
  final String merchant;
  final String priceText;
  final String dateText;
  final String categoryText;
  final String? imageUrl;

  const CartAlternativeEntry({
    required this.id,
    required this.title,
    required this.merchant,
    required this.priceText,
    required this.dateText,
    required this.categoryText,
    this.imageUrl,
  });
}

@immutable
class CartEntry {
  final String id;
  final String title;
  final String merchant;
  final String priceText;
  final int quantity;
  final String dateText;
  final String categoryText;
  final String? imageUrl;
  final List<CartAlternativeEntry> alternatives;

  const CartEntry({
    required this.id,
    required this.title,
    required this.merchant,
    required this.priceText,
    required this.quantity,
    required this.dateText,
    required this.categoryText,
    this.imageUrl,
    this.alternatives = const [],
  });
}

