import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../service/notification_service.dart';

enum NotifType { budget, retard, document, info, ia }

class AppNotification {
  final String id;
  final String message;
  final String projet;
  final String date;
  final String heure;
  final NotifType type;
  bool lue;

  AppNotification({
    required this.id,
    required this.message,
    required this.projet,
    required this.date,
    this.heure = '',
    required this.type,
    this.lue = false,
  });

  factory AppNotification.fromJson(Map<String, dynamic> j) => AppNotification(
    id:      j['id']?.toString() ?? '',
    message: j['message'] as String? ?? '',
    projet:  j['projet']  as String? ?? '',
    date:    j['date']    as String? ?? '',
    heure:   j['heure']   as String? ?? '',
    type:    NotifType.values.firstWhere(
      (t) => t.name == (j['type'] ?? 'info'),
      orElse: () => NotifType.info,
    ),
    lue: j['lue'] as bool? ?? false,
  );

  Color get typeColor {
    switch (type) {
      case NotifType.budget:   return const Color(0xFFEF4444);
      case NotifType.retard:   return const Color(0xFFF59E0B);
      case NotifType.document: return const Color(0xFF3B82F6);
      case NotifType.ia:       return const Color(0xFF8B5CF6);
      default:                 return const Color(0xFF6B7280);
    }
  }

  IconData get typeIcon {
    switch (type) {
      case NotifType.budget:   return LucideIcons.alertTriangle;
      case NotifType.retard:   return LucideIcons.clock;
      case NotifType.document: return LucideIcons.fileText;
      case NotifType.ia:       return LucideIcons.sparkles;
      default:                 return LucideIcons.bell;
    }
  }

  String get typeLabel {
    switch (type) {
      case NotifType.budget:   return 'Alerte budget';
      case NotifType.retard:   return 'Retard';
      case NotifType.document: return 'Document';
      case NotifType.ia:       return '✨ Analyse IA';
      default:                 return 'Info';
    }
  }
}

/// Envoie une alerte IA dans Supabase (fire-and-forget, sans await).
void addIaNotification(String message, String projet) {
  NotificationService.add(
    message: message,
    projet:  projet,
    type:    NotifType.ia,
  );
}
