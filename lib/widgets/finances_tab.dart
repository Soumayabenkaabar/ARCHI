import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../constants/colors.dart';
import '../models/project.dart';
import '../models/facture.dart';
import '../service/facture_service.dart';

class FinancesTab extends StatefulWidget {
  final Project project;

  const FinancesTab({super.key, required this.project});

  @override
  State<FinancesTab> createState() => _FinancesTabState();
}

class _FinancesTabState extends State<FinancesTab> {
  List<Facture> factures = [];
  bool loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final data = await FactureService.getFactures(widget.project.id);
      setState(() {
        factures = data;
        loading = false;
      });
    } catch (e) {
      setState(() => loading = false);
    }
  }

  String _fmt(double v) {
    if (v == 0) return '0 DT';
    final s = v.toInt().toString();
    final buf = StringBuffer();
    int c = 0;
    for (int i = s.length - 1; i >= 0; i--) {
      if (c > 0 && c % 3 == 0) buf.write('.');
      buf.write(s[i]);
      c++;
    }
    return '${buf.toString().split('').reversed.join()} DT';
  }

  Color _factureColor(String s) {
    switch (s) {
      case 'payee':
        return const Color(0xFF10B981);
      case 'en_retard':
        return kRed;
      default:
        return kAccent;
    }
  }

  String _factureLabel(String s) {
    switch (s) {
      case 'payee':
        return 'Payée';
      case 'en_retard':
        return 'En retard';
      default:
        return 'En attente';
    }
  }

  @override
  Widget build(BuildContext context) {
    if (loading)
      return const Center(child: CircularProgressIndicator(color: kAccent));

    final isMobile = MediaQuery.of(context).size.width < 800;
    final pad = isMobile ? 16.0 : 28.0;
    final p = widget.project;
    final budget = p.budgetTotal;
    final depense = p.budgetDepense;
    final restant = budget - depense;
    final pctBudget = budget > 0 ? (depense / budget).clamp(0.0, 1.0) : 0.0;

    return SingleChildScrollView(
      padding: EdgeInsets.all(pad),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Header ────────────────────────────────────────────────────
          Row(
            children: [
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Gestion financière',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        color: kTextMain,
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      'Suivi du budget, factures et paiements',
                      style: TextStyle(color: kTextSub, fontSize: 12),
                    ),
                  ],
                ),
              ),
              ElevatedButton.icon(
                onPressed: () {},
                icon: const Icon(
                  LucideIcons.plus,
                  size: 14,
                  color: Colors.white,
                ),
                label: const Text(
                  'Nouvelle facture',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: kAccent,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 20),

          // ── KPI Cards ──────────────────────────────────────────────────
          LayoutBuilder(
            builder: (ctx, constraints) {
              final cols = constraints.maxWidth > 600 ? 4 : 2;
              final cards = [
                _FinKpiCard(
                  icon: LucideIcons.dollarSign,
                  iconColor: kAccent,
                  label: 'Budget prévu',
                  value: _fmt(budget),
                ),
                _FinKpiCard(
                  icon: LucideIcons.trendingUp,
                  iconColor: kAccent,
                  label: 'Coût réalisé',
                  value: _fmt(depense),
                  sub: '${(pctBudget * 100).toStringAsFixed(0)}% du budget',
                ),
                _FinKpiCard(
                  icon: LucideIcons.trendingDown,
                  iconColor: const Color(0xFF10B981),
                  label: 'Reste à payer',
                  value: _fmt(restant),
                ),
                _FinKpiCard(
                  icon: LucideIcons.fileText,
                  iconColor: kTextSub,
                  label: 'Factures',
                  value: '${factures.length}',
                  sub: 'Total facturé: ${_fmt(depense)}',
                ),
              ];
              return Column(
                children: [
                  IntrinsicHeight(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Expanded(child: cards[0]),
                        const SizedBox(width: 12),
                        Expanded(child: cards[1]),
                        if (cols == 4) ...[
                          const SizedBox(width: 12),
                          Expanded(child: cards[2]),
                          const SizedBox(width: 12),
                          Expanded(child: cards[3]),
                        ],
                      ],
                    ),
                  ),
                  if (cols == 2) ...[
                    const SizedBox(height: 12),
                    IntrinsicHeight(
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Expanded(child: cards[2]),
                          const SizedBox(width: 12),
                          Expanded(child: cards[3]),
                        ],
                      ),
                    ),
                  ],
                ],
              );
            },
          ),

          const SizedBox(height: 20),

          // ── Utilisation du budget ──────────────────────────────────────
          _Section(
            title: 'Utilisation du budget',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Budget consommé',
                      style: TextStyle(color: kTextSub, fontSize: 13),
                    ),
                    Text(
                      '${_fmt(depense)} / ${_fmt(budget)}',
                      style: const TextStyle(color: kTextSub, fontSize: 12),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: LinearProgressIndicator(
                    value: pctBudget,
                    minHeight: 10,
                    backgroundColor: const Color(0xFFE5E7EB),
                    valueColor: AlwaysStoppedAnimation<Color>(
                      pctBudget > 0.9 ? kRed : kAccent,
                    ),
                  ),
                ),
                const SizedBox(height: 6),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      _fmt(depense),
                      style: const TextStyle(color: kTextSub, fontSize: 11),
                    ),
                    Text(
                      _fmt(budget),
                      style: const TextStyle(color: kTextSub, fontSize: 11),
                    ),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // ── Liste des factures ─────────────────────────────────────────
          _Section(
            title: 'Factures (${factures.length})',
            child: factures.isEmpty
                ? const Padding(
                    padding: EdgeInsets.symmetric(vertical: 20),
                    child: Center(
                      child: Text(
                        'Aucune facture pour ce projet',
                        style: TextStyle(color: kTextSub, fontSize: 13),
                      ),
                    ),
                  )
                : Column(
                    children: factures
                        .map(
                          (f) => _FactureRow(
                            facture: f,
                            fmt: _fmt,
                            factureColor: _factureColor(f.statut),
                            factureLabel: _factureLabel(f.statut),
                            onStatusChanged: (s) async {
                              await FactureService.updateStatut(f.id, s);
                              _load();
                            },
                            onDelete: () async {
                              await FactureService.deleteFacture(f.id);
                              _load();
                            },
                          ),
                        )
                        .toList(),
                  ),
          ),
        ],
      ),
    );
  }
}

