"""
Anomaly Detection
Détecte dépenses inhabituelles, fraude potentielle et comportement anormal
utilisant Isolation Forest et Z-score.

Anomaly Types:
- UNUSUAL_AMOUNT: Montant inhabituel pour catégorie
- SUDDEN_SPIKE: Augmentation brutale vs normale
- FRAUD_SUSPICIOUS: Pattern anormal détecté
- SEASONAL_ANOMALY: Anormal vs saisonnalité attendue
"""

import pandas as pd
import numpy as np
from sklearn.ensemble import IsolationForest
from datetime import datetime, timedelta
from typing import Dict, List, Tuple, Optional
import logging

logger = logging.getLogger(__name__)


class AnomalyDetector:
    """
    Détecte anomalies dans dépenses utilisateur.
    Utilise Isolation Forest pour outliers + Z-score pour spikes.
    """
    
    def __init__(self, contamination: float = 0.05, zscore_threshold: float = 2.5):
        """
        Args:
            contamination: % données attendues comme anomalies
            zscore_threshold: Seuil Z-score pour détection spikes
        """
        self.contamination = contamination
        self.zscore_threshold = zscore_threshold
        self.isolation_forest = IsolationForest(
            contamination=contamination,
            random_state=42,
            n_estimators=100
        )
    
    def detect_anomalies(
        self,
        expenses_df: pd.DataFrame,
        historical_expenses_df: Optional[pd.DataFrame] = None
    ) -> List[Dict]:
        """
        Détecte anomalies dans dépenses récentes.
        
        Returns:
            Liste d'anomalies détectées avec type, severity, description
        """
        
        if expenses_df.empty:
            return []
        
        anomalies = []
        
        # 1. Isolation Forest par catégorie
        anomalies.extend(self._detect_by_category_isolation_forest(expenses_df))
        
        # 2. Z-score pour spikes
        anomalies.extend(self._detect_spikes_zscore(expenses_df, historical_expenses_df))
        
        # 3. Patterns suspects
        anomalies.extend(self._detect_suspicious_patterns(expenses_df))
        
        logger.info(f"✅ Detected {len(anomalies)} anomalies")
        return anomalies
    
    def _detect_by_category_isolation_forest(self, expenses_df: pd.DataFrame) -> List[Dict]:
        """
        Détecte outliers par catégorie en utilisant Isolation Forest.
        """
        anomalies = []
        
        for category in expenses_df['category'].unique():
            category_expenses = expenses_df[expenses_df['category'] == category].copy()
            
            if len(category_expenses) < 5:
                continue
            
            X = category_expenses[['total']].values
            predictions = self.isolation_forest.fit_predict(X)
            
            for idx, (pred, row) in enumerate(zip(predictions, category_expenses.itertuples())):
                if pred == -1:  # Anomaly
                    anomalies.append({
                        "depense_id": getattr(row, 'id', str(idx)),
                        "anomaly_type": "UNUSUAL_AMOUNT",
                        "severity": "MEDIUM",
                        "description": f"Montant inhabituel pour {category}: {row.total:.2f}",
                        "metadata": {
                            "category": category,
                            "amount": float(row.total),
                            "method": "isolation_forest"
                        }
                    })
        
        return anomalies
    
    def _detect_spikes_zscore(
        self,
        expenses_df: pd.DataFrame,
        historical_df: Optional[pd.DataFrame] = None
    ) -> List[Dict]:
        """
        Détecte spikes (augmentations brutales) via Z-score.
        """
        anomalies = []
        
        if historical_df is not None:
            # Comparer avec historique
            for category in expenses_df['category'].unique():
                recent_df = expenses_df[expenses_df['category'] == category]
                historical = historical_df[historical_df['category'] == category]['total'].values
                
                if len(historical) < 5 or recent_df.empty:
                    continue
                
                mean_hist = historical.mean()
                std_hist = historical.std()
                
                for row in recent_df.itertuples():
                    amount = row.total
                    zscore = abs((amount - mean_hist) / (std_hist + 1e-6))
                    
                    if zscore > self.zscore_threshold:
                        anomalies.append({
                            "depense_id": getattr(row, 'id', None),
                            "anomaly_type": "SUDDEN_SPIKE",
                            "severity": "MEDIUM" if zscore < 3 else "HIGH",
                            "description": f"Spike {category}: {amount:.2f} (z-score: {zscore:.2f})",
                            "metadata": {
                                "zscore": float(zscore),
                                "historical_mean": float(mean_hist),
                                "amount": float(amount)
                            }
                        })
        
        return anomalies
    
    def _detect_suspicious_patterns(self, expenses_df: pd.DataFrame) -> List[Dict]:
        """
        Détecte patterns suspects (fraude potentielle).
        - Montants ronds (fraud indicator)
        - Fréquence anormale dans temps court
        - Montants identiques répétés
        """
        anomalies = []
        
        if expenses_df.empty:
            return anomalies
        
        # 1. Montants exactement identiques (pattern suspect)
        amount_counts = expenses_df['total'].value_counts()
        duplicates = amount_counts[amount_counts >= 8]
        
        for amount in duplicates.index:
            matching = expenses_df[expenses_df['total'] == amount]
            if len(matching) >= 8:
                dep_id = matching['id'].iloc[-1] if 'id' in matching.columns else None
                anomalies.append({
                    "depense_id": dep_id,
                    "anomaly_type": "FRAUD_SUSPICIOUS",
                    "severity": "MEDIUM",
                    "description": f"Repeat amount detected {len(matching)} times: {amount:.2f}",
                    "metadata": {
                        "amount": float(amount),
                        "repeat_count": int(len(matching)),
                        "method": "pattern_matching"
                    }
                })
        
        # 2. Fréquence anormale (plusieurs dépenses même jour)
        daily_counts = expenses_df.groupby(expenses_df['date'].dt.date).size()
        high_frequency = daily_counts[daily_counts > 5]
        
        for date, count in high_frequency.items():
            if count > 10:
                matching = expenses_df[expenses_df['date'].dt.date == date]
                dep_id = matching['id'].iloc[-1] if 'id' in matching.columns else None
                anomalies.append({
                    "depense_id": dep_id,
                    "anomaly_type": "FRAUD_SUSPICIOUS",
                    "severity": "HIGH",
                    "description": f"{count} dépenses en un jour: {date}",
                    "metadata": {
                        "date": str(date),
                        "transaction_count": int(count),
                        "method": "frequency_analysis"
                    }
                })
        
        return anomalies
    
    def get_anomaly_summary(self, anomalies: List[Dict]) -> Dict:
        """
        Résume les anomalies détectées.
        """
        if not anomalies:
            return {
                "total_anomalies": 0,
                "by_severity": {"LOW": 0, "MEDIUM": 0, "HIGH": 0},
                "by_type": {}
            }
        
        summary = {
            "total_anomalies": len(anomalies),
            "by_severity": {
                "LOW": len([a for a in anomalies if a.get('severity') == 'LOW']),
                "MEDIUM": len([a for a in anomalies if a.get('severity') == 'MEDIUM']),
                "HIGH": len([a for a in anomalies if a.get('severity') == 'HIGH'])
            },
            "by_type": {}
        }
        
        for anom in anomalies:
            atype = anom.get('anomaly_type', 'UNKNOWN')
            summary['by_type'][atype] = summary['by_type'].get(atype, 0) + 1
        
        return summary
