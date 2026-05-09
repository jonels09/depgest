import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/predictive_models.dart';
import '../models/models.dart';
import '../services/predictive_analytics_service.dart';
import '../services/sync_service.dart';
import 'database_helper.dart';

Future<List<Categorie>> getCategories() async {
  final db = await DatabaseHelper.instance.database;
  final rows = await db.query(
    'categories',
    where: 'is_deleted = 0',
    orderBy: 'nom',
  );
  return rows.map(Categorie.fromMap).toList();
}

Future<int> insertCategorie(Categorie c) async {
  final db = await DatabaseHelper.instance.database;
  final id = await db.insert(
    'categories',
    _withLocalSync(c.toMap()..remove('id')),
  );
  await enqueueSyncOperation('categories', id, 'upsert');
  _scheduleSync();
  return id;
}

Future<int> deleteCategorie(int id) async {
  final db = await DatabaseHelper.instance.database;
  final now = _nowIso();
  final categoryRows = await db.query(
    'categories',
    where: 'id = ?',
    whereArgs: [id],
  );
  final articleRows = await db.query(
    'articles',
    where: 'categorie_id = ? AND is_deleted = 0',
    whereArgs: [id],
  );
  final articleIds = articleRows.map((r) => r['id'] as int).toList();
  final depenseRows = articleIds.isEmpty
      ? <Map<String, dynamic>>[]
      : await db.query(
          'depenses',
          where:
              'article_id IN (${List.filled(articleIds.length, '?').join(',')}) AND is_deleted = 0',
          whereArgs: articleIds,
        );

  final changed = await db.transaction((txn) async {
    for (final depense in depenseRows) {
      await txn.update(
        'depenses',
        _softDeleteMap(now),
        where: 'id = ? AND is_deleted = 0',
        whereArgs: [depense['id']],
      );
    }
    await txn.update(
      'articles',
      _softDeleteMap(now),
      where: 'categorie_id = ? AND is_deleted = 0',
      whereArgs: [id],
    );
    return txn.update(
      'categories',
      _softDeleteMap(now),
      where: 'id = ? AND is_deleted = 0',
      whereArgs: [id],
    );
  });

  for (final depense in depenseRows) {
    await enqueueSyncOperation(
      'depenses',
      depense['id'] as int,
      'delete',
      remoteId: depense['remote_id'] as String?,
    );
  }
  for (final article in articleRows) {
    await enqueueSyncOperation(
      'articles',
      article['id'] as int,
      'delete',
      remoteId: article['remote_id'] as String?,
    );
  }
  if (categoryRows.isNotEmpty) {
    await enqueueSyncOperation(
      'categories',
      id,
      'delete',
      remoteId: categoryRows.first['remote_id'] as String?,
    );
  }

  _scheduleSync();
  return changed;
}

Future<List<Article>> getArticlesByCategorie(int categorieId) async {
  final db = await DatabaseHelper.instance.database;
  final rows = await db.query(
    'articles',
    where: 'categorie_id = ? AND is_deleted = 0',
    whereArgs: [categorieId],
    orderBy: 'nom',
  );
  return rows.map(Article.fromMap).toList();
}

Future<int> insertArticle(Article a) async {
  final db = await DatabaseHelper.instance.database;
  final id = await db.insert(
    'articles',
    _withLocalSync(a.toMap()..remove('id')),
  );
  await enqueueSyncOperation('articles', id, 'upsert');
  _scheduleSync();
  return id;
}

Future<int> deleteArticle(int id) async {
  final db = await DatabaseHelper.instance.database;
  final now = _nowIso();
  final articleRows = await db.query(
    'articles',
    where: 'id = ?',
    whereArgs: [id],
  );
  final depenseRows = await db.query(
    'depenses',
    where: 'article_id = ? AND is_deleted = 0',
    whereArgs: [id],
  );

  final changed = await db.transaction((txn) async {
    await txn.update(
      'depenses',
      _softDeleteMap(now),
      where: 'article_id = ? AND is_deleted = 0',
      whereArgs: [id],
    );
    return txn.update(
      'articles',
      _softDeleteMap(now),
      where: 'id = ? AND is_deleted = 0',
      whereArgs: [id],
    );
  });

  for (final depense in depenseRows) {
    await enqueueSyncOperation(
      'depenses',
      depense['id'] as int,
      'delete',
      remoteId: depense['remote_id'] as String?,
    );
  }
  if (articleRows.isNotEmpty) {
    await enqueueSyncOperation(
      'articles',
      id,
      'delete',
      remoteId: articleRows.first['remote_id'] as String?,
    );
  }

  _scheduleSync();
  return changed;
}

