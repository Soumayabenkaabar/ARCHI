import 'package:flutter/material.dart';
import '../constants/colors.dart';
import '../models/alert_item.dart';

class AlertCard extends StatelessWidget {
  final AlertItem alert;

  const AlertCard({super.key, required this.alert});

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 800;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: kCardBg,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFEEEEEE)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 4,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Icône
          Container(
            padding: const EdgeInsets.all(7),
            decoration: BoxDecoration(
              color: alert.bgColor,
              borderRadius: BorderRadius.circular(7),
            ),
            child: Icon(alert.icon, color: alert.iconColor, size: 15),
          ),

          const SizedBox(width: 8),

          // Texte + date
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  alert.text,
                  style: TextStyle(
                    color: alert.textColor,
                    fontSize: isMobile ? 12 : 13,
                    fontWeight: FontWeight.w500,
                    height: 1.4,
                  ),
                ),
                Text(
                  alert.date,
                  style: const TextStyle(color: kTextSub, fontSize: 11),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
