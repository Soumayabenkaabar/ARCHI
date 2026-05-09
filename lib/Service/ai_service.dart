import 'dart:convert';
import '../core/supabase_config.dart';
import '../models/project.dart';

class AiService {
  static const _modelFast  = 'claude-haiku-4-5-20251001';
  static const _modelSmart = 'claude-sonnet-4-6';

  // ── Prompt système de base ──────────────────────────────────────────────────
  static String _systemBase(List<Project>? projects) {
    const base = 'Tu es un assistant IA expert en gestion de projets de construction '
        'et d\'architecture. Tu réponds toujours en français, de manière professionnelle '
        'et concise. Tes analyses sont objectives et tes recommandations sont concrètes.';

    if (projects == null || projects.isEmpty) return base;

    final ctx = projects.map((p) {
      final budgetPct = p.budgetTotal > 0
          ? (p.budgetDepense / p.budgetTotal * 100).toStringAsFixed(1)
          : '—';
      return '• ${p.titre} | Client: ${p.client} | Statut: ${p.status} '
          '| Avancement: ${p.avancement}% | Budget: ${p.budgetTotal.toInt()} DT '
          '(${budgetPct}% consommé) | Chef: ${p.chef}';
    }).join('\n');

    return '$base\n\nProjets en cours de l\'agence :\n$ctx';
  }

  // ── Appel via Supabase Edge Function (contourne le blocage CORS sur Web) ───
  static Future<String> _call({
    required String model,
    required List<Map<String, String>> messages,
    String? system,
    int maxTokens = 1024,
  }) async {
    final body = <String, dynamic>{
      'model':      model,
      'max_tokens': maxTokens,
      'messages':   messages,
    };
    if (system != null) body['system'] = system;

    final res = await SupabaseConfig.client.functions
        .invoke('ai-proxy', body: body)
        .timeout(const Duration(seconds: 90));

    final data = res.data;
    if (data == null) throw Exception('Réponse vide');

    if (data['error'] != null) {
      final err = data['error'];
      final msg = err is Map ? (err['message'] ?? err.toString()) : err.toString();
      throw Exception(msg);
    }

    return (data['content'] as List).first['text'] as String;
  }

  // ── Chatbot ─────────────────────────────────────────────────────────────────
  static Future<String> chat({
    required String userMessage,
    required List<Map<String, String>> history,
    List<Project>? projects,
  }) {
    final messages = [
      ...history,
      {'role': 'user', 'content': userMessage},
    ];
    return _call(
      model: _modelFast,
      messages: messages,
      system: _systemBase(projects),
      maxTokens: 1024,
    );
  }

  // ── Rapport projet ──────────────────────────────────────────────────────────
  static Future<String> genererRapport(Project p) {
    final budgetPct = p.budgetTotal > 0
        ? '${(p.budgetDepense / p.budgetTotal * 100).toStringAsFixed(1)}%'
        : 'N/A';

    final prompt = '''Génère un rapport professionnel complet pour le projet suivant :

Titre : ${p.titre}
Client : ${p.client}
Statut : ${p.status}
Avancement : ${p.avancement}%
Localisation : ${p.localisation}
Chef de projet : ${p.chef}
Budget total : ${p.budgetTotal.toInt()} DT
Budget dépensé : ${p.budgetDepense.toInt()} DT ($budgetPct consommé)
Date début : ${p.dateDebut ?? 'Non définie'}
Date fin prévue : ${p.dateFin ?? 'Non définie'}

Rédige un rapport structuré avec :
1. Résumé exécutif
2. État d'avancement détaillé
3. Situation budgétaire et analyse des écarts
4. Points d'attention et risques identifiés
5. Recommandations (3 à 5 actions concrètes)
6. Conclusion

Adopte un ton professionnel et factuel.''';

    return _call(
      model: _modelSmart,
      messages: [{'role': 'user', 'content': prompt}],
      maxTokens: 2048,
    );
  }

