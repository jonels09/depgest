import 'dart:async';
import 'dart:convert';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite/sqflite.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../database/database_helper.dart';

class SyncService {
  static final SyncService instance = SyncService._();
  SyncService._();

  final _supabase = Supabase.instance.client;
  StreamSubscription<List<ConnectivityResult>>? _connectivitySub;
  bool _syncing = false;

  final ValueNotifier<SyncStatus> status = ValueNotifier(SyncStatus.idle);

  void init() {
    _connectivitySub = Connectivity().onConnectivityChanged.listen((results) {
      final online = results.any((r) => r != ConnectivityResult.none);
      if (online) syncAll();
    });
    syncAll();
  }

  void dispose() {
    _connectivitySub?.cancel();
    status.dispose();
  }

  Future<void> syncAll() async {
    if (_syncing) return;
    _syncing = true;
    status.value = SyncStatus.syncing;

    final pullStartedAt = _nowIso();
    try {
      final db = await DatabaseHelper.instance.database;
      await _createSnapshot(db);
      await _uploadPending(db);
      await _downloadChanged(db);

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_lastPulledAtKey, pullStartedAt);
      final openConflicts = await _openConflictCount(db);
      status.value = openConflicts > 0 ? SyncStatus.conflict : SyncStatus.done;
    } catch (e, st) {
      debugPrint('[SyncService] Sync error: $e\n$st');
      status.value = SyncStatus.error;
    } finally {
      _syncing = false;
    }
  }

  Future<void> rollbackLatestSnapshot() async {
    if (_syncing) return;
    _syncing = true;
    status.value = SyncStatus.syncing;
    try {
      final db = await DatabaseHelper.instance.database;
      final latest = await db.rawQuery(
        'SELECT batch_id FROM sync_snapshots ORDER BY created_at DESC LIMIT 1',
      );
      if (latest.isEmpty) return;
      final batchId = latest.first['batch_id'] as String;
      final rows = await db.query(
        'sync_snapshots',
        where: 'batch_id = ?',
        whereArgs: [batchId],
        orderBy: 'id ASC',
      );

      await db.transaction((txn) async {
        for (final table in _syncTables.reversed) {
          await txn.delete(table);
        }
        for (final row in rows) {
          final table = row['table_name'] as String;
          final payload = jsonDecode(row['payload'] as String);
          await txn.insert(table, Map<String, dynamic>.from(payload));
        }
        await txn.update(
          'sync_snapshots',
          {'restored_at': _nowIso()},
          where: 'batch_id = ?',
          whereArgs: [batchId],
        );
      });
      status.value = SyncStatus.done;
    } catch (e, st) {
      debugPrint('[SyncService] Rollback error: $e\n$st');
      status.value = SyncStatus.error;
    } finally {
      _syncing = false;
    }
  }

  Future<void> _uploadPending(Database db) async {
    await _uploadActiveTable(db, 'categories', _remoteCategorieMap);
    await _uploadActiveTable(db, 'unites', _remoteUniteMap);
    await _uploadActiveTable(db, 'articles', _remoteArticleMap);
    await _uploadActiveTable(db, 'revenus', _remoteRevenuMap);
    await _uploadActiveTable(db, 'depenses', _remoteDepenseMap);
    await _uploadActiveTable(db, 'budgets', _remoteBudgetMap);
    await _uploadActiveTable(db, 'saving_goals', _remoteSavingGoalMap);

    await _uploadDeletedTable(db, 'depenses');
    await _uploadDeletedTable(db, 'revenus');
    await _uploadDeletedTable(db, 'budgets');
    await _uploadDeletedTable(db, 'saving_goals');
    await _uploadDeletedTable(db, 'articles');
    await _uploadDeletedTable(db, 'unites');
    await _uploadDeletedTable(db, 'categories');
  }

  Future<void> _uploadActiveTable(
    Database db,
    String table,
    Future<Map<String, dynamic>?> Function(Database, Map<String, dynamic>)
    mapper,
  ) async {
    final rows = await db.query(
      table,
      where: 'synced = 0 AND is_deleted = 0',
      orderBy: 'id ASC',
    );

    for (final row in rows) {
      const operation = 'upsert';
      if (!await _canRetry(db, table, row['id'] as int, operation)) continue;

      try {
        if (await _hasRemoteConflict(db, table, row, operation)) continue;
        final remote = await mapper(db, row);
        if (remote == null) continue;

        final response = await _supabase
            .from(table)
            .upsert(remote, onConflict: 'id')
            .select('id, updated_at')
            .single();
        final remoteUpdatedAt = response['updated_at'] ?? row['updated_at'];

        await db.update(
          table,
          {
            'remote_id': response['id'],
            'updated_at': remoteUpdatedAt,
            'last_remote_updated_at': remoteUpdatedAt,
            'synced': 1,
          },
          where: 'id = ?',
          whereArgs: [row['id']],
        );
        await _markOperationDone(
          db,
          table,
          row['id'] as int,
          operation,
          remoteId: response['id'] as String?,
        );
        await _resolveRowErrors(db, table, row['id'] as int, operation);
      } catch (e, st) {
        await _recordError(
          db: db,
          table: table,
          localId: row['id'] as int,
          remoteId: row['remote_id'] as String?,
          operation: operation,
          error: e,
          stackTrace: st,
        );
      }
    }
  }

  Future<void> _uploadDeletedTable(Database db, String table) async {
    final rows = await db.query(
      table,
      where: 'synced = 0 AND is_deleted = 1',
      orderBy: 'id DESC',
    );

    for (final row in rows) {
      const operation = 'delete';
      final localId = row['id'] as int;
      if (!await _canRetry(db, table, localId, operation)) continue;

      try {
        final remoteId = row['remote_id'] as String?;
        if (remoteId == null) {
          await db.delete(table, where: 'id = ?', whereArgs: [localId]);
          await _markOperationDone(db, table, localId, operation);
          continue;
        }

        if (await _hasRemoteConflict(db, table, row, operation)) continue;
        final deletedAt = row['deleted_at'] ?? row['updated_at'] ?? _nowIso();
        final confirmed = await _supabase
            .from(table)
            .update({
              'deleted_at': deletedAt,
              'updated_at': row['updated_at'] ?? deletedAt,
            })
            .eq('id', remoteId)
            .select('id, updated_at')
            .maybeSingle();

        if (confirmed == null) {
          throw StateError(
            'Suppression distante non confirmee pour $table/$remoteId',
          );
        }

        final remoteUpdatedAt = confirmed['updated_at'] ?? row['updated_at'];
        await db.update(
          table,
          {'synced': 1, 'last_remote_updated_at': remoteUpdatedAt},
          where: 'id = ?',
          whereArgs: [localId],
        );
        await _markOperationDone(
          db,
          table,
          localId,
          operation,
          remoteId: remoteId,
        );
        await _resolveRowErrors(db, table, localId, operation);
      } catch (e, st) {
        await _recordError(
          db: db,
          table: table,
          localId: localId,
          remoteId: row['remote_id'] as String?,
          operation: operation,
          error: e,
          stackTrace: st,
        );
      }
    }
  }

  Future<Map<String, dynamic>?> _remoteCategorieMap(
    Database db,
    Map<String, dynamic> row,
  ) async {
    return _baseRemote(row)..addAll({'nom': row['nom']});
  }

  Future<Map<String, dynamic>?> _remoteUniteMap(
    Database db,
    Map<String, dynamic> row,
  ) async {
    return _baseRemote(row)..addAll({'nom': row['nom']});
  }

  Future<Map<String, dynamic>?> _remoteArticleMap(
    Database db,
    Map<String, dynamic> row,
  ) async {
    final cat = await _localById(db, 'categories', row['categorie_id']);
    if (cat == null || cat['remote_id'] == null) return null;
    return _baseRemote(row)
      ..addAll({'categorie_id': cat['remote_id'], 'nom': row['nom']});
  }

  Future<Map<String, dynamic>?> _remoteRevenuMap(
    Database db,
    Map<String, dynamic> row,
  ) async {
    return _baseRemote(row)..addAll({
      'source': row['source'],
      'montant': row['montant'],
      'date_revenu': row['date_revenu'],
    });
  }

  Future<Map<String, dynamic>?> _remoteDepenseMap(
    Database db,
    Map<String, dynamic> row,
  ) async {
    final article = await _localById(db, 'articles', row['article_id']);
    final unite = await _localById(db, 'unites', row['unite_id']);
    if (article == null || article['remote_id'] == null) return null;
    if (unite == null || unite['remote_id'] == null) return null;

    return _baseRemote(row)..addAll({
      'article_id': article['remote_id'],
      'unite_id': unite['remote_id'],
      'quantite': row['quantite'],
      'prix_unitaire': row['prix_unitaire'],
      'total': row['total'],
      'date_depense': row['date_depense'],
    });
  }

  Future<Map<String, dynamic>?> _remoteBudgetMap(
    Database db,
    Map<String, dynamic> row,
  ) async {
    final categoryId = row['categorie_id'];
    Map<String, dynamic>? category;
    if (categoryId != null) {
      category = await _localById(db, 'categories', categoryId);
      if (category == null || category['remote_id'] == null) return null;
    }
    return _baseRemote(row)..addAll({
      'categorie_id': category?['remote_id'],
      'mois': row['mois'],
      'montant': row['montant'],
    });
  }

  Future<Map<String, dynamic>?> _remoteSavingGoalMap(
    Database db,
    Map<String, dynamic> row,
  ) async {
    return _baseRemote(row)..addAll({
      'nom': row['nom'],
      'target_amount': row['target_amount'],
      'current_amount': row['current_amount'],
      'due_date': row['due_date'],
    });
  }

  Map<String, dynamic> _baseRemote(Map<String, dynamic> row) {
    final user = _supabase.auth.currentUser;
    return {
      if (row['remote_id'] != null) 'id': row['remote_id'],
      if (user != null) 'user_id': user.id,
      'created_at': row['created_at'],
      'updated_at': row['updated_at'],
      'deleted_at': null,
    };
  }

  Future<void> _downloadChanged(Database db) async {
    await _downloadCategories(db);
    await _downloadUnites(db);
    await _downloadArticles(db);
    await _downloadRevenus(db);
    await _downloadDepenses(db);
    await _downloadBudgets(db);
    await _downloadSavingGoals(db);
  }

  Future<void> _downloadCategories(Database db) async {
    final rows = await _fetchChanged('categories');
    for (final remote in rows) {
      await _upsertLocal(
        db: db,
        table: 'categories',
        remote: remote,
        values: {'nom': remote['nom']},
      );
    }
  }

  Future<void> _downloadUnites(Database db) async {
    final rows = await _fetchChanged('unites');
    for (final remote in rows) {
      await _upsertLocal(
        db: db,
        table: 'unites',
        remote: remote,
        values: {'nom': remote['nom']},
      );
    }
  }

  Future<void> _downloadArticles(Database db) async {
    final rows = await _fetchChanged('articles');
    for (final remote in rows) {
      final deleted = remote['deleted_at'] != null;
      final category = deleted
          ? null
          : await _localByRemoteId(db, 'categories', remote['categorie_id']);
      if (!deleted && category == null) continue;

      await _upsertLocal(
        db: db,
        table: 'articles',
        remote: remote,
        values: {
          if (category != null) 'categorie_id': category['id'],
          'nom': remote['nom'],
        },
      );
    }
  }

  Future<void> _downloadRevenus(Database db) async {
    final rows = await _fetchChanged('revenus');
    for (final remote in rows) {
      await _upsertLocal(
        db: db,
        table: 'revenus',
        remote: remote,
        values: {
          'source': remote['source'],
          'montant': remote['montant'],
          'date_revenu': remote['date_revenu'],
        },
      );
    }
  }

  Future<void> _downloadDepenses(Database db) async {
    final rows = await _fetchChanged('depenses');
    for (final remote in rows) {
      final deleted = remote['deleted_at'] != null;
      final article = deleted
          ? null
          : await _localByRemoteId(db, 'articles', remote['article_id']);
      final unite = deleted
          ? null
          : await _localByRemoteId(db, 'unites', remote['unite_id']);
      if (!deleted && (article == null || unite == null)) continue;

      await _upsertLocal(
        db: db,
        table: 'depenses',
        remote: remote,
        values: {
          if (article != null) 'article_id': article['id'],
          if (unite != null) 'unite_id': unite['id'],
          'quantite': remote['quantite'],
          'prix_unitaire': remote['prix_unitaire'],
          'total': remote['total'],
          'date_depense': remote['date_depense'],
        },
      );
    }
  }

  Future<void> _downloadBudgets(Database db) async {
    final rows = await _fetchChanged('budgets');
    for (final remote in rows) {
      final deleted = remote['deleted_at'] != null;
      final remoteCategorieId = remote['categorie_id'];
      final category = deleted || remoteCategorieId == null
          ? null
          : await _localByRemoteId(db, 'categories', remoteCategorieId);
      if (!deleted && remoteCategorieId != null && category == null) continue;

      await _upsertLocal(
        db: db,
        table: 'budgets',
        remote: remote,
        values: {
          'categorie_id': category?['id'],
          'mois': remote['mois'],
          'montant': remote['montant'],
        },
      );
    }
  }

  Future<void> _downloadSavingGoals(Database db) async {
    final rows = await _fetchChanged('saving_goals');
    for (final remote in rows) {
      await _upsertLocal(
        db: db,
        table: 'saving_goals',
        remote: remote,
        values: {
          'nom': remote['nom'],
          'target_amount': remote['target_amount'],
          'current_amount': remote['current_amount'],
          'due_date': remote['due_date'],
        },
      );
    }
  }

  Future<List<Map<String, dynamic>>> _fetchChanged(String table) async {
    final prefs = await SharedPreferences.getInstance();
    final since = prefs.getString(_lastPulledAtKey);

    final rows = since == null
        ? await _supabase.from(table).select().order('updated_at')
        : await _supabase
              .from(table)
              .select()
              .gt('updated_at', since)
              .order('updated_at');

    return List<Map<String, dynamic>>.from(rows);
  }

  Future<void> _upsertLocal({
    required Database db,
    required String table,
    required Map<String, dynamic> remote,
    required Map<String, dynamic> values,
  }) async {
    final remoteId = remote['id'];
    final existing = await _localByRemoteId(db, table, remoteId);
    final remoteUpdatedAt = remote['updated_at'] as String? ?? _nowIso();
    final deleted = remote['deleted_at'] != null;

    if (existing != null) {
      if (existing['synced'] == 0 &&
          _remoteChangedSinceLastKnown(existing, remoteUpdatedAt)) {
        await _recordConflict(
          db: db,
          table: table,
          local: existing,
          remote: remote,
          reason: 'local_and_remote_changed',
        );
        return;
      }

      await db.update(
        table,
        {
          ...values,
          'remote_id': remoteId,
          'synced': 1,
          'is_deleted': deleted ? 1 : 0,
          'created_at': remote['created_at'] ?? existing['created_at'],
          'updated_at': remoteUpdatedAt,
          'deleted_at': remote['deleted_at'],
          'last_remote_updated_at': remoteUpdatedAt,
        },
        where: 'id = ?',
        whereArgs: [existing['id']],
      );
      return;
    }

    if (deleted) return;

    await db.insert(table, {
      ...values,
      'remote_id': remoteId,
      'synced': 1,
      'is_deleted': 0,
      'created_at': remote['created_at'] ?? remoteUpdatedAt,
      'updated_at': remoteUpdatedAt,
      'deleted_at': null,
      'last_remote_updated_at': remoteUpdatedAt,
    });
  }

  Future<bool> _hasRemoteConflict(
    Database db,
    String table,
    Map<String, dynamic> local,
    String operation,
  ) async {
    final remoteId = local['remote_id'] as String?;
    if (remoteId == null) return false;

    final remote = await _supabase
        .from(table)
        .select()
        .eq('id', remoteId)
        .maybeSingle();
    if (remote == null) return false;

    final remoteUpdatedAt = remote['updated_at'] as String?;
    if (remoteUpdatedAt == null) return false;
    if (!_remoteChangedSinceLastKnown(local, remoteUpdatedAt)) return false;

    await _recordConflict(
      db: db,
      table: table,
      local: local,
      remote: Map<String, dynamic>.from(remote),
      reason: '${operation}_conflict',
    );
    await _markOperationConflict(db, table, local['id'] as int, operation);
    return true;
  }

  bool _remoteChangedSinceLastKnown(
    Map<String, dynamic> local,
    String remoteUpdatedAt,
  ) {
    final lastRemote = local['last_remote_updated_at'] as String?;
    return lastRemote != null && lastRemote != remoteUpdatedAt;
  }

  Future<void> _recordConflict({
    required Database db,
    required String table,
    required Map<String, dynamic> local,
    required Map<String, dynamic> remote,
    required String reason,
  }) async {
    final localId = local['id'] as int?;
    final remoteId = local['remote_id'] as String? ?? remote['id'] as String?;
    final existing = await db.query(
      'sync_conflicts',
      where:
          'table_name = ? AND local_id = ? AND remote_id = ? AND resolved = 0',
      whereArgs: [table, localId, remoteId],
      limit: 1,
    );
    if (existing.isNotEmpty) return;

    await db.insert('sync_conflicts', {
      'table_name': table,
      'local_id': localId,
      'remote_id': remoteId,
      'local_payload': jsonEncode(local),
      'remote_payload': jsonEncode(remote),
      'reason': reason,
      'resolved': 0,
      'created_at': _nowIso(),
    });
  }

  Future<bool> _canRetry(
    Database db,
    String table,
    int localId,
    String operation,
  ) async {
    final rows = await db.query(
      'sync_operations',
      where:
          'table_name = ? AND local_id = ? AND operation = ? AND status != ?',
      whereArgs: [table, localId, operation, 'done'],
      orderBy: 'id DESC',
      limit: 1,
    );
    if (rows.isEmpty) return true;
    final nextRetryAt = rows.first['next_retry_at'] as String?;
    if (nextRetryAt == null) return true;
    return !DateTime.parse(nextRetryAt).isAfter(DateTime.now().toUtc());
  }

  Future<void> _markOperationDone(
    Database db,
    String table,
    int localId,
    String operation, {
    String? remoteId,
  }) async {
    await db.update(
      'sync_operations',
      {
        'status': 'done',
        'remote_id': remoteId,
        'last_error': null,
        'next_retry_at': null,
        'updated_at': _nowIso(),
      },
      where:
          'table_name = ? AND local_id = ? AND operation = ? AND status != ?',
      whereArgs: [table, localId, operation, 'done'],
    );
  }

  Future<void> _markOperationConflict(
    Database db,
    String table,
    int localId,
    String operation,
  ) async {
    await db.update(
      'sync_operations',
      {
        'status': 'conflict',
        'last_error': 'Conflit local/distant detecte',
        'updated_at': _nowIso(),
      },
      where:
          'table_name = ? AND local_id = ? AND operation = ? AND status != ?',
      whereArgs: [table, localId, operation, 'done'],
    );
  }

  Future<void> _recordError({
    required Database db,
    required String table,
    required int localId,
    required String? remoteId,
    required String operation,
    required Object error,
    required StackTrace stackTrace,
  }) async {
    final now = _nowIso();
    final opRows = await db.query(
      'sync_operations',
      where:
          'table_name = ? AND local_id = ? AND operation = ? AND status != ?',
      whereArgs: [table, localId, operation, 'done'],
      orderBy: 'id DESC',
      limit: 1,
    );
    final attempts = opRows.isEmpty
        ? 1
        : (opRows.first['attempt_count'] as int) + 1;
    final delayMinutes = attempts > 6 ? 60 : 1 << (attempts - 1);
    final nextRetryAt = DateTime.now()
        .toUtc()
        .add(Duration(minutes: delayMinutes))
        .toIso8601String();

    if (opRows.isEmpty) {
      await db.insert('sync_operations', {
        'table_name': table,
        'local_id': localId,
        'remote_id': remoteId,
        'operation': operation,
        'status': 'failed',
        'attempt_count': attempts,
        'last_error': '$error',
        'next_retry_at': nextRetryAt,
        'created_at': now,
        'updated_at': now,
      });
    } else {
      await db.update(
        'sync_operations',
        {
          'status': 'failed',
          'attempt_count': attempts,
          'last_error': '$error',
          'next_retry_at': nextRetryAt,
          'updated_at': now,
        },
        where: 'id = ?',
        whereArgs: [opRows.first['id']],
      );
    }

    await db.insert('sync_errors', {
      'table_name': table,
      'local_id': localId,
      'remote_id': remoteId,
      'operation': operation,
      'message': '$error',
      'stack_trace': '$stackTrace',
      'created_at': now,
    });
  }

  Future<void> _resolveRowErrors(
    Database db,
    String table,
    int localId,
    String operation,
  ) async {
    await db.update(
      'sync_errors',
      {'resolved_at': _nowIso()},
      where:
          'table_name = ? AND local_id = ? AND operation = ? AND resolved_at IS NULL',
      whereArgs: [table, localId, operation],
    );
  }

  Future<void> _createSnapshot(Database db) async {
    final batchId = DateTime.now().toUtc().microsecondsSinceEpoch.toString();
    final now = _nowIso();
    await db.transaction((txn) async {
      for (final table in _syncTables) {
        final rows = await txn.query(table);
        for (final row in rows) {
          await txn.insert('sync_snapshots', {
            'batch_id': batchId,
            'table_name': table,
            'local_id': row['id'],
            'payload': jsonEncode(row),
            'created_at': now,
          });
        }
      }
    });
    await _cleanupSnapshots(db);
  }

  Future<void> _cleanupSnapshots(Database db) async {
    final batches = await db.rawQuery('''
      SELECT batch_id, MAX(created_at) AS created_at
      FROM sync_snapshots
      GROUP BY batch_id
      ORDER BY created_at DESC
      LIMIT -1 OFFSET 5
      ''');
    for (final batch in batches) {
      await db.delete(
        'sync_snapshots',
        where: 'batch_id = ?',
        whereArgs: [batch['batch_id']],
      );
    }
  }

  Future<int> _openConflictCount(Database db) async {
    final rows = await db.rawQuery(
      'SELECT COUNT(*) AS c FROM sync_conflicts WHERE resolved = 0',
    );
    return (rows.first['c'] as num).toInt();
  }

  Future<Map<String, dynamic>?> _localById(
    Database db,
    String table,
    Object? id,
  ) async {
    final rows = await db.query(table, where: 'id = ?', whereArgs: [id]);
    return rows.isEmpty ? null : rows.first;
  }

  Future<Map<String, dynamic>?> _localByRemoteId(
    Database db,
    String table,
    Object? remoteId,
  ) async {
    if (remoteId == null) return null;
    final rows = await db.query(
      table,
      where: 'remote_id = ?',
      whereArgs: [remoteId],
    );
    return rows.isEmpty ? null : rows.first;
  }
}

const _lastPulledAtKey = 'sync.lastPulledAt';
const _syncTables = [
  'categories',
  'unites',
  'articles',
  'revenus',
  'depenses',
  'budgets',
  'saving_goals',
];

String _nowIso() => DateTime.now().toUtc().toIso8601String();

enum SyncStatus { idle, syncing, done, error, conflict }
