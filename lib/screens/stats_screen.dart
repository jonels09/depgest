import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../database/dao.dart';
import '../models/models.dart';

// ── Design tokens ─────────────────────────────────────────────────────────────
class _C {
  static const primary = Color(0xFF004394);
  static const primaryContainer = Color(0xFF005AC1);
  static const primaryFixed = Color(0xFFD8E2FF);
  static const onPrimaryFixed = Color(0xFF001A41);
  static const secondary = Color(0xFF006D39);
  static const error = Color(0xFFBA1A1A);
  static const tertiaryFixed = Color(0xFFFFDAD5);
  static const onTertiaryFixed = Color(0xFF410002);
  static const surfaceContainerLow = Color(0xFFF4F3F6);
  static const surfaceContainerHigh = Color(0xFFE8E8EB);
  static const surfaceContainerLowest = Color(0xFFFFFFFF);
  static const surfaceVariant = Color(0xFFE3E2E5);
  static const outline = Color(0xFF727784);
  static const onSurface = Color(0xFF1A1C1E);
  static const onSurfaceVariant = Color(0xFF424753);
  static const onBackground = Color(0xFF1A1C1E);
}

// ── Palette donut (4 couleurs) ────────────────────────────────────────────────
const _donutColors = [_C.primary, _C.secondary, _C.error, _C.surfaceVariant];

// ── Icônes par catégorie ──────────────────────────────────────────────────────
const _catIcons = <String, IconData>{
  'Alimentation': Icons.restaurant,
  'Transport': Icons.directions_car,
  'Santé': Icons.local_hospital,
  'Logement': Icons.house,
  'Loisirs': Icons.theater_comedy,
};
const _catBg = <String, Color>{
  'Alimentation': _C.primaryFixed,
  'Transport': _C.tertiaryFixed,
  'Santé': Color(0xFFFFDAD6),
  'Logement': _C.primaryFixed,
  'Loisirs': _C.tertiaryFixed,
};
const _catFg = <String, Color>{
  'Alimentation': _C.onPrimaryFixed,
  'Transport': _C.onTertiaryFixed,
  'Santé': _C.error,
  'Logement': _C.onPrimaryFixed,
  'Loisirs': _C.onTertiaryFixed,
};

// ── Période ───────────────────────────────────────────────────────────────────
enum _Periode { jour, mois, annee }

class StatsScreen extends StatefulWidget {
  const StatsScreen({super.key});

  @override
  State<StatsScreen> createState() => _StatsScreenState();
}

class _StatsScreenState extends State<StatsScreen> {
  _Periode _periode = _Periode.mois;
  bool _loading = true;

  double _totalDepenses = 0;
  // [{categorie, total, transactions: [{article_nom, total}]}]
  List<_CatData> _categories = [];
  // index de la tranche sélectionnée dans le donut
  int _selectedSlice = 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final now = DateTime.now();

    List<Map<String, dynamic>> catRows;
    List<Depense> depenses;

    switch (_periode) {
      case _Periode.jour:
        depenses = await getDepensesJour(now);
        catRows = await _catParJour(now);
      case _Periode.mois:
        depenses = await getDepensesMois(now.year, now.month);
        catRows = await depensesParCategorieMois(now.year, now.month);
      case _Periode.annee:
        depenses = await _depensesAnnee(now.year);
        catRows = await _catParAnnee(now.year);
    }

    final total = depenses.fold(0.0, (s, d) => s + d.total);

    // Construire _CatData avec les articles détaillés
    final cats = <_CatData>[];
    for (final row in catRows) {
      final catNom = row['categorie'] as String;
      final catTotal = (row['total'] as num).toDouble();
      // Articles de cette catégorie dans la période
      final arts =
          depenses
              .where((d) => d.categorieNom == catNom)
              .fold<Map<String, double>>({}, (map, d) {
                final k = d.articleNom ?? '';
                map[k] = (map[k] ?? 0) + d.total;
                return map;
              })
              .entries
              .map((e) => _ArtData(nom: e.key, total: e.value))
              .toList()
            ..sort((a, b) => b.total.compareTo(a.total));

      cats.add(
        _CatData(
          nom: catNom,
          total: catTotal,
          transactions: depenses.where((d) => d.categorieNom == catNom).length,
          articles: arts,
        ),
      );
    }

