class Project {
  final String id;
  final String clientId;
  final String titre;
  final String description;
  final String statut; // 'en_cours' | 'en_attente' | 'termine' | 'annule'
  final int avancement; // 0-100
  final String? dateDebut;
  final String? dateFin;
  final double budgetTotal;
  final double budgetDepense;
  final String client;
  final String localisation;
  final String chef;
  final int taches;
  final List<String> membres;
  final List<String> docs;
  final bool portailClient;

  Project({
    required this.id,
    required this.clientId,
    required this.titre,
    this.description = '',
    required this.statut,
    this.avancement = 0,
    this.dateDebut,
    this.dateFin,
    this.budgetTotal = 0,
    this.budgetDepense = 0,
    this.client = '',
    this.localisation = '',
    this.chef = '',
    this.taches = 0,
    this.membres = const [],
    this.docs = const [],
    this.portailClient = false,
  });

  // ── Aliases UI ────────────────────────────────────────────────────────────
  String get title => titre;
  String get status => _statutLabel(statut);
  double get progress => avancement / 100.0;
  double get budgetProgress =>
      budgetTotal > 0 ? (budgetDepense / budgetTotal).clamp(0.0, 1.0) : 0.0;

  static String _statutLabel(String s) {
    switch (s) {
      case 'en_cours':
        return 'En cours';
      case 'en_attente':
        return 'Planification';
      case 'termine':
        return 'Terminé';
      case 'annule':
        return 'Annulé';
      default:
        return s;
    }
  }

  factory Project.fromJson(Map<String, dynamic> j) => Project(
    id: j['id']?.toString() ?? '',
    clientId: j['client_id']?.toString() ?? '',
    titre: j['titre'] ?? '',
    description: j['description'] ?? '',
    statut: j['statut'] ?? 'en_cours',
    avancement: (j['avancement'] as num?)?.toInt() ?? 0,
    dateDebut: j['date_debut']?.toString(),
    dateFin: j['date_fin']?.toString(),
    budgetTotal: (j['budget_total'] as num?)?.toDouble() ?? 0,
    budgetDepense: (j['budget_depense'] as num?)?.toDouble() ?? 0,
    client: j['client'] ?? '',
    localisation: j['localisation'] ?? '',
    chef: j['chef'] ?? '',
    taches: (j['taches'] as num?)?.toInt() ?? 0,
    membres: j['membres'] != null ? List<String>.from(j['membres']) : [],
    docs: j['docs'] != null ? List<String>.from(j['docs']) : [],
    portailClient: j['portail_client'] as bool? ?? false,
  );

  Map<String, dynamic> toJson() => {
    'client_id': clientId,
    'titre': titre,
    'description': description,
    'statut': statut,
    'avancement': avancement,
    'date_debut': dateDebut,
    'date_fin': dateFin,
    'budget_total': budgetTotal,
    'budget_depense': budgetDepense,
    'client': client,
    'localisation': localisation,
    'chef': chef,
    'taches': taches,
    'portail_client': portailClient,
  };
}

final List<Project> sampleProjects = [
  Project(
    id: '1',
    clientId: 'c1',
    titre: 'Villa Carthage',
    description: 'Construction villa R+1 avec piscine',
    statut: 'en_cours',
    avancement: 65,
    dateDebut: 'Jan 2024',
    dateFin: 'Déc 2024',
    budgetTotal: 8500000,
    budgetDepense: 1070000,
    client: 'Groupe OCP',
    localisation: 'Carthage, Tunis',
    chef: 'Ahmed Ben Ali',
    taches: 12,
    membres: ['Ahmed', 'Sonia', 'Karim'],
    docs: ['plan.pdf'],
  ),
  Project(
    id: '2',
    clientId: 'c2',
    titre: 'Résidence Les Pins',
    description: 'Immeuble R+4, 16 appartements',
    statut: 'en_attente',
    avancement: 20,
    dateDebut: 'Mar 2024',
    dateFin: 'Nov 2025',
    budgetTotal: 6500000,
    budgetDepense: 825000,
    client: 'Société Immobilière TN',
    localisation: 'La Marsa, Tunis',
    chef: 'Sonia Mrad',
    taches: 8,
    membres: ['Sonia', 'Ali'],
    docs: ['contrat.pdf'],
  ),
];
