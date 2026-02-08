/// Mirror of your structured outputs from the backend.

enum OutputItemType {
  // tool('tool'),
  // toolResult('tool_result'),
  text('text'),
  // thinking('thinking'),
  // answer('answer'),
  error('error'),
  textForm('text_form'),
  tree('tree'),
  peopleTree('people_tree'),
  placeTree('place_tree'),
  cart('cart'),
  items('items'),
  retailerOffers('retailer_offers');

  const OutputItemType(this.jsonValue);
  final String jsonValue;

  static OutputItemType fromJson(String value) {
    return OutputItemType.values.firstWhere(
      (OutputItemType e) => e.jsonValue == value,
      orElse: () => OutputItemType.error,
    );
  }
}

abstract class OutputItemBase {
  OutputItemType get type;
}

/// type: "text"
class TextChunk implements OutputItemBase {
  @override
  final OutputItemType type;
  final String content;

  TextChunk({required this.type, required this.content});

  factory TextChunk.fromJson(Map<String, dynamic> json) =>
      TextChunk(type: OutputItemType.text, content: json['content'] as String);
}

/// type: "error"
class ErrorOutput implements OutputItemBase {
  @override
  final OutputItemType type;
  final String message;
  final String? code;

  ErrorOutput({required this.type, required this.message, this.code});

  factory ErrorOutput.fromJson(Map<String, dynamic> json) => ErrorOutput(
    type: OutputItemType.error,
    message: json['message'] as String,
    code: json['code'] as String?,
  );
}

/// Each field of a form. Has a label and optional content.
/// Content may be prefilled by the AI when the user provided that information previously.
class TextFieldChunk {
  final String label;
  final String? content;

  TextFieldChunk({required this.label, this.content});

  factory TextFieldChunk.fromJson(Map<String, dynamic> json) => TextFieldChunk(
    label: json['label'] as String,
    content: json['content'] as String?,
  );

  Map<String, dynamic> toJson() => {
    'label': label,
    if (content != null) 'content': content,
  };
}

/// Form chunk containing tech/event information fields.
class TextFormChunk implements OutputItemBase {
  @override
  final OutputItemType type;
  final TextFieldChunk address;
  final TextFieldChunk budget;
  final TextFieldChunk date;
  final TextFieldChunk durationOfEvent;
  final TextFieldChunk numberOfAttendees;

  TextFormChunk({
    OutputItemType? type,
    required this.address,
    required this.budget,
    required this.date,
    required this.durationOfEvent,
    required this.numberOfAttendees,
  }) : type = type ?? OutputItemType.textForm;

  factory TextFormChunk.fromJson(Map<String, dynamic> json) => TextFormChunk(
    type: OutputItemType.textForm,
    address: TextFieldChunk.fromJson(json['address'] as Map<String, dynamic>),
    budget: TextFieldChunk.fromJson(json['budget'] as Map<String, dynamic>),
    date: TextFieldChunk.fromJson(json['date'] as Map<String, dynamic>),
    durationOfEvent: TextFieldChunk.fromJson(
      json['duration'] as Map<String, dynamic>,
    ),
    numberOfAttendees: TextFieldChunk.fromJson(
      json['numberOfAttendees'] as Map<String, dynamic>,
    ),
  );

  Map<String, dynamic> toJson() => {
    'address': address.toJson(),
    'budget': budget.toJson(),
    'date': date.toJson(),
    'duration': durationOfEvent.toJson(),
    'numberOfAttendees': numberOfAttendees.toJson(),
  };
}

/// Parses selected/boolean from JSON (bool, int, or string).
bool _parseBool(dynamic value) {
  if (value == null) return false;
  if (value is bool) return value;
  if (value is int) return value != 0;
  if (value is String) {
    final lower = value.toLowerCase();
    return lower == 'true' || lower == '1';
  }
  return false;
}

/// Root type for the category tree: people or place.
enum TreeType { people, place }

