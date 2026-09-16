CREATE OR REPLACE VIEW v_credit_card_agg AS
-- ### Engineered Proxies & Lags ###
-- Generating proxy values for unlisted fees and identifying active limit changes
WITH cc_lagged_features AS (
    SELECT
        *,
        LAG(AMT_CREDIT_LIMIT_ACTUAL) OVER (PARTITION BY SK_ID_PREV ORDER BY MONTHS_BALANCE ASC) AS prev_limit,
        -- If total receivable > principal, the remainder is an implied interest cost proxy
        COALESCE(GREATEST(AMT_RECIVABLE - AMT_RECEIVABLE_PRINCIPAL, 0), 0) AS interest_cost_proxy,
        -- If absolute total receivable > base receivable, the remainder is a late fee proxy
        COALESCE(GREATEST(AMT_TOTAL_RECEIVABLE - AMT_RECIVABLE, 0), 0) AS late_fee_proxy,
        -- Tiered DPD translation
        CASE
            WHEN SK_DPD = 0 THEN 0
            WHEN SK_DPD <= 30 THEN 1
            WHEN SK_DPD <= 60 THEN 2
            WHEN SK_DPD <= 90 THEN 3
            WHEN SK_DPD <= 120 THEN 4
            ELSE 5
        END AS row_dpd_penalty
    FROM credit_card_balance
)
SELECT
    SK_ID_PREV,
    ANY_VALUE(SK_ID_CURR) AS SK_ID_CURR,

    -- ### History Span ###
    -- Note: MONTHS_BALANCE is negative (0 = current month, -1 = last month)
    COUNT(*) AS cc_credit_length_months,
    MIN(MONTHS_BALANCE) AS cc_month_oldest,
    MAX(MONTHS_BALANCE) AS cc_month_most_recent,

    -- ### Delinquency Scoring ###
    SUM(row_dpd_penalty) AS cc_dpd_penalty_score,
    MAX(SK_DPD) AS cc_max_dpd,
    MAX(SK_DPD_DEF) AS cc_max_dpd_def,

    -- ### Limit & Utilization Tracking ###
    AVG(AMT_CREDIT_LIMIT_ACTUAL) AS cc_avg_limit,
    MAX(AMT_CREDIT_LIMIT_ACTUAL) AS cc_max_limit,
    COUNT(*) FILTER (WHERE prev_limit IS NOT NULL AND AMT_CREDIT_LIMIT_ACTUAL != prev_limit) AS cc_num_limit_changes,
    MAX(CASE WHEN prev_limit IS NOT NULL AND AMT_CREDIT_LIMIT_ACTUAL != prev_limit THEN 1 ELSE 0 END) AS cc_flag_limit_change_ever,
    MAX(CASE WHEN prev_limit IS NOT NULL AND AMT_CREDIT_LIMIT_ACTUAL > prev_limit THEN 1 ELSE 0 END) AS cc_flag_limit_increase_ever,

    -- Worst-case observed balance vs limit
    MAX(CASE WHEN AMT_CREDIT_LIMIT_ACTUAL > 0 THEN AMT_BALANCE / AMT_CREDIT_LIMIT_ACTUAL ELSE 0 END) AS cc_max_utilization,

    -- ### Spending & Withdrawal Behavior ###
    MAX(CASE WHEN CNT_DRAWINGS_ATM_CURRENT > 0 THEN 1 ELSE 0 END) AS cc_flag_atm_draw_ever,
    SUM(COALESCE(CNT_DRAWINGS_ATM_CURRENT, 0)) AS cc_sum_atm_draws,
    SUM(COALESCE(CNT_DRAWINGS_ATM_CURRENT, 0))::DOUBLE / NULLIF(COUNT(MONTHS_BALANCE), 0) AS cc_frac_atm_draws,

    -- Most recent functional status
    max_by(NAME_CONTRACT_STATUS, MONTHS_BALANCE) AS cc_current_status,

    -- ### Repayment & Financial Totals ###
    SUM(COALESCE(AMT_PAYMENT_TOTAL_CURRENT, 0)) AS cc_total_sum_repaid,
    SUM(COALESCE(AMT_INST_MIN_REGULARITY, 0)) AS cc_total_amount_ever_due,
    SUM(COALESCE(AMT_DRAWINGS_CURRENT, 0)) AS cc_total_amount_spent,

    SUM(AMT_RECIVABLE) AS cc_total_receivable,
    SUM(AMT_RECEIVABLE_PRINCIPAL) AS cc_total_receivable_principal,

    -- Proxy aggregates for hidden costs
    SUM(interest_cost_proxy) AS cc_sum_interest_costs,
    SUM(late_fee_proxy) AS cc_sum_late_costs,
    MAX(CASE WHEN late_fee_proxy > 0 OR SK_DPD_DEF > 0 THEN 1 ELSE 0 END) AS cc_ever_late_fees

FROM cc_lagged_features
GROUP BY SK_ID_PREV;