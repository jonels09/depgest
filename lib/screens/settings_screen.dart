import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../database/dao.dart';
import '../models/models.dart';
import '../screens/auth_screen.dart';
import '../services/notification_service.dart';
import '../services/sync_service.dart';
import 'sync_health_screen.dart';

// ── Design tokens ─────────────────────────────────────────────────────────────
class _C {
  static const primary = Color(0xFF004394);
  static const primaryContainer = Color(0xFF005AC1);
  static const onPrimary = Color(0xFFFFFFFF);
  static const error = Color(0xFFBA1A1A);
  static const surfaceContainerLow = Color(0xFFF4F3F6);
  static const surfaceContainerLowest = Color(0xFFFFFFFF);
  static const surfaceContainerHighest = Color(0xFFE3E2E5);
  static const surfaceVariant = Color(0xFFE3E2E5);
  static const outline = Color(0xFF727784);
  static const onSurface = Color(0xFF1A1C1E);
  static const onSurfaceVariant = Color(0xFF424753);
  static const surfaceContainerHigh = Color(0xFFE8E8EB);
}

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _darkMode = false;
  bool _biometric = true;
  bool _anomalyAlerts = true;
  bool _deficitAlerts = true;

  @override
  void initState() {
    super.initState();
    _loadNotificationSettings();
  }

  Future<void> _loadNotificationSettings() async {
    final anomalyAlerts = await NotificationService.instance
        .anomalyAlertsEnabled();
    final deficitAlerts = await NotificationService.instance
        .deficitAlertsEnabled();
    if (!mounted) return;
    setState(() {
      _anomalyAlerts = anomalyAlerts;
      _deficitAlerts = deficitAlerts;
    });
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
              child: const Icon(Icons.person, color: _C.onPrimary, size: 22),
            ),
            const SizedBox(width: 12),
            const Text(
              'Finance Manager',
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
      body: ListView(
        padding: const EdgeInsets.fromLTRB(24, 16, 24, 120),
        children: [
          // ── Titre page ───────────────────────────────────────────────
          const Text(
            'Paramètres',
            style: TextStyle(
              fontFamily: 'Inter',
              fontSize: 28,
              fontWeight: FontWeight.w600,
              color: _C.onSurface,
            ),
          ),
          const SizedBox(height: 24),

          // ── Section Compte utilisateur ───────────────────────────────
          _SectionLabel('Compte'),
          _Card(
            children: [
              _SettingsTile(
                icon: Icons.email_outlined,
                label: Supabase.instance.client.auth.currentUser?.email ?? 'Non connecté',
                trailing: const SizedBox.shrink(),
              ),
            ],
          ),
          const SizedBox(height: 24),

          // ── Section Base de données ──────────────────────────────────
          _SectionLabel('Base de données'),
          _Card(
            children: [
              _SettingsTile(
                icon: Icons.category_outlined,
                label: 'Articles',
                trailing: const Icon(Icons.chevron_right, color: _C.outline),
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const _ArticlesPage()),
                ),
              ),
              _Divider(),
              _SettingsTile(
                icon: Icons.straighten_outlined,
                label: 'Unités de mesure',
                trailing: const Icon(Icons.chevron_right, color: _C.outline),
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const _UnitesPage()),
                ),
              ),
              _Divider(),
              _SettingsTile(
                icon: Icons.cloud_sync_outlined,
                label: 'Synchronisation',
                trailing: const Icon(Icons.chevron_right, color: _C.outline),
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const SyncHealthScreen()),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),

          // ── Section Préférences ──────────────────────────────────────
          _SectionLabel('Préférences'),
          _Card(
            children: [
              _SettingsTile(
                icon: Icons.payments_outlined,
                label: 'Devise',
                trailing: _TrailingText('Ariary Ar'),
                onTap: () {},
              ),
              _Divider(),
              _SettingsTile(
                icon: Icons.language_outlined,
                label: 'Langue',
                trailing: _TrailingText('Français'),
                onTap: () {},
              ),
              _Divider(),
              _SettingsTile(
                icon: Icons.dark_mode_outlined,
                label: 'Mode Sombre',
                trailing: _Toggle(
                  value: _darkMode,
                  onChanged: (v) => setState(() => _darkMode = v),
                ),
              ),
              _Divider(),
              _SettingsTile(
                icon: Icons.warning_amber_outlined,
                label: 'Alertes anomalies IA',
                trailing: _Toggle(
                  value: _anomalyAlerts,
                  onChanged: (v) async {
                    await NotificationService.instance.setAnomalyAlertsEnabled(
                      v,
                    );
                    if (mounted) setState(() => _anomalyAlerts = v);
                  },
                ),
              ),
              _Divider(),
              _SettingsTile(
                icon: Icons.trending_down_outlined,
                label: 'Alertes risque deficit',
                trailing: _Toggle(
                  value: _deficitAlerts,
                  onChanged: (v) async {
                    await NotificationService.instance.setDeficitAlertsEnabled(
                      v,
                    );
                    if (mounted) setState(() => _deficitAlerts = v);
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),

          // ── Section Sécurité ─────────────────────────────────────────
          _SectionLabel('Sécurité'),
          _Card(
            children: [
              _SettingsTile(
                icon: Icons.lock_outline,
                label: 'Changer le mot de passe',
                trailing: const Icon(Icons.chevron_right, color: _C.outline),
                onTap: () {},
              ),
              _Divider(),
              _SettingsTile(
                icon: Icons.fingerprint,
                label: 'Authentification biométrique',
                trailing: _Toggle(
                  value: _biometric,
                  onChanged: (v) => setState(() => _biometric = v),
                  activeColor: _C.primary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),

          // ── Section À propos ─────────────────────────────────────────
          _SectionLabel('À propos'),
          _Card(
            children: [
              _SettingsTile(
                icon: Icons.help_outline,
                label: 'Aide',
                trailing: const Icon(
                  Icons.open_in_new,
                  color: _C.outline,
                  size: 20,
                ),
                onTap: () {},
              ),
              _Divider(),
              _SettingsTile(
                icon: Icons.description_outlined,
                label: "Conditions d'utilisation",
                trailing: const Icon(Icons.chevron_right, color: _C.outline),
                onTap: () {},
              ),
            ],
          ),
          const SizedBox(height: 24),

          // ── Bouton Déconnexion ───────────────────────────────────────
          OutlinedButton.icon(
            onPressed: () async {
              final ok = await showDialog<bool>(
                context: context,
                builder: (_) => AlertDialog(
                  title: const Text('Déconnexion'),
                  content: const Text(
                    'Vous serez redirigé vers l\'écran de connexion. Vos données restent sauvegardées sur le cloud.',
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context, false),
                      child: const Text('Annuler'),
                    ),
                    FilledButton(
                      style: FilledButton.styleFrom(backgroundColor: _C.error),
                      onPressed: () => Navigator.pop(context, true),
                      child: const Text('Se déconnecter'),
                    ),
                  ],
                ),
              );
              if (ok == true && context.mounted) {
                SyncService.instance.dispose();
                await Supabase.instance.client.auth.signOut();
                if (context.mounted) {
                  Navigator.of(context).pushAndRemoveUntil(
                    MaterialPageRoute(builder: (_) => const AuthScreen()),
                    (_) => false,
                  );
                }
              }
            },
            icon: const Icon(Icons.logout, color: _C.error),
            label: const Text(
              'Déconnexion',
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: _C.error,
              ),
            ),
            style: OutlinedButton.styleFrom(
              minimumSize: const Size.fromHeight(56),
              side: const BorderSide(color: _C.error, width: 2),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              backgroundColor: Colors.transparent,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Widgets réutilisables ─────────────────────────────────────────────────────

class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        text.toUpperCase(),
        style: const TextStyle(
          fontFamily: 'Inter',
          fontSize: 14,
          fontWeight: FontWeight.w500,
          letterSpacing: 1.2,
          color: _C.primary,
        ),
      ),
    );
  }
}

class _Card extends StatelessWidget {
  final List<Widget> children;
  const _Card({required this.children});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: _C.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(children: children),
    );
  }
}