    setState(() {
      _totalDepenses = total;
      _categories = cats;
      _selectedSlice = 0;
      _loading = false;
    });
  }

  // ── Helpers requêtes ────────────────────────────────────────────────────────

  Future<List<Map<String, dynamic>>> _catParJour(DateTime date) async {
    final start =
        '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
    final endDate = date.add(const Duration(days: 1));
    final end =
        '${endDate.year.toString().padLeft(4, '0')}-${endDate.month.toString().padLeft(2, '0')}-${endDate.day.toString().padLeft(2, '0')}';
    return depensesParCategoriePeriode(start, end);
  }

  Future<List<Depense>> _depensesAnnee(int annee) async {
    return getDepensesAnnee(annee);
  }

  Future<List<Map<String, dynamic>>> _catParAnnee(int annee) async {
    return depensesParCategoriePeriode('$annee-01-01', '${annee + 1}-01-01');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _C.surfaceContainerLow,
      appBar: AppBar(
        backgroundColor: _C.surfaceContainerLow,
        elevation: 0,
        titleSpacing: 24,
        title: Row(
          children: [
            CircleAvatar(
              radius: 20,
              backgroundColor: _C.primaryContainer,
              child: const Icon(Icons.person, color: Colors.white, size: 22),
            ),
            const SizedBox(width: 16),
            const Text(
              'Gestion dépense',
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 22,
                fontWeight: FontWeight.w700,
                color: _C.primary,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.notifications_outlined, color: _C.primary),
            onPressed: () {},
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: () async => _load(),
              child: ListView(
                padding: const EdgeInsets.fromLTRB(24, 8, 24, 120),
                children: [
                  // ── Chips filtre ─────────────────────────────────────
                  _PeriodeChips(
                    selected: _periode,
                    onChanged: (p) {
                      setState(() => _periode = p);
                      _load();
                    },
                  ),
                  const SizedBox(height: 16),

                  // ── Overview card ────────────────────────────────────
                  _OverviewCard(
                    total: _totalDepenses,
                    categories: _categories,
                    selected: _selectedSlice,
                    onSliceTap: (i) => setState(() => _selectedSlice = i),
                  ),
                  const SizedBox(height: 24),

                  // ── Répartition par catégorie ────────────────────────
                  const Text(
                    'Répartition par Catégorie',
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 22,
                      fontWeight: FontWeight.w500,
                      color: _C.onSurface,
                    ),
                  ),
                  const SizedBox(height: 12),

                  if (_categories.isEmpty)
                    const Center(
                      child: Padding(
                        padding: EdgeInsets.all(32),
                        child: Text(
                          'Aucune dépense sur cette période.',
                          style: TextStyle(color: _C.onSurfaceVariant),
                        ),
                      ),
                    )
                  else
                    ..._categories.asMap().entries.map(
                      (e) => _CategoryCard(
                        data: e.value,
                        color: _donutColors[e.key % _donutColors.length],
                        total: _totalDepenses,
                      ),
                    ),
                ],
              ),
            ),
    );
  }
}

// ── Chips période ─────────────────────────────────────────────────────────────

class _PeriodeChips extends StatelessWidget {
  final _Periode selected;
  final ValueChanged<_Periode> onChanged;
  const _PeriodeChips({required this.selected, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          _Chip(
            label: 'Jour',
            active: selected == _Periode.jour,
            onTap: () => onChanged(_Periode.jour),
          ),
          const SizedBox(width: 8),
          _Chip(
            label: 'Mois',
            active: selected == _Periode.mois,
            onTap: () => onChanged(_Periode.mois),
          ),
          const SizedBox(width: 8),
          _Chip(
            label: 'Année',
            active: selected == _Periode.annee,
            onTap: () => onChanged(_Periode.annee),
          ),
        ],
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  final String label;
  final bool active;
  final VoidCallback onTap;
  const _Chip({required this.label, required this.active, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        decoration: BoxDecoration(
          // Pill shape comme dans le design
          color: active ? _C.primaryContainer : _C.surfaceContainerHigh,
          borderRadius: BorderRadius.circular(50),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontFamily: 'Inter',
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: active ? Colors.white : _C.onSurfaceVariant,
          ),
        ),
      ),
    );
  }
}

// ── Overview card (donut + légende) ──────────────────────────────────────────

class _OverviewCard extends StatelessWidget {
  final double total;
  final List<_CatData> categories;
  final int selected;
  final ValueChanged<int> onSliceTap;

  const _OverviewCard({
    required this.total,
    required this.categories,
    required this.selected,
    required this.onSliceTap,
  });

