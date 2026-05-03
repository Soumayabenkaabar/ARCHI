import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../constants/colors.dart';
import '../models/notification.dart';
import '../service/notification_service.dart';

class NotificationsScreen extends StatefulWidget {
  final VoidCallback? onNotifChanged;
  const NotificationsScreen({super.key, this.onNotifChanged});
  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  List<AppNotification> _notifications = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final data = await NotificationService.getAll();
      if (mounted) setState(() { _notifications = data; _loading = false; });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _markAllRead() async {
    try {
      await NotificationService.markAllAsRead();
      await _load();
      widget.onNotifChanged?.call();
    } catch (e) {
      _snack('Erreur : $e');
    }
  }

  Future<void> _markRead(String id) async {
    setState(() {
      final n = _notifications.firstWhere((n) => n.id == id);
      n.lue = true;
    });
    try {
      await NotificationService.markAsRead(id);
      widget.onNotifChanged?.call();
    } catch (e) {
      _snack('Erreur : $e');
    }
  }

  Future<void> _delete(String id) async {
    setState(() => _notifications.removeWhere((n) => n.id == id));
    try {
      await NotificationService.delete(id);
      widget.onNotifChanged?.call();
    } catch (e) {
      _snack('Erreur : $e');
      await _load();
    }
  }

  void _clearAll() {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        title: const Text('Tout effacer ?', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
        content: const Text('Toutes les notifications seront supprimées.', style: TextStyle(color: kTextSub, fontSize: 13)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Annuler')),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              setState(() => _notifications.clear());
              try {
                await NotificationService.clearAll();
                widget.onNotifChanged?.call();
              } catch (e) {
                _snack('Erreur : $e');
                await _load();
              }
            },
            child: const Text('Effacer tout', style: TextStyle(color: kRed, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }

  void _snack(String msg) {
    showDialog(
      context: context,
      builder: (dctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        content: Row(children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(color: kRed.withOpacity(0.12), shape: BoxShape.circle),
            child: const Icon(Icons.error_outline_rounded, color: kRed, size: 24),
          ),
          const SizedBox(width: 12),
          Flexible(child: Text(msg, style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 14))),
        ]),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dctx),
            child: const Text('OK', style: TextStyle(color: kRed, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }


  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 800;
    final pad = isMobile ? 16.0 : 28.0;

    final nonLues   = _notifications.where((n) => !n.lue).toList();
    final lues      = _notifications.where((n) => n.lue).toList();
    final nbNonLues = nonLues.length;

    return Container(
      color: kBg,
      child: _loading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: EdgeInsets.fromLTRB(pad, pad, pad, pad + 20),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

                // ── Header ──────────────────────────────────────────────────
                Row(children: [
                  const Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('Centre de notifications', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800, color: kTextMain)),
                    SizedBox(height: 4),
                    Text('Restez informé des alertes et activités importantes', style: TextStyle(color: kTextSub, fontSize: 13)),
                  ])),
                  IconButton(
                    onPressed: _load,
                    tooltip: 'Actualiser',
                    icon: const Icon(LucideIcons.refreshCw, size: 18, color: kTextSub),
                  ),
                  if (nbNonLues > 0) ...[
                    OutlinedButton.icon(
                      onPressed: _markAllRead,
                      icon: const Icon(LucideIcons.checkCircle, size: 14, color: kAccent),
                      label: Text(isMobile ? 'Tout lu' : 'Tout marquer comme lu', style: const TextStyle(color: kAccent, fontSize: 12, fontWeight: FontWeight.w600)),
                      style: OutlinedButton.styleFrom(
                        padding: EdgeInsets.symmetric(horizontal: isMobile ? 10 : 14, vertical: 9),
                        side: const BorderSide(color: kAccent),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                    ),
                    const SizedBox(width: 8),
                  ],
                  OutlinedButton.icon(
                    onPressed: _notifications.isEmpty ? null : _clearAll,
                    icon: const Icon(LucideIcons.trash2, size: 14, color: kRed),
                    label: Text(isMobile ? '' : 'Tout effacer', style: const TextStyle(color: kRed, fontSize: 12, fontWeight: FontWeight.w600)),
                    style: OutlinedButton.styleFrom(
                      padding: EdgeInsets.symmetric(horizontal: isMobile ? 10 : 14, vertical: 9),
                      side: const BorderSide(color: kRed),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                  ),
                ]),

                const SizedBox(height: 24),

                const SizedBox(height: 8),

                // ── Non lues ─────────────────────────────────────────────────
                if (nonLues.isNotEmpty) ...[
                  Row(children: [
                    const Icon(Icons.warning_amber_rounded, color: kRed, size: 18),
                    const SizedBox(width: 8),
                    Text('Non lues (${nonLues.length})', style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: kTextMain)),
                  ]),
                  const SizedBox(height: 12),
                  ...nonLues.map((n) => Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: _NotifCard(notif: n, onMarkRead: () => _markRead(n.id), onDelete: () => _delete(n.id)),
                  )),
                  const SizedBox(height: 20),
                ],

