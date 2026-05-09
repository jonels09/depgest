import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../database/dao.dart';
import '../models/models.dart';

class PlanningScreen extends StatefulWidget {
  const PlanningScreen({super.key});

  @override
  State<PlanningScreen> createState() => _PlanningScreenState();
}

class _PlanningScreenState extends State<PlanningScreen> {
  int _annee = DateTime.now().year;
  int _mois = DateTime.now().month;
  bool _loading = true;
  List<Budget> _budgets = [];
  List<SavingGoal> _goals = [];
  MonthlyForecast? _forecast;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final results = await Future.wait([
      getBudgetsParMois(_annee, _mois),
      getSavingGoals(),
      getMonthlyForecast(_annee, _mois),
    ]);
    setState(() {
      _budgets = results[0] as List<Budget>;
      _goals = results[1] as List<SavingGoal>;
      _forecast = results[2] as MonthlyForecast;
      _loading = false;
    });
  }

  void _prevMonth() {
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

  void _nextMonth() {
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

  Future<void> _showBudgetDialog([Budget? budget]) async {
    final categories = await getCategories();
    if (!mounted) return;
    int? selectedCategory = budget?.categorieId;
    final amountCtrl = TextEditingController(
      text: budget == null ? '' : budget.montant.toStringAsFixed(0),
    );
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(budget == null ? 'Nouveau budget' : 'Modifier le budget'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            DropdownButtonFormField<int?>(
              initialValue: selectedCategory,
              decoration: const InputDecoration(labelText: 'Categorie'),
              items: [
                const DropdownMenuItem<int?>(
                  value: null,
                  child: Text('Budget global'),
                ),
                ...categories.map(
                  (c) =>
                      DropdownMenuItem<int?>(value: c.id, child: Text(c.nom)),
                ),
              ],
              onChanged: (value) => selectedCategory = value,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: amountCtrl,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: const InputDecoration(labelText: 'Montant'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Annuler'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Enregistrer'),
          ),
        ],
      ),
    );

    final amount = double.tryParse(amountCtrl.text.replaceAll(',', '.'));
    if (ok == true && amount != null && amount > 0) {
      await upsertBudget(
        Budget(
          id: budget?.id,
          categorieId: selectedCategory,
          mois: _monthKey(_annee, _mois),
          montant: amount,
        ),
      );
      await _load();
    }
  }

  Future<void> _showGoalDialog([SavingGoal? goal]) async {
    final nameCtrl = TextEditingController(text: goal?.nom ?? '');
    final targetCtrl = TextEditingController(
      text: goal == null ? '' : goal.targetAmount.toStringAsFixed(0),
    );
    DateTime? dueDate = goal?.dueDate == null
        ? null
        : DateTime.tryParse(goal!.dueDate!);

    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(goal == null ? "Nouvel objectif" : "Modifier l'objectif"),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameCtrl,
                decoration: const InputDecoration(labelText: 'Nom'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: targetCtrl,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: const InputDecoration(labelText: 'Montant cible'),
              ),
              const SizedBox(height: 12),
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Date cible'),
                subtitle: Text(
                  dueDate == null
                      ? 'Optionnelle'
                      : DateFormat('dd MMMM yyyy', 'fr_FR').format(dueDate!),
                ),
                trailing: const Icon(Icons.calendar_today),
                onTap: () async {
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: dueDate ?? DateTime.now(),
                    firstDate: DateTime.now().subtract(const Duration(days: 1)),
                    lastDate: DateTime(DateTime.now().year + 20),
                  );
                  if (picked != null) {
                    setDialogState(() => dueDate = picked);
                  }
                },
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Annuler'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Enregistrer'),
            ),
          ],
        ),
      ),
    );

    final target = double.tryParse(targetCtrl.text.replaceAll(',', '.'));
    if (ok == true &&
        nameCtrl.text.trim().isNotEmpty &&
        target != null &&
        target > 0) {
      await upsertSavingGoal(
        SavingGoal(
          id: goal?.id,
          nom: nameCtrl.text.trim(),
          targetAmount: target,
          currentAmount: goal?.currentAmount ?? 0,
          dueDate: dueDate == null ? null : _dateStr(dueDate!),
        ),
      );
      await _load();
    }
  }

  Future<void> _showContributionDialog(SavingGoal goal) async {
    final amountCtrl = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Ajouter a "${goal.nom}"'),
        content: TextField(
          controller: amountCtrl,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: const InputDecoration(labelText: 'Montant epargne'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Annuler'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Ajouter'),
          ),
        ],
      ),
    );
    final amount = double.tryParse(amountCtrl.text.replaceAll(',', '.'));
    if (ok == true && amount != null && amount > 0) {
      await addSavingContribution(goal.id!, amount);
      await _load();
    }
  }

  @override
  Widget build(BuildContext context) {
    final fmt = NumberFormat('#,##0', 'fr_FR');
    final monthLabel = DateFormat(
      'MMMM yyyy',
      'fr_FR',
    ).format(DateTime(_annee, _mois));

    return Scaffold(
      backgroundColor: const Color(0xFFF4F3F6),
      appBar: AppBar(
        backgroundColor: const Color(0xFFF4F3F6),
        elevation: 0,
        title: const Text('Plan financier'),
        actions: [
          IconButton(
            onPressed: _showBudgetDialog,
            icon: const Icon(Icons.account_balance_wallet_outlined),
            tooltip: 'Ajouter un budget',
          ),
          IconButton(
            onPressed: _showGoalDialog,
            icon: const Icon(Icons.savings_outlined),
            tooltip: 'Ajouter un objectif',
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 120),
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      IconButton(
                        onPressed: _prevMonth,
                        icon: const Icon(Icons.chevron_left),
                      ),
                      Text(
                        monthLabel.toUpperCase(),
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 16,
                        ),
                      ),
                      IconButton(
                        onPressed: _nextMonth,
                        icon: const Icon(Icons.chevron_right),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  if (_forecast != null)
                    _ForecastCard(forecast: _forecast!, fmt: fmt),
                  const SizedBox(height: 20),
                  _SectionHeader(
                    title: 'Budgets',
                    actionLabel: 'Ajouter',
                    onTap: _showBudgetDialog,
                  ),
                  const SizedBox(height: 8),
                  if (_budgets.isEmpty)
                    const _EmptyState(text: 'Aucun budget pour ce mois.')
                  else
                    ..._budgets.map(
                      (budget) => _BudgetCard(
                        budget: budget,
                        fmt: fmt,
                        onEdit: () => _showBudgetDialog(budget),
                        onDelete: () async {
                          await deleteBudget(budget.id!);
                          await _load();
                        },
                      ),
                    ),
                  const SizedBox(height: 20),
                  _SectionHeader(
                    title: "Objectifs d'epargne",
                    actionLabel: 'Ajouter',
                    onTap: _showGoalDialog,
                  ),
                  const SizedBox(height: 8),
                  if (_goals.isEmpty)
                    const _EmptyState(text: 'Aucun objectif pour le moment.')
                  else
                    ..._goals.map(
                      (goal) => _GoalCard(
                        goal: goal,
                        fmt: fmt,
                        onContribute: () => _showContributionDialog(goal),
                        onEdit: () => _showGoalDialog(goal),
                        onDelete: () async {
                          await deleteSavingGoal(goal.id!);
                          await _load();
                        },
                      ),
                    ),
                ],
              ),
            ),
    );
  }
}