class _SettingsTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final Widget trailing;
  final VoidCallback? onTap;

  const _SettingsTile({
    required this.icon,
    required this.label,
    required this.trailing,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: Row(
            children: [
              Icon(icon, color: _C.onSurfaceVariant, size: 22),
              const SizedBox(width: 16),
              Expanded(
                child: Text(
                  label,
                  style: const TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 16,
                    fontWeight: FontWeight.w400,
                    color: _C.onSurface,
                  ),
                ),
              ),
              trailing,
            ],
          ),
        ),
      ),
    );
  }
}

class _Divider extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Divider(
      height: 1,
      indent: 56,
      endIndent: 0,
      color: _C.surfaceVariant.withValues(alpha: 0.5),
    );
  }
}

class _TrailingText extends StatelessWidget {
  final String text;
  const _TrailingText(this.text);

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          text,
          style: const TextStyle(
            fontFamily: 'Inter',
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: _C.onSurfaceVariant,
          ),
        ),
        const SizedBox(width: 4),
        const Icon(Icons.chevron_right, color: _C.outline, size: 20),
      ],
    );
  }
}

/// Toggle switch custom fidèle au design HTML
class _Toggle extends StatelessWidget {
  final bool value;
  final ValueChanged<bool> onChanged;
  final Color activeColor;

