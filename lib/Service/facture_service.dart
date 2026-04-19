import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/facture.dart';

class FactureService {
  static final _db = Supabase.instance.client;

  static Future<List<Facture>> getFactures(String projetId) async {
    final response = await _db
        .from('factures')
        .select()
        .eq('projet_id', projetId)
        .order('created_at', ascending: false);
    return (response as List)
        .map((j) => Facture.fromJson(j as Map<String, dynamic>))
        .toList();
  }

  static Future<void> addFacture(Facture f) async {
    await _db.from('factures').insert({
      'projet_id':      f.projetId,
      'numero':         f.numero,
      'montant':        f.montant,
      'statut':         f.statut,
      'date_echeance':  f.dateEcheance,
      'url_pdf':        f.urlPdf,
      'fournisseur':    f.fournisseur,
      'tache_associee': f.tacheAssociee,
      'chef_projet':    f.chefProjet,
    });
  }

  static Future<void> updateStatut(String id, String statut) async {
    await _db.from('factures').update({'statut': statut}).eq('id', id);
  }

  static Future<void> deleteFacture(String id) async {
    await _db.from('factures').delete().eq('id', id);
  }
}