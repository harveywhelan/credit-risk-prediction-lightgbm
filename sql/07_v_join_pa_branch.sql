CREATE OR REPLACE VIEW v_join_pa_branch AS
SELECT
    pa.*,

    -- ### Table Joins ###
    pos.* EXCLUDE (SK_ID_PREV, SK_ID_CURR),
    inst.* EXCLUDE (SK_ID_PREV, SK_ID_CURR),
    cc.* EXCLUDE (SK_ID_PREV, SK_ID_CURR),

    -- ### Loan Approval & Value Ratios ###
    pa.AMT_APPLICATION - pa.AMT_CREDIT AS pa_awarded_credit_diff,
    COALESCE(pa.AMT_CREDIT / NULLIF(pa.AMT_APPLICATION, 0), 1) AS pa_awarded_credit_ratio,
    COALESCE(pa.AMT_CREDIT / NULLIF(pa.AMT_GOODS_PRICE, 0), 1) AS pa_loan_to_value_ratio,

    -- ### Repayment & Cost Expectations ###
    (pa.AMT_ANNUITY::DOUBLE * pa.CNT_PAYMENT) AS pa_total_expected_repayment,
    (pa.AMT_ANNUITY::DOUBLE * pa.CNT_PAYMENT) - pa.AMT_CREDIT AS pa_expected_interest_cost,
    pa.AMT_ANNUITY / NULLIF(pa.AMT_CREDIT, 0) AS pa_annuity_to_credit_ratio,

    -- ### Time Discrepancies & Age ###
    -- 365243 is a known anomaly/default value representing missing date data in this dataset
    NULLIF(pa.DAYS_LAST_DUE, 365243) - NULLIF(pa.DAYS_LAST_DUE_1ST_VERSION, 365243) AS pa_days_prolonged,
    NULLIF(pa.DAYS_TERMINATION, 365243) - NULLIF(pa.DAYS_LAST_DUE, 365243) AS pa_days_termination_delay,

    -- Convert negative absolute days into a clean readable yearly value
    ABS(pa.DAYS_DECISION) / 365.25 AS pa_years_since_decision,

    -- ### Categorical Flags ###
    CASE WHEN pa.CODE_REJECT_REASON != 'XAP' AND pa.CODE_REJECT_REASON IS NOT NULL THEN 1 ELSE 0 END AS pa_is_rejected_flag,
    CASE WHEN pa.AMT_DOWN_PAYMENT > 0 THEN 1 ELSE 0 END AS pa_has_down_payment_flag

FROM previous_application pa
LEFT JOIN v_pos_cash_agg pos ON pa.SK_ID_PREV = pos.SK_ID_PREV
LEFT JOIN v_installments_agg inst ON pa.SK_ID_PREV = inst.SK_ID_PREV
LEFT JOIN v_credit_card_agg cc ON pa.SK_ID_PREV = cc.SK_ID_PREV;