-- Migration SQL pour DepGest Predictive Analytics
-- À exécuter dans Supabase SQL Editor
-- Crée les tables pour stocker les prédictions, anomalies, scores et métadonnées

-- ==================== TABLE: financial_scores ====================
-- Stocke les scores financiers calculés mensuels
CREATE TABLE IF NOT EXISTS financial_scores (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    month TIMESTAMP WITH TIME ZONE NOT NULL,
    
    -- Scores composants (0-100)
    discipline_score DECIMAL(5, 2) NOT NULL CHECK (discipline_score >= 0 AND discipline_score <= 100),
    stability_score DECIMAL(5, 2) NOT NULL CHECK (stability_score >= 0 AND stability_score <= 100),
    savings_score DECIMAL(5, 2) NOT NULL CHECK (savings_score >= 0 AND savings_score <= 100),
    risk_score DECIMAL(5, 2) NOT NULL CHECK (risk_score >= 0 AND risk_score <= 100),
    
    -- Score global (moyenne pondérée)
    overall_score DECIMAL(5, 2) NOT NULL CHECK (overall_score >= 0 AND overall_score <= 100),
    
    -- Insights en JSON (ex: {"stability": "Vos dépenses sont stables...", ...})
    insights JSONB,
    
    -- Métadonnées
    created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT now(),
    updated_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT now(),
    
    CONSTRAINT unique_user_month UNIQUE (user_id, month)
);

CREATE INDEX IF NOT EXISTS idx_financial_scores_user_month ON financial_scores(user_id, month DESC);


-- ==================== TABLE: predictions ====================
-- Stocke les prédictions XGBoost pour dépenses futures
CREATE TABLE IF NOT EXISTS predictions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    month TIMESTAMP WITH TIME ZONE NOT NULL,
    
    -- Prédictions principales
    predicted_spending DECIMAL(12, 2) NOT NULL CHECK (predicted_spending >= 0),
    predicted_balance DECIMAL(12, 2),
    deficit_risk DECIMAL(5, 2) NOT NULL DEFAULT 0 CHECK (deficit_risk >= 0 AND deficit_risk <= 100),
    
    -- Budgets recommandés par catégorie (JSON)
    -- Ex: {"Alimentation": 450.50, "Transport": 120, ...}
    recommended_budget JSONB,
    
    -- Version du modèle
    model_version VARCHAR(20) DEFAULT 'v1.0',
    
    -- Métadonnées
    created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT now(),
    updated_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT now(),
    
    CONSTRAINT unique_user_prediction_month UNIQUE (user_id, month)
);

CREATE INDEX IF NOT EXISTS idx_predictions_user_month ON predictions(user_id, month DESC);


