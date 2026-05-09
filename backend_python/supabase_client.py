"""
Client Supabase pour le backend predictif DepGest.

Le schema applicatif utilise des noms de colonnes francais
(`montant`, `date_depense`, `quantite`, etc.). Ce module les normalise vers le
contrat attendu par les modeles Python: `date`, `total`, `amount`, `category`.
"""

from datetime import datetime, timezone
from typing import Any, Dict, List, Optional, Tuple
import logging

import pandas as pd
from supabase import Client, create_client

from config import settings

logger = logging.getLogger(__name__)


class SupabaseClient:
    """
    Acces aux donnees financieres et stockage des resultats predictifs.
    """

    def __init__(self):
        self.client: Client = create_client(settings.SUPABASE_URL, settings.SUPABASE_KEY)
        logger.info("Supabase client initialized")

    async def get_user_expenses(
        self,
        user_id: str,
        start_date: Optional[datetime] = None,
        end_date: Optional[datetime] = None,
    ) -> pd.DataFrame:
        try:
            query = (
                self.client.table("depenses")
                .select("*, articles(nom, categories(nom)), unites(nom)")
                .eq("user_id", user_id)
            )
            query = self._not_deleted(query)
            query = self._apply_date_range(query, "date_depense", start_date, end_date)
            response = query.execute()
            return self._expenses_dataframe(response.data or [])
        except Exception as error:
            logger.error(f"Error fetching expenses: {error}")
            return self._empty_expenses()

    async def get_user_income(
        self,
        user_id: str,
        start_date: Optional[datetime] = None,
        end_date: Optional[datetime] = None,
    ) -> pd.DataFrame:
        try:
            query = self.client.table("revenus").select("*").eq("user_id", user_id)
            query = self._not_deleted(query)
            query = self._apply_date_range(query, "date_revenu", start_date, end_date)
            response = query.execute()
            return self._income_dataframe(response.data or [])
        except Exception as error:
            logger.error(f"Error fetching income: {error}")
            return self._empty_income()

    async def get_user_budgets(self, user_id: str) -> pd.DataFrame:
        try:
            response = (
                self.client.table("budgets")
                .select("*, categories(nom)")
                .eq("user_id", user_id)
                .execute()
            )
            return self._budgets_dataframe(response.data or [])
        except Exception as error:
            logger.error(f"Error fetching budgets: {error}")
            return pd.DataFrame(columns=["category", "amount", "month"])

    async def get_user_savings_goals(self, user_id: str) -> pd.DataFrame:
        try:
            response = (
                self.client.table("saving_goals")
                .select("*")
                .eq("user_id", user_id)
                .execute()
            )
            df = pd.DataFrame(response.data or [])
            if df.empty:
                return pd.DataFrame(
                    columns=["goal_name", "target_amount", "current_amount", "deadline"]
                )
            return pd.DataFrame(
                {
                    "goal_name": df.get("nom", ""),
                    "target_amount": pd.to_numeric(df.get("target_amount", 0), errors="coerce").fillna(0),
                    "current_amount": pd.to_numeric(df.get("current_amount", 0), errors="coerce").fillna(0),
                    "deadline": df.get("due_date"),
                }
            )
        except Exception as error:
            logger.error(f"Error fetching savings goals: {error}")
            return pd.DataFrame(
                columns=["goal_name", "target_amount", "current_amount", "deadline"]
            )

    async def save_financial_scores(
        self,
        user_id: str,
        month: datetime,
        discipline_score: float,
        stability_score: float,
        savings_score: float,
        risk_score: float,
        overall_score: float,
        insights: Dict[str, Any],
    ) -> bool:
        try:
            data = {
                "user_id": user_id,
                "month": self._month_start_iso(month),
                "discipline_score": self._bounded_score(discipline_score),
                "stability_score": self._bounded_score(stability_score),
                "savings_score": self._bounded_score(savings_score),
                "risk_score": self._bounded_score(risk_score),
                "overall_score": self._bounded_score(overall_score),
                "insights": self._jsonable(insights),
                "updated_at": self._now_iso(),
            }
            self.client.table("financial_scores").upsert(
                data,
                on_conflict="user_id,month",
            ).execute()
            return True
        except Exception as error:
            logger.error(f"Error saving financial scores: {error}")
            return False

    async def save_predictions(
        self,
        user_id: str,
        month: datetime,
        predicted_spending: float,
        predicted_balance: float,
        deficit_risk: float,
        recommended_budget: Dict[str, float],
        model_version: str = "v1.0",
    ) -> bool:
        try:
            data = {
                "user_id": user_id,
                "month": self._month_start_iso(month),
                "predicted_spending": max(0.0, float(predicted_spending or 0)),
                "predicted_balance": float(predicted_balance or 0),
                "deficit_risk": max(0.0, min(100.0, float(deficit_risk or 0))),
                "recommended_budget": self._jsonable(recommended_budget or {}),
                "model_version": model_version,
                "updated_at": self._now_iso(),
            }
            self.client.table("predictions").upsert(
                data,
                on_conflict="user_id,month",
            ).execute()
            return True
        except Exception as error:
            logger.error(f"Error saving predictions: {error}")
            return False

    async def save_anomaly(
        self,
        user_id: str,
        depense_id: Optional[str],
        anomaly_type: str,
        severity: str,
        description: str,
        metadata: Optional[Dict[str, Any]] = None,
    ) -> bool:
        try:
            normalized_depense_id = depense_id if depense_id not in (None, "", "unknown") else None
            data = {
                "user_id": user_id,
                "depense_id": normalized_depense_id,
                "anomaly_type": anomaly_type,
                "severity": severity if severity in {"LOW", "MEDIUM", "HIGH"} else "LOW",
                "description": description,
                "metadata": self._jsonable(metadata or {}),
                "detected_at": self._now_iso(),
                "is_confirmed": False,
            }
            self.client.table("anomalies").insert(data).execute()
            return True
        except Exception as error:
            logger.error(f"Error saving anomaly: {error}")
            return False

    async def save_model_metadata(
        self,
        model_type: str,
        last_trained: datetime,
        training_count: int,
        data_points_used: int,
        metrics: Dict[str, float],
        model_version: str = "v1.0",
    ) -> bool:
        try:
            data = {
                "model_type": model_type,
                "last_trained": last_trained.isoformat(),
                "training_count": int(training_count),
                "data_points_used": int(data_points_used),
                "metrics": self._jsonable(metrics or {}),
                "model_version": model_version,
                "updated_at": self._now_iso(),
            }
            self.client.table("model_metadata").upsert(
                data,
                on_conflict="model_type",
            ).execute()
            return True
        except Exception as error:
            logger.error(f"Error saving model metadata: {error}")
            return False

    async def get_user_data_range(
        self,
        user_id: str,
    ) -> Tuple[Optional[datetime], Optional[datetime]]:
        try:
            response = (
                self.client.table("depenses")
                .select("date_depense")
                .eq("user_id", user_id)
                .order("date_depense", desc=False)
                .execute()
            )
            dates = [
                pd.to_datetime(row["date_depense"]).to_pydatetime()
                for row in response.data or []
                if row.get("date_depense")
            ]
            return (min(dates), max(dates)) if dates else (None, None)
        except Exception as error:
            logger.error(f"Error getting user data range: {error}")
            return None, None

    async def get_all_user_ids(self) -> List[str]:
        try:
            response = self.client.table("depenses").select("user_id").execute()
            return list({row["user_id"] for row in response.data or [] if row.get("user_id")})
        except Exception as error:
            logger.error(f"Error retrieving user ids: {error}")
            return []

    async def health_check(self) -> bool:
        try:
            self.client.table("depenses").select("id", count="exact").limit(1).execute()
            return True
        except Exception as error:
            logger.error(f"Supabase health check failed: {error}")
            return False

    def _expenses_dataframe(self, records: List[Dict[str, Any]]) -> pd.DataFrame:
        if not records:
            return self._empty_expenses()

        rows = []
        for record in records:
            article = record.get("articles") if isinstance(record.get("articles"), dict) else {}
            category_obj = article.get("categories") if isinstance(article.get("categories"), dict) else {}
            unit = record.get("unites") if isinstance(record.get("unites"), dict) else {}
            article_name = article.get("nom") or record.get("article") or record.get("article_id")
            category_name = (
                category_obj.get("nom")
                or record.get("category")
                or record.get("categorie")
                or record.get("categorie_nom")
                or "Non categorise"
            )
            rows.append(
                {
                    "id": record.get("id"),
                    "date": record.get("date_depense") or record.get("created_at"),
                    "total": record.get("total", 0),
                    "category": category_name,
                    "article": article_name or "",
                    "description": article_name or "",
                    "quantity": record.get("quantite", record.get("quantity", 1)),
                    "unit_price": record.get("prix_unitaire", record.get("unit_price", 0)),
                    "unit": unit.get("nom", ""),
                }
            )

        df = pd.DataFrame(rows)
        df["date"] = pd.to_datetime(df["date"], errors="coerce")
        df["total"] = pd.to_numeric(df["total"], errors="coerce").fillna(0)
        df["quantity"] = pd.to_numeric(df["quantity"], errors="coerce").fillna(0)
        df["unit_price"] = pd.to_numeric(df["unit_price"], errors="coerce").fillna(0)
        df = df.dropna(subset=["date"]).sort_values("date")
        return df if not df.empty else self._empty_expenses()

    def _income_dataframe(self, records: List[Dict[str, Any]]) -> pd.DataFrame:
        if not records:
            return self._empty_income()

        rows = [
            {
                "id": record.get("id"),
                "date": record.get("date_revenu") or record.get("created_at"),
                "amount": record.get("montant", record.get("amount", 0)),
                "source": record.get("source", ""),
                "description": record.get("source", ""),
            }
            for record in records
        ]
        df = pd.DataFrame(rows)
        df["date"] = pd.to_datetime(df["date"], errors="coerce")
        df["amount"] = pd.to_numeric(df["amount"], errors="coerce").fillna(0)
        df = df.dropna(subset=["date"]).sort_values("date")
        return df if not df.empty else self._empty_income()

    def _budgets_dataframe(self, records: List[Dict[str, Any]]) -> pd.DataFrame:
        if not records:
            return pd.DataFrame(columns=["category", "amount", "month"])

        rows = []
        for record in records:
            category = record.get("categories") if isinstance(record.get("categories"), dict) else {}
            rows.append(
                {
                    "category": category.get("nom") or record.get("categorie_id") or "Global",
                    "amount": record.get("montant", record.get("amount", 0)),
                    "month": record.get("mois") or record.get("created_at"),
                }
            )
        df = pd.DataFrame(rows)
        df["amount"] = pd.to_numeric(df["amount"], errors="coerce").fillna(0)
        return df

    def _empty_expenses(self) -> pd.DataFrame:
        return pd.DataFrame(
            columns=[
                "id",
                "date",
                "total",
                "category",
                "article",
                "description",
                "quantity",
                "unit_price",
                "unit",
            ]
        )

    def _empty_income(self) -> pd.DataFrame:
        return pd.DataFrame(columns=["id", "date", "amount", "source", "description"])

    def _not_deleted(self, query):
        try:
            return query.is_("deleted_at", "null")
        except AttributeError:
            return query.filter("deleted_at", "is", "null")

    def _apply_date_range(
        self,
        query,
        column: str,
        start_date: Optional[datetime],
        end_date: Optional[datetime],
    ):
        if start_date:
            query = query.gte(column, start_date.date().isoformat())
        if end_date:
            query = query.lte(column, end_date.date().isoformat())
        return query

    def _month_start_iso(self, value: datetime) -> str:
        timestamp = pd.Timestamp(value)
        if timestamp.tzinfo is None:
            timestamp = timestamp.tz_localize(timezone.utc)
        else:
            timestamp = timestamp.tz_convert(timezone.utc)
        return datetime(timestamp.year, timestamp.month, 1, tzinfo=timezone.utc).isoformat()

    def _now_iso(self) -> str:
        return datetime.now(timezone.utc).isoformat()

    def _bounded_score(self, value: float) -> float:
        return max(0.0, min(100.0, float(value or 0)))

    def _jsonable(self, value: Any) -> Any:
        if isinstance(value, dict):
            return {str(key): self._jsonable(val) for key, val in value.items()}
        if isinstance(value, list):
            return [self._jsonable(item) for item in value]
        if hasattr(value, "item"):
            return value.item()
        if isinstance(value, (pd.Timestamp, datetime)):
            return value.isoformat()
        return value


_supabase_client: Optional[SupabaseClient] = None


def get_supabase_client() -> SupabaseClient:
    global _supabase_client
    if _supabase_client is None:
        _supabase_client = SupabaseClient()
    return _supabase_client
