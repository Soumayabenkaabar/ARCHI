class Conge {
  final String id;
  final String membreId;
  final DateTime dateDebut;
  final DateTime dateFin;
  final String motif;
  final String createdAt;

  Conge({
    required this.id,
    required this.membreId,
    required this.dateDebut,
    required this.dateFin,
    this.motif = '',
    this.createdAt = '',
  });

  factory Conge.fromJson(Map<String, dynamic> j) => Conge(
    id:        j['id']         as String? ?? '',
    membreId:  j['membre_id']  as String? ?? '',
    dateDebut: DateTime.parse(j['date_debut'] as String),
    dateFin:   DateTime.parse(j['date_fin']   as String),
    motif:     j['motif']      as String? ?? '',
    createdAt: j['created_at'] as String? ?? '',
  );

  int get dureeJours => dateFin.difference(dateDebut).inDays + 1;

  bool get isActif {
    final today = DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day);
    return !dateDebut.isAfter(today) && !dateFin.isBefore(today);
  }

  bool get isFutur {
    final today = DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day);
    return dateDebut.isAfter(today);
  }

  static String _fmt(DateTime d) {
    const months = ['jan','fév','mar','avr','mai','jun','jul','aoû','sep','oct','nov','déc'];
    return '${d.day.toString().padLeft(2, '0')} ${months[d.month - 1]} ${d.year}';
  }

  String get periodeDisplay => '${_fmt(dateDebut)} → ${_fmt(dateFin)}';
}