-- ==================== TABLE: anomalies ====================
-- Stocke les anomalies détectées dans les dépenses
CREATE TABLE IF NOT EXISTS anomalies (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    depense_id UUID REFERENCES depenses(id) ON DELETE SET NULL,
    
    -- Classification anomalie
    anomaly_type VARCHAR(50) NOT NULL,
    -- LOW, MEDIUM, HIGH
    severity VARCHAR(10) NOT NULL CHECK (severity IN ('LOW', 'MEDIUM', 'HIGH')),
    
    -- Description humaine
    description TEXT NOT NULL,
    
    -- Métadonnées additionnelles (ex: z_score, isolation_forest_score, etc.)
    metadata JSONB,
    
    -- Suivi
    is_confirmed BOOLEAN DEFAULT FALSE,
    confirmed_at TIMESTAMP WITH TIME ZONE,
    is_false_positive BOOLEAN DEFAULT FALSE,
    
    -- Timestamps
    detected_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT now(),
    created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT now(),
    updated_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_anomalies_user ON anomalies(user_id, detected_at DESC);
CREATE INDEX IF NOT EXISTS idx_anomalies_severity ON anomalies(severity);
CREATE INDEX IF NOT EXISTS idx_anomalies_depense ON anomalies(depense_id);

ALTER TABLE anomalies ALTER COLUMN depense_id DROP NOT NULL;


-- ==================== TABLE: model_metadata ====================
-- Stocke les métadonnées sur les entraînements de modèles
CREATE TABLE IF NOT EXISTS model_metadata (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    
    -- Type de modèle
    model_type VARCHAR(50) NOT NULL UNIQUE,
    -- xgboost, prophet, anomaly_detection, score_calculator
    
    -- Infos entraînement
    last_trained TIMESTAMP WITH TIME ZONE NOT NULL,
    training_count INTEGER NOT NULL DEFAULT 1,
    data_points_used INTEGER NOT NULL DEFAULT 0,
    
    -- Métriques de performance
    -- Ex: {"mae": 45.23, "rmse": 52.10, "r2": 0.85}
    metrics JSONB,
    
    -- Version du modèle
    model_version VARCHAR(20) DEFAULT 'v1.0',
    
    -- Timestamps
    created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT now(),
    updated_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT now()
);


-- ==================== PROPHET_INSIGHTS (Table optionnelle) ====================
-- Stocke les insights saisonniers détectés par Prophet
CREATE TABLE IF NOT EXISTS prophet_insights (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    
    -- Période analyse
    analysis_month TIMESTAMP WITH TIME ZONE NOT NULL,
    
    -- Saisonnalité détectée
    has_yearly_seasonality BOOLEAN DEFAULT FALSE,
    has_weekly_seasonality BOOLEAN DEFAULT FALSE,
    
    -- Pattern saisonnier en JSON
    -- Ex: {"July": 1.25, "August": 1.22, ...} (multiplicateurs)
    seasonal_pattern JSONB,
    
    -- Tendance générale
    trend_direction VARCHAR(20),  -- UP, DOWN, STABLE
    trend_percent DECIMAL(5, 2),
    
    -- Forecast 3 mois
    forecast_next_3_months JSONB,
    
    -- Confidence intervals
    confidence_intervals JSONB,
    
    -- Insights textuels
    insights TEXT,
    
    -- Timestamps
    created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT now(),
    updated_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT now(),
    
    CONSTRAINT unique_user_prophet_month UNIQUE (user_id, analysis_month)
);

CREATE INDEX IF NOT EXISTS idx_prophet_insights_user ON prophet_insights(user_id);


-- ==================== ROW LEVEL SECURITY (RLS) ====================
-- Chaque utilisateur ne voit que ses propres prédictions/anomalies

-- financial_scores RLS
ALTER TABLE financial_scores ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can view their own financial scores"
ON financial_scores FOR SELECT
USING (auth.uid() = user_id);

CREATE POLICY "Users can insert their own financial scores"
ON financial_scores FOR INSERT
WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can update their own financial scores"
ON financial_scores FOR UPDATE
USING (auth.uid() = user_id)
WITH CHECK (auth.uid() = user_id);


-- predictions RLS
ALTER TABLE predictions ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can view their own predictions"
ON predictions FOR SELECT
USING (auth.uid() = user_id);

CREATE POLICY "Users can insert their own predictions"
ON predictions FOR INSERT
WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can update their own predictions"
ON predictions FOR UPDATE
USING (auth.uid() = user_id)
WITH CHECK (auth.uid() = user_id);


-- anomalies RLS
ALTER TABLE anomalies ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can view their own anomalies"
ON anomalies FOR SELECT
USING (auth.uid() = user_id);

CREATE POLICY "Users can insert their own anomalies"
ON anomalies FOR INSERT
WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can update their own anomalies"
ON anomalies FOR UPDATE
USING (auth.uid() = user_id);


-- prophet_insights RLS
ALTER TABLE prophet_insights ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can view their own prophet insights"
ON prophet_insights FOR SELECT
USING (auth.uid() = user_id);

CREATE POLICY "Users can insert their own prophet insights"
ON prophet_insights FOR INSERT
WITH CHECK (auth.uid() = user_id);


-- ==================== AUTO-UPDATE TRIGGERS ====================
-- Mise à jour automatique du champ updated_at

CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER update_financial_scores_updated_at
    BEFORE UPDATE ON financial_scores
    FOR EACH ROW
    EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_predictions_updated_at
    BEFORE UPDATE ON predictions
    FOR EACH ROW
    EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_anomalies_updated_at
    BEFORE UPDATE ON anomalies
    FOR EACH ROW
    EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_model_metadata_updated_at
    BEFORE UPDATE ON model_metadata
    FOR EACH ROW
    EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_prophet_insights_updated_at
    BEFORE UPDATE ON prophet_insights
    FOR EACH ROW
    EXECUTE FUNCTION update_updated_at_column();


-- ==================== SAMPLE DATA (optionnel, pour tests) ====================
-- À décommenter pour créer des données de test

-- INSERT INTO financial_scores (user_id, month, discipline_score, stability_score, savings_score, risk_score, overall_score)
-- VALUES (auth.uid(), NOW(), 75.5, 82.3, 65.0, 85.0, 76.95);