/// Selectable category in the tree. Expandable and may have subcategories.
/// User can select which subcategories are interesting for them.
class Category {
  final String emoji;
  final String label;
  final bool isSelected;
  final List<Category> subcategories;

  Category({
    required this.emoji,
    required this.label,
    required this.isSelected,
    required this.subcategories,
  });

  factory Category.fromJson(Map<String, dynamic> json) => Category(
    emoji: json['emoji'] as String,
    label: json['label'] as String,
    isSelected: _parseBool(json['selected']),
    subcategories:
        (json['children'] as List<dynamic>?)
            ?.map((e) => Category.fromJson(e as Map<String, dynamic>))
            .toList() ??
        const [],
  );

  Map<String, dynamic> toJson() => {
    'emoji': emoji,
    'label': label,
    'selected': isSelected,
    'children': subcategories.map((e) => e.toJson()).toList(),
  };
}

/// Chunk representing a category tree for people or equipment.
/// Categories can have nested subcategories built by the AI.
class TreeChunk implements OutputItemBase {
  @override
  final OutputItemType type;
  final TreeType treeType;
  final Category category;

  TreeChunk({
    OutputItemType? type,
    required this.treeType,
    required this.category,
  }) : type = type ?? OutputItemType.tree;

  factory TreeChunk.fromJson(Map<String, dynamic> json) => TreeChunk(
    type: OutputItemType.tree,
    treeType: TreeType.values.firstWhere(
      (TreeType e) => e.name == json['treeType'],
      orElse: () => TreeType.people,
    ),
    category: Category.fromJson(json['category'] as Map<String, dynamic>),
  );

  Map<String, dynamic> toJson() => {
    'treeType': treeType.name,
    'category': category.toJson(),
  };
}

/// type: "items" — list of item names from the shopping list agent.
class ItemsChunk implements OutputItemBase {
  @override
  final OutputItemType type;
  final List<String> items;

  ItemsChunk({OutputItemType? type, required this.items})
    : type = type ?? OutputItemType.items;

  factory ItemsChunk.fromJson(Map<String, dynamic> json) => ItemsChunk(
    type: OutputItemType.items,
    items:
        (json['items'] as List<dynamic>?)
            ?.map((e) => e as String)
            .toList() ??
        const [],
  );
}

/// A single discounted item within a retailer offer.
class RetailerOfferItem {
  final String? id;
  final String item;
  final int percent;

  RetailerOfferItem({this.id, required this.item, required this.percent});

  factory RetailerOfferItem.fromJson(Map<String, dynamic> json) =>
      RetailerOfferItem(
        id: json['id'] as String?,
        item: json['item'] as String,
        percent: (json['percent'] as num).toInt(),
      );
}

/// A retailer sponsorship decision with item-level discounts.
class RetailerOffer {
  final String retailer;
  final String status; // "approved" or "rejected"
  final String? reason;
  final int? discountPercent;
  final List<RetailerOfferItem> discountedItems;

  RetailerOffer({
    required this.retailer,
    required this.status,
    this.reason,
    this.discountPercent,
    required this.discountedItems,
  });

  factory RetailerOffer.fromJson(Map<String, dynamic> json) => RetailerOffer(
    retailer: json['retailer'] as String,
    status: json['status'] as String,
    reason: json['reason'] as String?,
    discountPercent: (json['discountPercent'] as num?)?.toInt(),
    discountedItems:
        (json['discountedItems'] as List<dynamic>?)
            ?.map(
              (e) => RetailerOfferItem.fromJson(e as Map<String, dynamic>),
            )
            .toList() ??
        const [],
  );
}

/// type: "retailer_offers" — sponsorship decisions and discounts by retailer.
class RetailerOffersChunk implements OutputItemBase {
  @override
  final OutputItemType type;
  final List<RetailerOffer> offers;

  RetailerOffersChunk({OutputItemType? type, required this.offers})
    : type = type ?? OutputItemType.retailerOffers;