Future<List<Unite>> getUnites() async {
  final db = await DatabaseHelper.instance.database;
  final rows = await db.query(
    'unites',
    where: 'is_deleted = 0',
    orderBy: 'nom',
  );
  return rows.map(Unite.fromMap).toList();
}

Future<int> insertUnite(Unite u) async {
  final db = await DatabaseHelper.instance.database;
  final id = await db.insert('unites', _withLocalSync(u.toMap()..remove('id')));
  await enqueueSyncOperation('unites', id, 'upsert');
  _scheduleSync();
  return id;
}

Future<int> insertRevenu(Revenu r) async {
  final db = await DatabaseHelper.instance.database;
  final id = await db.insert(
    'revenus',
    _withLocalSync(r.toMap()..remove('id')),
  );
  await enqueueSyncOperation('revenus', id, 'upsert');
  _scheduleSync();
  _scheduleFinancialRefresh();
  return id;
}

Future<int> deleteRevenu(int id) async {
  final db = await DatabaseHelper.instance.database;
  final rows = await db.query('revenus', where: 'id = ?', whereArgs: [id]);
  final changed = await db.update(
    'revenus',
    _softDeleteMap(_nowIso()),
    where: 'id = ? AND is_deleted = 0',
    whereArgs: [id],
  );
  if (rows.isNotEmpty) {
    await enqueueSyncOperation(
      'revenus',
      id,
      'delete',
      remoteId: rows.first['remote_id'] as String?,
    );
  }
  _scheduleSync();
  return changed;
}

Future<List<Revenu>> getRevenusParMois(int annee, int mois) async {
  final db = await DatabaseHelper.instance.database;
  final range = _monthRange(annee, mois);
  final rows = await db.query(
    'revenus',
    where: 'date_revenu >= ? AND date_revenu < ? AND is_deleted = 0',
    whereArgs: [range.start, range.end],
    orderBy: 'date_revenu DESC',
  );
  return rows.map(Revenu.fromMap).toList();
}

Future<int> insertDepense(Depense d) async {
  final db = await DatabaseHelper.instance.database;
  final id = await db.insert(
    'depenses',
    _withLocalSync(d.toMap()..remove('id')),
  );
  await enqueueSyncOperation('depenses', id, 'upsert');
  _scheduleSync();
  _schedulePostExpenseAnalysis(localDepenseId: id);
  return id;
}

Future<int> deleteDepense(int id) async {
  final db = await DatabaseHelper.instance.database;
  final rows = await db.query('depenses', where: 'id = ?', whereArgs: [id]);
  final changed = await db.update(
    'depenses',
    _softDeleteMap(_nowIso()),
    where: 'id = ? AND is_deleted = 0',
    whereArgs: [id],
  );
  if (rows.isNotEmpty) {
    await enqueueSyncOperation(
      'depenses',
      id,
      'delete',
      remoteId: rows.first['remote_id'] as String?,
    );
  }
  _scheduleSync();
  return changed;
}

const String _depenseJoinQuery = '''
  SELECT d.*, a.nom AS article_nom, c.nom AS categorie_nom, u.nom AS unite_nom
  FROM depenses d
  JOIN articles a ON d.article_id = a.id
  JOIN categories c ON a.categorie_id = c.id
  JOIN unites u ON d.unite_id = u.id
''';

Future<List<Depense>> getDepensesJour(DateTime date) async {
  final db = await DatabaseHelper.instance.database;
  final rows = await db.rawQuery(
    '''
    $_depenseJoinQuery
    WHERE d.date_depense = ?
      AND d.is_deleted = 0
      AND a.is_deleted = 0
      AND c.is_deleted = 0
      AND u.is_deleted = 0
    ORDER BY d.id DESC
    ''',
    [_dateStr(date)],
  );
  return rows.map(Depense.fromMap).toList();
}

