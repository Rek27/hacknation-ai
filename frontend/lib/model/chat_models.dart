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
  cart('cart');

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

/// type: "tool"
// class ToolOutput implements OutputItemBase {
//   @override
//   final OutputItemType type;
//   final String name;
//   final String? reason;
//   final Map<String, dynamic>? arguments;

//   ToolOutput({
//     required this.type,
//     required this.name,
//     this.reason,
//     this.arguments,
//   });

//   factory ToolOutput.fromJson(Map<String, dynamic> json) => ToolOutput(
//     type: OutputItemType.tool,
//     name: json['name'] as String,
//     reason: json['reason'] as String?,
//     arguments: json['arguments'] as Map<String, dynamic>?,
//   );
// }

/// type: "tool_result"
// class ToolResultOutput implements OutputItemBase {
//   @override
//   final OutputItemType type;
//   final String name;
//   final String result;
//   final bool success;

//   ToolResultOutput({
//     required this.type,
//     required this.name,
//     required this.result,
//     required this.success,
//   });

//   factory ToolResultOutput.fromJson(Map<String, dynamic> json) =>
//       ToolResultOutput(
//         type: OutputItemType.toolResult,
//         name: json['name'] as String,
//         result: json['result'] as String,
//         success: (json['success'] as bool?) ?? true,
//       );
// }

/// type: "text"
class TextChunk implements OutputItemBase {
  @override
  final OutputItemType type;
  final String content;

  TextChunk({required this.type, required this.content});

  factory TextChunk.fromJson(Map<String, dynamic> json) =>
      TextChunk(type: OutputItemType.text, content: json['content'] as String);
}

/// type: "thinking"
// class ThinkingChunk implements OutputItemBase {
//   @override
//   final OutputItemType type;
//   final String content;

//   ThinkingChunk({required this.type, required this.content});

//   factory ThinkingChunk.fromJson(Map<String, dynamic> json) => ThinkingChunk(
//     type: OutputItemType.thinking,
//     content: json['content'] as String,
//   );
// }

/// type: "answer"
// class ApiAnswerOutput implements OutputItemBase {
//   @override
//   final OutputItemType type;
//   final String content;
//   final Map<String, dynamic>? metadata;

//   ApiAnswerOutput({required this.type, required this.content, this.metadata});

//   factory ApiAnswerOutput.fromJson(Map<String, dynamic> json) =>
//       ApiAnswerOutput(
//         type: OutputItemType.answer,
//         content: json['content'] as String,
//         metadata: json['metadata'] as Map<String, dynamic>?,
//       );
// }

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
    isSelected: (json['selected'] as bool?) ?? false,
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

Duration _parseDeliveryTime(Map<String, dynamic> json) {
  final ms = json['deliveryTimeMs'] as int?;
  if (ms != null) return Duration(milliseconds: ms);
  final inner = json['deliveryTime'] as Map<String, dynamic>?;
  final innerMs = inner?['milliseconds'] as int?;
  return Duration(milliseconds: innerMs ?? 0);
}

class CartItem {
  final String? id;
  final String name;
  final double price;
  final int amount;
  final String retailer;
  final Duration deliveryTime;

  CartItem({
    this.id,
    required this.name,
    required this.price,
    required this.amount,
    required this.retailer,
    required this.deliveryTime,
  });

  factory CartItem.fromJson(Map<String, dynamic> json) => CartItem(
    id: json['id'] as String?,
    name: json['name'] as String,
    price: (json['price'] as num).toDouble(),
    amount: json['amount'] as int,
    retailer: json['retailer'] as String,
    deliveryTime: _parseDeliveryTime(json),
  );

  Map<String, dynamic> toJson() => {
    if (id != null) 'id': id,
    'name': name,
    'price': price,
    'amount': amount,
    'retailer': retailer,
    'deliveryTimeMs': deliveryTime.inMilliseconds,
  };
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

  factory RecommendedItem.fromJson(Map<String, dynamic> json) =>
      RecommendedItem(
        main: CartItem.fromJson(json['main'] as Map<String, dynamic>),
        cheapest: CartItem.fromJson(json['cheapest'] as Map<String, dynamic>),
        bestReviewed: CartItem.fromJson(
          json['bestReviewed'] as Map<String, dynamic>,
        ),
        fastest: CartItem.fromJson(json['fastest'] as Map<String, dynamic>),
      );

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
