CREATE OR REPLACE VIEW v_pos_cash_agg AS
-- ### Window Functions for Term Changes ###
-- Track previous term limits to detect if repayment schedules were actively altered
WITH pos_monthly_calc AS (
    SELECT
        *,
        LAG(CNT_INSTALMENT) OVER (PARTITION BY SK_ID_PREV ORDER BY MONTHS_BALANCE ASC) AS prev_cnt_instalment
    FROM pos_cash_balance
)
SELECT
    SK_ID_PREV,
    ANY_VALUE(SK_ID_CURR) AS SK_ID_CURR,

    -- ### Time & Record Counts ###
    -- Note: MONTHS_BALANCE is negative (0 = current month, -1 = last month)
    COUNT(*) AS pos_cash_total_records,
    MIN(MONTHS_BALANCE) AS pos_cash_months_balance_min,
    MAX(MONTHS_BALANCE) AS pos_cash_months_balance_max,

    -- ### Term Change Flags ###
    MAX(CNT_INSTALMENT) AS pos_cnt_instalment_max,
    AVG(CNT_INSTALMENT) AS pos_cnt_instalment_mean,
    COUNT(*) FILTER (WHERE prev_cnt_instalment IS NOT NULL AND CNT_INSTALMENT != prev_cnt_instalment) AS pos_count_term_change,
    MAX(CASE WHEN prev_cnt_instalment IS NOT NULL AND CNT_INSTALMENT != prev_cnt_instalment THEN 1 ELSE 0 END) AS pos_flag_term_ever_changed,

    -- ### Delinquency & Severity (DPD) ###
    MAX(SK_DPD) AS pos_loan_max_dpd,
    SUM(SK_DPD) AS pos_loan_sum_dpd,
    MAX(SK_DPD_DEF) AS pos_loan_max_dpd_def,

    -- Tiered severity score based on length of delinquency
    SUM(CASE
        WHEN SK_DPD BETWEEN 1 AND 30 THEN 1
        WHEN SK_DPD BETWEEN 31 AND 60 THEN 2
        WHEN SK_DPD BETWEEN 61 AND 90 THEN 3
        WHEN SK_DPD BETWEEN 91 AND 120 THEN 4
        WHEN SK_DPD > 120 THEN 5
        ELSE 0 END) AS pos_loan_dpd_severity_score,

    -- ### Recency Penalty Metrics ###
    MAX(CASE WHEN SK_DPD > 0 AND MONTHS_BALANCE >= -12 THEN 1 ELSE 0 END) AS pos_past_due_last_12m_flag,

    -- Weights recent defaults much higher than older defaults
    SUM(CASE
        WHEN SK_DPD > 0 AND MONTHS_BALANCE >= -6 THEN 3
        WHEN SK_DPD > 0 AND MONTHS_BALANCE >= -12 THEN 2
        WHEN SK_DPD > 0 AND MONTHS_BALANCE >= -24 THEN 1
        ELSE 0 END) AS pos_loan_dpd_recency_penalty_score,

    -- ### Latest Context ###
    -- Pulls the exact contract status and remaining installments for the most recent month
    max_by(NAME_CONTRACT_STATUS, MONTHS_BALANCE) AS pos_latest_contract_status,
    max_by(CNT_INSTALMENT_FUTURE, MONTHS_BALANCE) AS pos_latest_instalments_future

FROM pos_monthly_calc
GROUP BY SK_ID_PREV;