Future<List<Depense>> getDepensesMois(int annee, int mois) async {
  final range = _monthRange(annee, mois);
  return getDepensesPeriode(range.start, range.end);
}

Future<List<Depense>> getDepensesAnnee(int annee) async {
  final range = _yearRange(annee);
  return getDepensesPeriode(range.start, range.end);
}

Future<List<Depense>> getDepensesPeriode(String start, String end) async {
  final db = await DatabaseHelper.instance.database;
  final rows = await db.rawQuery(
    '''
    $_depenseJoinQuery
    WHERE d.date_depense >= ? AND d.date_depense < ?
      AND d.is_deleted = 0
      AND a.is_deleted = 0
      AND c.is_deleted = 0
      AND u.is_deleted = 0
    ORDER BY d.date_depense DESC, d.id DESC
    ''',
    [start, end],
  );
  return rows.map(Depense.fromMap).toList();
}

Future<double> sommeDepensesJour(DateTime date) async {
  final db = await DatabaseHelper.instance.database;
  final result = await db.rawQuery(
    '''
    SELECT COALESCE(SUM(total), 0) AS s
    FROM depenses
    WHERE date_depense = ? AND is_deleted = 0
    ''',
    [_dateStr(date)],
  );
  return (result.first['s'] as num).toDouble();
}

Future<double> sommeDepensesMois(int annee, int mois) async {
  final range = _monthRange(annee, mois);
  return sommeDepensesPeriode(range.start, range.end);
}

Future<double> sommeDepensesPeriode(String start, String end) async {
  final db = await DatabaseHelper.instance.database;
  final result = await db.rawQuery(
    '''
    SELECT COALESCE(SUM(total), 0) AS s
    FROM depenses
    WHERE date_depense >= ? AND date_depense < ? AND is_deleted = 0
    ''',
    [start, end],
  );
  return (result.first['s'] as num).toDouble();
}

Future<double> sommeRevenusMois(int annee, int mois) async {
  final range = _monthRange(annee, mois);
  return sommeRevenusPeriode(range.start, range.end);
}

Future<double> sommeRevenusPeriode(String start, String end) async {
  final db = await DatabaseHelper.instance.database;
  final result = await db.rawQuery(
    '''
    SELECT COALESCE(SUM(montant), 0) AS s
    FROM revenus
    WHERE date_revenu >= ? AND date_revenu < ? AND is_deleted = 0
    ''',
    [start, end],
  );
  return (result.first['s'] as num).toDouble();
}

Future<List<Map<String, dynamic>>> depensesParCategorieMois(
  int annee,
  int mois,
) async {
  final range = _monthRange(annee, mois);
  return depensesParCategoriePeriode(range.start, range.end);
}

Future<List<Map<String, dynamic>>> depensesParCategoriePeriode(
  String start,
  String end,
) async {
  final db = await DatabaseHelper.instance.database;
  return db.rawQuery(
    '''
    SELECT c.nom AS categorie, COALESCE(SUM(d.total), 0) AS total
    FROM depenses d
    JOIN articles a ON d.article_id = a.id
    JOIN categories c ON a.categorie_id = c.id
    WHERE d.date_depense >= ? AND d.date_depense < ?
      AND d.is_deleted = 0
      AND a.is_deleted = 0
      AND c.is_deleted = 0
    GROUP BY c.id
    ORDER BY total DESC
    ''',
    [start, end],
  );
}

Future<List<Map<String, dynamic>>> resumeAnnuel(int annee) async {
  final db = await DatabaseHelper.instance.database;
  final range = _yearRange(annee);

  final depenses = await db.rawQuery(
    '''
    SELECT SUBSTR(date_depense, 6, 2) AS mois, COALESCE(SUM(total), 0) AS total
    FROM depenses
    WHERE date_depense >= ? AND date_depense < ? AND is_deleted = 0
    GROUP BY mois
    ORDER BY mois
    ''',
    [range.start, range.end],
  );

  final revenus = await db.rawQuery(
    '''
    SELECT SUBSTR(date_revenu, 6, 2) AS mois, COALESCE(SUM(montant), 0) AS total
    FROM revenus
    WHERE date_revenu >= ? AND date_revenu < ? AND is_deleted = 0
    GROUP BY mois
    ORDER BY mois
    ''',
    [range.start, range.end],
  );

  final result = <String, Map<String, dynamic>>{};
  for (var i = 1; i <= 12; i++) {
    final m = i.toString().padLeft(2, '0');
    result[m] = {'mois': i, 'depenses': 0.0, 'revenus': 0.0};
  }
  for (final r in depenses) {
    result[r['mois'] as String]!['depenses'] = (r['total'] as num).toDouble();
  }
  for (final r in revenus) {
    result[r['mois'] as String]!['revenus'] = (r['total'] as num).toDouble();
  }
  return result.values.toList();
}