  const _Toggle({
    required this.value,
    required this.onChanged,
    this.activeColor = _C.primary,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => onChanged(!value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: 48,
        height: 24,
        decoration: BoxDecoration(
          color: value ? activeColor : _C.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(12),
        ),
        child: AnimatedAlign(
          duration: const Duration(milliseconds: 200),
          alignment: value ? Alignment.centerRight : Alignment.centerLeft,
          child: Container(
            margin: const EdgeInsets.all(3),
            width: 18,
            height: 18,
            decoration: BoxDecoration(
              color: value ? _C.onPrimary : _C.outline,
              shape: BoxShape.circle,
            ),
          ),
        ),
      ),
    );
  }
}

// ── Page Articles ─────────────────────────────────────────────────────────────

// ── Page Unités de mesure ─────────────────────────────────────────────────────

class _UnitesPage extends StatefulWidget {
  const _UnitesPage();
  @override
  State<_UnitesPage> createState() => _UnitesPageState();
}

class _UnitesPageState extends State<_UnitesPage> {
  List<Unite> _unites = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final units = await getUnites();
    setState(() {
      _unites = units;
      _loading = false;
    });
  }

  Future<void> _addUnite() async {
    final ctrl = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Nouvelle unité'),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          decoration: const InputDecoration(hintText: 'Ex: kg, litre, pièce…'),
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
    if (confirmed == true && ctrl.text.trim().isNotEmpty) {
      await insertUnite(Unite(nom: ctrl.text.trim()));
      _load();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _C.surfaceContainerLow,
      appBar: AppBar(
        backgroundColor: _C.surfaceContainerLow,
        elevation: 0,
        title: const Text(
          'Unités de mesure',
          style: TextStyle(
            fontFamily: 'Inter',
            fontWeight: FontWeight.w700,
            color: _C.primary,
          ),
        ),
        iconTheme: const IconThemeData(color: _C.primary),
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: _C.primary,
        foregroundColor: _C.onPrimary,
        onPressed: _addUnite,
        child: const Icon(Icons.add),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _unites.isEmpty
          ? const Center(child: Text('Aucune unité.'))
          : ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: _unites.length,
              separatorBuilder: (context, index) => const SizedBox(height: 8),
              itemBuilder: (context, i) {
                final u = _unites[i];
                return Container(
                  decoration: BoxDecoration(
                    color: _C.surfaceContainerLowest,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.04),
                        blurRadius: 4,
                      ),
                    ],
                  ),
                  child: ListTile(
                    leading: const Icon(
                      Icons.straighten,
                      color: _C.onSurfaceVariant,
                    ),
                    title: Text(
                      u.nom,
                      style: const TextStyle(
                        fontFamily: 'Inter',
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                );
              },
            ),
    );
  }
}

