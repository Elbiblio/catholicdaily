import 'daily_reading.dart';
import '../services/order_of_mass_service.dart';

enum NavigableItemType {
  reading,
  orderOfMass,
}

class NavigableItem {
  final NavigableItemType type;
  final DailyReading? reading;
  final ResolvedOrderOfMassItem? orderOfMassItem;
  final String? insertionPoint;
  final int? order;

  const NavigableItem({
    required this.type,
    this.reading,
    this.orderOfMassItem,
    this.insertionPoint,
    this.order,
  });

  factory NavigableItem.fromReading(DailyReading reading) {
    return NavigableItem(
      type: NavigableItemType.reading,
      reading: reading,
    );
  }

  factory NavigableItem.fromOrderOfMass(
    ResolvedOrderOfMassItem item,
    String insertionPoint,
  ) {
    return NavigableItem(
      type: NavigableItemType.orderOfMass,
      orderOfMassItem: item,
      insertionPoint: insertionPoint,
      order: item.order,
    );
  }

  String get title {
    switch (type) {
      case NavigableItemType.reading:
        return reading?.position ?? 'Reading';
      case NavigableItemType.orderOfMass:
        return orderOfMassItem?.title ?? 'Prayer';
    }
  }

  String get reference {
    switch (type) {
      case NavigableItemType.reading:
        return reading?.reading ?? '';
      case NavigableItemType.orderOfMass:
        return orderOfMassItem?.id ?? '';
    }
  }

  bool get isReading => type == NavigableItemType.reading;
  bool get isOrderOfMass => type == NavigableItemType.orderOfMass;
}