  factory RetailerOffersChunk.fromJson(Map<String, dynamic> json) =>
      RetailerOffersChunk(
        type: OutputItemType.retailerOffers,
        offers:
            (json['offers'] as List<dynamic>?)
                ?.map(
                  (e) => RetailerOffer.fromJson(e as Map<String, dynamic>),
                )
                .toList() ??
            const [],
      );
}

Duration _parseDeliveryTime(Map<String, dynamic> json) {
  final ms = json['deliveryTimeMs'] as int?;
  if (ms != null) return Duration(milliseconds: ms);
  final inner = json['deliveryTime'] as Map<String, dynamic>?;
  final innerMs = inner?['milliseconds'] as int?;
  return Duration(milliseconds: innerMs ?? 0);
}

final RegExp _quantitySuffix = RegExp(r'\s*\(x(\d+)\)\s*$', caseSensitive: false);

class CartItem {
  final String? id;
  final String name;
  final double price;
  final int amount;
  final String retailer;
  final double? reviewRating;
  final int reviewsCount;
  final Duration deliveryTime;
  final String? imageUrl;

  CartItem({
    this.id,
    required this.name,
    required this.price,
    required this.amount,
    required this.retailer,
    this.reviewRating,
    this.reviewsCount = 0,
    required this.deliveryTime,
    this.imageUrl,
  });