class _ForecastCard extends StatelessWidget {
  final MonthlyForecast forecast;
  final NumberFormat fmt;

  const _ForecastCard({required this.forecast, required this.fmt});

  @override
  Widget build(BuildContext context) {
    final overBudget =
        forecast.budgetTotal > 0 &&
        forecast.projectedSpending > forecast.budgetTotal;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: overBudget ? Colors.red.shade200 : Colors.green.shade200,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Prevision du mois',
            style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
          ),
          const SizedBox(height: 12),
          _MetricRow(
            label: 'Depense actuelle',
            value: '${fmt.format(forecast.spentSoFar)} Ar',
          ),
          _MetricRow(
            label: 'Projection fin de mois',
            value: '${fmt.format(forecast.projectedSpending)} Ar',
          ),
          _MetricRow(
            label: 'Moyenne 3 mois',
            value: '${fmt.format(forecast.averagePreviousMonths)} Ar',
          ),
          _MetricRow(
            label: 'Budget total',
            value: forecast.budgetTotal == 0
                ? 'Non defini'
                : '${fmt.format(forecast.budgetTotal)} Ar',
          ),
        ],
      ),
    );
  }
}

class _BudgetCard extends StatelessWidget {
  final Budget budget;
  final NumberFormat fmt;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _BudgetCard({
    required this.budget,
    required this.fmt,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final progress = budget.montant <= 0
        ? 0.0
        : (budget.depenseActuelle / budget.montant).clamp(0.0, 1.0).toDouble();
    final remaining = budget.montant - budget.depenseActuelle;
    return Card(
      child: ListTile(
        title: Text(budget.categorieNom ?? 'Budget global'),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 6),
            LinearProgressIndicator(value: progress),
            const SizedBox(height: 6),
            Text(
              '${fmt.format(budget.depenseActuelle)} / ${fmt.format(budget.montant)} Ar',
            ),
            Text(
              remaining >= 0
                  ? 'Reste ${fmt.format(remaining)} Ar'
                  : 'Depassement ${fmt.format(remaining.abs())} Ar',
            ),
          ],
        ),
        trailing: PopupMenuButton<String>(
          onSelected: (value) => value == 'edit' ? onEdit() : onDelete(),
          itemBuilder: (context) => const [
            PopupMenuItem(value: 'edit', child: Text('Modifier')),
            PopupMenuItem(value: 'delete', child: Text('Supprimer')),
          ],
        ),
      ),
    );
  }
}

