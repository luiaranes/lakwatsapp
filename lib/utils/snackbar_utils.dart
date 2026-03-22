import 'package:flutter/material.dart';

class SnackBarUtils {
  static void show(
    BuildContext context,
    String message, {
    Color? backgroundColor,
    Duration duration = const Duration(seconds: 2),
    SnackBarAction? action,
  }) {
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: backgroundColor,
          behavior: SnackBarBehavior.floating,
          duration: duration,
          action: action,
        ),
      );
  }

  static void showSuccess(BuildContext context, String message) {
    show(context, message, backgroundColor: Colors.green);
  }

  static void showError(BuildContext context, String message) {
    show(context, message, backgroundColor: Colors.red);
  }

  static void showInfo(BuildContext context, String message) {
    show(context, message);
  }
}
