// lib/models/facture.dart
// ══════════════════════════════════════════════════════════════════════════════
//  Modèle Facture — avec champ factureType ('initiale' | 'extra')
// ══════════════════════════════════════════════════════════════════════════════

class Facture {
  final String  id;
  final String  projetId;
  final String? phaseId;
  final String  numero;
  final double  montant;
  final String  statut;         // 'en_attente' | 'payee' | 'en_retard'
  final String? dateEcheance;
  final String? urlPdf;
  final String  fournisseur;
  final String  tacheAssociee;
  final String  chefProjet;
  final String  createdAt;
  final String? factureType;    // ← NOUVEAU : 'initiale' | 'extra'

  const Facture({
    required this.id,
    required this.projetId,
    this.phaseId,
    required this.numero,
    required this.montant,
    required this.statut,
    this.dateEcheance,
    this.urlPdf,
    required this.fournisseur,
    required this.tacheAssociee,
    required this.chefProjet,
    required this.createdAt,
    this.factureType,           // ← NOUVEAU (nullable, défaut null = 'extra')
  });

  factory Facture.fromJson(Map<String, dynamic> json) {
    return Facture(
      id:            json['id']              as String? ?? '',
      projetId:      json['projet_id']       as String? ?? '',
      phaseId:       json['phase_id']        as String?,
      numero:        json['numero']          as String? ?? '',
      montant:       (json['montant'] as num?)?.toDouble() ?? 0.0,
      statut:        json['statut']          as String? ?? 'en_attente',
      dateEcheance:  json['date_echeance']   as String?,
      urlPdf:        json['url_pdf']         as String?,
      fournisseur:   json['fournisseur']     as String? ?? '',
      tacheAssociee: json['tache_associee']  as String? ?? '',
      chefProjet:    json['chef_projet']     as String? ?? '',
      createdAt:     json['created_at']      as String? ?? '',
      factureType:   json['facture_type']    as String?,  // ← NOUVEAU
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'projet_id':      projetId,
      if (phaseId != null) 'phase_id': phaseId,
      'numero':         numero,
      'montant':        montant,
      'statut':         statut,
      if (dateEcheance != null) 'date_echeance': dateEcheance,
      if (urlPdf != null) 'url_pdf': urlPdf,
      'fournisseur':    fournisseur,
      'tache_associee': tacheAssociee,
      'chef_projet':    chefProjet,
      'facture_type':   factureType,  // ← NOUVEAU
    };
  }

  Facture copyWith({
    String?  id,
    String?  projetId,
    String?  phaseId,
    String?  numero,
    double?  montant,
    String?  statut,
    String?  dateEcheance,
    String?  urlPdf,
    String?  fournisseur,
    String?  tacheAssociee,
    String?  chefProjet,
    String?  createdAt,
    String?  factureType,
  }) {
    return Facture(
      id:            id            ?? this.id,
      projetId:      projetId      ?? this.projetId,
      phaseId:       phaseId       ?? this.phaseId,
      numero:        numero        ?? this.numero,
      montant:       montant       ?? this.montant,
      statut:        statut        ?? this.statut,
      dateEcheance:  dateEcheance  ?? this.dateEcheance,
      urlPdf:        urlPdf        ?? this.urlPdf,
      fournisseur:   fournisseur   ?? this.fournisseur,
      tacheAssociee: tacheAssociee ?? this.tacheAssociee,
      chefProjet:    chefProjet    ?? this.chefProjet,
      createdAt:     createdAt     ?? this.createdAt,
      factureType:   factureType   ?? this.factureType,
    );
  }
}