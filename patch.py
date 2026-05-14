import sys
import re

path = r'c:\Users\ACER\Documents\flutter project\depgest\backend_python\models\xgboost_forecaster.py'
with open(path, 'r', encoding='utf-8') as f:
    content = f.read()

new_recommend = """    def _recommend_budgets(
        self,
        expenses_df: pd.DataFrame,
        total_budget: float
    ) -> Dict[str, float]:
        \"\"\"
        Recommande budgets par catégorie basé sur historique.
        \"\"\"
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
        }"""

content = re.sub(r'    def _recommend_budgets\([^)]*\)\s*->\s*Dict\[str,\s*float\]:.*?return\s*\{[^}]*\}', new_recommend, content, flags=re.DOTALL)

new_default = """    def _default_forecast(self) -> Dict:
        \"\"\"
        Retourne forecast par défaut si modèle non disponible.
        \"\"\"
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
        }"""

content = re.sub(r'    def _default_forecast\(self\)\s*->\s*Dict:.*?return\s*\{[^}]*\}', new_default, content, flags=re.DOTALL)

with open(path, 'w', encoding='utf-8') as f:
    f.write(content)
print('Patched successfully')
