CREATE OR REPLACE VIEW v_pa_branch_agg AS
SELECT
    SK_ID_CURR,

    -- ### Previous Application Counts & Ratios ###
    COUNT(*) AS pa_total_prev_apps,
    COUNT(*) FILTER (WHERE NAME_CONTRACT_STATUS = 'Approved') AS pa_count_approved,
    SUM(pa_is_rejected_flag) AS pa_count_rejected,
    SUM(pa_has_down_payment_flag) AS pa_count_down_payments,
    COUNT(*) FILTER (WHERE NAME_CONTRACT_STATUS = 'Approved')::DOUBLE / NULLIF(COUNT(*), 0) AS pa_approval_ratio,

    -- Evaluate the nature of the most recent application (MAX DAYS_DECISION = closest to 0)
    max_by(NAME_CONTRACT_STATUS, DAYS_DECISION) AS pa_most_recent_app_status,
    max_by(pa_is_rejected_flag, DAYS_DECISION) AS pa_most_recent_app_was_rejected,

    -- ### Previous Application Timelines ###
    MAX(DAYS_DECISION) AS pa_days_since_newest_app,
    MIN(DAYS_DECISION) AS pa_days_since_oldest_app,
    COUNT(*) FILTER (WHERE DAYS_DECISION >= -365) AS pa_count_apps_last_1yr,
    COALESCE(SUM(pa_is_rejected_flag) FILTER (WHERE DAYS_DECISION >= -365), 0) AS pa_count_rejects_last_1yr,
    MAX(pa_days_prolonged) AS pa_max_days_prolonged,
    MAX(pa_days_termination_delay) AS pa_max_days_termination_delay,

    -- ### Previous Application Financials ###
    SUM(AMT_APPLICATION) AS pa_global_amt_requested,
    SUM(AMT_CREDIT) AS pa_global_amt_awarded,
    SUM(AMT_CREDIT) / NULLIF(SUM(AMT_APPLICATION), 0) AS pa_global_awarded_to_requested_ratio,
    SUM(pa_expected_interest_cost) AS pa_global_expected_interest_cost,
    MAX(pa_expected_interest_cost) AS pa_max_expected_interest_cost,

    -- ### Rolled Up POS Cash Analytics ###
    MAX(pos_loan_max_dpd) AS pos_global_worst_dpd,
    SUM(pos_loan_sum_dpd) AS pos_global_sum_dpd,
    MAX(pos_loan_dpd_severity_score) AS pos_global_worst_severity_score,
    SUM(pos_loan_dpd_recency_penalty_score) AS pos_global_recency_penalty_score,
    MAX(pos_past_due_last_12m_flag) AS pos_any_past_due_last_12m,
    MAX(pos_flag_term_ever_changed) AS pos_any_term_change_ever,

    -- ### Rolled Up Installment Behavior ###
    SUM(inst_total_installments) AS inst_global_total_installments,
    SUM(inst_total_paid_amount) / NULLIF(SUM(inst_total_required_amount), 0) AS inst_global_payment_ratio,
    SUM(inst_total_amount_outstanding) AS inst_global_total_outstanding,

    SUM(inst_num_late_payments) AS inst_global_total_late_payments,
    SUM(inst_num_underpayments) AS inst_global_total_underpayments,
    MAX(inst_max_days_late) AS inst_global_worst_days_late,
    SUM(inst_total_days_late) / NULLIF(SUM(inst_num_late_payments), 0) AS inst_global_avg_days_late,
    MAX(inst_num_version_changes) AS inst_global_max_version_changes,

    -- ### Rolled Up Credit Card Analytics ###
    MAX(cc_max_utilization) AS cc_global_max_utilization,
    MAX(cc_flag_atm_draw_ever) AS cc_any_atm_draw_ever,

    MAX(cc_max_dpd) AS cc_global_worst_dpd,
    MAX(cc_dpd_penalty_score) AS cc_global_worst_dpd_penalty,

    SUM(cc_sum_late_costs) AS cc_global_total_late_costs,
    MAX(cc_ever_late_fees) AS cc_any_late_fees_ever,
    SUM(cc_total_amount_spent) AS cc_global_total_spent,
    SUM(cc_total_amount_spent) / NULLIF(SUM(cc_total_sum_repaid), 0) AS cc_global_spend_to_repay_ratio

FROM v_join_pa_branch
GROUP BY SK_ID_CURR;