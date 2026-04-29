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
///   id, user_id, nom, email, telephone, acces_portail, created_at
class Client {
  final String id;
  final String? userId;
  final String nom;
  final String email;
  final String telephone;
  final bool accesPortail;
  final DateTime? createdAt;

  Client({
    required this.id,
    this.userId,
    required this.nom,
    this.email = '',
    this.telephone = '',
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
    return '—';
  }

  factory Client.fromJson(Map<String, dynamic> json) => Client(
    id:           json['id']?.toString() ?? '',
    userId:       json['user_id']?.toString(),
    nom:          json['nom'] ?? '',
    email:        json['email'] ?? '',
    telephone:    json['telephone'] ?? '',
    accesPortail: json['acces_portail'] ?? true,
    createdAt:    json['created_at'] != null
                    ? DateTime.tryParse(json['created_at'].toString())
                    : null,
  );

  Map<String, dynamic> toJson() => {
    'nom':           nom,
    'email':         email,
    'telephone':     telephone,
    'acces_portail': accesPortail,
  };
}
