/// Table model for Cafe De Paris
enum TableStatus { available, ordered, preparing, ready, eating, billing, billed }

class TableModel {
  final String id;
  final String name;
  final int number; // Added this
  final TableStatus status;
  final int seats;

  const TableModel({
    required this.id,
    required this.name,
    required this.number, // Added this
    required this.status,
    this.seats = 4,
  });

  factory TableModel.fromJson(Map<String, dynamic> json) {
    final num = json['number'] as int? ?? 0;
    return TableModel(
      id: json['id']?.toString() ?? '',
      number: num,
      name: num > 0 ? 'Table $num' : (json['name'] as String? ?? 'Table'),
      status: _parseStatus(json['status'] as String? ?? 'available'),
      seats: json['seats'] as int? ?? 4,
    );
  }


  static TableStatus _parseStatus(String s) {
    switch (s.toLowerCase().trim()) {
      case 'available': return TableStatus.available;
      case 'new': case 'new_order': case 'ordered': case 'ordering': return TableStatus.ordered;
      case 'preparing': return TableStatus.preparing;
      case 'ready': case 'ready_to_serve': return TableStatus.ready;
      case 'eating': case 'served': return TableStatus.eating;
      case 'billing': return TableStatus.billing;
      case 'billed': return TableStatus.billed;
      default: return TableStatus.available;
    }
  }

  String get statusLabel {
    switch (status) {
      case TableStatus.available: return 'Available';
      case TableStatus.ordered: return 'Ordered';
      case TableStatus.preparing: return 'Preparing';
      case TableStatus.ready: return 'Ready';
      case TableStatus.eating: return 'Eating';
      case TableStatus.billing: return 'Billing';
      case TableStatus.billed: return 'Billed';
    }
  }
}
