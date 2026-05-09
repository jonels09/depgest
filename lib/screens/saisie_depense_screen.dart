import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../database/dao.dart';
import '../models/models.dart';

class SaisieDepenseScreen extends StatefulWidget {
  const SaisieDepenseScreen({super.key});

  @override
  State<SaisieDepenseScreen> createState() => _SaisieDepenseScreenState();
}

class _SaisieDepenseScreenState extends State<SaisieDepenseScreen> {
  List<Categorie> _categories = [];
  List<Article> _articles = [];
  List<Unite> _unites = [];

  Categorie? _selectedCategorie;
  Article? _selectedArticle;
  Unite? _selectedUnite;
  DateTime _selectedDate = DateTime.now();

  final _quantiteCtrl = TextEditingController();
  final _prixCtrl = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  double get _total {
    final q = double.tryParse(_quantiteCtrl.text) ?? 0;
    final p = double.tryParse(_prixCtrl.text) ?? 0;
    return q * p;
  }

  @override
  void initState() {
    super.initState();
    _loadCategories();
    _loadUnites();
    _quantiteCtrl.addListener(() => setState(() {}));
    _prixCtrl.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _quantiteCtrl.dispose();
    _prixCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadCategories() async {
    final cats = await getCategories();
    setState(() => _categories = cats);
  }

  Future<void> _loadUnites() async {
    final units = await getUnites();
    setState(() => _unites = units);
  }

  Future<void> _onCategorieChanged(Categorie? cat) async {
    setState(() {
      _selectedCategorie = cat;
      _selectedArticle = null;
      _articles = [];
    });
    if (cat != null) {
      final arts = await getArticlesByCategorie(cat.id!);
      setState(() => _articles = arts);
    }
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (picked != null) setState(() => _selectedDate = picked);
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedArticle == null || _selectedUnite == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Veuillez compléter tous les champs.')),
      );
      return;
    }
    final q = double.parse(_quantiteCtrl.text);
    final p = double.parse(_prixCtrl.text);
    final depense = Depense(
      articleId: _selectedArticle!.id!,
      uniteId: _selectedUnite!.id!,
      quantite: q,
      prixUnitaire: p,
      total: q * p,
      dateDepense: DateFormat('yyyy-MM-dd').format(_selectedDate),
    );
    await insertDepense(depense);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Dépense enregistrée ✓'),
          backgroundColor: Colors.green,
        ),
      );
      Navigator.pop(context, true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final fmt = NumberFormat('#,##0.00', 'fr_FR');
    return Scaffold(
      appBar: AppBar(title: const Text('Nouvelle dépense')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Étape 1 – Catégorie
            _StepCard(
              step: '1',
              label: 'Catégorie',
              child: DropdownButtonFormField<Categorie>(
                initialValue: _selectedCategorie,
                hint: const Text('Choisir une catégorie'),
                items: _categories
                    .map((c) => DropdownMenuItem(value: c, child: Text(c.nom)))
                    .toList(),
                onChanged: _onCategorieChanged,
                validator: (v) => v == null ? 'Requis' : null,
              ),
            ),
            const SizedBox(height: 12),

            // Étape 2 – Article
            _StepCard(
              step: '2',
              label: 'Article',
              child: DropdownButtonFormField<Article>(
                initialValue: _selectedArticle,
                hint: const Text('Choisir un article'),
                items: _articles
                    .map((a) => DropdownMenuItem(value: a, child: Text(a.nom)))
                    .toList(),
                onChanged: _selectedCategorie == null
                    ? null
                    : (a) => setState(() => _selectedArticle = a),
                validator: (v) => v == null ? 'Requis' : null,
              ),
            ),
            const SizedBox(height: 12),

            // Étape 3 – Unité
            _StepCard(
              step: '3',
              label: 'Unité de mesure',
              child: DropdownButtonFormField<Unite>(
                initialValue: _selectedUnite,
                hint: const Text('Choisir une unité'),
                items: _unites
                    .map((u) => DropdownMenuItem(value: u, child: Text(u.nom)))
                    .toList(),
                onChanged: (u) => setState(() => _selectedUnite = u),
                validator: (v) => v == null ? 'Requis' : null,
              ),
            ),
            const SizedBox(height: 12),

            // Étape 4 – Date
            _StepCard(
              step: '4',
              label: 'Date',
              child: ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(
                  DateFormat('dd MMMM yyyy', 'fr_FR').format(_selectedDate),
                ),
                trailing: const Icon(Icons.calendar_today),
                onTap: _pickDate,
              ),
            ),
            const SizedBox(height: 12),

            // Étape 5 – Quantité & Prix
            _StepCard(
              step: '5',
              label: 'Quantité & Prix unitaire',
              child: Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _quantiteCtrl,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      decoration: const InputDecoration(labelText: 'Quantité'),
                      validator: (v) =>
                          (v == null || double.tryParse(v) == null)
                          ? 'Invalide'
                          : null,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextFormField(
                      controller: _prixCtrl,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      decoration: const InputDecoration(
                        labelText: 'Prix unitaire',
                      ),
                      validator: (v) =>
                          (v == null || double.tryParse(v) == null)
                          ? 'Invalide'
                          : null,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Total calculé
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primaryContainer,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'TOTAL',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                  Text(
                    '${fmt.format(_total)} FCFA',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 20,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            FilledButton.icon(
              onPressed: _save,
              icon: const Icon(Icons.save),
              label: const Text('Enregistrer la dépense'),
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(50),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StepCard extends StatelessWidget {
  final String step;
  final String label;
  final Widget child;
  const _StepCard({
    required this.step,
    required this.label,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 12,
                  backgroundColor: Theme.of(context).colorScheme.primary,
                  child: Text(
                    step,
                    style: const TextStyle(color: Colors.white, fontSize: 12),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  label,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
              ],
            ),
            const SizedBox(height: 8),
            child,
          ],
        ),
      ),
    );
  }
}
