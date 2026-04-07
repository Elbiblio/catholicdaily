import 'order_of_mass_item.dart';

class OrderOfMassSection {
  final String insertionPoint;
  final String title;
  final List<OrderOfMassItem> items;

  const OrderOfMassSection({
    required this.insertionPoint,
    required this.title,
    required this.items,
  });
}