  @override
  Widget build(BuildContext context) {
    final fmt = NumberFormat('#,##0.00', 'fr_FR');

    // Calcul des sweeps pour le donut
    final sweeps = <double>[];
    if (total > 0) {
      for (int i = 0; i < categories.length && i < 4; i++) {
        sweeps.add(categories[i].total / total);
      }
      // "Autres" si > 4 catégories
      if (categories.length > 4) {
        final rest = categories.skip(4).fold(0.0, (s, c) => s + c.total);
        sweeps.add(rest / total);
      }
    }

    final selectedCat = (categories.isNotEmpty && selected < categories.length)
        ? categories[selected]
        : null;
    final selectedPct = (total > 0 && selectedCat != null)
        ? (selectedCat.total / total * 100).round()
        : 0;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: _C.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          // Titre + total — sur 2 lignes comme dans le design
          const Text(
            'DÉPENSES TOTALES',
            style: TextStyle(
              fontFamily: 'Inter',
              fontSize: 12,
              fontWeight: FontWeight.w500,
              letterSpacing: 1,
              color: _C.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 4),
          RichText(
            textAlign: TextAlign.center,
            text: TextSpan(
              style: const TextStyle(
                fontFamily: 'Inter',
                fontSize: 52,
                fontWeight: FontWeight.w700,
                color: _C.onBackground,
                height: 1.05,
              ),
              children: [
                TextSpan(text: fmt.format(total)),
                const TextSpan(text: '\nAr'),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Donut chart — pleine largeur
          GestureDetector(
            onTapDown: (details) => _handleDonutTap(details, context),
            child: SizedBox(
              width: double.infinity,
              height: 260,
              child: CustomPaint(
                painter: _DonutPainter(
                  sweeps: sweeps,
                  colors: _donutColors,
                  selected: selected,
                ),
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        selectedCat?.nom ?? '',
                        style: const TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 13,
                          color: _C.onSurfaceVariant,
                        ),
                      ),
                      Text(
                        '$selectedPct%',
                        style: const TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 22,
                          fontWeight: FontWeight.w700,
                          color: _C.primary,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 20),

          // Légende 2 colonnes
          _DonutLegend(categories: categories, colors: _donutColors),
        ],
      ),
    );
  }

  void _handleDonutTap(TapDownDetails details, BuildContext context) {
    // Calcul de l'angle du tap pour sélectionner la tranche
    final box = context.findRenderObject() as RenderBox?;
    if (box == null || categories.isEmpty) return;
    // Simplifié : cycle entre les tranches
    onSliceTap((selected + 1) % math.min(categories.length, 4));
  }
}

// ── Donut painter ─────────────────────────────────────────────────────────────

class _DonutPainter extends CustomPainter {
  final List<double> sweeps;
  final List<Color> colors;
  final int selected;

  const _DonutPainter({
    required this.sweeps,
    required this.colors,
    required this.selected,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;
    final outerR = size.width / 2;
    final innerR = outerR * 0.62;
    final gap = 0.025; // gap en radians entre tranches

    if (sweeps.isEmpty) {
      // Cercle vide
      final paint = Paint()
        ..color = _C.surfaceVariant
        ..style = PaintingStyle.stroke
        ..strokeWidth = outerR - innerR;
      canvas.drawCircle(Offset(cx, cy), (outerR + innerR) / 2, paint);
      return;
    }

    double startAngle = -math.pi / 2;
    for (int i = 0; i < sweeps.length; i++) {
      final sweep = sweeps[i] * 2 * math.pi - gap;
      if (sweep <= 0) {
        startAngle += sweeps[i] * 2 * math.pi;
        continue;
      }

      final isSelected = i == selected;
      final color = i < colors.length ? colors[i] : _C.surfaceVariant;

      // Légère expansion de la tranche sélectionnée
      final expand = isSelected ? 6.0 : 0.0;
      final midAngle = startAngle + sweep / 2;
      final dx = math.cos(midAngle) * expand;
      final dy = math.sin(midAngle) * expand;

      final paint = Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = outerR - innerR + (isSelected ? 4 : 0)
        ..strokeCap = StrokeCap.butt;

      final rect = Rect.fromCircle(
        center: Offset(cx + dx, cy + dy),
        radius: (outerR + innerR) / 2,
      );
      canvas.drawArc(rect, startAngle + gap / 2, sweep, false, paint);
      startAngle += sweeps[i] * 2 * math.pi;
    }

    // Cercle blanc central (trou du donut)
    final holePaint = Paint()
      ..color = _C.surfaceContainerLowest
      ..style = PaintingStyle.fill;
    canvas.drawCircle(Offset(cx, cy), innerR - 2, holePaint);
  }

  @override
  bool shouldRepaint(_DonutPainter old) =>
      old.sweeps != sweeps || old.selected != selected;
}

// ── Légende donut ─────────────────────────────────────────────────────────────

class _DonutLegend extends StatelessWidget {
  final List<_CatData> categories;
  final List<Color> colors;
  const _DonutLegend({required this.categories, required this.colors});

  @override
  Widget build(BuildContext context) {
    final items = categories.take(4).toList();
    // Ajouter "Autres" si besoin
    if (categories.length > 4) {
      items.add(
        _CatData(
          nom: 'Autres',
          total: categories.skip(4).fold(0.0, (s, c) => s + c.total),
          transactions: 0,
          articles: [],
        ),
      );
    }

    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      childAspectRatio: 5,
      mainAxisSpacing: 4,
      crossAxisSpacing: 4,
      children: items.asMap().entries.map((e) {
        final color = e.key < colors.length ? colors[e.key] : _C.surfaceVariant;
        return Row(
          children: [
            Container(
              width: 12,
              height: 12,
              decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            ),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                e.value.nom,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 12,
                  color: _C.onSurfaceVariant,
                ),
              ),
            ),
          ],
        );
      }).toList(),
    );
  }
}