// ── Ligne facture ─────────────────────────────────────────────────────────────
class _FactureRow extends StatelessWidget {
  final Facture facture;
  final String Function(double) fmt;
  final Color factureColor;
  final String factureLabel;
  final ValueChanged<String> onStatusChanged;
  final VoidCallback onDelete;

  const _FactureRow({
    required this.facture,
    required this.fmt,
    required this.factureColor,
    required this.factureLabel,
    required this.onStatusChanged,
    required this.onDelete,
  });

  String _labelFor(String s) {
    switch (s) {
      case 'payee':
        return 'Payée';
      case 'en_retard':
        return 'En retard';
      default:
        return 'En attente';
    }
  }

  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.only(bottom: 10),
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: const Color(0xFFF9FAFB),
      borderRadius: BorderRadius.circular(10),
      border: Border.all(color: const Color(0xFFE5E7EB)),
    ),
    child: Row(
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: const Color(0xFFEFF6FF),
            borderRadius: BorderRadius.circular(8),
          ),
          child: const Icon(
            LucideIcons.fileText,
            color: Color(0xFF3B82F6),
            size: 18,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                facture.numero,
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                  color: kTextMain,
                ),
              ),
              Text(
                fmt(facture.montant),
                style: const TextStyle(color: kTextSub, fontSize: 12),
              ),
              if (facture.dateEcheance != null)
                Text(
                  'Échéance : ${facture.dateEcheance}',
                  style: const TextStyle(color: kTextSub, fontSize: 11),
                ),
            ],
          ),
        ),
        Material(
          color: Colors.transparent,
          child: PopupMenuButton<String>(
            onSelected: onStatusChanged,
            itemBuilder: (_) => ['en_attente', 'payee', 'en_retard']
                .map((s) => PopupMenuItem(value: s, child: Text(_labelFor(s))))
                .toList(),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: factureColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                factureLabel,
                style: TextStyle(
                  color: factureColor,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
        ),
        const SizedBox(width: 8),
        IconButton(
          onPressed: onDelete,
          icon: const Icon(LucideIcons.trash2, size: 15, color: kRed),
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(),
        ),
      ],
    ),
  );
}

// ── KPI Card ──────────────────────────────────────────────────────────────────
class _FinKpiCard extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String label, value;
  final String? sub;
  const _FinKpiCard({
    required this.icon,
    required this.iconColor,
    required this.label,
    required this.value,
    this.sub,
  });

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: kCardBg,
      borderRadius: BorderRadius.circular(12),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withOpacity(0.04),
          blurRadius: 6,
          offset: const Offset(0, 2),
        ),
      ],
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            Icon(icon, size: 14, color: iconColor),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                label,
                style: const TextStyle(color: kTextSub, fontSize: 12),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Text(
          value,
          style: const TextStyle(
            fontWeight: FontWeight.w800,
            fontSize: 16,
            color: kTextMain,
          ),
          overflow: TextOverflow.ellipsis,
        ),
        if (sub != null) ...[
          const SizedBox(height: 4),
          Text(sub!, style: const TextStyle(color: kTextSub, fontSize: 11)),
        ],
      ],
    ),
  );
}

// ── Section card ──────────────────────────────────────────────────────────────
class _Section extends StatelessWidget {
  final String title;
  final Widget child;
  const _Section({required this.title, required this.child});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(18),
    decoration: BoxDecoration(
      color: kCardBg,
      borderRadius: BorderRadius.circular(12),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withOpacity(0.04),
          blurRadius: 6,
          offset: const Offset(0, 2),
        ),
      ],
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontWeight: FontWeight.w700,
            fontSize: 15,
            color: kTextMain,
          ),
        ),
        const SizedBox(height: 14),
        child,
      ],
    ),
  );
}
