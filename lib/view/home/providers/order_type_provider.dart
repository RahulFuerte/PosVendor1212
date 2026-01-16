import 'package:flutter/material.dart';

enum OrderType { dineIn, pickUp, delivery }

enum PaymentType { cash, upi, debit, complementory }

class OrderTypeProvider extends ChangeNotifier {
  OrderType _orderType = OrderType.dineIn;
  PaymentType _paymentType = PaymentType.cash;

  OrderType get orderType => _orderType;
  PaymentType get paymentType => _paymentType;

  void setOrderType(OrderType type) {
    if (_orderType == type) return;
    _orderType = type;
    notifyListeners();
  }

  void setPaymentType(PaymentType type) {
    if (_paymentType == type) return;
    _paymentType = type;
    notifyListeners();
  }
}