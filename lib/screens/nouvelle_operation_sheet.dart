import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../database/dao.dart';
import '../models/models.dart';

// ── Design tokens (partagés) ─────────────────────────────────────────────────
class _C {
  static const primary = Color(0xFF004394);
  static const onPrimary = Color(0xFFFFFFFF);
  static const secondary = Color(0xFF006D39);
  static const error = Color(0xFFBA1A1A);
  static const surface = Color(0xFFFAF9FC);
  static const surfaceContainerLow = Color(0xFFF4F3F6);
  static const surfaceContainerLowest = Color(0xFFFFFFFF);
  static const surfaceContainerHighest = Color(0xFFE3E2E5);
  static const outlineVariant = Color(0xFFC2C6D5);
  static const onSurface = Color(0xFF1A1C1E);
  static const onSurfaceVariant = Color(0xFF424753);
}

/// Ouvre la bottom sheet unifiée Dépense / Revenu.
/// Retourne `true` si une opération a été enregistrée.
Future<bool?> showNouvelleOperationSheet(BuildContext context) {
  return showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => const _NouvelleOperationSheet(),
  );
}

// ── Bottom Sheet principale ──────────────────────────────────────────────────

class _NouvelleOperationSheet extends StatefulWidget {
  const _NouvelleOperationSheet();

  @override
  State<_NouvelleOperationSheet> createState() =>
      _NouvelleOperationSheetState();
}

class _NouvelleOperationSheetState extends State<_NouvelleOperationSheet> {
  bool _isDepense = true;

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Container(
      decoration: const BoxDecoration(
        color: _C.surfaceContainerLow,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.92,
      ),
      padding: EdgeInsets.only(bottom: bottomInset),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Drag handle
          const SizedBox(height: 12),
          Center(
            child: Container(
              width: 40,
              height: 6,
              decoration: BoxDecoration(
                color: _C.outlineVariant.withValues(alpha: 0.4),
                borderRadius: BorderRadius.circular(3),
              ),
            ),
          ),
          const SizedBox(height: 12),

          // Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Nouvelle Opération',
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 28,
                    fontWeight: FontWeight.w700,
                    color: _C.onSurface,
                  ),
                ),
                GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: _C.surfaceContainerHighest.withValues(alpha: 0.5),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.close,
                      color: _C.onSurface,
                      size: 20,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Toggle Dépense / Revenu
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: _Toggle(
              isDepense: _isDepense,
              onChanged: (v) => setState(() => _isDepense = v),
            ),
          ),
          const SizedBox(height: 16),

          // Formulaire scrollable
          Flexible(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 32),
              child: _isDepense
                  ? _DepenseForm(onSaved: () => Navigator.pop(context, true))
                  : _RevenuForm(onSaved: () => Navigator.pop(context, true)),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Toggle Dépense / Revenu ──────────────────────────────────────────────────

class _Toggle extends StatelessWidget {
  final bool isDepense;
  final ValueChanged<bool> onChanged;
  const _Toggle({required this.isDepense, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 52,
      padding: const EdgeInsets.all(5),
      decoration: BoxDecoration(
        color: _C.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(50), // pill container
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          _ToggleBtn(
            label: 'Dépense',
            active: isDepense,
            activeColor: _C.primary,
            onTap: () => onChanged(true),
          ),
          _ToggleBtn(
            label: 'Revenu',
            active: !isDepense,
            activeColor: _C.secondary,
            onTap: () => onChanged(false),
          ),
        ],
      ),
    );
  }
}

class _ToggleBtn extends StatelessWidget {
  final String label;
  final bool active;
  final Color activeColor;
  final VoidCallback onTap;
  const _ToggleBtn({
    required this.label,
    required this.active,
    required this.activeColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          decoration: BoxDecoration(
            color: active ? activeColor : Colors.transparent,
            borderRadius: BorderRadius.circular(50), // pill button
            boxShadow: active
                ? [
                    BoxShadow(
                      color: activeColor.withValues(alpha: 0.25),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ]
                : [],
          ),
          alignment: Alignment.center,
          child: Text(
            label,
            style: TextStyle(
              fontFamily: 'Inter',
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: active ? _C.onPrimary : _C.onSurfaceVariant,
            ),
          ),
        ),
      ),
    );
  }
}

// ── Formulaire Dépense ───────────────────────────────────────────────────────

class _DepenseForm extends StatefulWidget {
  final VoidCallback onSaved;
  const _DepenseForm({required this.onSaved});

