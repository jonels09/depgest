import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../database/dao.dart';
import '../models/models.dart';
import 'nouvelle_operation_sheet.dart';
import 'planning_screen.dart';
import 'rapport_mensuel_screen.dart';
import 'settings_screen.dart';
import 'stats_screen.dart';
import 'predictive_dashboard_screen.dart';
import '../services/sync_service.dart';

// ── Design tokens ────────────────────────────────────────────────────────────
class _C {
  static const primary = Color(0xFF004394);
  static const primaryContainer = Color(0xFF005AC1);
  static const primaryFixed = Color(0xFFD8E2FF);
  static const onPrimary = Color(0xFFFFFFFF);

  static const secondary = Color(0xFF006D39);
  static const secondaryContainer = Color(0xFF99F3B1);
  static const secondaryFixed = Color(0xFF9BF6B4);
  static const onSecondaryContainer = Color(0xFF0B723D);

  static const error = Color(0xFFBA1A1A);
  static const errorContainer = Color(0xFFFFDAD6);
  static const onErrorContainer = Color(0xFF93000A);

  static const tertiary = Color(0xFF920009);
  static const tertiaryFixed = Color(0xFFFFDAD5);

  static const surface = Color(0xFFFAF9FC);
  static const surfaceContainerLow = Color(0xFFF4F3F6);
  static const surfaceContainerLowest = Color(0xFFFFFFFF);
  static const surfaceVariant = Color(0xFFE3E2E5);
  static const outlineVariant = Color(0xFFC2C6D5);
  static const onSurface = Color(0xFF1A1C1E);
  static const onSurfaceVariant = Color(0xFF424753);
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _navIndex = 0;
  double _revenusTotaux = 0;
  double _depensesTotales = 0;
  double _revenusMois = 0;
  double _depensesMois = 0;
  List<dynamic> _recentActivities = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    SyncService.instance.status.addListener(_onSyncStatusChanged);
    _load();
  }

  @override
  void dispose() {
    SyncService.instance.status.removeListener(_onSyncStatusChanged);
    super.dispose();
  }

  void _onSyncStatusChanged() {
    if (SyncService.instance.status.value == SyncStatus.done && mounted) {
      _load();
    }
  }

  Future<void> _load() async {
    final now = DateTime.now();
    setState(() => _loading = true);
    try {
      final results = await Future.wait([
        sommeRevenusMois(now.year, now.month),
        sommeDepensesMois(now.year, now.month),
        sommeRevenusTotaux(),
        sommeDepensesTotales(),
        getToutesActivitesRecentes(10),
      ]);
      setState(() {
        _revenusMois = results[0] as double;
        _depensesMois = results[1] as double;
        _revenusTotaux = results[2] as double;
        _depensesTotales = results[3] as double;
        _recentActivities = results[4] as List<dynamic>;
        _loading = false;
      });
    } catch (e, st) {
      debugPrint('[HomeScreen] Error loading data: $e\n$st');
      setState(() => _loading = false);
    }
  }

  String get _userId =>
      Supabase.instance.client.auth.currentUser?.id ?? 'anonymous';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _C.surface,
      body: IndexedStack(
        index: _navIndex,
        children: [
          _DashboardTab(
            soldeGlobal: _revenusTotaux - _depensesTotales,
            revenusMois: _revenusMois,
            depensesMois: _depensesMois,
            recentActivities: _recentActivities,
            loading: _loading,
            onRefresh: _load,
            userId: _userId,
            onOpenAnalytics: () => setState(() => _navIndex = 2),
          ),
          const StatsScreen(),
          PredictiveDashboardScreen(userId: _userId),
          const PlanningScreen(),
          const SettingsScreen(),
        ],
      ),
      floatingActionButton: _navIndex == 0 ? _AddFab(onRefresh: _load) : null,
      bottomNavigationBar: _BottomNav(
        current: _navIndex,
        onTap: (i) => setState(() => _navIndex = i),
      ),
    );
  }
}

// ── Dashboard ────────────────────────────────────────────────────────────────

class _DashboardTab extends StatelessWidget {
  final double soldeGlobal;
  final double revenusMois;
  final double depensesMois;
  final List<dynamic> recentActivities;
  final bool loading;
  final VoidCallback onRefresh;
  final String userId;
  final VoidCallback onOpenAnalytics;

  const _DashboardTab({
    required this.soldeGlobal,
    required this.revenusMois,
    required this.depensesMois,
    required this.recentActivities,
    required this.loading,
    required this.onRefresh,
    required this.userId,
    required this.onOpenAnalytics,
  });

