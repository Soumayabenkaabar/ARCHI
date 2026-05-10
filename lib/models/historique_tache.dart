class HistoriqueTache {
  final String  id;
  final String  tacheId;
  final String  projetId;
  final String  evenement;
  final String? statutAvant;
  final String? statutApres;
  final String  createdAt;

  const HistoriqueTache({
    required this.id,
    required this.tacheId,
    required this.projetId,
    required this.evenement,
    this.statutAvant,
    this.statutApres,
    this.createdAt = '',
  });

  factory HistoriqueTache.fromJson(Map<String, dynamic> j) => HistoriqueTache(
    id:          j['id']           as String? ?? '',
    tacheId:     j['tache_id']     as String? ?? '',
    projetId:    j['projet_id']    as String? ?? '',
    evenement:   j['evenement']    as String? ?? '',
    statutAvant: j['statut_avant'] as String?,
    statutApres: j['statut_apres'] as String?,
    createdAt:   j['created_at']   as String? ?? '',
  );
}
