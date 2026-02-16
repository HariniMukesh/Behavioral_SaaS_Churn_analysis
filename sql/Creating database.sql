CREATE DATABASE ravenstack_analytics;
USE ravenstack_analytics;
-- imported data into ravenstack_analytics database using "Table Data Import Wizard" 
SELECT COUNT(*) FROM accounts_raw;

CREATE TABLE accounts (
    account_id VARCHAR(50) PRIMARY KEY,
    account_name VARCHAR(255),
    industry VARCHAR(100),
    country VARCHAR(5),
    signup_date DATE,
    referral_source VARCHAR(50),
    plan_tier VARCHAR(50),
    seats INT,
    is_trial BOOLEAN,
    churn_flag BOOLEAN
);

INSERT INTO accounts (
    account_id,
    account_name,
    industry,
    country,
    signup_date,
    referral_source,
    plan_tier,
    seats,
    is_trial,
    churn_flag
)
SELECT
    account_id,
    account_name,
    industry,
    country,
    STR_TO_DATE(signup_date, '%Y-%m-%d'),
    referral_source,
    plan_tier,
    CAST(seats AS UNSIGNED),
    CASE WHEN is_trial = 'True' THEN 1 ELSE 0 END,
    CASE WHEN churn_flag = 'True' THEN 1 ELSE 0 END
FROM accounts_raw;

SELECT COUNT(*) FROM accounts;
SELECT * FROM accounts LIMIT 5;

SELECT COUNT(*) FROM subscriptions_raw;

CREATE TABLE subscriptions (
     subscription_id VARCHAR(50) PRIMARY KEY,
     account_id VARCHAR(50),
     start_date DATE,
     end_date DATE,
     plan_tier VARCHAR(50),
     seats INT,
     mrr_amount DECIMAL(10,2),
     arr_amount DECIMAL(10,2),
     is_trial BOOLEAN,
     upgrade_flag BOOLEAN,
     downgrade_flag BOOLEAN,
     churn_flag BOOLEAN,
     billing_frequency VARCHAR(20),
     auto_renew_flag BOOLEAN,
     FOREIGN KEY (account_id) REFERENCES accounts(account_id)
); 

INSERT INTO subscriptions (
     subscription_id,
     account_id,
     start_date,
     end_date,
     plan_tier,
     seats,
     mrr_amount,
     arr_amount,
     is_trial,
     upgrade_flag,
     downgrade_flag,
     churn_flag,
     billing_frequency,
     auto_renew_flag
)
SELECT
     subscription_id,
     account_id,
     STR_TO_DATE(start_date, '%Y-%m-%d'),
     CASE 
         WHEN end_date IS NULL OR end_date = ''
         THEN NULL
         ELSE STR_TO_DATE(end_date, '%Y-%m-%d')
	 END,
     plan_tier,
     CAST(seats AS UNSIGNED),
     CAST(mrr_amount AS DECIMAL(10,2)),
     CAST(arr_amount AS DECIMAL(10,2)),
     CASE WHEN is_trial = 'True' THEN 1 ELSE 0 END,
     CASE WHEN upgrade_flag = 'True' THEN 1 ELSE 0 END,
     CASE WHEN downgrade_flag = 'True' THEN 1 ELSE 0 END,
     CASE WHEN churn_flag = 'True' THEN 1 ELSE 0 END,
     billing_frequency,
     CASE WHEN auto_renew_flag = 'True' THEN 1 ELSE 0 END
FROM subscriptions_raw;
   
select count(*) from subscriptions; 
select * from subscriptions limit 20;

select count(*) from feature_usage_raw;

CREATE TABLE feature_usage (
    id INT AUTO_INCREMENT PRIMARY KEY,
    usage_id VARCHAR(50),
    subscription_id VARCHAR(50),
    usage_date DATE,
    feature_name VARCHAR(100),
    usage_count INT,
    usage_duration_secs INT,
    error_count INT,
    is_beta_feature BOOLEAN,
    FOREIGN KEY (subscription_id) REFERENCES subscriptions(subscription_id)
);

INSERT INTO feature_usage (
    usage_id,
    subscription_id,
    usage_date,
    feature_name,
    usage_count,
    usage_duration_secs,
    error_count,
    is_beta_feature
)
SELECT
    usage_id,
    subscription_id,
    STR_TO_DATE(usage_date, '%Y-%m-%d'),
    feature_name,
    CAST(usage_count AS UNSIGNED),
    CAST(usage_duration_secs AS UNSIGNED),
    CAST(error_count AS UNSIGNED),
    CASE WHEN is_beta_feature = 'True' THEN 1 ELSE 0 END
FROM feature_usage_raw;

select * from feature_usage limit 10;

select count(*) from support_tickets_raw;

CREATE TABLE support_tickets (
    ticket_id VARCHAR(50) PRIMARY KEY,
    account_id VARCHAR(50),
    submitted_at DATETIME,
    closed_at DATETIME,
    resolution_time_hours FLOAT,
    priority VARCHAR(20),
    first_response_time_minutes INT,
    satisfaction_score INT,
    escalation_flag BOOLEAN,
    FOREIGN KEY (account_id) REFERENCES accounts(account_id)
);

INSERT INTO support_tickets (
    ticket_id,
    account_id,
    submitted_at,
    closed_at,
    resolution_time_hours,
    priority,
    first_response_time_minutes,
    satisfaction_score,
    escalation_flag
)
SELECT
    ticket_id,
    account_id,
    STR_TO_DATE(submitted_at, '%Y-%m-%d %H:%i:%s'),
    STR_TO_DATE(closed_at, '%Y-%m-%d %H:%i:%s'),
    CAST(resolution_time_hours AS DECIMAL(5,2)),
    priority,
    CAST(first_response_time_minutes AS UNSIGNED),
    NULLIF(satisfaction_score, ''),
    CASE WHEN escalation_flag = 'True' THEN 1 ELSE 0 END
FROM support_tickets_raw;

select * from support_tickets limit 20;

select count(*) from churn_events_raw;

CREATE TABLE churn_events (
    churn_event_id VARCHAR(50) PRIMARY KEY,
    account_id VARCHAR(50),
    churn_date DATE,
    reason_code VARCHAR(100),
    refund_amount_usd DECIMAL(10,2),
    preceding_upgrade_flag BOOLEAN,
    preceding_downgrade_flag BOOLEAN,
    is_reactivation BOOLEAN,
    feedback_text TEXT,
    FOREIGN KEY (account_id) REFERENCES accounts(account_id)
);

INSERT INTO churn_events (
    churn_event_id,
    account_id,
    churn_date,
    reason_code,
    refund_amount_usd,
    preceding_upgrade_flag,
    preceding_downgrade_flag,
    is_reactivation,
    feedback_text
)
SELECT
    churn_event_id,
    account_id,
    STR_TO_DATE(churn_date, '%Y-%m-%d'),
    reason_code,
    CAST(refund_amount_usd AS DECIMAL(10,2)),
    CASE WHEN preceding_upgrade_flag = 'True' THEN 1 ELSE 0 END,
    CASE WHEN preceding_downgrade_flag = 'True' THEN 1 ELSE 0 END,
    CASE WHEN is_reactivation = 'True' THEN 1 ELSE 0 END,
    feedback_text
FROM churn_events_raw;

select * from churn_events limit 10;