  @override
  State<_DepenseForm> createState() => _DepenseFormState();
}

class _DepenseFormState extends State<_DepenseForm> {
  final _formKey = GlobalKey<FormState>();
  List<Categorie> _categories = [];
  List<Article> _articles = [];
  List<Unite> _unites = [];

  Categorie? _cat;
  Article? _article;
  Unite? _unite;
  DateTime _date = DateTime.now();

  final _qCtrl = TextEditingController();
  final _pCtrl = TextEditingController();

  double get _total {
    final q = double.tryParse(_qCtrl.text.replaceAll(',', '.')) ?? 0;
    final p = double.tryParse(_pCtrl.text.replaceAll(',', '.')) ?? 0;
    return q * p;
  }

  @override
  void initState() {
    super.initState();
    _load();
    _qCtrl.addListener(() => setState(() {}));
    _pCtrl.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _qCtrl.dispose();
    _pCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final cats = await getCategories();
    final units = await getUnites();
    setState(() {
      _categories = cats;
      _unites = units;
    });
  }

  Future<void> _onCatChanged(Categorie? cat) async {
    setState(() {
      _cat = cat;
      _article = null;
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
      initialDate: _date,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (picked != null) setState(() => _date = picked);
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (_article == null || _unite == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Veuillez compléter tous les champs.')),
      );
      return;
    }
    final q = double.parse(_qCtrl.text.replaceAll(',', '.'));
    final p = double.parse(_pCtrl.text.replaceAll(',', '.'));
    await insertDepense(
      Depense(
        articleId: _article!.id!,
        uniteId: _unite!.id!,
        quantite: q,
        prixUnitaire: p,
        total: q * p,
        dateDepense: DateFormat('yyyy-MM-dd').format(_date),
      ),
    );
    if (mounted) widget.onSaved();
  }

  @override
  Widget build(BuildContext context) {
    final fmt = NumberFormat('#,##0.00', 'fr_FR');
    final dateStr = _isToday(_date)
        ? "Aujourd'hui"
        : DateFormat('dd MMMM yyyy', 'fr_FR').format(_date);

    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Card 1 : Catégorisation ──────────────────────────────────
          _FormCard(
            children: [
              _FieldLabel('Catégorie'),
              _StyledDropdown<Categorie>(
                hint: 'Choisir une catégorie',
                value: _cat,
                items: _categories,
                itemLabel: (c) => c.nom,
                prefixIcon: Icons.restaurant,
                onChanged: _onCatChanged,
                validator: (v) => v == null ? 'Requis' : null,
              ),
              const SizedBox(height: 16),
              _FieldLabel('Article / Source'),
              _StyledDropdown<Article>(
                hint: 'Choisir un article',
                value: _article,
                items: _articles,
                itemLabel: (a) => a.nom,
                onChanged: _cat == null
                    ? null
                    : (a) => setState(() => _article = a),
                validator: (v) => v == null ? 'Requis' : null,
              ),
            ],
          ),
          const SizedBox(height: 16),

          // ── Card 2 : Montants ────────────────────────────────────────
          _FormCard(
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _FieldLabel('Quantité'),
                        _StyledInput(
                          controller: _qCtrl,
                          hint: '0.00',
                          validator: (v) =>
                              (v == null ||
                                  double.tryParse(v.replaceAll(',', '.')) ==
                                      null)
                              ? 'Invalide'
                              : null,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  SizedBox(
                    width: 110,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _FieldLabel('Unité'),
                        _StyledDropdown<Unite>(
                          hint: 'kg',
                          value: _unite,
                          items: _unites,
                          itemLabel: (u) => u.nom,
                          onChanged: (u) => setState(() => _unite = u),
                          validator: (v) => v == null ? 'Requis' : null,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              _FieldLabel('Prix Unitaire'),
              _StyledInput(
                controller: _pCtrl,
                hint: '0,00',
                suffix: 'Ar',
                validator: (v) =>
                    (v == null ||
                        double.tryParse(v.replaceAll(',', '.')) == null)
                    ? 'Invalide'
                    : null,
              ),
            ],
          ),
          const SizedBox(height: 16),

          // ── Card 3 : Date ────────────────────────────────────────────
          _FormCard(
            children: [
              _FieldLabel("Date de l'opération"),
              const SizedBox(height: 8),
              GestureDetector(
                onTap: _pickDate,
                child: Container(
                  height: 56,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  decoration: BoxDecoration(
                    color: _C.surfaceContainerLow,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.calendar_today,
                        color: _C.primary,
                        size: 22,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          dateStr,
                          style: const TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: _C.onSurface,
                          ),
                        ),
                      ),
                      const Icon(
                        Icons.edit_calendar,
                        color: _C.onSurfaceVariant,
                        size: 20,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // ── Total estimé ─────────────────────────────────────────────
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
            decoration: BoxDecoration(
              color: _C.primary,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: _C.primary.withValues(alpha: 0.35),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'TOTAL ESTIMÉ',
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1.5,
                        color: Color(0xB3FFFFFF),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      fmt.format(_total),
                      style: const TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 40,
                        fontWeight: FontWeight.w900,
                        color: _C.onPrimary,
                        height: 1,
                      ),
                    ),
                    const Text(
                      'Ar',
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        color: _C.onPrimary,
                      ),
                    ),
                  ],
                ),
                Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: const Icon(
                    Icons.payments,
                    color: _C.onPrimary,
                    size: 32,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // ── Bouton enregistrer ───────────────────────────────────────
          SizedBox(
            width: double.infinity,
            height: 64,
            child: ElevatedButton.icon(
              onPressed: _save,
              icon: const Icon(Icons.add_circle, size: 24),
              label: const Text(
                'Enregistrer la dépense',
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: _C.onSurface,
                foregroundColor: _C.surface,
                elevation: 6,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

bool _isToday(DateTime d) {
  final now = DateTime.now();
  return d.year == now.year && d.month == now.month && d.day == now.day;
}

// ── Formulaire Revenu ────────────────────────────────────────────────────────

class _RevenuForm extends StatefulWidget {
  final VoidCallback onSaved;
  const _RevenuForm({required this.onSaved});

  @override
  State<_RevenuForm> createState() => _RevenuFormState();
}

class _RevenuFormState extends State<_RevenuForm> {
  final _formKey = GlobalKey<FormState>();
  final _sourceCtrl = TextEditingController();
  final _montantCtrl = TextEditingController();
  DateTime _date = DateTime.now();

  double get _montant =>
      double.tryParse(_montantCtrl.text.replaceAll(',', '.')) ?? 0;

  @override
  void initState() {
    super.initState();
    _montantCtrl.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _sourceCtrl.dispose();
    _montantCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (picked != null) setState(() => _date = picked);
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    await insertRevenu(
      Revenu(
        source: _sourceCtrl.text,
        montant: _montant,
        dateRevenu: DateFormat('yyyy-MM-dd').format(_date),
      ),
    );
    if (mounted) widget.onSaved();
  }

  @override
  Widget build(BuildContext context) {
    final fmt = NumberFormat('#,##0.00', 'fr_FR');
    final dateStr = _isToday(_date)
        ? "Aujourd'hui"
        : DateFormat('dd MMMM yyyy', 'fr_FR').format(_date);

    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Card source ──────────────────────────────────────────────
          _FormCard(
            children: [
              _FieldLabel('Source du revenu'),
              _StyledInput(
                controller: _sourceCtrl,
                hint: 'Ex: Salaire, Freelance…',
                keyboardType: TextInputType.text,
                validator: (v) => (v == null || v.isEmpty) ? 'Requis' : null,
              ),
              const SizedBox(height: 16),
              _FieldLabel('Montant'),
              _StyledInput(
                controller: _montantCtrl,
                hint: '0,00',
                suffix: 'Ar',
                validator: (v) =>
                    (v == null ||
                        double.tryParse(v.replaceAll(',', '.')) == null)
                    ? 'Invalide'
                    : null,
              ),
            ],
          ),
          const SizedBox(height: 16),

          // ── Card date ────────────────────────────────────────────────
          _FormCard(
            children: [
              _FieldLabel("Date de l'opération"),
              const SizedBox(height: 8),
              GestureDetector(
                onTap: _pickDate,
                child: Container(
                  height: 56,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  decoration: BoxDecoration(
                    color: _C.surfaceContainerLow,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.calendar_today,
                        color: _C.secondary,
                        size: 22,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          dateStr,
                          style: const TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: _C.onSurface,
                          ),
                        ),
                      ),
                      const Icon(
                        Icons.edit_calendar,
                        color: _C.onSurfaceVariant,
                        size: 20,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // ── Total estimé (vert pour revenu) ──────────────────────────
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
            decoration: BoxDecoration(
              color: _C.secondary,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: _C.secondary.withValues(alpha: 0.35),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'MONTANT',
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1.5,
                        color: Color(0xB3FFFFFF),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      fmt.format(_montant),
                      style: const TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 40,
                        fontWeight: FontWeight.w900,
                        color: _C.onPrimary,
                        height: 1,
                      ),
                    ),
                    const Text(
                      'Ar',
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        color: _C.onPrimary,
                      ),
                    ),
                  ],
                ),
                Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: const Icon(
                    Icons.savings,
                    color: _C.onPrimary,
                    size: 32,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // ── Bouton enregistrer ───────────────────────────────────────
          SizedBox(
            width: double.infinity,
            height: 64,
            child: ElevatedButton.icon(
              onPressed: _save,
              icon: const Icon(Icons.add_circle, size: 24),
              label: const Text(
                'Enregistrer le revenu',
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: _C.onSurface,
                foregroundColor: _C.surface,
                elevation: 6,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Widgets réutilisables ────────────────────────────────────────────────────

class _FormCard extends StatelessWidget {
  final List<Widget> children;
  const _FormCard({required this.children});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
      decoration: BoxDecoration(
        color: _C.surfaceContainerLowest, // blanc pur
        borderRadius: BorderRadius.circular(16),
        // Pas de border visible — ombre légère seulement
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: children,
      ),
    );
  }
}

class _FieldLabel extends StatelessWidget {
  final String text;
  const _FieldLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Text(
        text.toUpperCase(),
        style: const TextStyle(
          fontFamily: 'Inter',
          fontSize: 13,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.5,
          color: _C.onSurface,
        ),
      ),
    );
  }
}

class _StyledInput extends StatelessWidget {
  final TextEditingController controller;
  final String hint;
  final String? suffix;
  final TextInputType keyboardType;
  final String? Function(String?)? validator;

  const _StyledInput({
    required this.controller,
    required this.hint,
    this.suffix,
    this.keyboardType = const TextInputType.numberWithOptions(decimal: true),
    this.validator,
  });

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      validator: validator,
      style: const TextStyle(
        fontFamily: 'Inter',
        fontSize: 20,
        fontWeight: FontWeight.w700,
        color: _C.onSurface,
      ),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(
          fontFamily: 'Inter',
          color: _C.onSurfaceVariant,
          fontWeight: FontWeight.w400,
          fontSize: 20,
        ),
        suffixText: suffix,
        suffixStyle: const TextStyle(
          fontFamily: 'Inter',
          fontSize: 20,
          fontWeight: FontWeight.w700,
          color: _C.primary,
        ),
        filled: true,
        fillColor: _C.surfaceContainerLow,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: _C.primary, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: _C.error, width: 1),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: _C.error, width: 2),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 18,
        ),
      ),
    );
  }
}

class _StyledDropdown<T> extends StatelessWidget {
  final String hint;
  final T? value;
  final List<T> items;
  final String Function(T) itemLabel;
  final IconData? prefixIcon;
  final void Function(T?)? onChanged;
  final String? Function(T?)? validator;

  const _StyledDropdown({
    required this.hint,
    required this.value,
    required this.items,
    required this.itemLabel,
    this.prefixIcon,
    this.onChanged,
    this.validator,
  });

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<T>(
      initialValue: value,
      onChanged: onChanged,
      validator: validator,
      hint: Text(
        hint,
        style: const TextStyle(
          fontFamily: 'Inter',
          color: _C.onSurfaceVariant,
          fontSize: 16,
        ),
      ),
      // Chevron bleu comme dans le design
      icon: const Icon(
        Icons.keyboard_arrow_down_rounded,
        color: _C.primary,
        size: 26,
      ),
      style: const TextStyle(
        fontFamily: 'Inter',
        fontSize: 16,
        fontWeight: FontWeight.w600,
        color: _C.onSurface,
      ),
      decoration: InputDecoration(
        prefixIcon: prefixIcon != null
            ? Icon(prefixIcon, color: _C.primary, size: 22)
            : null,
        filled: true,
        fillColor: _C.surfaceContainerLow,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: _C.primary, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: _C.error, width: 1),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: _C.error, width: 2),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      ),
      items: items
          .map(
            (item) =>
                DropdownMenuItem<T>(value: item, child: Text(itemLabel(item))),
          )
          .toList(),
    );
  }
}
