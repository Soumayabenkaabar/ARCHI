class Commentaire {
  final String id;
  final String projetId;
  final String auteur;
  final String role; // 'client' | 'architecte'
  final String contenu;
  final String createdAt;

  Commentaire({
    required this.id,
    required this.projetId,
    required this.auteur,
    required this.role,
    required this.contenu,
    required this.createdAt,
  });

  factory Commentaire.fromJson(Map<String, dynamic> j) => Commentaire(
    id: j['id'] ?? '',
    projetId: j['projet_id'] ?? '',
    auteur: j['auteur'] ?? '',
    role: j['role'] ?? 'client',
    contenu: j['contenu'] ?? '',
    createdAt: j['created_at'] ?? '',
  );

  Map<String, dynamic> toJson() => {
    'projet_id': projetId,
    'auteur': auteur,
    'role': role,
    'contenu': contenu,
  };
}
