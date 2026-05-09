import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../database/dao.dart';

class RapportAnnuelScreen extends StatefulWidget {
  const RapportAnnuelScreen({super.key});

  @override
  State<RapportAnnuelScreen> createState() => _RapportAnnuelScreenState();
}

class _RapportAnnuelScreenState extends State<RapportAnnuelScreen> {
  int _annee = DateTime.now().year;
  List<Map<String, dynamic>> _data = [];
  bool _loading = true;

  static const _moisNoms = [
    '',
    'Jan',
    'Fév',
    'Mar',
    'Avr',
    'Mai',
    'Jun',
    'Jul',
    'Aoû',
    'Sep',
    'Oct',
    'Nov',
    'Déc',
  ];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final data = await resumeAnnuel(_annee);
    setState(() {
      _data = data;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final fmt = NumberFormat('#,##0', 'fr_FR');
    final totalDep = _data.fold(0.0, (s, m) => s + (m['depenses'] as double));
    final totalRev = _data.fold(0.0, (s, m) => s + (m['revenus'] as double));
    final maxVal = _data.fold(0.0, (s, m) {
      final d = m['depenses'] as double;
      final r = m['revenus'] as double;
      return s < d ? (s < r ? r : s) : (s < r ? r : s);
    });

    return Scaffold(
      appBar: AppBar(title: const Text('Rapport annuel')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(12),
              children: [
                // Navigation année
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    IconButton(
                      onPressed: () {
                        setState(() => _annee--);
                        _load();
                      },
                      icon: const Icon(Icons.chevron_left),
                    ),
                    Text(
                      '$_annee',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 20,
                      ),
                    ),
                    IconButton(
                      onPressed: () {
                        setState(() => _annee++);
                        _load();
                      },
                      icon: const Icon(Icons.chevron_right),
                    ),
                  ],
                ),
                const SizedBox(height: 8),

                // Résumé annuel
                Row(
                  children: [
                    _AnnualStat(
                      label: 'Revenus',
                      value: totalRev,
                      color: Colors.green,
                    ),
                    const SizedBox(width: 8),
                    _AnnualStat(
                      label: 'Dépenses',
                      value: totalDep,
                      color: Colors.red,
                    ),
                    const SizedBox(width: 8),
                    _AnnualStat(
                      label: 'Solde',
                      value: totalRev - totalDep,
                      color: (totalRev - totalDep) >= 0
                          ? Colors.blue
                          : Colors.orange,
                    ),
                  ],
                ),
                const SizedBox(height: 20),

                // Graphique en barres
                const Text(
                  'Évolution mensuelle',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  height: 200,
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: _data.map((m) {
                      final moisIdx = m['mois'] as int;
                      final dep = m['depenses'] as double;
                      final rev = m['revenus'] as double;
                      final depH = maxVal > 0 ? (dep / maxVal) * 160 : 0.0;
                      final revH = maxVal > 0 ? (rev / maxVal) * 160 : 0.0;
                      return Expanded(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Container(
                                  width: 8,
                                  height: revH,
                                  color: Colors.green.shade400,
                                ),
                                const SizedBox(width: 2),
                                Container(
                                  width: 8,
                                  height: depH,
                                  color: Colors.red.shade400,
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text(
                              _moisNoms[moisIdx],
                              style: const TextStyle(fontSize: 9),
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _Legend(color: Colors.green.shade400, label: 'Revenus'),
                    const SizedBox(width: 16),
                    _Legend(color: Colors.red.shade400, label: 'Dépenses'),
                  ],
                ),
                const SizedBox(height: 20),

                // Tableau mensuel
                const Text(
                  'Détail par mois',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                ),
                const SizedBox(height: 8),
                Table(
                  border: TableBorder.all(color: Colors.grey.shade300),
                  columnWidths: const {
                    0: FlexColumnWidth(1.5),
                    1: FlexColumnWidth(2),
                    2: FlexColumnWidth(2),
                    3: FlexColumnWidth(2),
                  },
                  children: [
                    TableRow(
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.primaryContainer,
                      ),
                      children: const [
                        _TableCell(text: 'Mois', bold: true),
                        _TableCell(text: 'Revenus', bold: true),
                        _TableCell(text: 'Dépenses', bold: true),
                        _TableCell(text: 'Solde', bold: true),
                      ],
                    ),
                    ..._data.map((m) {
                      final moisIdx = m['mois'] as int;
                      final dep = m['depenses'] as double;
                      final rev = m['revenus'] as double;
                      final solde = rev - dep;
                      return TableRow(
                        children: [
                          _TableCell(text: _moisNoms[moisIdx]),
                          _TableCell(
                            text: fmt.format(rev),
                            color: Colors.green.shade700,
                          ),
                          _TableCell(
                            text: fmt.format(dep),
                            color: Colors.red.shade700,
                          ),
                          _TableCell(
                            text:
                                '${solde >= 0 ? '+' : ''}${fmt.format(solde)}',
                            color: solde >= 0
                                ? Colors.blue.shade700
                                : Colors.orange.shade700,
                          ),
                        ],
                      );
                    }),
                  ],
                ),
              ],
            ),
    );
  }
}

class _AnnualStat extends StatelessWidget {
  final String label;
  final double value;
  final Color color;
  const _AnnualStat({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final fmt = NumberFormat('#,##0', 'fr_FR');
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: color.withValues(alpha: 0.3)),
        ),
        child: Column(
          children: [
            Text(label, style: TextStyle(color: color, fontSize: 12)),
            Text(
              fmt.format(value),
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: color,
                fontSize: 13,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Legend extends StatelessWidget {
  final Color color;
  final String label;
  const _Legend({required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(width: 12, height: 12, color: color),
        const SizedBox(width: 4),
        Text(label, style: const TextStyle(fontSize: 12)),
      ],
    );
  }
}

class _TableCell extends StatelessWidget {
  final String text;
  final bool bold;
  final Color? color;
  const _TableCell({required this.text, this.bold = false, this.color});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(6),
      child: Text(
        text,
        style: TextStyle(
          fontWeight: bold ? FontWeight.bold : FontWeight.normal,
          color: color,
          fontSize: 12,
        ),
        textAlign: TextAlign.center,
      ),
    );
  }
}
