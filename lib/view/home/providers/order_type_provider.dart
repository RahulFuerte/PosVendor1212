import 'package:flutter/material.dart';

enum OrderType { dineIn, pickUp, delivery }

class OrderTypeProvider extends ChangeNotifier {
  OrderType _selected = OrderType.dineIn;

  OrderType get selected => _selected;

  void setOrderType(OrderType type) {
    if (_selected == type) return;
    _selected = type;
    notifyListeners();
  }
}
