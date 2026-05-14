"""
XGBoost Forecaster
Prédit dépenses futures, solde, risque déficit et budgets recommandés
en utilisant Gradient Boosting avec données mensuelles/catégories.

Outputs:
- predicted_spending: Dépenses prévues mois suivant
- predicted_balance: Solde fin mois
- deficit_risk: Probabilité déficit (0-100%)
- recommended_budget: Budgets recommandés par catégorie
"""

import pandas as pd
import numpy as np
from xgboost import XGBRegressor, XGBClassifier
from sklearn.preprocessing import StandardScaler
from sklearn.model_selection import train_test_split
from typing import Dict, Tuple, Optional
import logging

logger = logging.getLogger(__name__)


class XGBoostForecaster:
    """
    Prédit dépenses futures et budgets recommandés via XGBoost.
    """
    
    def __init__(
        self,
        max_depth: int = 6,
        learning_rate: float = 0.1,
        n_estimators: int = 100,
        test_size: float = 0.2
    ):
        """
        Args:
            max_depth: Profondeur arbre
            learning_rate: Taux d'apprentissage
            n_estimators: Nombre arbres
            test_size: Proportion test/train
        """
        self.max_depth = max_depth
        self.learning_rate = learning_rate
        self.n_estimators = n_estimators
        self.test_size = test_size
        
        # Modèles
        self.spending_model = None
        self.balance_model = None
        self.deficit_model = None  # Classification
        self.historical_deficit_risk = 0.0
        
        self.scaler = StandardScaler()
        self.is_trained = False
    
    def train(
        self,
        expenses_df: pd.DataFrame,
        income_df: pd.DataFrame,
        budgets_df: Optional[pd.DataFrame] = None
    ) -> Dict[str, float]:
        """
        Entraîne modèles XGBoost.
        
        Returns:
            Métriques performance (MAE, RMSE, R2)
        """
        
        if len(expenses_df) < 3 or len(income_df) < 3:
            logger.warning("⚠️ Insufficient data for XGBoost training")
            self.is_trained = False
            return {}
        
        try:
            # 1. Préparer features
            X, y_spending, y_balance, y_deficit = self._prepare_features(
                expenses_df, income_df, budgets_df
            )
            
            if X.empty or len(X) < 3:
                logger.warning("Not enough monthly feature rows prepared")
                self.is_trained = False
                return {}
            self.historical_deficit_risk = float(y_deficit.mean() * 100)
            
            # 2. Split train/test
            X_train, X_test, y_spend_train, y_spend_test, \
            y_bal_train, y_bal_test, y_def_train, y_def_test = train_test_split(
                X, y_spending, y_balance, y_deficit,
                test_size=self.test_size,
                random_state=42
            )
            
            # 3. Entraîner modèles
            metrics = {}
            
            # Spending predictor
            self.spending_model = XGBRegressor(
                max_depth=self.max_depth,
                learning_rate=self.learning_rate,
                n_estimators=self.n_estimators
            )
            self.spending_model.fit(X_train, y_spend_train)
            metrics['spending_mae'] = self._mae(
                self.spending_model.predict(X_test), y_spend_test
            )
            
            # Balance predictor
            self.balance_model = XGBRegressor(
                max_depth=self.max_depth,
                learning_rate=self.learning_rate,
                n_estimators=self.n_estimators
            )
            self.balance_model.fit(X_train, y_bal_train)
            metrics['balance_mae'] = self._mae(
                self.balance_model.predict(X_test), y_bal_test
            )
            
            # Deficit classifier
            if len(y_deficit.unique()) > 1:
                self.deficit_model = XGBClassifier(
                    max_depth=self.max_depth,
                    learning_rate=self.learning_rate,
                    n_estimators=self.n_estimators,
                    use_label_encoder=False,
                    eval_metric='logloss'
                )
                self.deficit_model.fit(X_train, y_def_train)
                metrics['deficit_accuracy'] = self.deficit_model.score(X_test, y_def_test)
            
            self.is_trained = True
            logger.info(f"✅ XGBoost training complete - Metrics: {metrics}")
            return metrics
            
        except Exception as e:
            logger.error(f"❌ XGBoost training failed: {e}")
            return {}
    
    def forecast(
        self,
        expenses_df: pd.DataFrame,
        income_df: pd.DataFrame,
        budgets_df: Optional[pd.DataFrame] = None
    ) -> Dict:
        """
        Prédit dépenses, solde et budgets pour mois suivant.
        
        Returns:
            Dict avec predicted_spending, balance, deficit_risk, budgets recommandés
        """
        
        if not self.is_trained:
            logger.warning("⚠️ Model not trained yet")
            return self._default_forecast()
        
        try:
            # Préparer features pour dernière période
            X, _, _, _ = self._prepare_features(expenses_df, income_df, budgets_df)
            
            if X.empty:
                return self._default_forecast()
            
            # Prédictions
            predicted_spending = float(self.spending_model.predict(X.iloc[-1:].values)[0])
            predicted_balance = float(self.balance_model.predict(X.iloc[-1:].values)[0])
            
            deficit_prob = 0.0
            if self.deficit_model is not None:
                deficit_prob = float(
                    self.deficit_model.predict_proba(X.iloc[-1:].values)[0][1] * 100
                )
            else:
                deficit_prob = self.historical_deficit_risk
            
            # Budgets recommandés par catégorie
            recommended_budgets = self._recommend_budgets(expenses_df, predicted_spending)
            
            return {
                "predicted_spending": max(0, predicted_spending),
                "predicted_balance": predicted_balance,
                "deficit_risk": deficit_prob,
                "recommended_budget": recommended_budgets,
                "model_version": "v1.0",
                "forecast_date": pd.Timestamp.now().isoformat()
            }
            
        except Exception as e:
            logger.error(f"❌ Forecast failed: {e}")
            return self._default_forecast()
    
    def baseline_forecast(
        self,
        expenses_df: pd.DataFrame,
        income_df: pd.DataFrame,
    ) -> Dict:
        """
        Forecast simple pour utilisateurs avec peu de donnees.
        """
        if expenses_df.empty and income_df.empty:
            return self._default_forecast()

        try:
            expenses = expenses_df.copy()
            income = income_df.copy()
            predicted_spending = 0.0
            
            if not expenses.empty:
                expenses['date'] = pd.to_datetime(expenses['date'], errors='coerce')
                expenses['total'] = pd.to_numeric(expenses['total'], errors='coerce').fillna(0)
                expenses = expenses.dropna(subset=['date'])

                monthly_expenses = expenses.groupby(
                    expenses['date'].dt.to_period('M')
                )['total'].sum()
                recent_expenses = monthly_expenses.tail(3)
                predicted_spending = float(recent_expenses.mean()) if not recent_expenses.empty else 0.0

            predicted_income = 0.0
            if not income.empty:
                income['date'] = pd.to_datetime(income['date'], errors='coerce')
                income['amount'] = pd.to_numeric(income['amount'], errors='coerce').fillna(0)
                income = income.dropna(subset=['date'])
                monthly_income = income.groupby(income['date'].dt.to_period('M'))['amount'].sum()
                predicted_income = float(monthly_income.tail(3).mean()) if not monthly_income.empty else 0.0

            predicted_balance = predicted_income - predicted_spending
            
            if predicted_income <= 0 and predicted_spending <= 0:
                deficit_risk = 0.0
            elif predicted_income <= 0 and predicted_spending > 0:
                deficit_risk = 100.0
            elif predicted_balance < 0:
                deficit_risk = 80.0
            else:
                deficit_risk = 20.0

            return {
                "predicted_spending": max(0.0, predicted_spending),
                "predicted_balance": predicted_balance,
                "deficit_risk": deficit_risk,
                "recommended_budget": self._recommend_budgets(expenses, predicted_spending),
                "model_version": "baseline",
                "forecast_date": pd.Timestamp.now().isoformat()
            }
        except Exception as e:
            logger.error(f"Baseline forecast failed: {e}")
            return self._default_forecast()

    def _prepare_features(
        self,
        expenses_df: pd.DataFrame,
        income_df: pd.DataFrame,
        budgets_df: Optional[pd.DataFrame] = None
    ) -> Tuple[pd.DataFrame, pd.Series, pd.Series, pd.Series]:
        """
        Prépare features pour modèles XGBoost.
        
        Features:
        - Historique dépenses mensuelles (12 derniers mois)
        - Historique revenus mensuels
        - Jour du mois, mois, jour semaine
        - Ratio revenu/dépenses
        - Catégories principales
        """
        
        if expenses_df.empty or income_df.empty:
            return pd.DataFrame(), pd.Series(), pd.Series(), pd.Series()
        
        try:
            # 1. Agréger par mois
            expenses_df = expenses_df.copy()
            income_df = income_df.copy()
            
            expenses_df['date'] = pd.to_datetime(expenses_df['date'], errors='coerce')
            income_df['date'] = pd.to_datetime(income_df['date'], errors='coerce')
            expenses_df['total'] = pd.to_numeric(expenses_df['total'], errors='coerce').fillna(0)
            income_df['amount'] = pd.to_numeric(income_df['amount'], errors='coerce').fillna(0)
            expenses_df = expenses_df.dropna(subset=['date'])
            income_df = income_df.dropna(subset=['date'])
            if expenses_df.empty or income_df.empty:
                return pd.DataFrame(), pd.Series(), pd.Series(), pd.Series()
            
            expenses_monthly = expenses_df.groupby(expenses_df['date'].dt.to_period('M'))['total'].sum()
            income_monthly = income_df.groupby(income_df['date'].dt.to_period('M'))['amount'].sum()
            
            # 2. Aligner indices et combler les mois sans mouvement.
            all_months = pd.period_range(
                start=min(expenses_monthly.index.min(), income_monthly.index.min()),
                end=max(expenses_monthly.index.max(), income_monthly.index.max()),
                freq='M',
            )
            expenses_monthly = expenses_monthly.reindex(all_months, fill_value=0)
            income_monthly = income_monthly.reindex(all_months, fill_value=0)
            
            if len(expenses_monthly) < 3:
                return pd.DataFrame(), pd.Series(), pd.Series(), pd.Series()
            
            # 3. Créer features
            X_list = []
            y_spending = []
            y_balance = []
            y_deficit = []
            
            for i in range(len(expenses_monthly) - 1):
                # Features: dépenses passées 3 mois, revenu passé, tendances
                prev_expenses = expenses_monthly.iloc[max(0, i-3):i].values
                prev_income = income_monthly.iloc[max(0, i-3):i].values
                
                # Padding si < 3 mois
                while len(prev_expenses) < 3:
                    prev_expenses = np.insert(prev_expenses, 0, prev_expenses[0] if len(prev_expenses) > 0 else 0)
                while len(prev_income) < 3:
                    prev_income = np.insert(prev_income, 0, prev_income[0] if len(prev_income) > 0 else 0)
                
                features = {
                    'exp_m1': prev_expenses[-1] if len(prev_expenses) > 0 else 0,
                    'exp_m2': prev_expenses[-2] if len(prev_expenses) > 1 else 0,
                    'exp_m3': prev_expenses[-3] if len(prev_expenses) > 2 else 0,
                    'inc_m1': prev_income[-1] if len(prev_income) > 0 else 0,
                    'inc_m2': prev_income[-2] if len(prev_income) > 1 else 0,
                    'inc_m3': prev_income[-3] if len(prev_income) > 2 else 0,
                    'avg_expense': np.mean(prev_expenses) if len(prev_expenses) > 0 else 0,
                    'avg_income': np.mean(prev_income) if len(prev_income) > 0 else 0,
                }
                
                X_list.append(features)
                
                # Target: dépenses suivantes
                y_spending.append(expenses_monthly.iloc[i + 1])
                
                # Target: solde (revenu - dépenses)
                y_balance.append(income_monthly.iloc[i + 1] - expenses_monthly.iloc[i + 1])
                
                # Target: déficit (binary: 1 si déficit)
                y_deficit.append(1 if income_monthly.iloc[i + 1] < expenses_monthly.iloc[i + 1] else 0)
            
            X = pd.DataFrame(X_list)
            return X, pd.Series(y_spending), pd.Series(y_balance), pd.Series(y_deficit)
            
        except Exception as e:
            logger.error(f"Feature preparation error: {e}")
            return pd.DataFrame(), pd.Series(), pd.Series(), pd.Series()
    
    def _recommend_budgets(
        self,
        expenses_df: pd.DataFrame,
        total_budget: float
    ) -> Dict[str, float]:
        """
        Recommande budgets par catégorie basé sur historique.
        """
        default_distribution = {
            "Alimentation": 0.50,
            "Logement": 0.30,
            "Transport": 0.20
        }
        
        if expenses_df.empty or 'category' not in expenses_df.columns:
            return {cat: float(ratio * total_budget) for cat, ratio in default_distribution.items()}
        
        category_ratio = expenses_df.groupby('category')['total'].sum()
        if category_ratio.sum() <= 0:
            return {cat: float(ratio * total_budget) for cat, ratio in default_distribution.items()}
            
        category_ratio = category_ratio / category_ratio.sum()
        
        return {
            cat: float(ratio * total_budget)
            for cat, ratio in category_ratio.items()
        }
        
        category_ratio = expenses_df.groupby('category')['total'].sum()
        if category_ratio.sum() <= 0:
            return {}
        category_ratio = category_ratio / category_ratio.sum()
        
        return {
            cat: float(ratio * total_budget)
            for cat, ratio in category_ratio.items()
        }
    
    def _mae(self, y_true, y_pred) -> float:
        return np.mean(np.abs(y_true - y_pred))
    
    def _default_forecast(self) -> Dict:
        """
        Retourne forecast par défaut si modèle non disponible.
        """
        default_distribution = {
            "Alimentation": 0.0,
            "Logement": 0.0,
            "Transport": 0.0
        }
        return {
            "predicted_spending": 0.0,
            "predicted_balance": 0.0,
            "deficit_risk": 0.0,
            "recommended_budget": default_distribution,
            "model_version": "baseline",
            "forecast_date": pd.Timestamp.now().isoformat()
        },
            "model_version": "baseline",
            "forecast_date": pd.Timestamp.now().isoformat()
        }
