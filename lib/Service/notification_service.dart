
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/notification.dart';
import 'auth_service.dart';

class NotificationService {
  static final _db = Supabase.instance.client;
  static String? get _uid => AuthService.currentUser?.id;

  static Future<List<AppNotification>> getAll() async {
    if (_uid == null) return [];
    final data = await _db
        .from('notifications')
        .select()
        .eq('user_id', _uid!)
        .order('created_at', ascending: false);
    return (data as List).map((e) => AppNotification.fromJson(e)).toList();
  }

  static Future<int> getUnreadCount() async {
    if (_uid == null) return 0;
    final data = await _db
        .from('notifications')
        .select('id')
        .eq('user_id', _uid!)
        .eq('lue', false);
    return (data as List).length;
  }

  static Future<void> markAsRead(String id) async {
    await _db.from('notifications').update({'lue': true}).eq('id', id);
  }

  static Future<void> markAllAsRead() async {
    if (_uid == null) return;
    await _db.from('notifications')
        .update({'lue': true})
        .eq('user_id', _uid!)
        .eq('lue', false);
  }

  static Future<void> delete(String id) async {
    await _db.from('notifications').delete().eq('id', id);
  }

  static Future<void> clearAll() async {
    if (_uid == null) return;
    await _db.from('notifications').delete().eq('user_id', _uid!);
  }

  static Future<void> add({
    required String message,
    required String projet,
    required NotifType type,
  }) async {
    if (_uid == null) return;
    final now = DateTime.now();
    final date  = '${now.day.toString().padLeft(2,'0')}/${now.month.toString().padLeft(2,'0')}/${now.year}';
    final heure = '${now.hour.toString().padLeft(2,'0')}:${now.minute.toString().padLeft(2,'0')}';
    await _db.from('notifications').insert({
      'user_id': _uid,
      'message': message,
      'projet':  projet,
      'date':    date,
      'heure':   heure,
      'type':    type.name,
      'lue':     false,
    });
  }
}
