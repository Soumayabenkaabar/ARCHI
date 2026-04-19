class Architecte {
  final String id;
  final String nom;
  final String prenom;
  final String email;
  final String? telephone;
  final String? cabinet;
  final String? avatarUrl;
  final String createdAt;

  const Architecte({
    required this.id,
    required this.nom,
    required this.prenom,
    required this.email,
    this.telephone,
    this.cabinet,
    this.avatarUrl,
    required this.createdAt,
  });

  String get fullName => '$prenom $nom';
  String get initials {
    final p = prenom.isNotEmpty ? prenom[0].toUpperCase() : '';
    final n = nom.isNotEmpty ? nom[0].toUpperCase() : '';
    return '$p$n';
  }

  factory Architecte.fromJson(Map<String, dynamic> json) => Architecte(
    id: json['id'] as String? ?? '',
    nom: json['nom'] as String? ?? '',
    prenom: json['prenom'] as String? ?? '',
    email: json['email'] as String? ?? '',
    telephone: json['telephone'] as String?,
    cabinet: json['cabinet'] as String?,
    avatarUrl: json['avatarUrl'] as String?,
    createdAt: json['createdAt'] as String? ?? '',
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'nom': nom,
    'prenom': prenom,
    'email': email,
    if (telephone != null) 'telephone': telephone,
    if (cabinet != null) 'cabinet': cabinet,
    if (avatarUrl != null) 'avatarUrl': avatarUrl,
    'createdAt': createdAt,
  };
}