Future<List<Budget>> getBudgetsParMois(int annee, int mois) async {
  final db = await DatabaseHelper.instance.database;
  final moisKey = _monthKey(annee, mois);
  final range = _monthRange(annee, mois);
  final rows = await db.rawQuery(
    '''
    SELECT b.*,
           c.nom AS categorie_nom,
           COALESCE((
             SELECT SUM(d.total)
             FROM depenses d
             JOIN articles a ON d.article_id = a.id
             WHERE d.is_deleted = 0
               AND a.is_deleted = 0
               AND d.date_depense >= ?
               AND d.date_depense < ?
               AND (b.categorie_id IS NULL OR a.categorie_id = b.categorie_id)
           ), 0) AS depense_actuelle
    FROM budgets b
    LEFT JOIN categories c ON b.categorie_id = c.id
    WHERE b.mois = ? AND b.is_deleted = 0
    ORDER BY c.nom IS NULL DESC, c.nom
    ''',
    [range.start, range.end, moisKey],
  );
  return rows.map(Budget.fromMap).toList();
}

Future<int> upsertBudget(Budget budget) async {
  final db = await DatabaseHelper.instance.database;
  final now = _nowIso();
  if (budget.id == null) {
    final id = await db.insert(
      'budgets',
      _withLocalSync(budget.toMap()..remove('id')),
    );
    await enqueueSyncOperation('budgets', id, 'upsert');
    _scheduleSync();
    return id;
  }
  final changed = await db.update(
    'budgets',
    {
      'categorie_id': budget.categorieId,
      'mois': budget.mois,
      'montant': budget.montant,
      'synced': 0,
      'updated_at': now,
      'deleted_at': null,
      'is_deleted': 0,
    },
    where: 'id = ?',
    whereArgs: [budget.id],
  );
  await enqueueSyncOperation('budgets', budget.id!, 'upsert');
  _scheduleSync();
  return changed;
}

Future<int> deleteBudget(int id) async {
  final db = await DatabaseHelper.instance.database;
  final rows = await db.query('budgets', where: 'id = ?', whereArgs: [id]);
  final changed = await db.update(
    'budgets',
    _softDeleteMap(_nowIso()),
    where: 'id = ? AND is_deleted = 0',
    whereArgs: [id],
  );
  if (rows.isNotEmpty) {
    await enqueueSyncOperation(
      'budgets',
      id,
      'delete',
      remoteId: rows.first['remote_id'] as String?,
    );
  }
  _scheduleSync();
  return changed;
}

Future<List<SavingGoal>> getSavingGoals() async {
  final db = await DatabaseHelper.instance.database;
  final rows = await db.query(
    'saving_goals',
    where: 'is_deleted = 0',
    orderBy: 'due_date IS NULL, due_date ASC, id DESC',
  );
  return rows.map(SavingGoal.fromMap).toList();
}

Future<int> upsertSavingGoal(SavingGoal goal) async {
  final db = await DatabaseHelper.instance.database;
  final now = _nowIso();
  if (goal.id == null) {
    final id = await db.insert(
      'saving_goals',
      _withLocalSync(goal.toMap()..remove('id')),
    );
    await enqueueSyncOperation('saving_goals', id, 'upsert');
    _scheduleSync();
    return id;
  }
  final changed = await db.update(
    'saving_goals',
    {
      'nom': goal.nom,
      'target_amount': goal.targetAmount,
      'current_amount': goal.currentAmount,
      'due_date': goal.dueDate,
      'synced': 0,
      'updated_at': now,
      'deleted_at': null,
      'is_deleted': 0,
    },
    where: 'id = ?',
    whereArgs: [goal.id],
  );
  await enqueueSyncOperation('saving_goals', goal.id!, 'upsert');
  _scheduleSync();
  return changed;
}

