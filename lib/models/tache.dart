class Tache {
  final String  id;
  final String  projetId;
  final String? phaseId;
  final String  titre;
  final String  description;
  final String  statut;
  final String? dateDebut;
  final String? dateFin;
  final double  budgetEstime;
  final String  remarques;
  final List<String> meshNames;
  final String  phase;       // legacy
  final String  createdAt;

  const Tache({
    required this.id,
    required this.projetId,
    this.phaseId,
    required this.titre,
    this.description = '',
    required this.statut,
    this.dateDebut,
    this.dateFin,
    this.budgetEstime = 0,
    this.remarques    = '',
    this.meshNames    = const [],
    this.phase        = 'Général',
    this.createdAt    = '',
  });

  factory Tache.fromJson(Map<String, dynamic> j) => Tache(
    id:           j['id']            as String? ?? '',
    projetId:     j['projet_id']     as String? ?? '',
    phaseId:      j['phase_id']      as String?,
    titre:        j['titre']         as String? ?? '',
    description:  j['description']   as String? ?? '',
    statut:       j['statut']        as String? ?? 'en_attente',
    dateDebut:    j['date_debut']    as String?,
    dateFin:      j['date_fin']      as String?,
    budgetEstime: (j['budget_estime'] as num?)?.toDouble() ?? 0,
    remarques:    j['remarques']     as String? ?? '',
    meshNames:    List<String>.from(j['mesh_names'] ?? []),
    phase:        j['phase']         as String? ?? 'Général',
    createdAt:    j['created_at']    as String? ?? '',
  );

  Map<String, dynamic> toJson() => {
    'id':            id,
    'projet_id':     projetId,
    'phase_id':      phaseId,
    'titre':         titre,
    'description':   description,
    'statut':        statut,
    'date_debut':    dateDebut,
    'date_fin':      dateFin,
    'budget_estime': budgetEstime,
    'remarques':     remarques,
    'mesh_names':    meshNames,
    'phase':         phase,
    'created_at':    createdAt,
  };

  String get statutLabel {
    switch (statut) {
      case 'en_cours': return 'En cours';
      case 'termine':  return 'Terminé';
      default:         return 'Pas commencé';
    }
  }

  Tache copyWith({
    String? id, String? projetId, String? phaseId,
    String? titre, String? description, String? statut,
    String? dateDebut, String? dateFin,
    double? budgetEstime, String? remarques,
    List<String>? meshNames,
    String? phase, String? createdAt,
  }) => Tache(
    id:           id           ?? this.id,
    projetId:     projetId     ?? this.projetId,
    phaseId:      phaseId      ?? this.phaseId,
    titre:        titre        ?? this.titre,
    description:  description  ?? this.description,
    statut:       statut       ?? this.statut,
    dateDebut:    dateDebut    ?? this.dateDebut,
    dateFin:      dateFin      ?? this.dateFin,
    budgetEstime: budgetEstime ?? this.budgetEstime,
    remarques:    remarques    ?? this.remarques,
    meshNames:    meshNames    ?? this.meshNames,
    phase:        phase        ?? this.phase,
    createdAt:    createdAt    ?? this.createdAt,
  );
}
