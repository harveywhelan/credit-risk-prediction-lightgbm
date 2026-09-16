CREATE OR REPLACE VIEW v_agg_b_join_bb_agg AS
SELECT
    SK_ID_CURR,

    -- ### Loan Counts & Categorization ###
    COUNT(*) AS b_total_loans,
    COUNT(*) FILTER (WHERE CREDIT_ACTIVE = 'Active') AS b_active_loans,
    COUNT(*) FILTER (WHERE CREDIT_ACTIVE = 'Closed') AS b_closed_loans,
    COUNT(*) FILTER (WHERE CREDIT_ACTIVE NOT IN ('Active', 'Closed')) AS b_other_status_loans,
    COUNT(DISTINCT CREDIT_CURRENCY) AS b_unique_currencies,
    COUNT(*) FILTER (WHERE CREDIT_TYPE = 'Credit card') AS b_credit_card_loans,
    COUNT(*) FILTER (WHERE CREDIT_TYPE = 'Consumer credit') AS b_consumer_loans,
    COUNT(*) FILTER (WHERE CREDIT_TYPE NOT IN ('Credit card', 'Consumer credit')) AS b_other_loan_types,

    -- ### Timeline Metrics ###
    -- Note: DAYS_* features are negative. MAX = most recent, MIN = oldest
    MAX(DAYS_CREDIT) AS b_days_since_latest_app,
    MIN(DAYS_CREDIT) AS b_days_since_oldest_app,
    AVG(DAYS_CREDIT) AS b_avg_days_since_app,
    MAX(DAYS_CREDIT_UPDATE) AS b_days_since_latest_update,
    AVG(DAYS_CREDIT_UPDATE) AS b_avg_days_since_update,

    -- Expected and actual closure dates
    MAX(DAYS_CREDIT_ENDDATE) AS b_latest_expected_end_date,
    MIN(DAYS_CREDIT_ENDDATE) AS b_earliest_expected_end_date,
    COUNT(*) FILTER (WHERE DAYS_CREDIT_ENDDATE > 0) AS b_count_expected_end_date_future,
    COUNT(*) FILTER (WHERE DAYS_CREDIT_ENDDATE < 0) AS b_count_expected_end_date_past,
    MAX(DAYS_ENDDATE_FACT) AS b_latest_actual_end_date,
    MIN(DAYS_ENDDATE_FACT) AS b_earliest_actual_end_date,
    AVG(DAYS_ENDDATE_FACT) AS b_avg_actual_end_date,

    -- Duration and discrepancies
    SUM(b_tot_scheduled_length) AS b_total_scheduled_length,
    AVG(b_tot_scheduled_length) AS b_avg_scheduled_length,
    MAX(b_tot_scheduled_length) AS b_max_scheduled_length,
    MIN(b_tot_scheduled_length) AS b_min_scheduled_length,
    MAX(b_diff_pred_actual_end_date) AS b_max_diff_pred_actual_end_date,
    AVG(b_diff_pred_actual_end_date) AS b_avg_diff_pred_actual_end_date,

    -- ### Financial Aggregations ###
    SUM(AMT_CREDIT_SUM) AS b_total_credit_sum,
    MAX(AMT_CREDIT_SUM) AS b_max_credit_sum,
    AVG(AMT_CREDIT_SUM) AS b_avg_credit_sum,

    SUM(AMT_CREDIT_SUM_DEBT) AS b_total_current_debt,
    MAX(AMT_CREDIT_SUM_DEBT) AS b_max_current_debt,
    MIN(AMT_CREDIT_SUM_DEBT) AS b_min_current_debt,
    AVG(AMT_CREDIT_SUM_DEBT) AS b_avg_current_debt,

    SUM(AMT_CREDIT_SUM_LIMIT) AS b_total_credit_limit,
    MAX(AMT_CREDIT_SUM_LIMIT) AS b_max_credit_limit,
    AVG(AMT_CREDIT_SUM_LIMIT) AS b_avg_credit_limit,

    MAX(AMT_ANNUITY) AS b_max_annuity,
    SUM(AMT_ANNUITY) FILTER (WHERE CREDIT_ACTIVE = 'Active') AS b_current_active_annuity,

    SUM(b_amount_paid_or_not_os) AS b_total_amount_paid_or_not_os,
    AVG(b_amount_paid_or_not_os) AS b_avg_amount_paid_or_not_os,

    -- ### Default & Overdue Metrics ###
    SUM(AMT_CREDIT_SUM_OVERDUE) AS b_total_current_overdue_amt,
    MAX(AMT_CREDIT_SUM_OVERDUE) AS b_max_current_overdue_amt,
    MAX(AMT_CREDIT_MAX_OVERDUE) AS b_worst_max_overdue_amt_ever,
    SUM(AMT_CREDIT_MAX_OVERDUE) AS b_total_max_overdue_amt_ever,
    MAX(CREDIT_DAY_OVERDUE) AS b_max_days_overdue_current,
    SUM(CREDIT_DAY_OVERDUE) AS b_total_days_overdue_current,

    SUM(CNT_CREDIT_PROLONG) AS b_total_prolongations,
    AVG(CNT_CREDIT_PROLONG) AS b_avg_prolongations,
    MAX(CNT_CREDIT_PROLONG) AS b_max_prolongations,

    -- ### Aggregated Financial Ratios ###
    AVG(b_frac_debt_remaining) AS b_avg_frac_debt_remaining,
    MAX(b_frac_debt_remaining) AS b_max_frac_debt_remaining,
    AVG(b_frac_paid_or_not_os) AS b_avg_frac_paid_or_not_os,
    MAX(b_frac_paid_or_not_os) AS b_max_frac_paid_or_not_os,
    MAX(b_frac_debt_remaining_is_overdue) AS b_max_frac_debt_remaining_is_overdue,
    AVG(b_frac_debt_remaining_is_overdue) AS b_avg_frac_debt_remaining_is_overdue,
    AVG(b_frac_total_per_payment) AS b_avg_frac_total_per_payment,

    -- ### Historical Bureau Balance Aggregations ###
    SUM(bb_record_count) AS bb_total_months_tracked,
    AVG(bb_record_count) AS bb_avg_months_tracked,
    MIN(bb_earliest_mon) AS bb_oldest_balance_month,
    MAX(bb_latest_mon) AS bb_most_recent_balance_month,
    MAX(bb_history_span_mon) AS bb_longest_history_span,
    AVG(bb_history_span_mon) AS bb_avg_history_span,

    SUM(bb_no_mon_closed) AS bb_total_mon_closed,
    SUM(bb_no_mon_unknown) AS bb_total_mon_unknown,
    SUM(bb_no_mon_clean) AS bb_total_mon_clean,
    SUM(bb_no_mon_in_dpd) AS bb_total_mon_in_dpd,
    SUM(bb_no_mon_in_dpd_30_plus) AS bb_total_mon_in_dpd_30_plus,
    SUM(bb_no_mon_in_dpd_last_6m) AS bb_total_mon_in_dpd_last_6m,
    SUM(bb_no_mon_in_dpd_last_12m) AS bb_total_mon_in_dpd_last_12m,
    SUM(bb_no_mon_written_off_or_severe) AS bb_total_mon_severe_default,

    -- Worst-case penalties & scores
    MAX(bb_max_dpd) AS bb_worst_dpd_level_ever,
    MAX(bb_dpd_penalty_sum) AS bb_worst_dpd_penalty_score,
    SUM(bb_dpd_penalty_sum) AS bb_total_dpd_penalty_score,
    MAX(bb_recency_dpd_penalty_sum) AS bb_worst_recent_penalty_score,
    SUM(bb_recency_dpd_penalty_sum) AS bb_total_recent_penalty_score,

    -- Aggregated behavioral rates
    AVG(bb_frac_mon_in_dpd) AS bb_avg_frac_mon_in_dpd,
    AVG(bb_frac_mon_in_dpd_30_plus) AS bb_avg_frac_mon_in_dpd_30_plus,
    AVG(bb_frac_mon_in_dpd_last_6m) AS bb_avg_frac_mon_in_dpd_last_6m,
    AVG(bb_frac_mon_in_dpd_last_12m) AS bb_avg_frac_mon_in_dpd_last_12m,
    AVG(bb_frac_mon_clean) AS bb_avg_frac_mon_clean,
    AVG(bb_frac_mon_unknown) AS bb_avg_frac_mon_unknown,
    AVG(bb_frac_mon_closed) AS bb_avg_frac_mon_closed,

    MAX(bb_frac_mon_in_dpd) AS bb_max_frac_mon_in_dpd,
    MAX(bb_frac_mon_in_dpd_30_plus) AS bb_max_frac_mon_in_dpd_30_plus,
    MAX(bb_frac_mon_in_dpd_last_6m) AS bb_max_frac_mon_in_dpd_last_6m,
    MAX(bb_frac_mon_in_dpd_last_12m) AS bb_max_frac_mon_in_dpd_last_12m,
    MAX(bb_frac_mon_clean) AS bb_max_frac_mon_clean,
    MAX(bb_frac_mon_unknown) AS bb_max_frac_mon_unknown,
    MAX(bb_frac_mon_closed) AS bb_max_frac_mon_closed,

    -- ### Boolean Condition Summaries (ANY / COUNT) ###
    MAX(b_has_current_debt) AS b_any_current_debt,
    SUM(b_has_current_debt) AS b_count_loans_with_debt,
    MAX(b_is_currently_overdue) AS b_any_currently_overdue,
    SUM(b_is_currently_overdue) AS b_count_loans_currently_overdue,

    MAX(bb_has_historical_dpd) AS bb_any_historical_dpd,
    SUM(bb_has_historical_dpd) AS bb_count_loans_with_historical_dpd,
    MAX(bb_has_closed) AS bb_any_closed_history,
    MAX(bb_has_unknown) AS bb_any_unknown_history,
    MAX(bb_has_written_off_or_severe) AS bb_any_severe_default,
    SUM(bb_has_written_off_or_severe) AS bb_count_loans_severe_default,
    MAX(bb_has_any_balance_history) AS bb_any_balance_history_available

FROM v_join_b_branch
GROUP BY SK_ID_CURR;