/// Modèle Client — table `clients`
///
/// Colonnes BDD :
///   id, user_id, nom, email, telephone, entreprise,
///   nb_projets, date_depuis, acces_portail, created_at
class Client {
  final String id; // non-nullable : toujours présent depuis Supabase
  final String? userId;
  final String nom;
  final String email;
  final String telephone;
  final String entreprise;
  final int nbProjets;
  final String dateDepuis;
  final bool accesPortail;

  Client({
    required this.id,
    this.userId,
    required this.nom,
    this.email = '',
    this.telephone = '',
    this.entreprise = '',
    this.nbProjets = 0,
    this.dateDepuis = '',
    this.accesPortail = true,
  });

  factory Client.fromJson(Map<String, dynamic> json) => Client(
    id: json['id']?.toString() ?? '',
    userId: json['user_id']?.toString(),
    nom: json['nom'] ?? '',
    email: json['email'] ?? '',
    telephone: json['telephone'] ?? '',
    entreprise: json['entreprise'] ?? '',
    nbProjets: (json['nb_projets'] as num?)?.toInt() ?? 0,
    dateDepuis: json['date_depuis']?.toString() ?? '',
    accesPortail: json['acces_portail'] ?? true,
  );

  Map<String, dynamic> toJson() => {
    'nom': nom,
    'email': email,
    'telephone': telephone,
    'entreprise': entreprise,
    'acces_portail': accesPortail,
  };
}
