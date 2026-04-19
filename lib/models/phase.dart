class Phase {
  final String id;
  final String projetId;
  final String nom;
  final int    ordre;
  final String createdAt;

  const Phase({
    required this.id,
    required this.projetId,
    required this.nom,
    required this.ordre,
    this.createdAt = '',
  });

  factory Phase.fromJson(Map<String, dynamic> j) => Phase(
    id:        j['id']         as String? ?? '',
    projetId:  j['projet_id']  as String? ?? '',
    nom:       j['nom']        as String? ?? '',
    ordre:     (j['ordre']     as num?)?.toInt() ?? 0,
    createdAt: j['created_at'] as String? ?? '',
  );

  Map<String, dynamic> toJson() => {
    'id':         id,
    'projet_id':  projetId,
    'nom':        nom,
    'ordre':      ordre,
    'created_at': createdAt,
  };

  Phase copyWith({String? id, String? projetId, String? nom, int? ordre, String? createdAt}) => Phase(
    id:        id        ?? this.id,
    projetId:  projetId  ?? this.projetId,
    nom:       nom       ?? this.nom,
    ordre:     ordre     ?? this.ordre,
    createdAt: createdAt ?? this.createdAt,
  );
}