Future<int> addSavingContribution(int goalId, double amount) async {
  final db = await DatabaseHelper.instance.database;
  final rows = await db.query(
    'saving_goals',
    where: 'id = ?',
    whereArgs: [goalId],
  );
  if (rows.isEmpty) return 0;
  final current = ((rows.first['current_amount'] ?? 0) as num).toDouble();
  final changed = await db.update(
    'saving_goals',
    {'current_amount': current + amount, 'synced': 0, 'updated_at': _nowIso()},
    where: 'id = ? AND is_deleted = 0',
    whereArgs: [goalId],
  );
  await enqueueSyncOperation('saving_goals', goalId, 'upsert');
  _scheduleSync();
  return changed;
}

Future<int> deleteSavingGoal(int id) async {
  final db = await DatabaseHelper.instance.database;
  final rows = await db.query('saving_goals', where: 'id = ?', whereArgs: [id]);
  final changed = await db.update(
    'saving_goals',
    _softDeleteMap(_nowIso()),
    where: 'id = ? AND is_deleted = 0',
    whereArgs: [id],
  );
  if (rows.isNotEmpty) {
    await enqueueSyncOperation(
      'saving_goals',
      id,
      'delete',
      remoteId: rows.first['remote_id'] as String?,
    );
  }
  _scheduleSync();
  return changed;
}

Future<MonthlyForecast> getMonthlyForecast(int annee, int mois) async {
  final now = DateTime.now();
  final range = _monthRange(annee, mois);
  final spentSoFar = await sommeDepensesPeriode(range.start, range.end);
  final daysInMonth = DateTime(annee, mois + 1, 0).day;
  final elapsedDays = annee == now.year && mois == now.month
      ? now.day.clamp(1, daysInMonth)
      : daysInMonth;
  final projected = elapsedDays == 0
      ? spentSoFar
      : (spentSoFar / elapsedDays) * daysInMonth;

  var historyTotal = 0.0;
  var historyCount = 0;
  for (var offset = 1; offset <= 3; offset++) {
    final date = DateTime(annee, mois - offset);
    historyTotal += await sommeDepensesMois(date.year, date.month);
    historyCount++;
  }

  final budgets = await getBudgetsParMois(annee, mois);
  final budgetTotal = budgets.fold(0.0, (sum, b) => sum + b.montant);
  return MonthlyForecast(
    spentSoFar: spentSoFar,
    projectedSpending: projected,
    averagePreviousMonths: historyCount == 0 ? 0 : historyTotal / historyCount,
    budgetTotal: budgetTotal,
  );
}

Future<PredictionData> getPredictions({String? userId}) async {
  final supabase = Supabase.instance.client;
  final resolvedUserId = userId ?? supabase.auth.currentUser?.id;
  if (resolvedUserId == null) {
    return PredictionData.empty();
  }

  final scores = await _fetchLatestScore(supabase, resolvedUserId);
  final xgboost = await _fetchLatestPrediction(supabase, resolvedUserId);
  final prophet = await _fetchLatestProphet(supabase, resolvedUserId);
  final anomalies = await _fetchLatestAnomalies(supabase, resolvedUserId);

  return PredictionData(
    scores: scores,
    xgboost: xgboost,
    prophet: prophet,
    anomalies: anomalies,
    fetchedAt: DateTime.now().toIso8601String(),
  );
}

Future<FinancialScores?> _fetchLatestScore(
  SupabaseClient supabase,
  String userId,
) async {
  try {
    final row = await supabase
        .from('financial_scores')
        .select()
        .eq('user_id', userId)
        .order('month', ascending: false)
        .limit(1)
        .maybeSingle();
    return row == null ? null : FinancialScores.fromJson(row);
  } catch (error) {
    debugPrint('[DAO] Unable to fetch financial scores: $error');
    return null;
  }
}