  @override
  Widget build(BuildContext context) {
    final fmt = NumberFormat('#,##0.00', 'fr_FR');
    final solde = soldeGlobal;

    return Scaffold(
      backgroundColor: _C.surfaceContainerLow,
      appBar: AppBar(
        backgroundColor: _C.surfaceContainerLow,
        elevation: 0,
        titleSpacing: 24,
        title: Row(
          children: [
            // Avatar photo
            CircleAvatar(
              radius: 20,
              backgroundColor: _C.primaryContainer,
              child: const Icon(Icons.person, color: _C.onPrimary, size: 22),
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
          // Indicateur de synchronisation
          ValueListenableBuilder<SyncStatus>(
            valueListenable: SyncService.instance.status,
            builder: (context, status, child) {
              if (status == SyncStatus.syncing) {
                return const Padding(
                  padding: EdgeInsets.all(14),
                  child: SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: _C.onSurfaceVariant,
                    ),
                  ),
                );
              }
              if (status == SyncStatus.error) {
                return IconButton(
                  icon: const Icon(Icons.sync_problem, color: _C.error),
                  tooltip: 'Erreur de synchronisation — appuyer pour réessayer',
                  onPressed: () => SyncService.instance.syncAll(),
                );
              }
              if (status == SyncStatus.conflict) {
                return IconButton(
                  icon: const Icon(
                    Icons.report_problem_outlined,
                    color: Colors.orange,
                  ),
                  tooltip: 'Conflit de synchronisation',
                  onPressed: () => SyncService.instance.syncAll(),
                );
              }
              return IconButton(
                icon: const Icon(
                  Icons.notifications_outlined,
                  color: _C.onSurfaceVariant,
                ),
                onPressed: () {},
              );
            },
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: () async => onRefresh(),
              child: ListView(
                padding: const EdgeInsets.fromLTRB(24, 16, 24, 120),
                children: [
                  _SoldeCard(
                    solde: solde,
                    revenus: revenusMois,
                    depenses: depensesMois,
                    fmt: fmt,
                  ),
                  const SizedBox(height: 16),
                  _PredictionSnippet(
                    userId: userId,
                    onOpenAnalytics: onOpenAnalytics,
                  ),
                  const SizedBox(height: 28),

                  // Header section
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Activités récentes',
                        style: TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 22,
                          fontWeight: FontWeight.w500,
                          color: _C.onSurface,
                        ),
                      ),
                      TextButton(
                        onPressed: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const RapportMensuelScreen(),
                          ),
                        ),
                        style: TextButton.styleFrom(padding: EdgeInsets.zero),
                        child: const Text(
                          'Voir tout',
                          style: TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            color: _C.primary,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  if (recentActivities.isEmpty)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 32),
                      child: Center(
                        child: Text(
                          'Aucune activité ce mois.',
                          style: TextStyle(color: _C.onSurfaceVariant),
                        ),
                      ),
                    )
                  else
                    ...recentActivities.map(
                      (item) => _TransactionCard(item: item, fmt: fmt),
                    ),
                ],
              ),
            ),
    );
  }
}

// ── Solde card ───────────────────────────────────────────────────────────────

class _PredictionSnippet extends StatelessWidget {
  final String userId;
  final VoidCallback onOpenAnalytics;

  const _PredictionSnippet({
    required this.userId,
    required this.onOpenAnalytics,
  });

