/// Modèle Document — table `documents`
///
/// Colonnes BDD :
///   id, projet_id, nom, url, type, taille_kb, uploaded_at
///
/// ── Stratégie d'encodage des métadonnées UI ──────────────────────────────────
/// Les métadonnées livrables (phase, typeLabel, version, dateDoc) sont encodées
/// directement dans le champ [nom] avec le séparateur ||META|| (null char) :
///
///   nom = "NOM_AFFICHE||META||phase||META||typeLabel||META||version||META||dateDoc"
///
/// Exemple :
///   nom = "Plan architectural V2||META||ESQ||META||Plan||META||2||META||10/01/2026"
///   type = "dwg"   ← valeur BDD valide (pdf|dwg|xlsx|image|autre)
///
/// Les anciens documents sans ||META|| sont lus normalement (rétrocompatibilité).
/// ─────────────────────────────────────────────────────────────────────────────
class Document {
  final String id;
  final String projetId;
  final String nom;       // peut contenir les métadonnées encodées (voir ci-dessus)
  final String url;
  final String type;      // 'pdf' | 'dwg' | 'xlsx' | 'image' | 'autre'
  final int?   tailleKb;
  final String uploadedAt;

  Document({
    required this.id,
    required this.projetId,
    required this.nom,
    required this.url,
    this.type       = 'pdf',
    this.tailleKb,
    this.uploadedAt = '',
  });

  // ── Désérialisation ─────────────────────────────────────────────────────────
  factory Document.fromJson(Map<String, dynamic> j) => Document(
    id:         j['id']?.toString()           ?? '',
    projetId:   j['projet_id']?.toString()    ?? '',
    nom:        j['nom']                      ?? '',
    url:        j['url']                      ?? '',
    type:       j['type']                     ?? 'pdf',
    tailleKb:   j['taille_kb'] as int?,
    uploadedAt: j['uploaded_at']?.toString()  ?? '',
  );

  // ── Sérialisation ───────────────────────────────────────────────────────────
  Map<String, dynamic> toJson() => {
    'projet_id': projetId,
    'nom':       nom,
    'url':       url,
    'type':      type,
    if (tailleKb != null) 'taille_kb': tailleKb,
  };

  // ── Helpers de décodage ─────────────────────────────────────────────────────

  /// Vrai si le champ [nom] contient des métadonnées encodées.
  bool get hasMetadata => nom.contains('||META||');

  /// Nom lisible (sans les métadonnées encodées).
  String get nomAffiche {
    if (!hasMetadata) return nom;
    return nom.split('||META||').first;
  }

  /// Phase architecturale encodée, ou 'ESQ' par défaut.
  String get phase {
    if (!hasMetadata) return 'ESQ';
    final parts = nom.split('||META||');
    return parts.length > 1 ? parts[1] : 'ESQ';
  }

  /// Type livrable UI (Plan, Devis, Permis…), ou 'Plan' par défaut.
  String get typeLabel {
    if (!hasMetadata) return 'Plan';
    final parts = nom.split('||META||');
    return parts.length > 2 ? parts[2] : 'Plan';
  }

  /// Numéro de version, ou 1 par défaut.
  int get version {
    if (!hasMetadata) return 1;
    final parts = nom.split('||META||');
    return parts.length > 3 ? (int.tryParse(parts[3]) ?? 1) : 1;
  }

  /// Date du document formatée (dd/MM/yyyy), ou null.
  String? get dateDocument {
    if (!hasMetadata) return null;
    final parts = nom.split('||META||');
    if (parts.length <= 4) return null;
    final d = parts[4];
    return d.isEmpty ? null : d;
  }

  // ── Helper d'encodage statique ──────────────────────────────────────────────

  /// Encode les métadonnées dans le champ [nom] pour la sauvegarde BDD.
  ///
  /// Utilisation :
  /// ```dart
  /// final nomEncode = Document.encodeNom(
  ///   nomAffiche: 'Plan architectural V2',
  ///   phase:      'ESQ',
  ///   typeLabel:  'Plan',
  ///   version:    2,
  ///   dateDoc:    '10/01/2026',
  /// );
  /// // → "Plan architectural V2||META||ESQ||META||Plan||META||2||META||10/01/2026"
  /// ```
  static String encodeNom({
    required String nomAffiche,
    required String phase,
    required String typeLabel,
    required int    version,
    String?         dateDoc,
  }) =>
      '$nomAffiche||META||$phase||META||$typeLabel||META||$version||META||${dateDoc ?? ''}';

  // ── copyWith ────────────────────────────────────────────────────────────────
  Document copyWith({
    String? id,
    String? projetId,
    String? nom,
    String? url,
    String? type,
    int?    tailleKb,
    String? uploadedAt,
  }) =>
      Document(
        id:         id         ?? this.id,
        projetId:   projetId   ?? this.projetId,
        nom:        nom        ?? this.nom,
        url:        url        ?? this.url,
        type:       type       ?? this.type,
        tailleKb:   tailleKb   ?? this.tailleKb,
        uploadedAt: uploadedAt ?? this.uploadedAt,
      );

  @override
  String toString() =>
      'Document(id: $id, nom: $nomAffiche, phase: $phase, type: $type, version: $version)';
}