                // ── Lues ─────────────────────────────────────────────────────
                if (lues.isNotEmpty) ...[
                  Row(children: [
                    const Icon(Icons.check_circle_outline_rounded, color: kTextSub, size: 18),
                    const SizedBox(width: 8),
                    Text('Lues (${lues.length})', style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: kTextMain)),
                  ]),
                  const SizedBox(height: 12),
                  ...lues.map((n) => Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: _NotifCard(notif: n, onMarkRead: null, onDelete: () => _delete(n.id)),
                  )),
                ],

                // ── Vide ─────────────────────────────────────────────────────
                if (_notifications.isEmpty)
                  Center(child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 60),
                    child: Column(children: [
                      Container(
                        width: 64, height: 64,
                        decoration: BoxDecoration(color: const Color(0xFFF3F4F6), borderRadius: BorderRadius.circular(16)),
                        child: const Icon(LucideIcons.bellOff, size: 28, color: kTextSub),
                      ),
                      const SizedBox(height: 14),
                      const Text('Aucune notification', style: TextStyle(color: kTextMain, fontSize: 15, fontWeight: FontWeight.w600)),
                      const SizedBox(height: 4),
                      const Text('Tout est à jour !', style: TextStyle(color: kTextSub, fontSize: 13)),
                    ]),
                  )),
              ]),
            ),
    );
  }
}

// ── Stat Card ─────────────────────────────────────────────────────────────────
class _StatCard extends StatelessWidget {
  final String label, value; final IconData icon; final Color color;
  const _StatCard({required this.label, required this.value, required this.icon, required this.color});

  @override
  Widget build(BuildContext context) => Container(
    width: 140,
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(12),
      border: Border(left: BorderSide(color: color, width: 3)),
      boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 6, offset: const Offset(0, 2))],
    ),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        Expanded(child: Text(label, style: const TextStyle(color: kTextSub, fontSize: 11, fontWeight: FontWeight.w500), overflow: TextOverflow.ellipsis)),
        Icon(icon, color: color, size: 16),
      ]),
      const SizedBox(height: 8),
      Text(value, style: TextStyle(fontSize: 26, fontWeight: FontWeight.w800, color: color)),
    ]),
  );
}

// ── Notification Card ─────────────────────────────────────────────────────────
class _NotifCard extends StatelessWidget {
  final AppNotification notif;
  final VoidCallback? onMarkRead;
  final VoidCallback onDelete;
  const _NotifCard({required this.notif, required this.onMarkRead, required this.onDelete});

  @override
  Widget build(BuildContext context) {
    final isLue = notif.lue;
    final color = notif.typeColor;
    final isIA  = notif.type == NotifType.ia;

    return Container(
      decoration: BoxDecoration(
        color: isIA && !isLue ? const Color(0xFFFAF5FF) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border(left: BorderSide(color: isLue ? const Color(0xFFE5E7EB) : color, width: 3)),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(isLue ? 0.02 : 0.05), blurRadius: 6, offset: const Offset(0, 2))],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          // Icône
          Container(
            width: 38, height: 38,
            decoration: BoxDecoration(color: color.withOpacity(isLue ? 0.07 : 0.13), borderRadius: BorderRadius.circular(10)),
            child: Icon(notif.typeIcon, color: isLue ? color.withOpacity(0.5) : color, size: 18),
          ),
          const SizedBox(width: 14),
          // Contenu
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(color: color.withOpacity(isLue ? 0.07 : 0.13), borderRadius: BorderRadius.circular(20)),
              child: Text(notif.typeLabel, style: TextStyle(color: isLue ? color.withOpacity(0.6) : color, fontSize: 11, fontWeight: FontWeight.w700)),
            ),
            const SizedBox(height: 8),
            Text(notif.message, style: TextStyle(color: isLue ? kTextSub : kTextMain, fontSize: 13, fontWeight: isLue ? FontWeight.w400 : FontWeight.w500, height: 1.4)),
            const SizedBox(height: 6),
            Text('— ${notif.projet}', style: TextStyle(color: isLue ? kTextSub : color, fontSize: 12, fontWeight: FontWeight.w500)),
            const SizedBox(height: 5),
            Row(children: [
              Text(notif.date, style: const TextStyle(color: kTextSub, fontSize: 11)),
              if (notif.heure.isNotEmpty) ...[
                const Text(' · ', style: TextStyle(color: kTextSub, fontSize: 11)),
                Text(notif.heure, style: const TextStyle(color: kTextSub, fontSize: 11)),
              ],
            ]),
          ])),
          const SizedBox(width: 8),
          // Actions
          Column(children: [
            if (onMarkRead != null) ...[
              GestureDetector(
                onTap: onMarkRead,
                child: Tooltip(
                  message: 'Marquer comme lu',
                  child: Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(color: kBg, borderRadius: BorderRadius.circular(6)),
                    child: const Icon(Icons.check_circle_outline_rounded, size: 17, color: kTextSub),
                  ),
                ),
              ),
              const SizedBox(height: 6),
            ],
            GestureDetector(
              onTap: onDelete,
              child: Tooltip(
                message: 'Supprimer',
                child: Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(color: kBg, borderRadius: BorderRadius.circular(6)),
                  child: const Icon(Icons.delete_outline_rounded, size: 17, color: kRed),
                ),
              ),
            ),
          ]),
        ]),
      ),
    );
  }
}
