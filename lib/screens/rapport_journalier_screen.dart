import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../database/dao.dart';
import '../models/models.dart';

class RapportJournalierScreen extends StatefulWidget {
  const RapportJournalierScreen({super.key});

  @override
  State<RapportJournalierScreen> createState() =>
      _RapportJournalierScreenState();
}

class _RapportJournalierScreenState extends State<RapportJournalierScreen> {
  DateTime _date = DateTime.now();
  List<Depense> _depenses = [];
  double _total = 0;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final depenses = await getDepensesJour(_date);
    final total = await sommeDepensesJour(_date);
    setState(() {
      _depenses = depenses;
      _total = total;
      _loading = false;
    });
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (picked != null) {
      setState(() => _date = picked);
      _load();
    }
  }

  @override
  Widget build(BuildContext context) {
    final fmt = NumberFormat('#,##0', 'fr_FR');
    final dateFmt = DateFormat('dd MMMM yyyy', 'fr_FR');
    return Scaffold(
      appBar: AppBar(title: const Text('Rapport journalier')),
      body: Column(
        children: [
          // Sélecteur de date
          Card(
            margin: const EdgeInsets.all(12),
            child: ListTile(
              leading: const Icon(Icons.calendar_today),
              title: Text(
                dateFmt.format(_date),
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              trailing: const Icon(Icons.edit),
              onTap: _pickDate,
            ),
          ),
          // Total du jour
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 12),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.red.shade50,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.red.shade200),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Total dépenses du jour',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
                Text(
                  '${fmt.format(_total)} FCFA',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                    color: Colors.red.shade700,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _depenses.isEmpty
                ? const Center(child: Text('Aucune dépense ce jour.'))
                : ListView.builder(
                    padding: const EdgeInsets.all(12),
                    itemCount: _depenses.length,
                    itemBuilder: (_, i) {
                      final d = _depenses[i];
                      return _DepenseCard(
                        depense: d,
                        onDelete: () async {
                          await deleteDepense(d.id!);
                          _load();
                        },
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

class _DepenseCard extends StatelessWidget {
  final Depense depense;
  final VoidCallback onDelete;
  const _DepenseCard({required this.depense, required this.onDelete});

  @override
  Widget build(BuildContext context) {
    final fmt = NumberFormat('#,##0', 'fr_FR');
    return Card(
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: Theme.of(context).colorScheme.secondaryContainer,
          child: Text(
            depense.categorieNom?[0] ?? '?',
            style: TextStyle(color: Theme.of(context).colorScheme.secondary),
          ),
        ),
        title: Text(depense.articleNom ?? ''),
        subtitle: Text(
          '${depense.quantite} ${depense.uniteNom} × ${fmt.format(depense.prixUnitaire)} FCFA',
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '${fmt.format(depense.total)} FCFA',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            IconButton(
              icon: const Icon(Icons.delete_outline, color: Colors.red),
              onPressed: onDelete,
            ),
          ],
        ),
      ),
    );
  }
}