class _GoalCard extends StatelessWidget {
  final SavingGoal goal;
  final NumberFormat fmt;
  final VoidCallback onContribute;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _GoalCard({
    required this.goal,
    required this.fmt,
    required this.onContribute,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final progress = goal.targetAmount <= 0
        ? 0.0
        : (goal.currentAmount / goal.targetAmount).clamp(0.0, 1.0).toDouble();
    return Card(
      child: ListTile(
        title: Text(goal.nom),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 6),
            LinearProgressIndicator(value: progress),
            const SizedBox(height: 6),
            Text(
              '${fmt.format(goal.currentAmount)} / ${fmt.format(goal.targetAmount)} Ar',
            ),
            if (goal.dueDate != null) Text('Date cible : ${goal.dueDate}'),
          ],
        ),
        trailing: PopupMenuButton<String>(
          onSelected: (value) {
            if (value == 'add') onContribute();
            if (value == 'edit') onEdit();
            if (value == 'delete') onDelete();
          },
          itemBuilder: (context) => const [
            PopupMenuItem(value: 'add', child: Text('Ajouter')),
            PopupMenuItem(value: 'edit', child: Text('Modifier')),
            PopupMenuItem(value: 'delete', child: Text('Supprimer')),
          ],
        ),
      ),
    );
  }
}

class _MetricRow extends StatelessWidget {
  final String label;
  final String value;

  const _MetricRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  final String actionLabel;
  final VoidCallback onTap;

  const _SectionHeader({
    required this.title,
    required this.actionLabel,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          title,
          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 18),
        ),
        TextButton.icon(
          onPressed: onTap,
          icon: const Icon(Icons.add),
          label: Text(actionLabel),
        ),
      ],
    );
  }
}

class _EmptyState extends StatelessWidget {
  final String text;
  const _EmptyState({required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(text, textAlign: TextAlign.center),
    );
  }
}

String _monthKey(int annee, int mois) =>
    '${annee.toString().padLeft(4, '0')}-${mois.toString().padLeft(2, '0')}';

String _dateStr(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
