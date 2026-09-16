CREATE OR REPLACE VIEW v_join_b_branch AS
SELECT
    b.*,
    bb.* EXCLUDE (SK_ID_BUREAU),

    -- ### Financial & Debt Ratios ###
    b.AMT_CREDIT_SUM_DEBT / NULLIF(b.AMT_CREDIT_SUM, 0) AS b_frac_debt_remaining,
    b.AMT_CREDIT_SUM - COALESCE(b.AMT_CREDIT_SUM_DEBT, 0) AS b_amount_paid_or_not_os,
    (b.AMT_CREDIT_SUM - COALESCE(b.AMT_CREDIT_SUM_DEBT, 0)) / NULLIF(b.AMT_CREDIT_SUM, 0) AS b_frac_paid_or_not_os,
    b.AMT_CREDIT_SUM_OVERDUE / NULLIF(b.AMT_CREDIT_SUM_DEBT, 0) AS b_frac_debt_remaining_is_overdue,
    b.AMT_ANNUITY / NULLIF(b.AMT_CREDIT_SUM, 0) AS b_frac_total_per_payment,

    -- ### Time-Based Features ###
    -- Note: All DAYS_* features are negative integers representing days before current application
    b.DAYS_CREDIT_ENDDATE - b.DAYS_CREDIT AS b_tot_scheduled_length,

    -- Discrepancy between when a loan was predicted to end vs when it actually ended
    CASE WHEN b.DAYS_ENDDATE_FACT IS NOT NULL AND b.DAYS_CREDIT_ENDDATE IS NOT NULL
         THEN b.DAYS_ENDDATE_FACT - b.DAYS_CREDIT_ENDDATE END AS b_diff_pred_actual_end_date,

    -- ### Bureau Balance Aggregation Fractions ###
    -- Normalize raw counts by total record length to get behavior rates
    bb.bb_no_mon_in_dpd::DOUBLE / NULLIF(bb.bb_record_count, 0) AS bb_frac_mon_in_dpd,
    bb.bb_no_mon_in_dpd_30_plus::DOUBLE / NULLIF(bb.bb_record_count, 0) AS bb_frac_mon_in_dpd_30_plus,
    bb.bb_no_mon_in_dpd_last_6m::DOUBLE / NULLIF(LEAST(COALESCE(bb.bb_record_count, 0), 6), 0) AS bb_frac_mon_in_dpd_last_6m,
    bb.bb_no_mon_in_dpd_last_12m::DOUBLE / NULLIF(LEAST(COALESCE(bb.bb_record_count, 0), 12), 0) AS bb_frac_mon_in_dpd_last_12m,
    bb.bb_no_mon_clean::DOUBLE / NULLIF(bb.bb_record_count, 0) AS bb_frac_mon_clean,
    bb.bb_no_mon_unknown::DOUBLE / NULLIF(bb.bb_record_count, 0) AS bb_frac_mon_unknown,
    bb.bb_no_mon_closed::DOUBLE / NULLIF(bb.bb_record_count, 0) AS bb_frac_mon_closed,

    -- ### Critical Risk Flags ###
    CASE WHEN COALESCE(b.AMT_CREDIT_SUM_DEBT, 0) > 0 THEN 1 ELSE 0 END AS b_has_current_debt,
    CASE WHEN COALESCE(b.CREDIT_DAY_OVERDUE, 0) > 0 OR COALESCE(b.AMT_CREDIT_SUM_OVERDUE, 0) > 0 THEN 1 ELSE 0 END AS b_is_currently_overdue,
    CASE WHEN COALESCE(bb.bb_no_mon_in_dpd, 0) > 0 THEN 1 ELSE 0 END AS bb_has_historical_dpd,
    CASE WHEN COALESCE(bb.bb_no_mon_closed, 0) > 0 THEN 1 ELSE 0 END AS bb_has_closed,
    CASE WHEN COALESCE(bb.bb_no_mon_unknown, 0) > 0 THEN 1 ELSE 0 END AS bb_has_unknown,
    CASE WHEN COALESCE(bb.bb_no_mon_written_off_or_severe, 0) > 0 THEN 1 ELSE 0 END AS bb_has_written_off_or_severe,
    CASE WHEN bb.SK_ID_BUREAU IS NULL THEN 0 ELSE 1 END AS bb_has_any_balance_history

FROM bureau AS b
LEFT JOIN v_bb_agg AS bb ON b.SK_ID_BUREAU = bb.SK_ID_BUREAU;