Future<XGBoostForecast?> _fetchLatestPrediction(
  SupabaseClient supabase,
  String userId,
) async {
  try {
    final row = await supabase
        .from('predictions')
        .select()
        .eq('user_id', userId)
        .order('month', ascending: false)
        .limit(1)
        .maybeSingle();
    return row == null ? null : XGBoostForecast.fromJson(row);
  } catch (error) {
    debugPrint('[DAO] Unable to fetch predictions: $error');
    return null;
  }
}

Future<ProphetForecast?> _fetchLatestProphet(
  SupabaseClient supabase,
  String userId,
) async {
  try {
    final row = await supabase
        .from('prophet_insights')
        .select()
        .eq('user_id', userId)
        .order('analysis_month', ascending: false)
        .limit(1)
        .maybeSingle();
    if (row == null) return null;

    return ProphetForecast.fromJson({
      'user_id': userId,
      'status': 'success',
      'forecast': {
        'monthly_forecast': row['forecast_next_3_months'] ?? const [],
        'seasonal_patterns': row['seasonal_pattern'] ?? const {},
        'trend': {
          'direction': row['trend_direction'],
          'percent': row['trend_percent'],
        },
      },
      'metrics': const {},
      'generated_at': row['created_at'],
    });
  } catch (error) {
    debugPrint('[DAO] Unable to fetch prophet insights: $error');
    return null;
  }
}

Future<List<AnomalyAlert>> _fetchLatestAnomalies(
  SupabaseClient supabase,
  String userId,
) async {
  try {
    final rows = await supabase
        .from('anomalies')
        .select()
        .eq('user_id', userId)
        .order('detected_at', ascending: false)
        .limit(10);
    return List<Map<String, dynamic>>.from(
      rows,
    ).map(AnomalyAlert.fromJson).toList();
  } catch (error) {
    debugPrint('[DAO] Unable to fetch anomalies: $error');
    return const <AnomalyAlert>[];
  }
}

Future<void> enqueueSyncOperation(
  String tableName,
  int localId,
  String operation, {
  String? remoteId,
}) async {
  final db = await DatabaseHelper.instance.database;
  final now = _nowIso();
  final existing = await db.query(
    'sync_operations',
    where: 'table_name = ? AND local_id = ? AND operation = ? AND status != ?',
    whereArgs: [tableName, localId, operation, 'done'],
    limit: 1,
  );
  if (existing.isEmpty) {
    await db.insert('sync_operations', {
      'table_name': tableName,
      'local_id': localId,
      'remote_id': remoteId,
      'operation': operation,
      'status': 'pending',
      'attempt_count': 0,
      'created_at': now,
      'updated_at': now,
    });
  } else {
    await db.update(
      'sync_operations',
      {
        'remote_id': remoteId ?? existing.first['remote_id'],
        'status': 'pending',
        'updated_at': now,
        'next_retry_at': null,
      },
      where: 'id = ?',
      whereArgs: [existing.first['id']],
    );
  }
}

Future<SyncHealth> getSyncHealth() async {
  final db = await DatabaseHelper.instance.database;
  var pendingRows = 0;
  for (final table in _syncTables) {
    final rows = await db.rawQuery(
      'SELECT COUNT(*) AS c FROM $table WHERE synced = 0',
    );
    pendingRows += (rows.first['c'] as num).toInt();
  }
  final pending = await db.rawQuery(
    "SELECT COUNT(*) AS c FROM sync_operations WHERE status != 'done'",
  );
  final errors = await db.rawQuery(
    'SELECT COUNT(*) AS c FROM sync_errors WHERE resolved_at IS NULL',
  );
  final conflicts = await db.rawQuery(
    'SELECT COUNT(*) AS c FROM sync_conflicts WHERE resolved = 0',
  );
  final snapshots = await db.rawQuery(
    'SELECT MAX(created_at) AS last FROM sync_snapshots',
  );
  return SyncHealth(
    pendingOperations: pendingRows + (pending.first['c'] as num).toInt(),
    openErrors: (errors.first['c'] as num).toInt(),
    openConflicts: (conflicts.first['c'] as num).toInt(),
    lastSnapshotAt: snapshots.first['last'] as String?,
  );
}

