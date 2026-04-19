/// Modèle Membre — table `membres`
///
/// Colonnes BDD :
///   id, user_id, nom, role, specialite, email,
///   telephone, disponible, projets_assignes, created_at
class Membre {
  final String id; // non-nullable : toujours présent depuis Supabase
  final String? userId;
  final String nom;
  final String role;
  final String specialite;
  final String email;
  final String telephone;
  final bool disponible;
  final List<String> projetsAssignes;

  Membre({
    required this.id,
    this.userId,
    required this.nom,
    required this.role,
    this.specialite = '',
    this.email = '',
    this.telephone = '',
    this.disponible = true,
    this.projetsAssignes = const [],
  });

  factory Membre.fromJson(Map<String, dynamic> json) => Membre(
    id: json['id']?.toString() ?? '',
    userId: json['user_id']?.toString(),
    nom: json['nom'] ?? '',
    role: json['role'] ?? '',
    specialite: json['specialite'] ?? '',
    email: json['email'] ?? '',
    telephone: json['telephone'] ?? '',
    disponible: json['disponible'] ?? true,
    projetsAssignes: List<String>.from(json['projets_assignes'] ?? []),
  );

  Map<String, dynamic> toJson() => {
    'nom': nom,
    'role': role,
    'specialite': specialite,
    'email': email,
    'telephone': telephone,
    'disponible': disponible,
    'projets_assignes': projetsAssignes,
  };
}
