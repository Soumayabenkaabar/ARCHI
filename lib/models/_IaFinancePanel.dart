 
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:lucide_icons/lucide_icons.dart';
import '../constants/colors.dart';
import '../models/project.dart';
import '../models/tache.dart';
import '../models/facture.dart';
import '../models/notification.dart';
 
class _IaFinancePanel extends StatefulWidget {
  final Project       project;
  final List<Facture> factures;
  final List<Tache>   taches;
  const _IaFinancePanel({required this.project, required this.factures, required this.taches});
  @override State<_IaFinancePanel> createState() => _IaFinancePanelState();
}
 
class _IaFinancePanelState extends State<_IaFinancePanel> {
  bool   _loading   = false;
  bool   _done      = false;
  String _summary   = '';
  int    _alertCount = 0;
 
  // ── Formater les données pour le prompt ────────────────────────────────────
  String _buildPrompt() {
    final p = widget.project;
    final buf = StringBuffer();
 
    buf.writeln('Tu es un assistant financier expert en gestion de projets d\'architecture.');
    buf.writeln('Analyse les données financières du projet suivant et génère des alertes pertinentes.');
    buf.writeln('');
    buf.writeln('=== PROJET ===');
    buf.writeln('Titre        : ${p.titre}');
    buf.writeln('Statut       : ${p.statut}');
    buf.writeln('Budget total : ${p.budgetTotal} DT');
    buf.writeln('Consommé     : ${p.budgetDepense} DT');
    buf.writeln('Restant      : ${p.budgetTotal - p.budgetDepense} DT');
    buf.writeln('Avancement   : ${p.avancement}%');
    buf.writeln('Date début   : ${p.dateDebut ?? "—"}');
    buf.writeln('Date fin     : ${p.dateFin   ?? "—"}');
    buf.writeln('');
 
    buf.writeln('=== TÂCHES (${widget.taches.length}) ===');
    for (final t in widget.taches) {
      buf.writeln('- ${t.titre} | statut: ${t.statut} | budget estimé: ${t.budgetEstime} DT | dates: ${t.dateDebut ?? "?"} → ${t.dateFin ?? "?"}');
    }
    buf.writeln('');
 
    buf.writeln('=== FACTURES (${widget.factures.length}) ===');
    for (final f in widget.factures) {
      buf.writeln('- ${f.numero} | montant: ${f.montant} DT | statut: ${f.statut} | échéance: ${f.dateEcheance ?? "—"}');
    }
    buf.writeln('');
 
    buf.writeln('=== INSTRUCTIONS ===');
    buf.writeln('1. Calcule le taux de consommation du budget (consommé / total).');
    buf.writeln('2. Compare l\'avancement du projet au taux de dépense — s\'il y a un écart, c\'est une anomalie.');
    buf.writeln('3. Identifie les tâches sans coût réel mais dont la date de fin est proche ou dépassée.');
    buf.writeln('4. Signale les factures en retard (statut en_retard).');
    buf.writeln('5. Prédit si le projet va dépasser son budget en fin de course.');
    buf.writeln('');
    buf.writeln('Réponds UNIQUEMENT en JSON valide, sans texte avant ni après, avec ce format exact :');
    buf.writeln('{');
    buf.writeln('  "resume": "Résumé en 1 phrase de la situation financière",');
    buf.writeln('  "alertes": [');
    buf.writeln('    {"niveau": "critique|warning|info", "message": "Message clair en français, max 120 caractères"}');
    buf.writeln('  ],');
    buf.writeln('  "prediction": "Phrase de prédiction du coût final"');
    buf.writeln('}');
    buf.writeln('Génère entre 1 et 5 alertes pertinentes selon les données. Si tout va bien, génère 1 alerte info positive.');
 
    return buf.toString();
  }
 
