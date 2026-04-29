import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';
import '../core/supabase_config.dart';
import '../models/client.dart'; // inclut ClientStats
import '../service/auth_service.dart';

class ClientService {
  static final _db = SupabaseConfig.client;

  // ─── GET CLIENTS ─────────────────────
  static Future<List<Client>> getClients() async {
    try {
      final data = await _db.from('clients').select('*, created_at');
      return (data as List).map((e) => Client.fromJson(e)).toList();
    } catch (e) {
      debugPrint("ERROR GET CLIENTS: $e");
      return [];
    }
  }

  // ─── PROJECT STATS PAR CLIENT ────────
  static Future<Map<String, ClientStats>> getProjectStats() async {
    try {
      final uid = AuthService.currentUser?.id;
      final query = uid != null
          ? _db.from('projets').select('client_id, statut').eq('user_id', uid)
          : _db.from('projets').select('client_id, statut');
      final data = await query as List;
      final result = <String, ClientStats>{};
      for (final p in data) {
        final cid = p['client_id']?.toString() ?? '';
        if (cid.isEmpty) continue;
        result.putIfAbsent(cid, ClientStats.new).add(p['statut'] as String? ?? '');
      }
      return result;
    } catch (e) {
      debugPrint("ERROR GET PROJECT STATS: $e");
      return {};
    }
  }

// Dans client_service.dart — remplace toute la méthode addClient

static Future<void> addClient(Client client) async {
  try {
    final json = Map<String, dynamic>.from(client.toJson());
    final uid = AuthService.currentUser?.id;
    json['user_id'] = uid;
    await _db.from('clients').insert(json);

    if (client.accesPortail == true && client.email.isNotEmpty) {
      // 1. Envoie l'invitation Supabase Auth
      await _inviteClient(client.email, client.nom);

      final trimEmail = client.email.trim().toLowerCase();

      // 2. Cherche un projet existant lié à ce client (par nom ou email)
      String? projetId;

      // Tentative par nom du client
      final byNom = await _db
          .from('projets')
          .select('id')
          .ilike('client', client.nom.trim())
          .eq('portail_client', true)
          .eq('user_id', uid ?? '')
          .limit(1);

      if ((byNom as List).isNotEmpty) {
        projetId = byNom.first['id'] as String;
      }

      // Tentative par email si pas trouvé par nom
      if (projetId == null) {
        final byEmail = await _db
            .from('projets')
            .select('id')
            .ilike('client', trimEmail)
            .eq('portail_client', true)
            .eq('user_id', uid ?? '')
            .limit(1);

        if ((byEmail as List).isNotEmpty) {
          projetId = byEmail.first['id'] as String;
        }
      }

      // 3. Vérifie si un accès existe déjà
      final existing = await _db
          .from('client_portal_access')
          .select('id, projet_id')
          .eq('client_email', trimEmail)
          .limit(1);

      if ((existing as List).isEmpty) {
        // Crée le nouvel accès avec projet_id si trouvé
        await _db.from('client_portal_access').insert({
          'client_nom':    client.nom,
          'client_email':  trimEmail,
          'password_hash': '',
          'actif':         client.accesPortail,
          'projet_id':     projetId, // null si aucun projet trouvé
        });
      } else {
        // Accès existant — met à jour projet_id si null
        final existingProjetId = existing.first['projet_id'];
        if (existingProjetId == null && projetId != null) {
          await _db
              .from('client_portal_access')
              .update({'projet_id': projetId, 'actif': true})
              .eq('id', existing.first['id']);
        }
      }
    }
  } catch (e) {
    debugPrint("ERROR ADD CLIENT: $e");
    rethrow;
  }
}
  // ─── UPDATE CLIENT ───────────
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
  // Dans projet_service.dart — dans updatePortailClient, après le update DB :

static Future<void> updatePortailClient(String projetId, bool value) async {
  await _db
      .from('projets')
      .update({'portail_client': value})
      .eq('id', projetId);

  // Si on active le portail, lie automatiquement l'accès existant
  if (value) {
    final projet = await _db
        .from('projets')
        .select('client, user_id')
        .eq('id', projetId)
        .single();

    final clientNom = (projet['client'] as String? ?? '').trim();
    if (clientNom.isNotEmpty) {
      // Cherche un accès sans projet_id pour ce nom de client
     final accesAll = await _db
    .from('client_portal_access')
    .select('id, projet_id')
    .ilike('client_nom', clientNom);

final acces = (accesAll as List)
    .where((a) => a['projet_id'] == null)
    .toList();

      if ((acces as List).isNotEmpty) {
        await _db
            .from('client_portal_access')
            .update({'projet_id': projetId})
            .eq('id', acces.first['id']);
      }
    }
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