  // ── Analyse de risque ───────────────────────────────────────────────────────
  static Future<String> analyserProjet(Project p) {
    final budgetPct = p.budgetTotal > 0
        ? (p.budgetDepense / p.budgetTotal * 100).toStringAsFixed(1)
        : '0';

    final prompt = '''Analyse ce projet de construction et fournis une évaluation de risque :

Projet : ${p.titre}
Statut : ${p.status}
Avancement : ${p.avancement}%
Budget consommé : $budgetPct% (${p.budgetDepense.toInt()} / ${p.budgetTotal.toInt()} DT)
Date fin prévue : ${p.dateFin ?? 'Non définie'}

Fournis une réponse structurée avec :
- **Niveau de risque global** : Faible / Moyen / Élevé
- **Points critiques** (2-3 points)
- **Recommandations** (3 actions concrètes et prioritaires)

Sois direct et concis.''';

    return _call(
      model: _modelFast,
      messages: [{'role': 'user', 'content': prompt}],
      maxTokens: 512,
    );
  }

  // ── Prédiction ──────────────────────────────────────────────────────────────
  static Future<Map<String, String>> predireProjet(Project p) async {
    final budgetPct = p.budgetTotal > 0
        ? (p.budgetDepense / p.budgetTotal * 100).toStringAsFixed(1)
        : '0';

    final prompt = '''Préds les indicateurs clés pour ce projet de construction :

Projet : ${p.titre}
Avancement actuel : ${p.avancement}%
Budget total : ${p.budgetTotal.toInt()} DT
Budget consommé : ${p.budgetDepense.toInt()} DT ($budgetPct%)
Date de début : ${p.dateDebut ?? 'Non définie'}
Date de fin prévue : ${p.dateFin ?? 'Non définie'}

Réponds UNIQUEMENT en JSON valide avec ces clés :
{
  "budget_final_estime": "valeur en DT",
  "date_fin_estimee": "date au format JJ/MM/AAAA ou description",
  "niveau_risque": "Faible|Moyen|Élevé",
  "probabilite_respect_budget": "X%",
  "justification": "1-2 phrases explicatives"
}''';

    final raw = await _call(
      model: _modelSmart,
      messages: [{'role': 'user', 'content': prompt}],
      maxTokens: 512,
    );

    try {
      final start = raw.indexOf('{');
      final end   = raw.lastIndexOf('}') + 1;
      if (start >= 0 && end > start) {
        final json = jsonDecode(raw.substring(start, end)) as Map<String, dynamic>;
        return json.map((k, v) => MapEntry(k, v.toString()));
      }
    } catch (_) {}

    return {
      'budget_final_estime': '—',
      'date_fin_estimee': '—',
      'niveau_risque': 'Inconnu',
      'probabilite_respect_budget': '—',
      'justification': raw,
    };
  }

  // ── Devis IA ────────────────────────────────────────────────────────────────
  static Future<String> genererDevis({
    required String typeProjet,
    required String surface,
    required String description,
    required String clientNom,
  }) {
    final prompt = '''Génère un devis professionnel détaillé pour :

Client : $clientNom
Type de projet : $typeProjet
Surface : $surface m²
Description / cahier des charges : $description

Le devis doit inclure :
1. En-tête professionnel
2. Descriptif des travaux par poste (gros œuvre, second œuvre, finitions…)
3. Tableau récapitulatif des coûts estimés (en DT)
4. Délai d'exécution estimé
5. Conditions de paiement suggérées
6. Mentions légales standards
7. Signature / validation

Base-toi sur les prix du marché tunisien de la construction. Sois précis et professionnel.''';

    return _call(
      model: _modelSmart,
      messages: [{'role': 'user', 'content': prompt}],
      maxTokens: 2048,
    );
  }

  // ── Calcul de risque local (sans API) ───────────────────────────────────────
  static String risqueLocal(Project p) {
    if (p.budgetTotal == 0 || p.avancement == 0) return 'Inconnu';
    final budgetRatio     = p.budgetDepense / p.budgetTotal;
    final avancementRatio = p.avancement / 100;
    final delta           = budgetRatio - avancementRatio;

    if (p.statut == 'annule') return 'Annulé';
    if (p.statut == 'termine') return 'Terminé';
    if (delta > 0.20 || budgetRatio > 0.95) return 'Élevé';
    if (delta > 0.08 || budgetRatio > 0.75) return 'Moyen';
    return 'Faible';
  }
}
