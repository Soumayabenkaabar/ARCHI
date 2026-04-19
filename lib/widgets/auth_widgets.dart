import 'package:flutter/material.dart';
import 'dart:ui';

/// 🔥 GLASS CONTAINER (mobile seulement)
Widget glassContainer({required Widget child}) {
  return ClipRRect(
    borderRadius: BorderRadius.circular(20),
    child: BackdropFilter(
      filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
      child: Container(
        width: double.infinity, // ok
        constraints: BoxConstraints(maxWidth: 450),
        padding: EdgeInsets.all(30),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.15),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.white.withOpacity(0.2)),
        ),
        child: child,
      ),
    ),
  );
}
