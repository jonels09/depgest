class Categorie {
  final int? id;
  final String nom;
  Categorie({this.id, required this.nom});
  factory Categorie.fromMap(Map<String, dynamic> m) =>
      Categorie(id: m['id'], nom: m['nom']);
  Map<String, dynamic> toMap() => {'id': id, 'nom': nom};
}

class Article {
  final int? id;
  final int categorieId;
  final String nom;
  Article({this.id, required this.categorieId, required this.nom});
  factory Article.fromMap(Map<String, dynamic> m) =>
      Article(id: m['id'], categorieId: m['categorie_id'], nom: m['nom']);
  Map<String, dynamic> toMap() => {
    'id': id,
    'categorie_id': categorieId,
    'nom': nom,
  };
}

class Unite {
  final int? id;
  final String nom;
  Unite({this.id, required this.nom});
  factory Unite.fromMap(Map<String, dynamic> m) =>
      Unite(id: m['id'], nom: m['nom']);
  Map<String, dynamic> toMap() => {'id': id, 'nom': nom};
}

class Revenu {
  final int? id;
  final String source;
  final double montant;
  final String dateRevenu;
  Revenu({
    this.id,
    required this.source,
    required this.montant,
    required this.dateRevenu,
  });
  factory Revenu.fromMap(Map<String, dynamic> m) => Revenu(
    id: m['id'],
    source: m['source'],
    montant: m['montant'],
    dateRevenu: m['date_revenu'],
  );
  Map<String, dynamic> toMap() => {
    'id': id,
    'source': source,
    'montant': montant,
    'date_revenu': dateRevenu,
  };
}

class Depense {
  final int? id;
  final int articleId;
  final int uniteId;
  final double quantite;
  final double prixUnitaire;
  final double total;
  final String dateDepense;
  // Champs joints pour l'affichage
  final String? articleNom;
  final String? categorieNom;
  final String? uniteNom;

  Depense({
    this.id,
    required this.articleId,
    required this.uniteId,
    required this.quantite,
    required this.prixUnitaire,
    required this.total,
    required this.dateDepense,
    this.articleNom,
    this.categorieNom,
    this.uniteNom,
  });

  factory Depense.fromMap(Map<String, dynamic> m) => Depense(
    id: m['id'],
    articleId: m['article_id'],
    uniteId: m['unite_id'],
    quantite: m['quantite'],
    prixUnitaire: m['prix_unitaire'],
    total: m['total'],
    dateDepense: m['date_depense'],
    articleNom: m['article_nom'],
    categorieNom: m['categorie_nom'],
    uniteNom: m['unite_nom'],
  );

  Map<String, dynamic> toMap() => {
    'id': id,
    'article_id': articleId,
    'unite_id': uniteId,
    'quantite': quantite,
    'prix_unitaire': prixUnitaire,
    'total': total,
    'date_depense': dateDepense,
  };
}

class Budget {
  final int? id;
  final int? categorieId;
  final String mois;
  final double montant;
  final String? categorieNom;
  final double depenseActuelle;

  Budget({
    this.id,
    this.categorieId,
    required this.mois,
    required this.montant,
    this.categorieNom,
    this.depenseActuelle = 0,
  });

  factory Budget.fromMap(Map<String, dynamic> m) => Budget(
    id: m['id'],
    categorieId: m['categorie_id'],
    mois: m['mois'],
    montant: (m['montant'] as num).toDouble(),
    categorieNom: m['categorie_nom'],
    depenseActuelle: ((m['depense_actuelle'] ?? 0) as num).toDouble(),
  );

  Map<String, dynamic> toMap() => {
    'id': id,
    'categorie_id': categorieId,
    'mois': mois,
    'montant': montant,
  };
}

class SavingGoal {
  final int? id;
  final String nom;
  final double targetAmount;
  final double currentAmount;
  final String? dueDate;

  SavingGoal({
    this.id,
    required this.nom,
    required this.targetAmount,
    this.currentAmount = 0,
    this.dueDate,
  });

  factory SavingGoal.fromMap(Map<String, dynamic> m) => SavingGoal(
    id: m['id'],
    nom: m['nom'],
    targetAmount: (m['target_amount'] as num).toDouble(),
    currentAmount: ((m['current_amount'] ?? 0) as num).toDouble(),
    dueDate: m['due_date'],
  );

  Map<String, dynamic> toMap() => {
    'id': id,
    'nom': nom,
    'target_amount': targetAmount,
    'current_amount': currentAmount,
    'due_date': dueDate,
  };
}

class MonthlyForecast {
  final double spentSoFar;
  final double projectedSpending;
  final double averagePreviousMonths;
  final double budgetTotal;

  const MonthlyForecast({
    required this.spentSoFar,
    required this.projectedSpending,
    required this.averagePreviousMonths,
    required this.budgetTotal,
  });
}

class SyncHealth {
  final int pendingOperations;
  final int openErrors;
  final int openConflicts;
  final String? lastSnapshotAt;

  const SyncHealth({
    required this.pendingOperations,
    required this.openErrors,
    required this.openConflicts,
    this.lastSnapshotAt,
  });
}

class SyncErrorEntry {
  final int id;
  final String? tableName;
  final int? localId;
  final String? operation;
  final String message;
  final String createdAt;

  SyncErrorEntry({
    required this.id,
    this.tableName,
    this.localId,
    this.operation,
    required this.message,
    required this.createdAt,
  });

  factory SyncErrorEntry.fromMap(Map<String, dynamic> m) => SyncErrorEntry(
    id: m['id'],
    tableName: m['table_name'],
    localId: m['local_id'],
    operation: m['operation'],
    message: m['message'],
    createdAt: m['created_at'],
  );
}

class SyncConflictEntry {
  final int id;
  final String tableName;
  final int? localId;
  final String? remoteId;
  final String reason;
  final String createdAt;

  SyncConflictEntry({
    required this.id,
    required this.tableName,
    this.localId,
    this.remoteId,
    required this.reason,
    required this.createdAt,
  });

  factory SyncConflictEntry.fromMap(Map<String, dynamic> m) =>
      SyncConflictEntry(
        id: m['id'],
        tableName: m['table_name'],
        localId: m['local_id'],
        remoteId: m['remote_id'],
        reason: m['reason'],
        createdAt: m['created_at'],
      );
}