// ── Category card (expandable) ────────────────────────────────────────────────

class _CategoryCard extends StatefulWidget {
  final _CatData data;
  final Color color;
  final double total;
  const _CategoryCard({
    required this.data,
    required this.color,
    required this.total,
  });

  @override
  State<_CategoryCard> createState() => _CategoryCardState();
}

class _CategoryCardState extends State<_CategoryCard>
    with SingleTickerProviderStateMixin {
  bool _expanded = false;
  late final AnimationController _ctrl;
  late final Animation<double> _rotation;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
    );
    _rotation = Tween(
      begin: 0.0,
      end: 0.5,
    ).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _toggle() {
    setState(() => _expanded = !_expanded);
    _expanded ? _ctrl.forward() : _ctrl.reverse();
  }

  @override
  Widget build(BuildContext context) {
    final fmt = NumberFormat('#,##0.00', 'fr_FR');
    final data = widget.data;
    final icon = _catIcons[data.nom] ?? Icons.category;
    final bg = _catBg[data.nom] ?? _C.surfaceVariant;
    final fg = _catFg[data.nom] ?? _C.onSurfaceVariant;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: _C.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(16),
        // Pas de border — ombre légère seulement
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          // ── Header ──────────────────────────────────────────────────
          InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: _toggle,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  // Icône catégorie
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: bg,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(icon, color: fg, size: 20),
                  ),
                  const SizedBox(width: 12),
                  // Nom + nb transactions
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          data.nom,
                          style: const TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: _C.onSurface,
                          ),
                        ),
                        Text(
                          '${data.transactions} Transaction${data.transactions > 1 ? 's' : ''}',
                          style: const TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 12,
                            color: _C.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Montant + chevron
                  Text(
                    '${fmt.format(data.total)} Ar',
                    style: const TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: _C.onSurface,
                    ),
                  ),
                  const SizedBox(width: 4),
                  RotationTransition(
                    turns: _rotation,
                    child: const Icon(
                      Icons.expand_more,
                      color: _C.outline,
                      size: 22,
                    ),
                  ),
                ],
              ),
            ),
          ),

          // ── Détail articles (expandable) ─────────────────────────────
          AnimatedCrossFade(
            duration: const Duration(milliseconds: 200),
            crossFadeState: _expanded
                ? CrossFadeState.showSecond
                : CrossFadeState.showFirst,
            firstChild: const SizedBox.shrink(),
            secondChild: Column(
              children: [
                Divider(
                  height: 1,
                  color: _C.surfaceVariant.withValues(alpha: 0.4),
                ),
                ...data.articles.map(
                  (art) => Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 10,
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          art.nom,
                          style: const TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 14,
                            color: _C.onSurfaceVariant,
                          ),
                        ),
                        Text(
                          '${fmt.format(art.total)} Ar',
                          style: const TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: _C.onSurface,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 4),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Data classes ──────────────────────────────────────────────────────────────

class _CatData {
  final String nom;
  final double total;
  final int transactions;
  final List<_ArtData> articles;
  const _CatData({
    required this.nom,
    required this.total,
    required this.transactions,
    required this.articles,
  });
}

class _ArtData {
  final String nom;
  final double total;
  const _ArtData({required this.nom, required this.total});
}
