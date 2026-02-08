import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:frontend/model/chat_models.dart';
import 'package:frontend/service/agent_api.dart';

/// Phases of the checkout flow.
enum CheckoutPhase { cart, summary, ordering, complete }

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

  /// Current checkout phase.
  CheckoutPhase _phase = CheckoutPhase.cart;
  CheckoutPhase get phase => _phase;

  /// Legacy helper for backwards-compat in cart_panel routing.
  bool get showSummary => _phase == CheckoutPhase.summary;

  /// Retailer sponsorship offers received from the backend.
  List<RetailerOffer> _retailerOffers = const [];
  List<RetailerOffer> get retailerOffers => _retailerOffers;

  /// Unique retailers derived from current items.
  List<String> get uniqueRetailers =>
      items.map((e) => e.retailer).toSet().toList();

  /// Representative image per retailer (first available item image).
  Map<String, String?> get retailerImageUrls {
    final Map<String, String?> out = {};
    for (final item in items) {
      if (!out.containsKey(item.retailer) || out[item.retailer] == null) {
        out[item.retailer] = item.imageUrl;
      }
    }
    return out;
  }

  /// Which retailers have finished the mock ordering process.
  final Set<String> _confirmedRetailers = <String>{};
  Set<String> get confirmedRetailers => _confirmedRetailers;

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

  /// Dynamic total computed from items (price x amount), before discounts.
  double get totalPrice =>
      items.fold<double>(0.0, (sum, it) => sum + (it.price * it.amount));

  /// Discount percent for a cart item from retailer offers (approved only).
  /// Matches by retailer and by item id or name. Returns null if no discount.
  int? getDiscountPercentForItem(CartItem item) {
    for (final RetailerOffer offer in _retailerOffers) {
      if (offer.retailer != item.retailer) {
        continue;
      }

      if (offer.status != 'approved') {
        continue;
      }

      for (final RetailerOfferItem di in offer.discountedItems) {
        final bool matchId =
            di.id != null && item.id != null && di.id == item.id;
        final bool matchName =
            di.item.trim().toLowerCase() == item.name.trim().toLowerCase();
        if (matchId || matchName) {
          return di.percent;
        }
      }
    }
    return null;
  }

  /// Unit price after discount for an item (same as price if no discount).
  double discountedUnitPrice(CartItem item) {
    final int? percent = getDiscountPercentForItem(item);
    if (percent == null || percent <= 0) return item.price;
    return item.price * (1.0 - percent / 100.0);
  }

  /// Line total (price * amount) after discount for an item.
  double discountedLineTotal(CartItem item) =>
      discountedUnitPrice(item) * item.amount;

  /// Final total after all item-level discounts.
  double get finalTotalPrice =>
      items.fold<double>(0.0, (sum, it) => sum + discountedLineTotal(it));

  /// True if any item has a discount from retailer offers.
  bool get hasAnyDiscount =>
      items.any((it) => getDiscountPercentForItem(it) != null);

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

  CartController();

  void setLoading(bool value) {
    isLoading = value;
    if (value) {
      errorMessage = null;
    }
    notifyListeners();
  }

  void setError(String message) {
    errorMessage = message;
    isLoading = false;
    notifyListeners();
  }

  void clearError() {
    errorMessage = null;
    notifyListeners();
  }

  void setCartFromChunk(CartChunk cart) {
    _cart = cart;
    errorMessage = null;
    isLoading = false;
    _selectedMainByIndex.clear();
    _expandedIds.clear();
    _expandedGroups.clear();
    _reasonsByIndex.clear();
    _aiReasoning.clear();
    _aiReasoningLoading.clear();
    // DO NOT clear _retailerOffers here - they arrive separately and should persist!
    notifyListeners();
  }

  /// Clear cart and all associated state (for new conversations).
  void clearCart() {
    _cart = null;
    _retailerOffers = const [];
    _selectedMainByIndex.clear();
    _expandedIds.clear();
    _expandedGroups.clear();
    _reasonsByIndex.clear();
    _aiReasoning.clear();
    _aiReasoningLoading.clear();
    _phase = CheckoutPhase.cart;
    _confirmedRetailers.clear();
    errorMessage = null;
    isLoading = false;
    notifyListeners();
  }

  /// Accumulate retailer sponsorship offers from the stream.
  /// Upserts by retailer name so incremental chunks merge correctly.
  void setRetailerOffers(List<RetailerOffer> offers) {
    final Map<String, RetailerOffer> merged = <String, RetailerOffer>{
      for (final RetailerOffer o in _retailerOffers) o.retailer: o,
    };
    for (final RetailerOffer o in offers) {
      merged[o.retailer] = o;
    }
    _retailerOffers = merged.values.toList();
    notifyListeners();
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
      return reasons['best'] ?? 'Best quality option.';
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
      reviewRating: prev.reviewRating,
      reviewsCount: prev.reviewsCount,
      deliveryTime: prev.deliveryTime,
      imageUrl: prev.imageUrl,
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

  /// Resets the displayed item for a group back to the original recommendation.
  void resetToMain(int groupIndex) {
    _selectedMainByIndex.remove(groupIndex);
    notifyListeners();
  }

  /// Whether the user has overridden the main with an alternative for [index].
  bool isAlternativeActive(int index) {
    if (_cart == null) return false;
    if (index < 0 || index >= _cart!.items.length) return false;
    final CartItem? override = _selectedMainByIndex[index];
    if (override == null) return false;
    final CartItem original = _cart!.items[index].main;
    return (override.id ?? override.name) != (original.id ?? original.name);
  }

  /// Begin checkout flow (switch panel to summary).
  void startCheckout() {
    _phase = CheckoutPhase.summary;
    notifyListeners();
  }

  /// Return to cart list (edit mode).
  void cancelCheckout() {
    _phase = CheckoutPhase.cart;
    _confirmedRetailers.clear();
    notifyListeners();
  }

  /// Start the mock ordering animation.
  /// Each retailer completes after a random delay (1.5–5 s).
  /// When all are done the phase advances to [CheckoutPhase.complete].
  void placeOrder() {
    _phase = CheckoutPhase.ordering;
    _confirmedRetailers.clear();
    notifyListeners();

    final rng = Random();
    final retailers = uniqueRetailers;

    for (final retailer in retailers) {
      final delayMs = 1500 + rng.nextInt(3500); // 1.5 – 5 s
      Future.delayed(Duration(milliseconds: delayMs), () {
        _confirmedRetailers.add(retailer);
        notifyListeners();
        if (_confirmedRetailers.length == retailers.length) {
          // Small extra pause before showing the final summary.
          Future.delayed(const Duration(milliseconds: 800), () {
            _phase = CheckoutPhase.complete;
            notifyListeners();
          });
        }
      });
    }
  }

  /// Reset checkout back to the cart (for re-ordering etc).
  void resetToCart() {
    _phase = CheckoutPhase.cart;
    _confirmedRetailers.clear();
    notifyListeners();
  }

  /// Returns the key of the displayed category: main/cheapest/best/fastest.
  String displayedCategoryKey(int index) {
    final group = getGroup(index);
    if (group == null) return 'main';
    final displayed = getDisplayedMain(index) ?? group.main;
    bool same(CartItem a, CartItem b) => (a.id ?? a.name) == (b.id ?? b.name);
    if (same(displayed, group.cheapest)) return 'cheapest';
    if (same(displayed, group.bestReviewed)) return 'best';
    if (same(displayed, group.fastest)) return 'fastest';
    return 'main';
  }

  // ---------------------------------------------------------------------------
  // AI recommendation reasoning
  // ---------------------------------------------------------------------------

  final Map<int, String> _aiReasoning = <int, String>{};
  final Set<int> _aiReasoningLoading = <int>{};

  /// Whether the AI reasoning is currently being fetched for [groupIndex].
  bool isReasoningLoading(int groupIndex) =>
      _aiReasoningLoading.contains(groupIndex);

  /// Returns the AI reasoning for [groupIndex], or null if not yet fetched.
  String? getAiReasoning(int groupIndex) => _aiReasoning[groupIndex];

  /// Fetches the AI recommendation reasoning for the given [groupIndex].
  Future<void> fetchRecommendationReason(int groupIndex, AgentApi api) async {
    final group = getGroup(groupIndex);
    if (group == null) return;
    if (_aiReasoningLoading.contains(groupIndex)) return; // already loading

    _aiReasoningLoading.add(groupIndex);
    _aiReasoning.remove(groupIndex);
    notifyListeners();

    try {
      final reasoning = await api.getRecommendationReason(group);
      _aiReasoning[groupIndex] = reasoning;
    } catch (e) {
      _aiReasoning[groupIndex] =
          'Could not fetch explanation. Please try again.';
    } finally {
      _aiReasoningLoading.remove(groupIndex);
      notifyListeners();
    }
  }

  /// Background alpha used for category chips, mirroring recommendation tiles.
  double categoryAlpha(String key) {
    switch (key) {
      case 'cheapest':
        return 0.16;
      case 'best':
        return 0.22;
      case 'fastest':
        return 0.28;
      case 'main':
      default:
        return 0.10;
    }
  }
}
