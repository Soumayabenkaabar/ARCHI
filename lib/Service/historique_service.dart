import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/historique_tache.dart';

class HistoriqueService {
  static final _db = Supabase.instance.client;

  static Future<void> addEvenement({
    required String tacheId,
    required String projetId,
    required String evenement,
    String? statutAvant,
    String? statutApres,
  }) async {
    await _db.from('tache_historique').insert({
      'tache_id':     tacheId,
      'projet_id':    projetId,
      'evenement':    evenement,
      'statut_avant': statutAvant,
      'statut_apres': statutApres,
    });
  }

  static Future<List<HistoriqueTache>> getHistorique(String tacheId) async {
    final data = await _db
        .from('tache_historique')
        .select()
        .eq('tache_id', tacheId)
        .order('created_at', ascending: false);
    return (data as List)
        .map((j) => HistoriqueTache.fromJson(j as Map<String, dynamic>))
        .toList();
  }
}
