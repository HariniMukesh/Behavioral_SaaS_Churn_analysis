**SaaS Behavioral Churn Analysis**

End-to-end analytics project analyzing customer behavior, churn drivers, revenue impact, and churn risk prediction for a SaaS platform.

This project combines SQL analysis, Python machine learning, and Power BI dashboards to understand why customers churn and how to identify at-risk customers early.

**Project Overview**

Customer churn is one of the most critical metrics for SaaS businesses.
This project analyzes customer behavior data to uncover churn patterns and build predictive insights.

The analysis is structured into four layers:

Executive Overview – high-level SaaS performance metrics

Customer Behavior & Churn Drivers – behavioral signals linked to churn

Revenue Intelligence – financial impact of churn

Churn Risk Radar – predictive churn monitoring

The goal is to move from:

Descriptive Analytics → Diagnostic Insights → Predictive Intelligence

**Tech Stack**
Tool	                   Purpose
SQL (MySQL)              Data exploration and analysis
Python	                 Churn prediction model
Pandas / Scikit-learn	   Data processing and machine learning
Power BI	               Interactive dashboards and business intelligence
Git / GitHub	           Version control and project documentation

**Dashboard Preview:**
Executive Overview
Customer Behavior & Churn Drivers
Revenue Intelligence
Churn Risk Radar

**Key Insights:**
Most churn occurs during early and mid customer lifecycle stages
Product experience issues (feature usage and support) drive the majority of churn
Enterprise and Pro plans contribute the highest revenue
Some customers downgrade plans before churning, indicating early dissatisfaction
Predictive risk scoring helps identify high-risk customers early

**Project Pipeline**
Dataset
   ↓
SQL Data Analysis
   ↓
Feature Engineering
   ↓
Python Churn Prediction Model
   ↓
Power BI Business Intelligence Dashboard

**Repository Structure**
Behavioral_SaaS_Churn_analysis

data/
│
├── raw/
│   ├── customer_support_tickets.csv
│   ├── ravenstack_accounts.csv
│   ├── ravenstack_churn_events.csv
│   ├── ravenstack_feature_usage.csv
│   ├── ravenstack_subscriptions.csv
│   └── ravenstack_support_tickets.csv
│
└── processed/
    ├── churn_model_dataset.csv
    └── churn_risk_predictions.csv

images/
├── ER Diagram.png
├── Executive Dashboard.png
├── Customer Behaviour & Churn Drivers.png
├── Revenue Intelligence.png
└── Churn Risk Radar.png

notebooks/
└── churn_prediction_model.ipynb

powerbi/
└── Analysis_Dashboards.pbix

sql/
├── Creating database.sql
└── Exploratory_analysis.sql

requirements.txt
.gitignore
README.md

**Dataset**

The dataset used in this project was obtained from Kaggle and represents synthetic SaaS customer behavior data.

**Licensing**

This dataset is fully synthetic and distributed under a permissive MIT-like license.
You may use or remix it for learning, research, or portfolio purposes, but you must credit the dataset author:
River @ Rivalytics

**Author**

Harini Mukesh
Behavioral Data Analyst | Psychology Graduate
Python • SQL • Power BI • Customer Analytics

**Status**

Project completed.
Further improvements and refinements will be added soon.
