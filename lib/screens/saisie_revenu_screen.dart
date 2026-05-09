import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../database/dao.dart';
import '../models/models.dart';

class SaisieRevenuScreen extends StatefulWidget {
  const SaisieRevenuScreen({super.key});

  @override
  State<SaisieRevenuScreen> createState() => _SaisieRevenuScreenState();
}

class _SaisieRevenuScreenState extends State<SaisieRevenuScreen> {
  final _sourceCtrl = TextEditingController();
  final _montantCtrl = TextEditingController();
  DateTime _selectedDate = DateTime.now();
  final _formKey = GlobalKey<FormState>();

  @override
  void dispose() {
    _sourceCtrl.dispose();
    _montantCtrl.dispose();
    super.dispose();
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
    final revenu = Revenu(
      source: _sourceCtrl.text,
      montant: double.parse(_montantCtrl.text),
      dateRevenu: DateFormat('yyyy-MM-dd').format(_selectedDate),
    );
    await insertRevenu(revenu);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Revenu enregistré ✓'),
          backgroundColor: Colors.green,
        ),
      );
      Navigator.pop(context, true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Nouveau revenu')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            TextFormField(
              controller: _sourceCtrl,
              decoration: const InputDecoration(
                labelText: 'Source du revenu',
                border: OutlineInputBorder(),
              ),
              validator: (v) => (v == null || v.isEmpty) ? 'Requis' : null,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _montantCtrl,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: const InputDecoration(
                labelText: 'Montant',
                border: OutlineInputBorder(),
                suffixText: 'FCFA',
              ),
              validator: (v) =>
                  (v == null || double.tryParse(v) == null) ? 'Invalide' : null,
            ),
            const SizedBox(height: 16),
            Card(
              child: ListTile(
                title: const Text('Date'),
                subtitle: Text(
                  DateFormat('dd MMMM yyyy', 'fr_FR').format(_selectedDate),
                ),
                trailing: const Icon(Icons.calendar_today),
                onTap: _pickDate,
              ),
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: _save,
              icon: const Icon(Icons.save),
              label: const Text('Enregistrer le revenu'),
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
