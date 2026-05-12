/// Order model for Cafe De Paris
enum OrderStatus { newOrder, preparing, ready, served, awaitingPayment }

class OrderItem {
  final String name;
  final int quantity;

  const OrderItem({required this.name, required this.quantity});

  factory OrderItem.fromJson(Map<String, dynamic> json) {
    return OrderItem(
      name: json['name'] as String? ?? 'Item',
      quantity: json['quantity'] as int? ?? 1,
    );
  }

  Map<String, dynamic> toJson() => {'name': name, 'quantity': quantity};
}

class Order {
  final String id;
  final String tableId;
  final String tableName;
  final String menuItemId; // Added this
  final OrderStatus status;
  final List<OrderItem> items;
  final DateTime createdAt;

  const Order({
    required this.id,
    required this.tableId,
    required this.tableName,
    required this.menuItemId, // Added this
    required this.status,
    required this.items,
    required this.createdAt,
  });

  factory Order.fromJson(Map<String, dynamic> json) {
    final statusStr = json['status'] as String? ?? 'new';
    OrderStatus status;
    switch (statusStr.toLowerCase()) {
      case 'new': status = OrderStatus.newOrder; break;
      case 'preparing': status = OrderStatus.preparing; break;
      case 'ready': case 'ready_to_serve': status = OrderStatus.ready; break;
      case 'served': case 'eating': status = OrderStatus.served; break;
      case 'awaiting_payment': status = OrderStatus.awaitingPayment; break;
      default: status = OrderStatus.preparing;
    }

    final menuItemName = json['menu_item'] as String? ?? 'Unknown Item';
    final quantity = json['quantity'] as int? ?? 1;
    final tableNum = json['table_number']?.toString() ?? '0';
    final mId = json['menu_item_id']?.toString() ?? ''; // Extract this

    return Order(
      id: json['id']?.toString() ?? '',
      tableId: tableNum,
      tableName: 'Table $tableNum',
      menuItemId: mId, // Map this
      status: status,
      items: [OrderItem(name: menuItemName, quantity: quantity)],
      createdAt: DateTime.tryParse(json['ordered_at'] ?? '') ?? DateTime.now(),
    );
  }

  String get itemsSummary => items.map((i) => '${i.quantity}× ${i.name}').join(', ');
}

