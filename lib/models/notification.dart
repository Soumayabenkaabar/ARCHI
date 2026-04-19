import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';

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

// ── Données globales (en mémoire) ─────────────────────────────────────────────
final List<AppNotification> sampleNotifications = [
  AppNotification(
    id: 'n1',
    message: 'Le budget du projet Villa Riad dépasse 85% — vérifiez les dépenses.',
    projet:  'Villa Riad Marrakech',
    date:    '12/04/2026',
    heure:   '09:14',
    type:    NotifType.budget,
  ),
  AppNotification(
    id: 'n2',
    message: 'La tâche "Charpente et toiture" accuse 3 jours de retard.',
    projet:  'Immeuble Casablanca',
    date:    '11/04/2026',
    heure:   '16:42',
    type:    NotifType.retard,
  ),
  AppNotification(
    id: 'n3',
    message: 'Nouveau document ajouté : Plan architectural V3.pdf',
    projet:  'Villa Riad Marrakech',
    date:    '10/04/2026',
    heure:   '11:05',
    type:    NotifType.document,
    lue:     true,
  ),
];

/// Ajoute une alerte IA dans les notifications (déduplique par message)
void addIaNotification(String message, String projet) {
  // Éviter les doublons exacts
  final alreadyExists = sampleNotifications.any(
    (n) => n.type == NotifType.ia && n.message == message && n.projet == projet,
  );
  if (alreadyExists) return;

  final now = DateTime.now();
  final dateStr = '${now.day.toString().padLeft(2,'0')}/${now.month.toString().padLeft(2,'0')}/${now.year}';
  final heureStr = '${now.hour.toString().padLeft(2,'0')}:${now.minute.toString().padLeft(2,'0')}';

  sampleNotifications.insert(0, AppNotification(
    id:      'ia_${now.millisecondsSinceEpoch}',
    message: message,
    projet:  projet,
    date:    dateStr,
    heure:   heureStr,
    type:    NotifType.ia,
    lue:     false,
  ));
}