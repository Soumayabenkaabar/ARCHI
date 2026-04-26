class ClientStats {
  int enCours   = 0;
  int enAttente = 0;
  int termine   = 0;
  int annule    = 0;
  int get total => enCours + enAttente + termine + annule;

  void add(String statut) {
    switch (statut.trim().toLowerCase()) {
      case 'en_cours':   enCours++;   break;
      case 'en_attente': enAttente++; break;
      case 'termine':    termine++;   break;
      case 'annule':     annule++;    break;
    }
  }
}

/// Modèle Client — table `clients`
///
/// Colonnes BDD :
///   id, user_id, nom, email, telephone, entreprise,
///   nb_projets, date_depuis, acces_portail, created_at
class Client {
  final String id;
  final String? userId;
  final String nom;
  final String email;
  final String telephone;
  final String entreprise;
  final int nbProjets;
  final String dateDepuis;
  final bool accesPortail;
  final DateTime? createdAt;

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
    this.createdAt,
  });

  String get dateDepuisDisplay {
    if (createdAt != null) {
      final d = createdAt!;
      final months = ['jan', 'fév', 'mar', 'avr', 'mai', 'jun',
                      'jul', 'aoû', 'sep', 'oct', 'nov', 'déc'];
      return '${d.day.toString().padLeft(2, '0')} ${months[d.month - 1]} ${d.year}';
    }
    return dateDepuis.isNotEmpty ? dateDepuis : '—';
  }

  factory Client.fromJson(Map<String, dynamic> json) => Client(
    id:           json['id']?.toString() ?? '',
    userId:       json['user_id']?.toString(),
    nom:          json['nom'] ?? '',
    email:        json['email'] ?? '',
    telephone:    json['telephone'] ?? '',
    entreprise:   json['entreprise'] ?? '',
    nbProjets:    (json['nb_projets'] as num?)?.toInt() ?? 0,
    dateDepuis:   json['date_depuis']?.toString() ?? '',
    accesPortail: json['acces_portail'] ?? true,
    createdAt:    json['created_at'] != null
                    ? DateTime.tryParse(json['created_at'].toString())
                    : null,
  );

  Map<String, dynamic> toJson() => {
    'nom': nom,
    'email': email,
    'telephone': telephone,
    'entreprise': entreprise,
    'acces_portail': accesPortail,
  };
}
