# Explainable Credit Risk Modelling: Default Prediction using LightGBM and DuckDB

> **Predicting credit default risk whilst prioritising model explainability, regulatory fairness, and efficient data processing.**

![Current Project Status](https://img.shields.io/badge/Status-Completed-limegreen.svg)
<!--
![Image of SHAP importance plot for the best model found by Optuna. This shows that the model retains strong predictive power without relying on attributes that are indistinguishable from noise, highly correlated with other features, or using protected attributes.](assets/final_shap_plot.png)
-->


## ✦ Overview

- **Problem Statement:** Accurately identifying clients capable of loan repayment while navigating massive and messy relational datasets whilst strictly adhering to fair lending regulations.
- **Objective:** To engineer an explainable, memory-efficient LightGBM model predicting credit default risk using temporally aggregated relational data.
- **Impact:** Enhances automated lending decisions by providing transparent risk scores whilst ensuring strict compliance with anti-discrimination regulations.



## ✦ Tech Stack

**AWS (EC2, S3)**, **DuckDB**, **LightGBM**, **SHAP**, **Optuna**, **PyArrow**, **Python**, **pandas**, **NumPy**



## ✦ Data

- **Source(s):** Relational dataset from the Kaggle Home Credit Default Risk competition accessed via Kaggle API.
- **Size:** Millions of records across seven relational tables spanning three heirarchal layers. Aggregated behavioural signals up to the applicant level, engineering a dataset of 275 features for over 350,000 customers.
- **Notable Characteristics:** Severe class imbalance, large relational structure requiring SQL aggregation via in-memory DuckDB instance, and numerous protected demographic attributes requiring removal.



## ✦ Methodology

- **Preprocessing:** Systematically downcast datatypes to 32-bit formats, and mapped categorical string features to integer indices to enable memory-efficient GPU execution via Apache PyArrow tables.
- **Feature Engineering:** Extracted and preserved temporally derived behavioural signals from child tables via DuckDB SQL aggregations and joins. Used category specific SHAP noise probe injection to prune non-predictive features, then analysed Spearman correlations to remove redundant features, and finally removed any remaining protected attributes/proxies which remain.
- **Modelling:** Selected LightGBM for its native handling of imbalanced data and missing values, and integrated with Optuna for Bayesian hyperparameter optimisation. Developed and compared multiple models with varied levels of feature pruning.
- **Evaluation:**  Evaluated primarily on Average Precision (PR-AUC) due to severe target imbalance, focusing on identifying the minority default class, minimising credit loss, whilst protecting interest revenue from the majority.



## ✦ Key Results and Outputs

- Pruned the feature space from 275 to 80 features using SHAP noise probes and Spearman correlation with minimal performance loss.
- Ensured regulatory compliance by removing protected attributes alongside socio-economic and demographic proxies (e.g. housing metrics, education level) to align with legal obligations such as UK 2010 Equality Act, FCA Consumer Duty, and GDPR.
- Built a highly scalable, in-memory DuckDB and PyArrow pipeline capable of efficiently aggregating complex relational tables on T4 GPU compute resources hosted on an AWS EC2 instance.



## ✦ Roadmap and Limitations

- **Limitation:** The strict removal of protected attributes inherently degrades raw predictive power in favour of ethical and regulatory compliance. No comparison exists to other model architectures.
- **Future Work:** Extend this work to validate that protected attributes' proxies have been completely removed (e.g. phi coefficients and adversarial debiasing methods). Could compare to more simple baseline models (logistic regression), cluster applicants (K-means, Silhouette Scores, Elbow method) to train and apply more specialised models to each cluster, apply ensemble majority voting, or compare predictions to anomaly detection methods (Isolation Forest, OCSVM), since default prediction and fraud detection can be seen as two sides of the same coin.