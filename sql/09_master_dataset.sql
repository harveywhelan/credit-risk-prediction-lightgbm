-- Note: Requires Python formatting strings via {output_table} and {source_table}
CREATE OR REPLACE TABLE {output_table} AS
WITH app_engineered AS (
    SELECT
        *,

        -- ### Baseline Financial Ratios ###
        AMT_CREDIT / NULLIF(AMT_INCOME_TOTAL, 0) AS ratio_debt_to_income,
        AMT_ANNUITY / NULLIF(AMT_INCOME_TOTAL, 0) AS ratio_annuity_to_income,
        AMT_ANNUITY / NULLIF(AMT_CREDIT, 0) AS ratio_annuity_to_credit,
        AMT_GOODS_PRICE / NULLIF(AMT_CREDIT, 0) AS ratio_price_to_credit,

        -- ### Demographic & Employment Standardization ###
        -- DAYS_BIRTH & DAYS_EMPLOYED are negative. 365243 indicates missing/anomalous data
        ABS(DAYS_BIRTH) / 365.25 AS age_in_years,
        CASE WHEN DAYS_EMPLOYED = 365243 THEN 1 ELSE 0 END AS flag_employed_anomaly,
        CASE WHEN DAYS_EMPLOYED = 365243 THEN NULL ELSE ABS(DAYS_EMPLOYED) / 365.25 END AS years_employed,
        CASE WHEN DAYS_EMPLOYED = 365243 THEN 0 ELSE ABS(DAYS_EMPLOYED) / NULLIF(ABS(DAYS_BIRTH), 0) END AS ratio_life_employed,

        -- ### External Bureau Sourcing Aggregation ###
        (CASE WHEN EXT_SOURCE_1 IS NULL THEN 1 ELSE 0 END +
         CASE WHEN EXT_SOURCE_2 IS NULL THEN 1 ELSE 0 END +
         CASE WHEN EXT_SOURCE_3 IS NULL THEN 1 ELSE 0 END) AS ext_sources_null_count,

        -- Aggregate math across arbitrary external scoring systems (omitting nulls)
        list_aggregate(list_filter([EXT_SOURCE_1, EXT_SOURCE_2, EXT_SOURCE_3], x -> x IS NOT NULL), 'avg') AS ext_sources_mean,
        list_aggregate(list_filter([EXT_SOURCE_1, EXT_SOURCE_2, EXT_SOURCE_3], x -> x IS NOT NULL), 'min') AS ext_sources_min,
        list_aggregate(list_filter([EXT_SOURCE_1, EXT_SOURCE_2, EXT_SOURCE_3], x -> x IS NOT NULL), 'max') AS ext_sources_max,
        list_aggregate(list_filter([EXT_SOURCE_1, EXT_SOURCE_2, EXT_SOURCE_3], x -> x IS NOT NULL), 'var_samp') AS ext_sources_variance,

        -- ### Base Wealth Stability Index ###
        (CASE WHEN FLAG_OWN_CAR = 'Y' THEN 1 ELSE 0 END +
         CASE WHEN FLAG_OWN_REALTY = 'Y' THEN 1 ELSE 0 END +
         CASE WHEN NAME_EDUCATION_TYPE IN ('Higher education', 'Academic degree') THEN 1 ELSE 0 END) AS index_wealth_stability

    FROM {source_table})
-- ### Final Master Join Mapping ###
-- Bind current application data back to fully aggregated historical chains
SELECT
    app.*,
    bureau.* EXCLUDE (SK_ID_CURR),
    pa.* EXCLUDE (SK_ID_CURR)
FROM app_engineered AS app
LEFT JOIN v_agg_b_join_bb_agg AS bureau ON app.SK_ID_CURR = bureau.SK_ID_CURR
LEFT JOIN v_pa_branch_agg AS pa ON app.SK_ID_CURR = pa.SK_ID_CURR;