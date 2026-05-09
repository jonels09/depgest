"""
Score Financier Intelligent
Calcule 4 métriques composantes + 1 score global pour évaluer la santé financière utilisateur.

Métriques:
- Discipline Score (0-100): Régularité épargne, respect budgets, stabilité mensuelle
- Stability Score (0-100): Variance dépenses, ratio revenu/dépense stable
- Savings Score (0-100): % épargnes, progression goals, contributions
- Risk Score (0-100): Surspend rate, déficits mensuels, volatilité

Overall Score = 30% Discipline + 30% Stability + 25% Savings + 15% Risk (inversé)
"""

import pandas as pd
import numpy as np
from datetime import datetime, timedelta
from typing import Dict, Tuple, Optional
import logging

logger = logging.getLogger(__name__)


class ScoreCalculator:
    """
    Calcule scores financiers intelligents basés sur données utilisateur.
    """
    
    def __init__(self):
        self.min_history_days = 30  # Minimum 1 mois de données
    
    # ==================== PUBLIC METHODS ====================
    
    def calculate_all_scores(
        self,
        expenses_df: pd.DataFrame,
        income_df: pd.DataFrame,
        budgets_df: Optional[pd.DataFrame] = None,
        savings_goals_df: Optional[pd.DataFrame] = None,
        window_months: int = 3
    ) -> Dict[str, float]:
        """
        Calcule tous les scores pour une période donnée.
        
        Args:
            expenses_df: DataFrame dépenses (colonnes: date, total, category)
            income_df: DataFrame revenus (colonnes: date, amount)
            budgets_df: DataFrame budgets (colonnes: category, amount, month)
            savings_goals_df: DataFrame objectifs épargne
            window_months: Période d'analyse (3, 6, ou 12 mois)
        
        Returns:
            Dict avec scores: discipline, stability, savings, risk, overall, insights
        """
        
        # Valider données
        if expenses_df.empty or income_df.empty:
            logger.warning("⚠️ Insufficient data for score calculation")
            return self._default_scores("Données insuffisantes pour calculer")
        
        expenses_df = expenses_df.copy()
        income_df = income_df.copy()
        expenses_df['date'] = pd.to_datetime(expenses_df['date'], errors='coerce')
        income_df['date'] = pd.to_datetime(income_df['date'], errors='coerce')
        expenses_df = expenses_df.dropna(subset=['date'])
        income_df = income_df.dropna(subset=['date'])

        if expenses_df.empty or income_df.empty:
            logger.warning("⚠️ No valid dated records for score calculation")
            return self._default_scores("Données datées insuffisantes")

        # Filtrer par fenêtre temporelle en partant de la dernière donnée connue.
        end_date = max(expenses_df['date'].max(), income_df['date'].max())
        start_date = end_date - pd.DateOffset(months=window_months)
        
        expenses_period = expenses_df[
            (expenses_df['date'] >= start_date) & (expenses_df['date'] <= end_date)
        ].copy()
        
        income_period = income_df[
            (income_df['date'] >= start_date) & (income_df['date'] <= end_date)
        ].copy()
        
        # Calculs intermédiaires
        monthly_expenses = self._get_monthly_aggregates(expenses_period, 'total')
        monthly_income = self._get_monthly_aggregates(income_period, 'amount')
        
        # Calculer chaque score
        discipline_score = self._calculate_discipline_score(
            expenses_period, 
            monthly_expenses, 
            budgets_df
        )
        
        stability_score = self._calculate_stability_score(
            monthly_expenses, 
            monthly_income
        )
        
        savings_score = self._calculate_savings_score(
            monthly_income, 
            monthly_expenses,
            savings_goals_df
        )
        
        risk_score = self._calculate_risk_score(
            monthly_expenses, 
            monthly_income
        )
        
        # Score global (pondéré)
        overall_score = (
            0.30 * discipline_score +
            0.30 * stability_score +
            0.25 * savings_score +
            0.15 * (100 - risk_score)  # Risk inversé (moins = mieux)
        )
        
        # Générer insights
        insights = self._generate_insights(
            discipline_score,
            stability_score,
            savings_score,
            risk_score,
            overall_score,
            monthly_expenses,
            monthly_income
        )
        
        logger.info(f"✅ Calculated scores - Overall: {overall_score:.1f}")
        
        return {
            "discipline_score": round(discipline_score, 2),
            "stability_score": round(stability_score, 2),
            "savings_score": round(savings_score, 2),
            "risk_score": round(risk_score, 2),
            "overall_score": round(overall_score, 2),
            "insights": insights,
            "window_months": window_months,
            "calculated_at": datetime.utcnow().isoformat()
        }
    
    # ==================== SCORE COMPONENTS ====================
    
    def _calculate_discipline_score(
        self,
        expenses_df: pd.DataFrame,
        monthly_expenses: pd.DataFrame,
        budgets_df: Optional[pd.DataFrame] = None
    ) -> float:
        """
        Discipline Score (0-100):
        - Régularité épargne (contributions régulières vs sporadiques)
        - Respect des budgets mensuels
        - Stabilité (faible variance mois à mois)
        
        Formule:
        - Régularité: 30 points (days_with_expenses / total_days)
        - Budget respect: 40 points (months_under_budget / total_months ou baseline si pas budgets)
        - Stabilité mensuelle: 30 points (basé sur coefficient variation)
        """
        
        if len(monthly_expenses) == 0:
            return 0.0
        
        total_days = max(
            1,
            (monthly_expenses['date'].max() - monthly_expenses['date'].min()).days,
        )
        if total_days < self.min_history_days:
            return 50.0  # Baseline pour peu de données
        
        # 1. Régularité: % jours avec dépenses
        days_with_expenses = expenses_df['date'].dt.normalize().nunique()
        regularity_score = min(100, (days_with_expenses / total_days) * 100 * 0.5 + 50)
        regularity_points = (regularity_score / 100) * 30
        
        # 2. Respect budgets (40 points)
        budget_points = 40
        if budgets_df is not None and not budgets_df.empty:
            # Vérifier % mois où dépenses < budget
            budget_respect_rate = 0.5  # Default 50%
            budget_points = (budget_respect_rate * 40)
        
        # 3. Stabilité mensuelle (30 points)
        # Coefficient variation: < 0.3 = stable, > 0.8 = volatile
        cv = self._coefficient_variation(monthly_expenses['total'])
        stability_points = max(0, 30 - (cv * 30))  # Moins volatile = plus de points
        
        score = regularity_points + budget_points + stability_points
        return min(100, max(0, score))
    
    def _calculate_stability_score(
        self,
        monthly_expenses: pd.DataFrame,
        monthly_income: pd.DataFrame
    ) -> float:
        """
        Stability Score (0-100):
        - Variance des dépenses (faible variance = stable)
        - Ratio revenu/dépense stable (balance prévisible)
        - Couverture (revenu >= dépenses)
        
        Formule:
        - Variance: 40 points (coefficient variation)
        - Ratio stable: 30 points (variance du ratio)
        - Couverture: 30 points (% mois où revenu >= dépenses)
        """
        
        if len(monthly_expenses) == 0 or len(monthly_income) == 0:
            return 50.0
        
        # 1. Variance dépenses (40 points)
        aligned = self._align_monthly(monthly_expenses, monthly_income)
        if aligned.empty:
            return 50.0

        cv_expenses = self._coefficient_variation(aligned['total'])
        # Normaliser CV: 0.2 = 40 points, 1.0+ = 0 points
        variance_points = max(0, 40 - (cv_expenses * 40))
        
        # 2. Ratio revenu/dépenses stable (30 points)
        # Aligner les DataFrames mensuels
        monthly_ratio = (aligned['amount'] / (aligned['total'] + 1e-6)).dropna()
        if len(monthly_ratio) > 1:
            cv_ratio = self._coefficient_variation(monthly_ratio)
            ratio_points = max(0, 30 - (cv_ratio * 30))
        else:
            ratio_points = 15  # Default si < 2 mois
        
        # 3. Couverture (revenu >= dépenses) (30 points)
        months_covered = (aligned['amount'] >= aligned['total']).sum()
        coverage_rate = months_covered / len(aligned)
        coverage_points = coverage_rate * 30
        
        score = variance_points + ratio_points + coverage_points
        return min(100, max(0, score))
    
    def _calculate_savings_score(
        self,
        monthly_income: pd.DataFrame,
        monthly_expenses: pd.DataFrame,
        savings_goals_df: Optional[pd.DataFrame] = None
    ) -> float:
        """
        Savings Score (0-100):
        - % épargnes mensuelles (revenu - dépenses) / revenu
        - Progression objectifs épargne
        - Fréquence contributions
        
        Formule:
        - Taux épargne: 50 points (0% = 0, 30%+ = 50)
        - Progression goals: 30 points (si données)
        - Contributions: 20 points (régularité)
        """
        
        if len(monthly_income) == 0 or len(monthly_expenses) == 0:
            return 50.0
        
        # 1. Taux épargne (50 points)
        # Aligner par date
        aligned = self._align_monthly(monthly_expenses, monthly_income)
        if aligned.empty:
            return 50.0

        savings = aligned['amount'] - aligned['total']
        savings_rate = (savings / (aligned['amount'] + 1e-6)).mean()
        savings_rate = max(0, min(1, savings_rate))  # Clamp 0-1
        savings_points = min(1, savings_rate / 0.30) * 50
        
        # 2. Progression objectifs (30 points)
        goals_points = 15  # Default 50% des points si pas de goals
        if savings_goals_df is not None and not savings_goals_df.empty:
            # Vérifier % progression vers objectifs
            goal_completion_rate = 0.5  # À calculer depuis données
            goals_points = goal_completion_rate * 30
        
        # 3. Contributions régulières (20 points)
        # % mois avec épargnes positives
        positive_savings_rate = (savings > 0).sum() / max(1, len(savings))
        contribution_points = positive_savings_rate * 20
        
        score = savings_points + goals_points + contribution_points
        return min(100, max(0, score))
    
    def _calculate_risk_score(
        self,
        monthly_expenses: pd.DataFrame,
        monthly_income: pd.DataFrame
    ) -> float:
        """
        Risk Score (0-100, inversé):
        - Surspend rate (% mois où dépenses > revenus)
        - Volatilité dépenses (instabilité = risque)
        - Déficits mensuels accumulés
        
        Note: Score élevé = risque élevé (mauvais)
        
        Formule:
        - Surspend: 50 points (% mois deficit * 50)
        - Volatilité: 30 points (CV * 30)
        - Déficit depth: 20 points (montant moyen déficit * 0.01)
        """
        
        if len(monthly_income) == 0 or len(monthly_expenses) == 0:
            return 50.0
        
        # 1. Surspend rate (50 points)
        aligned = self._align_monthly(monthly_expenses, monthly_income)
        if aligned.empty:
            return 50.0

        monthly_balance = aligned['amount'].values - aligned['total'].values
        deficit_months = (monthly_balance < 0).sum()
        surspend_rate = deficit_months / len(monthly_balance)
        surspend_points = surspend_rate * 70
        
        # 2. Volatilité dépenses (30 points)
        cv = self._coefficient_variation(aligned['total'])
        volatility_points = min(20, cv * 20)
        
        # 3. Déficit depth (20 points)
        deficit_amounts = np.maximum(0, -monthly_balance)
        avg_deficit_rate = deficit_amounts.mean() / (aligned['total'].mean() + 1e-6)
        deficit_points = min(10, avg_deficit_rate * 10)
        
        score = surspend_points + volatility_points + deficit_points
        return min(100, max(0, score))
    
    # ==================== INSIGHTS GENERATION ====================
    
    def _generate_insights(
        self,
        discipline: float,
        stability: float,
        savings: float,
        risk: float,
        overall: float,
        monthly_expenses: pd.DataFrame,
        monthly_income: pd.DataFrame
    ) -> Dict[str, str]:
        """
        Génère des insights textuels basés sur les scores.
        """
        
        insights = {
            "overall": self._get_overall_insight(overall),
            "discipline": self._get_component_insight("Discipline", discipline),
            "stability": self._get_component_insight("Stabilité", stability),
            "savings": self._get_component_insight("Épargne", savings),
            "risk": self._get_component_insight("Risque", risk)
        }
        
        # Ajouter recommendations
        insights["recommendations"] = self._get_recommendations(
            discipline, stability, savings, risk,
            monthly_expenses, monthly_income
        )
        
        return insights
    
    def _get_overall_insight(self, score: float) -> str:
        if score >= 80:
            return "🟢 Excellent santé financière! Continuez à maintenir vos bonnes habitudes."
        elif score >= 65:
            return "🟡 Bonne gestion financière. Petites améliorations possibles."
        elif score >= 50:
            return "🟠 Santé financière modérée. Focalisez-vous sur amélioration régulière."
        elif score >= 35:
            return "🔴 Attention requise! Votre situation nécessite ajustements significatifs."
        else:
            return "🔴🔴 Situation critique. Demandez l'aide d'un conseiller financier."
    
    def _get_component_insight(self, component: str, score: float) -> str:
        if score >= 80:
            return f"{component}: Excellent (Continuez!)"
        elif score >= 65:
            return f"{component}: Bon (Poursuivez les efforts)"
        elif score >= 50:
            return f"{component}: Acceptable (Amélioration possible)"
        elif score >= 35:
            return f"{component}: Faible (À améliorer)"
        else:
            return f"{component}: Critique (Action urgente)"
    
    def _get_recommendations(
        self,
        discipline: float,
        stability: float,
        savings: float,
        risk: float,
        monthly_expenses: pd.DataFrame,
        monthly_income: pd.DataFrame
    ) -> list:
        """
        Retourne liste de recommendations basées sur scores.
        """
        recommendations = []
        
        if discipline < 60:
            recommendations.append(
                "📋 Définissez budgets mensuels par catégorie pour améliorer discipline"
            )
        
        if stability < 60:
            recommendations.append(
                "📊 Essayez de lisser vos dépenses mensuelles pour plus de stabilité"
            )
        
        if savings < 50:
            recommendations.append(
                "💰 Visez 10-15% d'épargnes chaque mois pour une meilleure sécurité"
            )
        
        if risk > 60:
            recommendations.append(
                "⚠️ Réduisez vos dépenses ou augmentez vos revenus pour diminuer risque"
            )
        
        if not recommendations:
            recommendations.append("✅ Vous êtes sur la bonne voie! Maintenez votre discipline.")
        
        return recommendations
    
    # ==================== UTILITY METHODS ====================
    
    def _get_monthly_aggregates(self, df: pd.DataFrame, amount_col: str) -> pd.DataFrame:
        """
        Agrège données par mois.
        """
        if df.empty or amount_col not in df.columns:
            return pd.DataFrame(columns=['date', amount_col])

        df_copy = df.copy()
        df_copy['date'] = pd.to_datetime(df_copy['date'], errors='coerce')
        df_copy[amount_col] = pd.to_numeric(df_copy[amount_col], errors='coerce').fillna(0)
        df_copy = df_copy.dropna(subset=['date'])
        if df_copy.empty:
            return pd.DataFrame(columns=['date', amount_col])

        df_copy['month'] = df_copy['date'].dt.to_period('M')
        return df_copy.groupby('month')[amount_col].sum().reset_index()\
            .rename(columns={'month': 'date'})\
            .assign(date=lambda x: x['date'].dt.to_timestamp())

    def _align_monthly(
        self,
        monthly_expenses: pd.DataFrame,
        monthly_income: pd.DataFrame,
    ) -> pd.DataFrame:
        if monthly_expenses.empty or monthly_income.empty:
            return pd.DataFrame(columns=['date', 'total', 'amount'])

        expenses = monthly_expenses[['date', 'total']].copy()
        income = monthly_income[['date', 'amount']].copy()
        expenses['date'] = pd.to_datetime(expenses['date']).dt.to_period('M').dt.to_timestamp()
        income['date'] = pd.to_datetime(income['date']).dt.to_period('M').dt.to_timestamp()
        aligned = expenses.merge(income, on='date', how='inner')
        aligned['total'] = pd.to_numeric(aligned['total'], errors='coerce').fillna(0)
        aligned['amount'] = pd.to_numeric(aligned['amount'], errors='coerce').fillna(0)
        return aligned.sort_values('date')

    def _coefficient_variation(self, values: pd.Series) -> float:
        numeric = pd.to_numeric(values, errors='coerce').dropna()
        if numeric.empty:
            return 0.0
        mean = float(numeric.mean())
        if abs(mean) < 1e-6:
            return 0.0
        std = float(numeric.std(ddof=0))
        if np.isnan(std):
            return 0.0
        return abs(std / mean)
    
    def _default_scores(self, reason: str) -> Dict[str, float]:
        """
        Retourne scores par défaut quand données insuffisantes.
        """
        return {
            "discipline_score": 50.0,
            "stability_score": 50.0,
            "savings_score": 50.0,
            "risk_score": 50.0,
            "overall_score": 50.0,
            "insights": {
                "overall": reason,
                "discipline": "Données insuffisantes",
                "stability": "Données insuffisantes",
                "savings": "Données insuffisantes",
                "risk": "Données insuffisantes",
                "recommendations": ["Ajoutez plus de données historiques pour calculs précis"]
            },
            "window_months": 0,
            "calculated_at": datetime.utcnow().isoformat()
        }
