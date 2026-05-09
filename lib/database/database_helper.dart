import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper._init();
  static Database? _database;

  DatabaseHelper._init();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('depgest.db');
    return _database!;
  }

  Future<Database> _initDB(String filePath) async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, filePath);
    return openDatabase(
      path,
      version: 4,
      onCreate: _createDB,
      onUpgrade: _upgradeDB,
    );
  }

  Future<void> _createDB(Database db, int version) async {
    await db.execute('''
      CREATE TABLE categories (
        id          INTEGER PRIMARY KEY AUTOINCREMENT,
        remote_id   TEXT,
        nom         TEXT NOT NULL,
        synced      INTEGER NOT NULL DEFAULT 0,
        is_deleted  INTEGER NOT NULL DEFAULT 0,
        created_at  TEXT NOT NULL,
        updated_at  TEXT NOT NULL,
        deleted_at  TEXT,
        last_remote_updated_at TEXT
      )
    ''');

    await db.execute('''
      CREATE TABLE articles (
        id            INTEGER PRIMARY KEY AUTOINCREMENT,
        remote_id     TEXT,
        categorie_id  INTEGER NOT NULL,
        nom           TEXT NOT NULL,
        synced        INTEGER NOT NULL DEFAULT 0,
        is_deleted    INTEGER NOT NULL DEFAULT 0,
        created_at    TEXT NOT NULL,
        updated_at    TEXT NOT NULL,
        deleted_at    TEXT,
        last_remote_updated_at TEXT,
        FOREIGN KEY (categorie_id) REFERENCES categories(id) ON DELETE CASCADE
      )
    ''');

    await db.execute('''
      CREATE TABLE unites (
        id          INTEGER PRIMARY KEY AUTOINCREMENT,
        remote_id   TEXT,
        nom         TEXT NOT NULL,
        synced      INTEGER NOT NULL DEFAULT 0,
        is_deleted  INTEGER NOT NULL DEFAULT 0,
        created_at  TEXT NOT NULL,
        updated_at  TEXT NOT NULL,
        deleted_at  TEXT,
        last_remote_updated_at TEXT
      )
    ''');

    await db.execute('''
      CREATE TABLE revenus (
        id          INTEGER PRIMARY KEY AUTOINCREMENT,
        remote_id   TEXT,
        source      TEXT NOT NULL,
        montant     REAL NOT NULL,
        date_revenu TEXT NOT NULL,
        synced      INTEGER NOT NULL DEFAULT 0,
        is_deleted  INTEGER NOT NULL DEFAULT 0,
        created_at  TEXT NOT NULL,
        updated_at  TEXT NOT NULL,
        deleted_at  TEXT,
        last_remote_updated_at TEXT
      )
    ''');

    await db.execute('''
      CREATE TABLE depenses (
        id            INTEGER PRIMARY KEY AUTOINCREMENT,
        remote_id     TEXT,
        article_id    INTEGER NOT NULL,
        unite_id      INTEGER NOT NULL,
        quantite      REAL NOT NULL,
        prix_unitaire REAL NOT NULL,
        total         REAL NOT NULL,
        date_depense  TEXT NOT NULL,
        synced        INTEGER NOT NULL DEFAULT 0,
        is_deleted    INTEGER NOT NULL DEFAULT 0,
        created_at    TEXT NOT NULL,
        updated_at    TEXT NOT NULL,
        deleted_at    TEXT,
        last_remote_updated_at TEXT,
        FOREIGN KEY (article_id) REFERENCES articles(id) ON DELETE CASCADE,
        FOREIGN KEY (unite_id)   REFERENCES unites(id)   ON DELETE CASCADE
      )
    ''');

    await _createBusinessTables(db);
    await _createSupportTables(db);
    await _createIndexes(db);
    await _seedData(db);
  }

  Future<void> _upgradeDB(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      for (final table in _baseSyncTables) {
        await _addColumnIfMissing(db, table, 'remote_id TEXT');
        await _addColumnIfMissing(
          db,
          table,
          'synced INTEGER NOT NULL DEFAULT 0',
        );
        await _addColumnIfMissing(
          db,
          table,
          'is_deleted INTEGER NOT NULL DEFAULT 0',
        );
      }
    }

    if (oldVersion < 3) {
      final now = _nowIso();
      for (final table in _baseSyncTables) {
        await _addColumnIfMissing(db, table, 'created_at TEXT');
        await _addColumnIfMissing(db, table, 'updated_at TEXT');
        await _addColumnIfMissing(db, table, 'deleted_at TEXT');
        await db.update(table, {
          'created_at': now,
          'updated_at': now,
        }, where: 'created_at IS NULL OR updated_at IS NULL');
      }
    }

    if (oldVersion < 4) {
      for (final table in _baseSyncTables) {
        await _addColumnIfMissing(db, table, 'last_remote_updated_at TEXT');
      }
      await _createBusinessTables(db);
      await _createSupportTables(db);
    }

    await _createIndexes(db);
  }

  Future<void> _createBusinessTables(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS budgets (
        id          INTEGER PRIMARY KEY AUTOINCREMENT,
        remote_id   TEXT,
        categorie_id INTEGER,
        mois        TEXT NOT NULL,
        montant     REAL NOT NULL,
        synced      INTEGER NOT NULL DEFAULT 0,
        is_deleted  INTEGER NOT NULL DEFAULT 0,
        created_at  TEXT NOT NULL,
        updated_at  TEXT NOT NULL,
        deleted_at  TEXT,
        last_remote_updated_at TEXT,
        FOREIGN KEY (categorie_id) REFERENCES categories(id) ON DELETE SET NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS saving_goals (
        id          INTEGER PRIMARY KEY AUTOINCREMENT,
        remote_id   TEXT,
        nom         TEXT NOT NULL,
        target_amount REAL NOT NULL,
        current_amount REAL NOT NULL DEFAULT 0,
        due_date    TEXT,
        synced      INTEGER NOT NULL DEFAULT 0,
        is_deleted  INTEGER NOT NULL DEFAULT 0,
        created_at  TEXT NOT NULL,
        updated_at  TEXT NOT NULL,
        deleted_at  TEXT,
        last_remote_updated_at TEXT
      )
    ''');
  }

  Future<void> _createSupportTables(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS sync_operations (
        id          INTEGER PRIMARY KEY AUTOINCREMENT,
        table_name  TEXT NOT NULL,
        local_id    INTEGER,
        remote_id   TEXT,
        operation   TEXT NOT NULL,
        status      TEXT NOT NULL DEFAULT 'pending',
        attempt_count INTEGER NOT NULL DEFAULT 0,
        last_error  TEXT,
        next_retry_at TEXT,
        created_at  TEXT NOT NULL,
        updated_at  TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS sync_errors (
        id          INTEGER PRIMARY KEY AUTOINCREMENT,
        table_name  TEXT,
        local_id    INTEGER,
        remote_id   TEXT,
        operation   TEXT,
        message     TEXT NOT NULL,
        stack_trace TEXT,
        created_at  TEXT NOT NULL,
        resolved_at TEXT
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS sync_conflicts (
        id          INTEGER PRIMARY KEY AUTOINCREMENT,
        table_name  TEXT NOT NULL,
        local_id    INTEGER,
        remote_id   TEXT,
        local_payload TEXT NOT NULL,
        remote_payload TEXT NOT NULL,
        reason      TEXT NOT NULL,
        resolved    INTEGER NOT NULL DEFAULT 0,
        created_at  TEXT NOT NULL,
        resolved_at TEXT
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS sync_snapshots (
        id          INTEGER PRIMARY KEY AUTOINCREMENT,
        batch_id    TEXT NOT NULL,
        table_name  TEXT NOT NULL,
        local_id    INTEGER NOT NULL,
        payload     TEXT NOT NULL,
        created_at  TEXT NOT NULL,
        restored_at TEXT
      )
    ''');
  }

  Future<void> _addColumnIfMissing(
    Database db,
    String table,
    String definition,
  ) async {
    final column = definition.split(' ').first;
    final columns = await db.rawQuery('PRAGMA table_info($table)');
    final exists = columns.any((c) => c['name'] == column);
    if (!exists) {
      await db.execute('ALTER TABLE $table ADD COLUMN $definition');
    }
  }

  Future<void> _createIndexes(Database db) async {
    for (final table in _syncTables) {
      await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_${table}_remote_id ON $table(remote_id)',
      );
      await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_${table}_sync ON $table(synced, is_deleted)',
      );
      await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_${table}_updated_at ON $table(updated_at)',
      );
    }

    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_depenses_date_active ON depenses(date_depense, is_deleted)',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_revenus_date_active ON revenus(date_revenu, is_deleted)',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_depenses_article_active ON depenses(article_id, is_deleted)',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_articles_categorie_active ON articles(categorie_id, is_deleted)',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_budgets_mois_active ON budgets(mois, is_deleted)',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_sync_operations_status ON sync_operations(status, next_retry_at)',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_sync_errors_open ON sync_errors(resolved_at, created_at)',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_sync_conflicts_open ON sync_conflicts(resolved, created_at)',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_sync_snapshots_batch ON sync_snapshots(batch_id, created_at)',
    );
  }

  Future<void> _seedData(Database db) async {
    final now = _nowIso();
    final catIds = <String, int>{};
    for (final nom in [
      'Alimentation',
      'Transport',
      'Sante',
      'Logement',
      'Loisirs',
    ]) {
      final id = await db.insert('categories', {
        'nom': nom,
        'synced': 0,
        'created_at': now,
        'updated_at': now,
      });
      catIds[nom] = id;
    }

    final articles = {
      'Alimentation': ['Riz', 'Pain', 'Huile', 'Sucre', 'Lait'],
      'Transport': ['Essence', 'Bus', 'Taxi', 'Entretien vehicule'],
      'Sante': ['Medicaments', 'Consultation', 'Analyses'],
      'Logement': ['Loyer', 'Electricite', 'Eau', 'Internet'],
      'Loisirs': ['Restaurant', 'Cinema', 'Sport'],
    };
    for (final entry in articles.entries) {
      for (final nom in entry.value) {
        await db.insert('articles', {
          'categorie_id': catIds[entry.key],
          'nom': nom,
          'synced': 0,
          'created_at': now,
          'updated_at': now,
        });
      }
    }

    for (final nom in ['kg', 'litre', 'piece', 'sachet', 'mois', 'forfait']) {
      await db.insert('unites', {
        'nom': nom,
        'synced': 0,
        'created_at': now,
        'updated_at': now,
      });
    }
  }

  Future<void> close() async {
    final db = await instance.database;
    await db.close();
  }
}

const _baseSyncTables = [
  'categories',
  'articles',
  'unites',
  'revenus',
  'depenses',
];
const _syncTables = [..._baseSyncTables, 'budgets', 'saving_goals'];

String _nowIso() => DateTime.now().toUtc().toIso8601String();
