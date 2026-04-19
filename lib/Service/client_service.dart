import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';
import '../core/supabase_config.dart';
import '../models/client.dart';
import '../service/auth_service.dart';

class ClientService {
  static final _db = SupabaseConfig.client;

  // ─── GET CLIENTS ─────────────────────
  static Future<List<Client>> getClients() async {
    try {
      final data = await _db.from('clients').select();
      return (data as List).map((e) => Client.fromJson(e)).toList();
    } catch (e) {
      debugPrint("ERROR GET CLIENTS: $e");
      return [];
    }
  }

  // ─── ADD CLIENT ─────────────────────
// Dans ClientService.addClient(), après l'insert :
static Future<void> addClient(Client client) async {
  try {
    final json = Map<String, dynamic>.from(client.toJson());
    json['user_id'] = AuthService.currentUser?.id;
    await _db.from('clients').insert(json);

    if (client.accesPortail == true && client.email.isNotEmpty) {
      // 1. Envoie l'invitation Supabase Auth (Edge Function)
      await _inviteClient(client.email, client.nom);

      // 2. Crée la ligne dans client_portal_access
      // ⚠️ Il faut le projet_id — à passer en paramètre ou récupérer après
      // Pour l'instant on crée sans projet, à lier manuellement
      final existing = await _db
          .from('client_portal_access')
          .select('id')
          .eq('client_email', client.email.trim().toLowerCase())
          .limit(1);

      if (existing.isEmpty) {
        await _db.from('client_portal_access').insert({
          'client_nom':   client.nom,
          'client_email': client.email.trim().toLowerCase(),
          'password_hash': '',
          'actif': client.accesPortail,
          'projet_id': null, // à lier manuellement au projet
        });
      }
    }
  } catch (e) {
    debugPrint("ERROR ADD CLIENT: $e");
    rethrow;
  }
}

  // ─── UPDATE CLIENT ──────────────────
  static Future<void> updateClient(Client client) async {
    try {
      if (client.id.isEmpty) throw Exception("ID client invalide");

      await _db
          .from('clients')
          .update(client.toJson())
          .eq('id', client.id);

    } catch (e) {
      debugPrint("ERROR UPDATE CLIENT: $e");
      rethrow;
    }
  }

  // ─── DELETE CLIENT ──────────────────
  static Future<void> deleteClient(String id) async {
    try {
      await _db.from('clients').delete().eq('id', id);
    } catch (e) {
      debugPrint("ERROR DELETE CLIENT: $e");
      rethrow;
    }
  }

  // ─── INVITE CLIENT (EMAIL SIMPLE) ───
// ─── INVITE CLIENT ───────────────────────────────────────────────

static Future<void> _inviteClient(String email, String nom) async {
  try {
    final res = await http.post(
      Uri.parse("https://ngcnfbbeefsbynknvogm.supabase.co/functions/v1/send-welcome-email"),
      headers: {
        "Content-Type": "application/json",
        "Authorization": "Bearer ${SupabaseConfig.client.auth.currentSession?.accessToken ?? ''}",
      },
      body: jsonEncode({
        "email": email.trim(),
        "name": nom,
      }),
    );
    debugPrint(res.statusCode == 200 ? "✅ Invitation envoyée" : "❌ ${res.body}");
  } catch (e) {
    debugPrint("❌ ERROR: $e");
  }
}
  // ─── PASSWORD ───────────────────────
  static String _generateTempPassword(String email) {
    final prefix = email.split('@').first;
    final short = prefix.length < 4 ? prefix : prefix.substring(0, 4);
    return 'Client@${short}2024!';
  }

  static String getTempPassword(String email) =>
      _generateTempPassword(email);
}