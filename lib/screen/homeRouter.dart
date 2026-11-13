import 'package:flutter/material.dart';

import '../services/auth_service.dart';
import 'businessMainScreen.dart';
import 'mainScreen.dart';

// Customers get the shop, business accounts get the management panel.
Future<Widget> resolveHome() async {
  try {
    if (await AuthService().isBusiness()) return const BusinessMainScreen();
  } catch (_) {
    // Fall back to the customer experience if the profile can't be read.
  }
  return const MainScreen();
}