// ── Page Articles ─────────────────────────────────────────────────────────────

class _ArticlesPage extends StatefulWidget {
  const _ArticlesPage();
  @override
  State<_ArticlesPage> createState() => _ArticlesPageState();
}

class _ArticlesPageState extends State<_ArticlesPage> {
  List<Categorie> _categories = [];
  Categorie? _selectedCat;
  List<Article> _articles = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadCategories();
  }

  Future<void> _loadCategories() async {
    final cats = await getCategories();
    setState(() {
      _categories = cats;
      _selectedCat = cats.isNotEmpty ? cats.first : null;
      _loading = false;
    });
    if (_selectedCat != null) _loadArticles(_selectedCat!);
  }

  Future<void> _loadArticles(Categorie cat) async {
    setState(() => _loading = true);
    final arts = await getArticlesByCategorie(cat.id!);
    setState(() {
      _articles = arts;
      _loading = false;
    });
  }

  // ── Supprimer une catégorie ────────────────────────────────────────────────
  Future<void> _deleteCategorie(Categorie cat) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Supprimer la catégorie ?'),
        content: Text(
          'Supprimer "${cat.nom}" supprimera aussi tous ses articles.\nCette action est irréversible.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Annuler'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: _C.error),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Supprimer'),
          ),
        ],
      ),
    );
    if (ok == true) {
      await deleteCategorie(cat.id!);
      await _loadCategories();
    }
  }

  // ── Ajouter une catégorie ───────────────────────────────────────────────────
  Future<void> _addCategorie() async {
    final ctrl = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Nouvelle catégorie'),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          textCapitalization: TextCapitalization.sentences,
          decoration: const InputDecoration(
            hintText: 'Ex: Alimentation, Transport…',
          ),
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
    if (ok == true && ctrl.text.trim().isNotEmpty) {
      final newCat = await insertCategorie(Categorie(nom: ctrl.text.trim()));
      await _loadCategories();
      // Sélectionner la nouvelle catégorie
      final cats = await getCategories();
      final created = cats.where((c) => c.id == newCat).firstOrNull;
      if (created != null && mounted) {
        setState(() => _selectedCat = created);
        _loadArticles(created);
      }
    }
  }

  // ── Ajouter un article ─────────────────────────────────────────────────────
  Future<void> _addArticle() async {
    if (_selectedCat == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Sélectionnez d\'abord une catégorie.')),
      );
      return;
    }
    final ctrl = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text('Nouvel article — ${_selectedCat!.nom}'),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          textCapitalization: TextCapitalization.sentences,
          decoration: const InputDecoration(hintText: 'Nom de l\'article'),
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
    if (ok == true && ctrl.text.trim().isNotEmpty) {
      await insertArticle(
        Article(categorieId: _selectedCat!.id!, nom: ctrl.text.trim()),
      );
      _loadArticles(_selectedCat!);
    }
  }

  Future<void> _deleteArticle(Article a) async {
    await deleteArticle(a.id!);
    _loadArticles(_selectedCat!);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _C.surfaceContainerLow,
      appBar: AppBar(
        backgroundColor: _C.surfaceContainerLow,
        elevation: 0,
        title: const Text(
          'Articles',
          style: TextStyle(
            fontFamily: 'Inter',
            fontWeight: FontWeight.w700,
            color: _C.primary,
          ),
        ),
        iconTheme: const IconThemeData(color: _C.primary),
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: _C.primary,
        foregroundColor: _C.onPrimary,
        onPressed: _addArticle,
        tooltip: 'Ajouter un article',
        child: const Icon(Icons.add),
      ),
      body: Column(
        children: [
          // ── Chips catégories + bouton "+ Catégorie" ──────────────────
          SizedBox(
            height: 56,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              itemCount: _categories.length + 1,
              separatorBuilder: (context, index) => const SizedBox(width: 8),
              itemBuilder: (context, i) {
                // Dernier item = bouton "+ Catégorie"
                if (i == _categories.length) {
                  return GestureDetector(
                    onTap: _addCategorie,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        border: Border.all(
                          color: _C.primaryContainer,
                          width: 1.5,
                        ),
                        borderRadius: BorderRadius.circular(50),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.add, size: 16, color: _C.primaryContainer),
                          SizedBox(width: 4),
                          Text(
                            'Catégorie',
                            style: TextStyle(
                              fontFamily: 'Inter',
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                              color: _C.primaryContainer,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }
                // Chip catégorie normale
                final cat = _categories[i];
                final active = cat.id == _selectedCat?.id;
                return GestureDetector(
                  onTap: () {
                    setState(() => _selectedCat = cat);
                    _loadArticles(cat);
                  },
                  onLongPress: () => _deleteCategorie(cat),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: active
                          ? _C.primaryContainer
                          : _C.surfaceContainerHigh,
                      borderRadius: BorderRadius.circular(50),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          cat.nom,
                          style: TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                            color: active ? _C.onPrimary : _C.onSurfaceVariant,
                          ),
                        ),
                        // Petite icône poubelle visible sur le chip actif
                        if (active) ...[
                          const SizedBox(width: 6),
                          const Icon(
                            Icons.close,
                            size: 14,
                            color: _C.onPrimary,
                          ),
                        ],
                      ],
                    ),
                  ),
                );
              },
            ),
          ),

          // ── Liste articles ───────────────────────────────────────────
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _categories.isEmpty
                ? Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.category_outlined,
                          size: 48,
                          color: _C.onSurfaceVariant,
                        ),
                        const SizedBox(height: 12),
                        const Text(
                          'Aucune catégorie.',
                          style: TextStyle(color: _C.onSurfaceVariant),
                        ),
                        const SizedBox(height: 8),
                        TextButton.icon(
                          onPressed: _addCategorie,
                          icon: const Icon(Icons.add),
                          label: const Text('Ajouter une catégorie'),
                        ),
                      ],
                    ),
                  )
                : _articles.isEmpty
                ? Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.label_off_outlined,
                          size: 48,
                          color: _C.onSurfaceVariant,
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'Aucun article dans "${_selectedCat?.nom}".',
                          style: const TextStyle(color: _C.onSurfaceVariant),
                        ),
                        const SizedBox(height: 8),
                        TextButton.icon(
                          onPressed: _addArticle,
                          icon: const Icon(Icons.add),
                          label: const Text('Ajouter un article'),
                        ),
                      ],
                    ),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.all(16),
                    itemCount: _articles.length,
                    separatorBuilder: (context, index) =>
                        const SizedBox(height: 8),
                    itemBuilder: (context, i) {
                      final art = _articles[i];
                      return Container(
                        decoration: BoxDecoration(
                          color: _C.surfaceContainerLowest,
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.04),
                              blurRadius: 4,
                            ),
                          ],
                        ),
                        child: ListTile(
                          leading: const Icon(
                            Icons.label_outline,
                            color: _C.onSurfaceVariant,
                          ),
                          title: Text(
                            art.nom,
                            style: const TextStyle(
                              fontFamily: 'Inter',
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          trailing: IconButton(
                            icon: const Icon(
                              Icons.delete_outline,
                              color: _C.error,
                              size: 20,
                            ),
                            onPressed: () => _deleteArticle(art),
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
