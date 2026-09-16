CREATE OR REPLACE VIEW v_bb_agg AS
SELECT
    SK_ID_BUREAU,

    -- ### Time-Based Features & Spans ###
    COUNT(*) AS bb_record_count,
    MIN(MONTHS_BALANCE) AS bb_earliest_mon,
    MAX(MONTHS_BALANCE) AS bb_latest_mon,
    MAX(MONTHS_BALANCE) - MIN(MONTHS_BALANCE) + 1 AS bb_history_span_mon,

    -- ### Status Frequencies ###
    COUNT(*) FILTER (WHERE STATUS = 'C') AS bb_no_mon_closed,
    COUNT(*) FILTER (WHERE STATUS = 'X') AS bb_no_mon_unknown,
    COUNT(*) FILTER (WHERE STATUS = '0') AS bb_no_mon_clean,

    -- ### Delinquency (DPD) Tracking ###
    COUNT(*) FILTER (WHERE STATUS IN ('1', '2', '3', '4', '5')) AS bb_no_mon_in_dpd,
    COUNT(*) FILTER (WHERE STATUS IN ('2', '3', '4', '5')) AS bb_no_mon_in_dpd_30_plus,
    COUNT(*) FILTER (WHERE STATUS = '5') AS bb_no_mon_written_off_or_severe,

    -- Time-windowed DPD flags using the CTE
    COUNT(*) FILTER (WHERE STATUS IN ('1', '2', '3', '4', '5') AND MONTHS_BALANCE >= -5) AS bb_no_mon_in_dpd_last_6m,
    COUNT(*) FILTER (WHERE STATUS IN ('1', '2', '3', '4', '5') AND MONTHS_BALANCE >= -11) AS bb_no_mon_in_dpd_last_12m,

    -- ### Delinquency Penalty Scoring ###
    MAX(CASE WHEN STATUS IN ('1', '2', '3', '4', '5') THEN CAST(STATUS AS INTEGER) ELSE 0 END) AS bb_max_dpd,

    SUM(CASE WHEN STATUS IN ('1', '2', '3', '4', '5')
        THEN GREATEST(POWER(3, CAST(STATUS AS DOUBLE) - 1) - 1, 1)
        ELSE 0 END) AS bb_dpd_penalty_sum,

    SUM(CASE WHEN STATUS IN ('1', '2', '3', '4', '5')
        THEN GREATEST(POWER(3, CAST(STATUS AS DOUBLE) - 1) - 1, 1) / GREATEST(ABS(MONTHS_BALANCE), 1)
        ELSE 0 END) AS bb_recency_dpd_penalty_sum

FROM bureau_balance
GROUP BY SK_ID_BUREAU;