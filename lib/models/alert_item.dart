import 'package:flutter/material.dart';
import '../constants/colors.dart';

class AlertItem {
  final IconData icon;
  final Color iconColor;
  final Color bgColor;
  final String text;
  final Color textColor;
  final String date;

  const AlertItem({
    required this.icon,
    required this.iconColor,
    required this.bgColor,
    required this.text,
    required this.textColor,
    required this.date,
  });
}

final List<AlertItem> sampleAlerts = [
  const AlertItem(
    icon: Icons.warning_rounded,
    iconColor: kRed,
    bgColor: kRedLight,
    text:
        "Dépassement budget de 5% sur 'Élévation des murs' - Villa Moderne Casablanca",
    textColor: kRed,
    date: '26/03/2026',
  ),
  const AlertItem(
    icon: Icons.warning_amber_outlined,
    iconColor: kAccent,
    bgColor: kAccentLight,
    text:
        "Retard de 3 jours prévu sur 'Fondations profondes' - Immeuble Résidentiel Rabat",
    textColor: kTextMain,
    date: '25/03/2026',
  ),
];