  factory CartItem.fromJson(Map<String, dynamic> json) {
    final normalized = _normalizeNameAndAmount(json);
    return CartItem(
      id: json['id'] as String?,
      name: normalized.name,
      price: (json['price'] as num).toDouble(),
      amount: normalized.amount,
      retailer: json['retailer'] as String,
      reviewRating: (json['reviewRating'] as num?)?.toDouble(),
      reviewsCount: (json['reviewsCount'] as num?)?.toInt() ?? 0,
      deliveryTime: _parseDeliveryTime(json),
      imageUrl: json['imageUrl'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
    if (id != null) 'id': id,
    'name': name,
    'price': price,
    'amount': amount,
    'retailer': retailer,
    if (reviewRating != null) 'reviewRating': reviewRating,
    'reviewsCount': reviewsCount,
    'deliveryTimeMs': deliveryTime.inMilliseconds,
    if (imageUrl != null) 'imageUrl': imageUrl,
  };
}

_CartItemNormalized _normalizeNameAndAmount(Map<String, dynamic> json) {
  final rawName = json['name'] as String;
  final int rawAmount = json['amount'] as int;
  final match = _quantitySuffix.firstMatch(rawName);
  if (match == null) {
    return _CartItemNormalized(name: rawName, amount: rawAmount);
  }
  final parsed = int.tryParse(match.group(1) ?? '');
  final cleaned = rawName.replaceAll(_quantitySuffix, '').trim();
  if (parsed == null) {
    return _CartItemNormalized(name: rawName, amount: rawAmount);
  }
  final int nextAmount = rawAmount <= 1 ? parsed : rawAmount;
  return _CartItemNormalized(name: cleaned, amount: nextAmount);
}

class _CartItemNormalized {
  const _CartItemNormalized({required this.name, required this.amount});
  final String name;
  final int amount;
}

/// Single item in the cart.
class RecommendedItem {
  CartItem main;
  CartItem cheapest;
  CartItem bestReviewed;
  CartItem fastest;

  RecommendedItem({
    required this.main,
    required this.cheapest,
    required this.bestReviewed,
    required this.fastest,
  });

  factory RecommendedItem.fromJson(Map<String, dynamic> json) {
    final Map<String, dynamic> mainJson =
        (json['recommendedItem'] ?? json['main']) as Map<String, dynamic>;
    final Map<String, dynamic> cheapestJson =
        (json['cheapestItem'] ?? json['cheapest']) as Map<String, dynamic>;
    final Map<String, dynamic> bestJson =
        (json['bestRatingItem'] ?? json['bestReviewed'])
            as Map<String, dynamic>;
    final Map<String, dynamic> fastestJson =
        (json['fastestDeliveryItem'] ?? json['fastest'])
            as Map<String, dynamic>;
    return RecommendedItem(
      main: CartItem.fromJson(mainJson),
      cheapest: CartItem.fromJson(cheapestJson),
      bestReviewed: CartItem.fromJson(bestJson),
      fastest: CartItem.fromJson(fastestJson),
    );
  }

  Map<String, dynamic> toJson() => {
    'main': main.toJson(),
    'cheapest': cheapest.toJson(),
    'bestReviewed': bestReviewed.toJson(),
    'fastest': fastest.toJson(),
  };
}

/// Chunk containing cart items and total price.
class CartChunk implements OutputItemBase {
  @override
  final OutputItemType type;
  final List<RecommendedItem> items;
  final double price;

  CartChunk({OutputItemType? type, required this.items, required this.price})
    : type = type ?? OutputItemType.cart;

  int get itemAmount => items.length;

  factory CartChunk.fromJson(Map<String, dynamic> json) => CartChunk(
    type: OutputItemType.cart,
    items:
        (json['items'] as List<dynamic>?)
            ?.map((e) => RecommendedItem.fromJson(e as Map<String, dynamic>))
            .toList() ??
        const [],
    price: (json['price'] as num?)?.toDouble() ?? 0,
  );

  Map<String, dynamic> toJson() => {
    'items': items.map((e) => e.toJson()).toList(),
    'price': price,
  };
}

/// Factory
OutputItemBase parseOutputItem(Map<String, dynamic> json) {
  final rawType = json['type'] as String? ?? '';
  final knownValues = OutputItemType.values
      .map((OutputItemType e) => e.jsonValue)
      .toSet();
  if (!knownValues.contains(rawType)) {
    return ErrorOutput(
      type: OutputItemType.error,
      message: 'Unknown output type: $rawType',
      code: 'UNKNOWN_TYPE',
    );
  }
  final type = OutputItemType.fromJson(rawType);
  switch (type) {
    // case OutputItemType.tool:
    // return ToolOutput.fromJson(json);
    // case OutputItemType.toolResult:
    // return ToolResultOutput.fromJson(json);
    case OutputItemType.text:
      return TextChunk.fromJson(json);
    // case OutputItemType.thinking:
    //   return ThinkingChunk.fromJson(json);
    // case OutputItemType.answer:
    //   return ApiAnswerOutput.fromJson(json);
    case OutputItemType.error:
      return ErrorOutput.fromJson(json);
    case OutputItemType.textForm:
      return TextFormChunk.fromJson(json);
    case OutputItemType.tree:
      return TreeChunk.fromJson(json);
    case OutputItemType.peopleTree:
      return _parseTreeTrunk(json, TreeType.people);
    case OutputItemType.placeTree:
      return _parseTreeTrunk(json, TreeType.place);
    case OutputItemType.cart:
      return CartChunk.fromJson(json);
    case OutputItemType.items:
      return ItemsChunk.fromJson(json);
    case OutputItemType.retailerOffers:
      return RetailerOffersChunk.fromJson(json);
  }
}

/// Parses a backend PeopleTreeTrunk / PlaceTreeTrunk into a frontend TreeChunk.
/// The backend sends `{ "type": "people_tree", "nodes": [...] }` where nodes
/// is a flat list of top-level TreeNodes. We wrap them in a synthetic root
/// Category so the existing UI can render them unchanged.
TreeChunk _parseTreeTrunk(Map<String, dynamic> json, TreeType treeType) {
  final List<Category> nodes =
      (json['nodes'] as List<dynamic>?)
          ?.map((e) => Category.fromJson(e as Map<String, dynamic>))
          .toList() ??
      const [];
  final String rootEmoji = treeType == TreeType.people ? '👥' : '📍';
  final String rootLabel = treeType == TreeType.people ? 'People' : 'Place';
  return TreeChunk(
    treeType: treeType,
    category: Category(
      emoji: rootEmoji,
      label: rootLabel,
      isSelected: false,
      subcategories: nodes,
    ),
  );
}
