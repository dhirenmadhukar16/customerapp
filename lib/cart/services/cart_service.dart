import 'package:flutter/foundation.dart';

class CartService extends ChangeNotifier {
  static final CartService instance = CartService._();
  CartService._();

  final Map<String, int> quantities = {};
  List<dynamic> allServices = []; 
  // map from uniqueId (catalogId_variantName) to the variant data
  final Map<String, Map<String, dynamic>> _addedItems = {};

  void setServices(List<dynamic> services) {
    if (allServices.isEmpty) {
      allServices = services;
    }
  }

  void addVariant(String catalogId, Map<String, dynamic> service, Map<String, dynamic> variant) {
    String variantName = variant['variantName'] ?? 'Standard';
    String id = '${catalogId}_$variantName';
    
    if (!_addedItems.containsKey(id)) {
      _addedItems[id] = {
        'catalogId': catalogId,
        'serviceType': service['serviceType'] ?? service['categoryName'] ?? 'Misc',
        'itemName': service['itemName'],
        'variantName': variantName,
        'price': variant['price'] ?? service['price'] ?? 0.0,
      };
    }
    increase(id);
  }

  void increase(String id) {
    quantities[id] = (quantities[id] ?? 0) + 1;
    notifyListeners();
  }

  void decrease(String id) {
    final current = quantities[id] ?? 0;
    if (current <= 1) {
      quantities.remove(id);
      _addedItems.remove(id);
    } else {
      quantities[id] = current - 1;
    }
    notifyListeners();
  }

  double get subtotal {
    double total = 0;
    for (final entry in quantities.entries) {
      final item = _addedItems[entry.key];
      if (item != null) {
        total += (item['price'] as double) * entry.value;
      }
    }
    return total;
  }

  double get gst => subtotal * 0.18;
  double get total => subtotal + gst;

  int get totalItems {
    return quantities.values.fold(0, (sum, qty) => sum + qty);
  }

  List<Map<String, dynamic>> get selectedItems {
    return _addedItems.entries.map((e) {
      final id = e.key;
      final item = e.value;
      return {
        'catalogId': item['catalogId'],
        'serviceType': item['serviceType'],
        'itemName': item['itemName'],
        'variantName': item['variantName'],
        'price': item['price'],
        'quantity': quantities[id] ?? 0,
        'cartId': id,
      };
    }).toList();
  }

  void clear() {
    quantities.clear();
    _addedItems.clear();
    notifyListeners();
  }
}

