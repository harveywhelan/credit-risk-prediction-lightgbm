CREATE OR REPLACE VIEW v_installments_agg AS
-- ### Installment Flattening ###
-- Consolidates multiple partial payments mapped to the same installment number
WITH installment_level AS (
    SELECT
        SK_ID_PREV,
        ANY_VALUE(SK_ID_CURR) AS SK_ID_CURR,
        NUM_INSTALMENT_NUMBER,
        MAX(NUM_INSTALMENT_VERSION) AS inst_version,
        MAX(DAYS_INSTALMENT) AS due_date,
        MAX(DAYS_ENTRY_PAYMENT) AS actual_paid_date,
        MIN(DAYS_ENTRY_PAYMENT) AS first_paid_date,
        MAX(AMT_INSTALMENT) AS required_amount,
        COALESCE(SUM(AMT_PAYMENT), 0) AS actual_paid_amount
    FROM installments_payments
    GROUP BY SK_ID_PREV, NUM_INSTALMENT_NUMBER
),
-- ### Behavioral Metrics Calculation ###
-- Calculates late days and tracking version (schedule) changes
installment_metrics AS (
    SELECT
        *,
        LAG(inst_version) OVER (PARTITION BY SK_ID_PREV ORDER BY NUM_INSTALMENT_NUMBER) AS prev_inst_version,
        actual_paid_date - due_date AS days_past_due,
        due_date - actual_paid_date AS days_before_due,
        actual_paid_amount - required_amount AS payment_difference,
        actual_paid_amount / NULLIF(required_amount, 0) AS payment_ratio
    FROM installment_level
)
SELECT
    SK_ID_PREV,
    MAX(SK_ID_CURR) AS SK_ID_CURR,

    -- ### Versioning & Schedule Changes ###
    -- inst_version = 0 represents a revolving credit card structure
    MAX(CASE WHEN inst_version = 0 THEN 1 ELSE 0 END) AS inst_is_credit_card,
    MAX(CASE WHEN prev_inst_version IS NOT NULL AND inst_version != prev_inst_version THEN 1 ELSE 0 END) AS inst_has_version_changed,
    COUNT(*) FILTER (WHERE prev_inst_version IS NOT NULL AND inst_version != prev_inst_version) AS inst_num_version_changes,
    MAX(inst_version) AS inst_max_installment_version,

    -- ### Financial Payment Metrics ###
    COUNT(NUM_INSTALMENT_NUMBER) AS inst_total_installments,
    SUM(required_amount) AS inst_total_required_amount,
    SUM(actual_paid_amount) AS inst_total_paid_amount,
    SUM(required_amount) - SUM(actual_paid_amount) AS inst_total_amount_outstanding,

    MAX(payment_difference) AS inst_max_payment_difference,
    MIN(payment_difference) AS inst_min_payment_difference,
    AVG(payment_ratio) AS inst_avg_payment_ratio,

    -- ### Payment Behavior Counts ###
    COUNT(*) FILTER (WHERE actual_paid_amount < required_amount) AS inst_num_underpayments,
    COUNT(*) FILTER (WHERE actual_paid_amount = required_amount) AS inst_num_exact_payments,
    COUNT(*) FILTER (WHERE actual_paid_amount > required_amount) AS inst_num_overpayments,
    COUNT(*) FILTER (WHERE days_past_due > 0) AS inst_num_late_payments,
    COUNT(*) FILTER (WHERE days_past_due <= 0) AS inst_num_on_time_or_early_payments,

    -- ### Time-Based Performance ###
    MAX(CASE WHEN days_past_due > 0 THEN days_past_due ELSE 0 END) AS inst_max_days_late,
    SUM(CASE WHEN days_past_due > 0 THEN days_past_due ELSE 0 END) AS inst_total_days_late,
    MAX(CASE WHEN days_before_due > 0 THEN days_before_due ELSE 0 END) AS inst_max_days_early,
    AVG(CASE WHEN days_before_due > 0 THEN days_before_due ELSE 0 END) AS inst_avg_days_early

FROM installment_metrics
GROUP BY SK_ID_PREV;