  @override
  Widget build(BuildContext context) {
    return FutureBuilder(
      future: getPredictions(userId: userId),
      builder: (context, snapshot) {
        if (!snapshot.hasData || !snapshot.data!.hasData) {
          return const SizedBox.shrink();
        }

        final data = snapshot.data!;
        final insights = data.topInsights();
        if (insights.isEmpty) return const SizedBox.shrink();

        final score = data.scores?.overallScore;
        final risk = data.xgboost?.deficitRiskPercent;

        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: _C.surfaceContainerLowest,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: _C.outlineVariant.withValues(alpha: 0.2)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 6,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: _C.primaryFixed,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
                      Icons.auto_graph,
                      color: _C.primary,
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text(
                      'Analyse IA',
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: _C.onSurface,
                      ),
                    ),
                  ),
                  TextButton(
                    onPressed: onOpenAnalytics,
                    child: const Text('Details'),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              if (score != null || risk != null)
                Row(
                  children: [
                    if (score != null)
                      Expanded(
                        child: _PredictionMetric(
                          label: 'Score',
                          value: '${score.toStringAsFixed(0)}/100',
                          color: _metricColor(score),
                        ),
                      ),
                    if (score != null && risk != null) const SizedBox(width: 8),
                    if (risk != null)
                      Expanded(
                        child: _PredictionMetric(
                          label: 'Risque',
                          value: '${risk.toStringAsFixed(0)}%',
                          color: _riskMetricColor(risk),
                        ),
                      ),
                  ],
                ),
              if (score != null || risk != null) const SizedBox(height: 12),
              ...insights.map(
                (item) => Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(
                        Icons.check_circle_outline,
                        size: 16,
                        color: _C.secondary,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          item,
                          style: const TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 13,
                            color: _C.onSurfaceVariant,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Color _metricColor(double value) {
    if (value >= 75) return _C.secondary;
    if (value >= 50) return Colors.orange;
    return _C.error;
  }

  Color _riskMetricColor(double value) {
    if (value < 35) return _C.secondary;
    if (value < 65) return Colors.orange;
    return _C.error;
  }
}

class _PredictionMetric extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _PredictionMetric({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontFamily: 'Inter',
              fontSize: 11,
              fontWeight: FontWeight.w500,
              color: _C.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            value,
            style: TextStyle(
              fontFamily: 'Inter',
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

class _SoldeCard extends StatelessWidget {
  final double solde;
  final double revenus;
  final double depenses;
  final NumberFormat fmt;

  const _SoldeCard({
    required this.solde,
    required this.revenus,
    required this.depenses,
    required this.fmt,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: _C.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
        border: Border.all(color: _C.outlineVariant.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Label
          const Text(
            'Solde restant',
            style: TextStyle(
              fontFamily: 'Inter',
              fontSize: 12,
              fontWeight: FontWeight.w500,
              letterSpacing: 0.5,
              color: _C.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 4),

          // ── Montant sur 2 lignes comme dans le design ──
          RichText(
            text: TextSpan(
              style: const TextStyle(
                fontFamily: 'Inter',
                fontSize: 57,
                fontWeight: FontWeight.w700,
                letterSpacing: -0.25,
                color: _C.primary,
                height: 1.1,
              ),
              children: [
                TextSpan(text: fmt.format(solde)),
                const TextSpan(text: '\nAr'),
              ],
            ),
          ),

          const SizedBox(height: 20),

          // Mini stats revenus / dépenses
          Row(
            children: [
              Expanded(
                child: _MiniStat(
                  label: 'Revenus total',
                  value: '+ ${fmt.format(revenus)} Ar',
                  bgColor: _C.secondaryContainer.withValues(alpha: 0.35),
                  textColor: _C.onSecondaryContainer,
                  valueColor: _C.secondary,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _MiniStat(
                  label: 'Dépenses',
                  value: '- ${fmt.format(depenses)} Ar',
                  bgColor: _C.errorContainer.withValues(alpha: 0.35),
                  textColor: _C.onErrorContainer,
                  valueColor: _C.error,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _MiniStat extends StatelessWidget {
  final String label;
  final String value;
  final Color bgColor;
  final Color textColor;
  final Color valueColor;

  const _MiniStat({
    required this.label,
    required this.value,
    required this.bgColor,
    required this.textColor,
    required this.valueColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              fontFamily: 'Inter',
              fontSize: 12,
              fontWeight: FontWeight.w500,
              letterSpacing: 0.5,
              color: textColor,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              fontFamily: 'Inter',
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: valueColor,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Transaction card ─────────────────────────────────────────────────────────

class _TransactionCard extends StatelessWidget {
  final dynamic item; // Depense ou Revenu
  final NumberFormat fmt;

  const _TransactionCard({required this.item, required this.fmt});

  static const _catIcons = <String, IconData>{
    'Alimentation': Icons.restaurant,
    'Transport': Icons.directions_car,
    'Santé': Icons.local_hospital,
    'Logement': Icons.house,
    'Loisirs': Icons.sports_esports,
  };

  static const _catBg = <String, Color>{
    'Alimentation': _C.primaryFixed,
    'Transport': _C.tertiaryFixed,
    'Santé': _C.errorContainer,
    'Logement': _C.primaryFixed,
    'Loisirs': _C.secondaryFixed,
  };

  static const _catFg = <String, Color>{
    'Alimentation': _C.primary,
    'Transport': _C.tertiary,
    'Santé': _C.error,
    'Logement': _C.primary,
    'Loisirs': _C.secondary,
  };

  @override
  Widget build(BuildContext context) {
    final bool isDepense = item is Depense;
    
    final String label = isDepense ? (item as Depense).articleNom ?? '' : (item as Revenu).source;
    final String cat = isDepense ? ((item as Depense).categorieNom ?? '') : 'Revenu';
    final double amount = isDepense ? (item as Depense).total : (item as Revenu).montant;
    final String dateRaw = isDepense ? (item as Depense).dateDepense : (item as Revenu).dateRevenu;

    final icon = isDepense ? (_catIcons[cat] ?? Icons.receipt_long) : Icons.savings;
    final bgColor = isDepense ? (_catBg[cat] ?? _C.surfaceVariant) : _C.secondaryFixed;
    final fgColor = isDepense ? (_catFg[cat] ?? _C.onSurfaceVariant) : _C.onSecondaryContainer;

    final dateFmt = DateFormat('dd MMM', 'fr_FR');
    final dateStr = dateFmt.format(
      DateTime.tryParse(dateRaw) ?? DateTime.now(),
    );

    final amountText = isDepense ? '- ${fmt.format(amount)} Ar' : '+ ${fmt.format(amount)} Ar';
    final amountColor = isDepense ? _C.onSurface : _C.secondary;

    return Container(
      // ── Espacement généreux entre les cartes ──
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: _C.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
        border: Border.all(color: _C.outlineVariant.withValues(alpha: 0.15)),
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () {},
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(
              children: [
                // Icône catégorie
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: bgColor,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(icon, color: fgColor, size: 22),
                ),
                const SizedBox(width: 14),

                // Nom + date — flexible pour ne pas écraser le montant
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        label,
                        style: const TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: _C.onSurface,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 3),
                      Text(
                        '$cat · $dateStr',
                        style: const TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          letterSpacing: 0.5,
                          color: _C.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(width: 8),

                // Montant — peut wrapper sur 2 lignes comme dans le design
                Text(
                  amountText,
                  textAlign: TextAlign.right,
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: _C.error,
                    height: 1.3,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ── FAB ──────────────────────────────────────────────────────────────────────

class _AddFab extends StatelessWidget {
  final VoidCallback onRefresh;
  const _AddFab({required this.onRefresh});

  @override
  Widget build(BuildContext context) {
    return FloatingActionButton(
      backgroundColor: _C.primary,
      foregroundColor: _C.onPrimary,
      elevation: 4,
      onPressed: () async {
        final result = await showNouvelleOperationSheet(context);
        if (result == true) onRefresh();
      },
      child: const Icon(Icons.add, size: 30),
    );
  }
}
// ── Bottom Navigation ────────────────────────────────────────────────────────

class _BottomNav extends StatelessWidget {
  final int current;
  final ValueChanged<int> onTap;
  const _BottomNav({required this.current, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: _C.surface,
        border: Border(
          top: BorderSide(color: _C.outlineVariant.withValues(alpha: 0.15)),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 8,
            offset: const Offset(0, -2),
          ),
        ],
        // Coins arrondis en haut comme dans le design
        borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _NavItem(
                icon: Icons.dashboard,
                label: 'Accueil',
                active: current == 0,
                onTap: () => onTap(0),
              ),
              _NavItem(
                icon: Icons.pie_chart_outline,
                label: 'Stats',
                active: current == 1,
                onTap: () => onTap(1),
              ),
              _NavItem(
                icon: Icons.smart_toy_outlined,
                label: 'IA',
                active: current == 2,
                onTap: () => onTap(2),
              ),
              _NavItem(
                icon: Icons.flag_outlined,
                label: 'Plan',
                active: current == 3,
                onTap: () => onTap(3),
              ),
              _NavItem(
                icon: Icons.settings_outlined,
                label: 'Paramètres',
                active: current == 4,
                onTap: () => onTap(4),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool active;
  final VoidCallback onTap;
  const _NavItem({
    required this.icon,
    required this.label,
    required this.active,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        // ── Pill shape pour l'onglet actif ──
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: active ? _C.secondaryContainer : Colors.transparent,
          borderRadius: BorderRadius.circular(50), // pill
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              color: active ? _C.onSecondaryContainer : _C.onSurfaceVariant,
              size: 24,
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 11,
                fontWeight: FontWeight.w500,
                letterSpacing: 0.5,
                color: active ? _C.onSecondaryContainer : _C.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
