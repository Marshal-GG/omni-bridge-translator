import 'package:flutter/material.dart';

class GlobalNavigator {
  static final GlobalKey<NavigatorState> key = GlobalKey<NavigatorState>();

  static BuildContext? get context => key.currentContext;

  static Future<void> pushReplacementNamed(String routeName, {Object? arguments}) async {
    await key.currentState?.pushReplacementNamed(routeName, arguments: arguments);
  }

  static Future<void> pushNamedAndRemoveUntil(String routeName, RoutePredicate predicate, {Object? arguments}) async {
    await key.currentState?.pushNamedAndRemoveUntil(routeName, predicate, arguments: arguments);
  }

  static void pop() {
    key.currentState?.pop();
  }
}
