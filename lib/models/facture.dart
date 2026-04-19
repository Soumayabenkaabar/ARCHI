class Facture {
  final String  id;
  final String  projetId;
  final String? phaseId;        // ← phase associée
  final String  numero;
  final double  montant;
  final String  statut;
  final String? dateEcheance;
  final String? urlPdf;
  final String  fournisseur;
  final String  tacheAssociee;
  final String  chefProjet;
  final String  createdAt;

  const Facture({
    required this.id,
    required this.projetId,
    this.phaseId,
    required this.numero,
    required this.montant,
    required this.statut,
    this.dateEcheance,
    this.urlPdf,
    this.fournisseur   = '',
    this.tacheAssociee = '',
    this.chefProjet    = '',
    this.createdAt     = '',
  });

  factory Facture.fromJson(Map<String, dynamic> j) => Facture(
    id:            j['id']             as String? ?? '',
    projetId:      j['projet_id']      as String? ?? '',
    phaseId:       j['phase_id']       as String?,
    numero:        j['numero']         as String? ?? '',
    montant:       (j['montant']       as num?)?.toDouble() ?? 0,
    statut:        j['statut']         as String? ?? 'en_attente',
    dateEcheance:  j['date_echeance']  as String?,
    urlPdf:        j['url_pdf']        as String?,
    fournisseur:   j['fournisseur']    as String? ?? '',
    tacheAssociee: j['tache_associee'] as String? ?? '',
    chefProjet:    j['chef_projet']    as String? ?? '',
    createdAt:     j['created_at']     as String? ?? '',
  );

  String get statutLabel {
    switch (statut) {
      case 'payee':     return 'Payée';
      case 'en_retard': return 'En retard';
      default:          return 'En attente';
    }
  }
}