  // ── Appel API Anthropic ────────────────────────────────────────────────────
  Future<void> _analyser() async {
    setState(() { _loading = true; _done = false; _summary = ''; _alertCount = 0; });
 
    try {
      final response = await http.post(
        Uri.parse('https://api.anthropic.com/v1/messages'),
        headers: {
          'Content-Type':      'application/json',
          'anthropic-version': '2023-06-01',
        },
        body: jsonEncode({
          'model':      'claude-sonnet-4-20250514',
          'max_tokens': 1000,
          'messages': [
            {'role': 'user', 'content': _buildPrompt()},
          ],
        }),
      );
 
      if (response.statusCode != 200) throw Exception('API error ${response.statusCode}');
 
      final data     = jsonDecode(response.body);
      final rawText  = (data['content'] as List).firstWhere((b) => b['type'] == 'text')['text'] as String;
 
      // Parser le JSON retourné par l'IA
      final clean  = rawText.trim().replaceAll(RegExp(r'^```json|^```|```$', multiLine: true), '').trim();
      final parsed = jsonDecode(clean) as Map<String, dynamic>;
 
      final resume   = parsed['resume']    as String? ?? '';
      final alertes  = parsed['alertes']   as List?   ?? [];
      final prediction = parsed['prediction'] as String? ?? '';
 
      // Injecter chaque alerte dans les notifications
      int count = 0;
      for (final a in alertes) {
        final msg    = a['message']  as String? ?? '';
        final niveau = a['niveau']   as String? ?? 'info';
        if (msg.isEmpty) continue;
 
        // Préfixer selon le niveau
        final prefix = niveau == 'critique' ? '🔴 ' : niveau == 'warning' ? '⚠️ ' : '✅ ';
        addIaNotification('$prefix$msg', widget.project.titre);
        count++;
      }
 
      // Alerte de prédiction si non vide
      if (prediction.isNotEmpty) {
        addIaNotification('📊 Prédiction : $prediction', widget.project.titre);
        count++;
      }
 
      setState(() {
        _loading    = false;
        _done       = true;
        _summary    = resume;
        _alertCount = count;
      });
    } catch (e) {
      setState(() {
        _loading = false;
        _done    = true;
        _summary = 'Erreur lors de l\'analyse : $e';
      });
    }
  }
 
  @override
  Widget build(BuildContext context) => Container(
    decoration: BoxDecoration(
      gradient: LinearGradient(colors: [const Color(0xFF8B5CF6).withOpacity(0.08), const Color(0xFF8B5CF6).withOpacity(0.03)], begin: Alignment.topLeft, end: Alignment.bottomRight),
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: const Color(0xFF8B5CF6).withOpacity(0.25)),
    ),
    padding: const EdgeInsets.all(20),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
 
      // ── Titre ──────────────────────────────────────────────────────────
      Row(children: [
        Container(
          width: 40, height: 40,
          decoration: BoxDecoration(color: const Color(0xFF8B5CF6).withOpacity(0.15), borderRadius: BorderRadius.circular(10)),
          child: const Icon(LucideIcons.sparkles, color: Color(0xFF8B5CF6), size: 20),
        ),
        const SizedBox(width: 12),
        const Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Analyse IA des finances', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15, color: kTextMain)),
          Text('Détection d\'anomalies et prédiction budgétaire', style: TextStyle(color: kTextSub, fontSize: 12)),
        ])),
        // Badge "Nouveau" si résultats
        if (_done && _alertCount > 0)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(color: const Color(0xFF8B5CF6), borderRadius: BorderRadius.circular(20)),
            child: Text('$_alertCount alerte${_alertCount > 1 ? 's' : ''} générée${_alertCount > 1 ? 's' : ''}', style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w700)),
          ),
      ]),
 
      const SizedBox(height: 16),
 
      // ── Résumé (après analyse) ──────────────────────────────────────────
      if (_done && _summary.isNotEmpty) ...[
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: const Color(0xFF8B5CF6).withOpacity(0.2)),
          ),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: const [
              Icon(LucideIcons.fileText, size: 13, color: Color(0xFF8B5CF6)),
              SizedBox(width: 6),
              Text('Résumé IA', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12, color: Color(0xFF8B5CF6))),
            ]),
            const SizedBox(height: 8),
            Text(_summary, style: const TextStyle(fontSize: 13, color: kTextMain, height: 1.5)),
          ]),
        ),
        const SizedBox(height: 12),
        // Message pour aller voir les notifications
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(color: const Color(0xFFF0FDF4), borderRadius: BorderRadius.circular(10), border: Border.all(color: const Color(0xFF10B981).withOpacity(0.3))),
          child: Row(children: [
            const Icon(LucideIcons.bell, size: 14, color: Color(0xFF10B981)),
            const SizedBox(width: 8),
            Expanded(child: Text('$_alertCount alerte(s) ajoutée(s) dans le centre de notifications.', style: const TextStyle(fontSize: 12, color: Color(0xFF10B981), fontWeight: FontWeight.w500))),
          ]),
        ),
        const SizedBox(height: 12),
      ],
 
      // ── Bouton ─────────────────────────────────────────────────────────
      SizedBox(
        width: double.infinity,
        child: ElevatedButton.icon(
          onPressed: _loading ? null : _analyser,
          icon: _loading
              ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
              : const Icon(LucideIcons.sparkles, size: 16, color: Colors.white),
          label: Text(
            _loading ? 'Analyse en cours...' : _done ? 'Relancer l\'analyse' : 'Analyser avec l\'IA',
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 13),
          ),
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF8B5CF6),
            elevation: 0,
            padding: const EdgeInsets.symmetric(vertical: 13),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        ),
      ),
    ]),
  );
}
 