import 'package:flutter/material.dart';

import '../database/dao.dart';
import '../models/models.dart';
import '../services/sync_service.dart';

class SyncHealthScreen extends StatefulWidget {
  const SyncHealthScreen({super.key});

  @override
  State<SyncHealthScreen> createState() => _SyncHealthScreenState();
}

class _SyncHealthScreenState extends State<SyncHealthScreen> {
  bool _loading = true;
  SyncHealth? _health;
  List<SyncErrorEntry> _errors = [];
  List<SyncConflictEntry> _conflicts = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final results = await Future.wait([
      getSyncHealth(),
      getOpenSyncErrors(),
      getOpenSyncConflicts(),
    ]);
    setState(() {
      _health = results[0] as SyncHealth;
      _errors = results[1] as List<SyncErrorEntry>;
      _conflicts = results[2] as List<SyncConflictEntry>;
      _loading = false;
    });
  }

  Future<void> _syncNow() async {
    await SyncService.instance.syncAll();
    await _load();
  }

  Future<void> _rollback() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Restaurer le dernier snapshot ?'),
        content: const Text(
          'Les donnees locales seront restaurees comme avant la derniere synchronisation. Les donnees cloud ne seront pas modifiees immediatement.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Annuler'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Restaurer'),
          ),
        ],
      ),
    );
    if (ok == true) {
      await SyncService.instance.rollbackLatestSnapshot();
      await _load();
    }
  }

  @override
  Widget build(BuildContext context) {
    final health = _health;
    return Scaffold(
      appBar: AppBar(title: const Text('Synchronisation')),
      body: _loading || health == null
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  ValueListenableBuilder<SyncStatus>(
                    valueListenable: SyncService.instance.status,
                    builder: (context, status, child) =>
                        _StatusCard(status: status, health: health),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: FilledButton.icon(
                          onPressed: _syncNow,
                          icon: const Icon(Icons.sync),
                          label: const Text('Synchroniser'),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: health.lastSnapshotAt == null
                              ? null
                              : _rollback,
                          icon: const Icon(Icons.restore),
                          label: const Text('Rollback'),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    'Conflits',
                    style: TextStyle(fontWeight: FontWeight.w700, fontSize: 18),
                  ),
                  const SizedBox(height: 8),
                  if (_conflicts.isEmpty)
                    const _InfoBox(text: 'Aucun conflit ouvert.')
                  else
                    ..._conflicts.map(
                      (c) => Card(
                        child: ListTile(
                          leading: const Icon(Icons.compare_arrows),
                          title: Text('${c.tableName} #${c.localId ?? '-'}'),
                          subtitle: Text('${c.reason}\n${c.createdAt}'),
                          isThreeLine: true,
                          trailing: IconButton(
                            icon: const Icon(Icons.check),
                            onPressed: () async {
                              await markSyncConflictResolved(c.id);
                              await _load();
                            },
                          ),
                        ),
                      ),
                    ),
                  const SizedBox(height: 20),
                  const Text(
                    'Erreurs recentes',
                    style: TextStyle(fontWeight: FontWeight.w700, fontSize: 18),
                  ),
                  const SizedBox(height: 8),
                  if (_errors.isEmpty)
                    const _InfoBox(text: 'Aucune erreur ouverte.')
                  else
                    ..._errors.map(
                      (e) => Card(
                        child: ListTile(
                          leading: const Icon(Icons.error_outline),
                          title: Text(
                            '${e.tableName ?? '-'} ${e.operation ?? ''}',
                          ),
                          subtitle: Text('${e.message}\n${e.createdAt}'),
                          isThreeLine: true,
                          trailing: IconButton(
                            icon: const Icon(Icons.check),
                            onPressed: () async {
                              await markSyncErrorResolved(e.id);
                              await _load();
                            },
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
    );
  }
}

class _StatusCard extends StatelessWidget {
  final SyncStatus status;
  final SyncHealth health;

  const _StatusCard({required this.status, required this.health});

  @override
  Widget build(BuildContext context) {
    final color = switch (status) {
      SyncStatus.error => Colors.red,
      SyncStatus.conflict => Colors.orange,
      SyncStatus.syncing => Colors.blue,
      SyncStatus.done => Colors.green,
      SyncStatus.idle => Colors.grey,
    };
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        border: Border.all(color: color.withValues(alpha: 0.25)),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.cloud_sync, color: color),
              const SizedBox(width: 8),
              Text(
                _label(status),
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 16,
                  color: color,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _Metric(
            label: 'Operations en attente',
            value: '${health.pendingOperations}',
          ),
          _Metric(label: 'Erreurs ouvertes', value: '${health.openErrors}'),
          _Metric(label: 'Conflits ouverts', value: '${health.openConflicts}'),
          _Metric(
            label: 'Dernier snapshot',
            value: health.lastSnapshotAt ?? 'Aucun',
          ),
        ],
      ),
    );
  }

  String _label(SyncStatus status) => switch (status) {
    SyncStatus.error => 'Erreur de synchronisation',
    SyncStatus.conflict => 'Conflits a verifier',
    SyncStatus.syncing => 'Synchronisation en cours',
    SyncStatus.done => 'Synchronise',
    SyncStatus.idle => 'En attente',
  };
}

class _Metric extends StatelessWidget {
  final String label;
  final String value;

  const _Metric({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoBox extends StatelessWidget {
  final String text;
  const _InfoBox({required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(text),
    );
  }
}
