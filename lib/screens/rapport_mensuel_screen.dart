import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../database/dao.dart';
import '../models/models.dart';

class RapportMensuelScreen extends StatefulWidget {
  /// Quand [embedded] est true, l'AppBar est masquée (utilisé dans IndexedStack)
  final bool embedded;
  const RapportMensuelScreen({super.key, this.embedded = false});

  @override
  State<RapportMensuelScreen> createState() => _RapportMensuelScreenState();
}

class _RapportMensuelScreenState extends State<RapportMensuelScreen> {
  int _annee = DateTime.now().year;
  int _mois = DateTime.now().month;

  double _totalRevenus = 0;
  double _totalDepenses = 0;
  List<Depense> _depenses = [];
  List<Map<String, dynamic>> _parCategorie = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final results = await Future.wait([
      sommeRevenusMois(_annee, _mois),
      sommeDepensesMois(_annee, _mois),
      getDepensesMois(_annee, _mois),
      depensesParCategorieMois(_annee, _mois),
    ]);
    setState(() {
      _totalRevenus = results[0] as double;
      _totalDepenses = results[1] as double;
      _depenses = results[2] as List<Depense>;
      _parCategorie = results[3] as List<Map<String, dynamic>>;
      _loading = false;
    });
  }

  void _prevMois() {
    setState(() {
      if (_mois == 1) {
        _mois = 12;
        _annee--;
      } else {
        _mois--;
      }
    });
    _load();
  }

  void _nextMois() {
    setState(() {
      if (_mois == 12) {
        _mois = 1;
        _annee++;
      } else {
        _mois++;
      }
    });
    _load();
  }

  @override
  Widget build(BuildContext context) {
    final fmt = NumberFormat('#,##0', 'fr_FR');
    final moisNom = DateFormat(
      'MMMM yyyy',
      'fr_FR',
    ).format(DateTime(_annee, _mois));
    final resteAVivre = _totalRevenus - _totalDepenses;

    return Scaffold(
      appBar: widget.embedded
          ? null
          : AppBar(title: const Text('Rapport mensuel')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(12),
              children: [
                // Navigation mois
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    IconButton(
                      onPressed: _prevMois,
                      icon: const Icon(Icons.chevron_left),
                    ),
                    Text(
                      moisNom.toUpperCase(),
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    IconButton(
                      onPressed: _nextMois,
                      icon: const Icon(Icons.chevron_right),
                    ),
                  ],
                ),
                const SizedBox(height: 8),

                // Résumé financier
                Row(
                  children: [
                    _SummaryCard(
                      label: 'Revenus',
                      amount: _totalRevenus,
                      color: Colors.green,
                      icon: Icons.arrow_downward,
                    ),
                    const SizedBox(width: 8),
                    _SummaryCard(
                      label: 'Dépenses',
                      amount: _totalDepenses,
                      color: Colors.red,
                      icon: Icons.arrow_upward,
                    ),
                  ],
                ),
                const SizedBox(height: 8),

                // Reste à vivre
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: resteAVivre >= 0
                        ? Colors.green.shade50
                        : Colors.red.shade50,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: resteAVivre >= 0
                          ? Colors.green.shade300
                          : Colors.red.shade300,
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Reste à vivre',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      Text(
                        '${resteAVivre >= 0 ? '+' : ''}${fmt.format(resteAVivre)} FCFA',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 18,
                          color: resteAVivre >= 0
                              ? Colors.green.shade700
                              : Colors.red.shade700,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // Dépenses par catégorie
                if (_parCategorie.isNotEmpty) ...[
                  const Text(
                    'Par catégorie',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                  ),
                  const SizedBox(height: 8),
                  ..._parCategorie.map(
                    (c) => _CategorieRow(
                      nom: c['categorie'] as String,
                      total: (c['total'] as num).toDouble(),
                      totalDepenses: _totalDepenses,
                    ),
                  ),
                  const SizedBox(height: 16),
                ],

                // Liste détaillée
                const Text(
                  'Détail des dépenses',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                ),
                const SizedBox(height: 8),
                if (_depenses.isEmpty)
                  const Center(
                    child: Padding(
                      padding: EdgeInsets.all(16),
                      child: Text('Aucune dépense ce mois.'),
                    ),
                  )
                else
                  ..._depenses.map(
                    (d) => Card(
                      child: ListTile(
                        title: Text(d.articleNom ?? ''),
                        subtitle: Text(
                          '${d.categorieNom} · ${d.quantite} ${d.uniteNom} · ${d.dateDepense}',
                        ),
                        trailing: Text(
                          '${fmt.format(d.total)} FCFA',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  final String label;
  final double amount;
  final Color color;
  final IconData icon;
  const _SummaryCard({
    required this.label,
    required this.amount,
    required this.color,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final fmt = NumberFormat('#,##0', 'fr_FR');
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withValues(alpha: 0.3)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: color, size: 16),
                const SizedBox(width: 4),
                Text(
                  label,
                  style: TextStyle(color: color, fontWeight: FontWeight.w600),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              '${fmt.format(amount)} FCFA',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: color,
                fontSize: 15,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CategorieRow extends StatelessWidget {
  final String nom;
  final double total;
  final double totalDepenses;
  const _CategorieRow({
    required this.nom,
    required this.total,
    required this.totalDepenses,
  });

  @override
  Widget build(BuildContext context) {
    final fmt = NumberFormat('#,##0', 'fr_FR');
    final pct = totalDepenses > 0 ? total / totalDepenses : 0.0;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(nom),
              Text(
                '${fmt.format(total)} FCFA',
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
            ],
          ),
          const SizedBox(height: 4),
          LinearProgressIndicator(
            value: pct,
            backgroundColor: Colors.grey.shade200,
            color: Theme.of(context).colorScheme.primary,
          ),
        ],
      ),
    );
  }
}