Future<List<SyncErrorEntry>> getOpenSyncErrors() async {
  final db = await DatabaseHelper.instance.database;
  final rows = await db.query(
    'sync_errors',
    where: 'resolved_at IS NULL',
    orderBy: 'created_at DESC',
    limit: 20,
  );
  return rows.map(SyncErrorEntry.fromMap).toList();
}

Future<List<SyncConflictEntry>> getOpenSyncConflicts() async {
  final db = await DatabaseHelper.instance.database;
  final rows = await db.query(
    'sync_conflicts',
    where: 'resolved = 0',
    orderBy: 'created_at DESC',
    limit: 20,
  );
  return rows.map(SyncConflictEntry.fromMap).toList();
}

Future<void> markSyncErrorResolved(int id) async {
  final db = await DatabaseHelper.instance.database;
  await db.update(
    'sync_errors',
    {'resolved_at': _nowIso()},
    where: 'id = ?',
    whereArgs: [id],
  );
}

Future<void> markSyncConflictResolved(int id) async {
  final db = await DatabaseHelper.instance.database;
  final rows = await db.query(
    'sync_conflicts',
    where: 'id = ?',
    whereArgs: [id],
  );
  if (rows.isEmpty) return;
  final conflict = rows.first;
  final remotePayload = jsonDecode(conflict['remote_payload'] as String);
  final table = conflict['table_name'] as String;
  final localId = conflict['local_id'] as int?;
  if (localId != null) {
    await db.update(
      table,
      {'last_remote_updated_at': remotePayload['updated_at'], 'synced': 0},
      where: 'id = ?',
      whereArgs: [localId],
    );
    await db.update(
      'sync_operations',
      {'status': 'pending', 'next_retry_at': null, 'updated_at': _nowIso()},
      where: 'table_name = ? AND local_id = ? AND status = ?',
      whereArgs: [table, localId, 'conflict'],
    );
  }
  await db.update(
    'sync_conflicts',
    {'resolved': 1, 'resolved_at': _nowIso()},
    where: 'id = ?',
    whereArgs: [id],
  );
  _scheduleSync();
}

Map<String, dynamic> _withLocalSync(Map<String, dynamic> map) {
  final now = _nowIso();
  return {
    ...map,
    'synced': 0,
    'is_deleted': 0,
    'created_at': now,
    'updated_at': now,
    'deleted_at': null,
    'last_remote_updated_at': null,
  };
}

Map<String, dynamic> _softDeleteMap(String now) => {
  'is_deleted': 1,
  'synced': 0,
  'updated_at': now,
  'deleted_at': now,
};

_DateRange _monthRange(int annee, int mois) {
  final start = DateTime(annee, mois);
  final end = DateTime(annee, mois + 1);
  return _DateRange(_dateStr(start), _dateStr(end));
}

_DateRange _yearRange(int annee) =>
    _DateRange('$annee-01-01', '${annee + 1}-01-01');

String _monthKey(int annee, int mois) =>
    '${annee.toString().padLeft(4, '0')}-${mois.toString().padLeft(2, '0')}';

String _dateStr(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

String _nowIso() => DateTime.now().toUtc().toIso8601String();

void _scheduleSync() {
  unawaited(SyncService.instance.syncAll());
}

void _schedulePostExpenseAnalysis({required int localDepenseId}) {
  final userId = Supabase.instance.client.auth.currentUser?.id;
  if (userId == null) return;

  unawaited(
    Future<void>(() async {
      await Future<void>.delayed(const Duration(seconds: 2));
      debugPrint(
        '[DAO] Triggering anomaly detection for depense $localDepenseId',
      );
      await PredictiveAnalyticsService().triggerPostExpenseAnalysis(
        userId: userId,
      );
    }),
  );
}

void _scheduleFinancialRefresh() {
  final userId = Supabase.instance.client.auth.currentUser?.id;
  if (userId == null) return;

  unawaited(
    Future<void>(() async {
      await Future<void>.delayed(const Duration(seconds: 2));
      await PredictiveAnalyticsService().triggerFinancialRefresh(
        userId: userId,
      );
    }),
  );
}

class _DateRange {
  final String start;
  final String end;
  const _DateRange(this.start, this.end);
}

const _syncTables = [
  'categories',
  'articles',
  'unites',
  'revenus',
  'depenses',
  'budgets',
  'saving_goals',
];
