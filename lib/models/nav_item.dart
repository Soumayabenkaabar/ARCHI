import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';

class NavItem {
  final IconData lucideIcon;
  final String label;

  const NavItem(this.lucideIcon, this.label);
}

final List<NavItem> navItems = [
  const NavItem(LucideIcons.layoutDashboard, 'Dashboard'),
  const NavItem(LucideIcons.folder, 'Projets'),
  const NavItem(LucideIcons.user, 'Client'),
  const NavItem(LucideIcons.users, 'Équipe'),
  const NavItem(LucideIcons.barChart3, 'Analytics'),
  const NavItem(LucideIcons.mapPin, 'Carte'),
  const NavItem(LucideIcons.bell, 'Notifications'),
  const NavItem(LucideIcons.settings, 'Paramètres'),
];

// Index de l'item Notifications dans navItems
const int kNotifNavIndex = 6;
