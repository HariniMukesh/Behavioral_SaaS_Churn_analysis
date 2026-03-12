/* ==========================================
Behavioral Churn & Revenue Intelligence
Exploratory SQL Analysis
Dataset: RavenStack SaaS CRM
Goal: Understand customer behavior leading to churn
========================================== */

USE ravenstack_analytics;

/* =====================================================
Step 1: Dataset size overview
Goal: Understand scale of the system before analysis.
This helps validate whether we have enough behavioral
data (usage, tickets, churn events) to study patterns.
-- ===================================================== */

SELECT 'accounts' AS table_name, COUNT(*) AS total_rows FROM accounts
UNION ALL
SELECT 'subscriptions', COUNT(*) FROM subscriptions
UNION ALL
SELECT 'feature_usage', COUNT(*) FROM feature_usage
UNION ALL
SELECT 'support_tickets', COUNT(*) FROM support_tickets
UNION ALL
SELECT 'churn_events', COUNT(*) FROM churn_events;

/* 
Observation:
The dataset represents a SaaS CRM platform with 500 customer accounts.
There are significantly more subscription records (5000), indicating that
customers change plans, renew, or reactivate over time.
Behavioral data is available through feature usage (25000 events) and
support tickets (2000 records), which enables analysis of engagement
and support interactions before churn.
*/


/*=====================================================
Step 2: Active accounts
Goal: Identify how many customers currently have
active subscriptions (end_date IS NULL).
This approximates the active customer base.
=====================================================*/

SELECT COUNT(DISTINCT account_id) AS active_accounts
FROM subscriptions
WHERE end_date IS NULL;

/*Observation:
500 accounts currently have active subscriptions (end_date IS NULL).
However, subscription records total 5000, meaning each customer has
multiple subscription lifecycle events such as upgrades, renewals,
or plan changes.*/


/* =====================================================
Step 3: Current Monthly Recurring Revenue (MRR)
Goal: Estimate current revenue from active customers.
We only take the latest active subscription per account
to avoid double counting historical plan changes.
=====================================================*/

SELECT SUM(mrr_amount) AS current_mrr
FROM subscriptions s
WHERE end_date IS NULL
AND start_date = (
    SELECT MAX(start_date)
    FROM subscriptions s2
    WHERE s2.account_id = s.account_id
);

/* -- Observation:
Current MRR is calculated using only the latest active subscription
per account to avoid counting historical subscription changes.
This represents the estimated monthly revenue generated from
currently active customers.*/

/*=====================================================
Step 4: Average Revenue Per Account (ARPA)
Goal: Estimate average customer value.
ARPA = Total MRR / Active Accounts
=====================================================*/

SELECT ROUND(SUM(mrr_amount) / COUNT(DISTINCT account_id),2) AS arpa
FROM subscriptions s
WHERE end_date IS NULL
AND start_date = (
    SELECT MAX(start_date)
    FROM subscriptions s2
    WHERE s2.account_id = s.account_id
);

/* Observation:
ARPA represents the average revenue generated per active customer.
The value (~$2597) suggests the product targets mid-sized businesses
rather than individual users.*/


/* =====================================================
Step 5: Historical churn rate
Goal: Measure how many customers churned at least once
during the dataset history.
Note: This is NOT a monthly churn rate.
-- =====================================================*/

SELECT 
    COUNT(DISTINCT ce.account_id) AS churned_accounts,
    COUNT(DISTINCT a.account_id) AS total_accounts,
    ROUND(
        COUNT(DISTINCT ce.account_id) /
        COUNT(DISTINCT a.account_id) * 100,
        2
    ) AS churn_rate_percent
FROM accounts a
LEFT JOIN churn_events ce
ON a.account_id = ce.account_id;

/* Observation:
Approximately 70% of accounts have churned at least once in the
dataset history. This is a historical churn metric rather than
a monthly churn rate.
Because churn events include reactivations, some customers churn
multiple times across the lifecycle.*/


/* =====================================================
Investigation: subscription lifecycle
Observation: Unexpected churn values prompted
investigation into subscription structure.
Result: Each account has multiple subscriptions
(plan changes, renewals, upgrades).
=====================================================*/

SELECT account_id, COUNT(subscription_id) AS total_sub
FROM subscriptions
GROUP BY account_id
ORDER BY COUNT(subscription_id) DESC
LIMIT 10;

/* Observation:
Some accounts have more than 15 subscription records.
This confirms that the subscriptions table captures plan changes,
renewals, and upgrades rather than a single active plan per customer.*/


/* =====================================================
Investigation: churn frequency per customer
Observation: Some accounts churn multiple times.
This confirms the dataset models churn + reactivation.
=====================================================*/

SELECT account_id, COUNT(*) AS churn_times
FROM churn_events
GROUP BY account_id
ORDER BY churn_times DESC
LIMIT 10;

/* Observation:
Some accounts appear multiple times in the churn_events table,
confirming that customers can churn and later reactivate.
This reflects realistic SaaS customer lifecycles.*/


/* =====================================================
Step 6: Initial churn analysis by plan tier
Observation: Direct grouping by subscriptions table
may produce misleading results because customers can
switch between plan tiers over time.
-- =====================================================*/

SELECT 
    s.plan_tier, 
    COUNT(DISTINCT ce.account_id) AS churned_accounts,
    COUNT(DISTINCT s.account_id) AS total_accounts,
    ROUND(
        COUNT(DISTINCT ce.account_id) / 
        COUNT(DISTINCT s.account_id) * 100,
        2
    ) AS churn_rate
FROM subscriptions s
LEFT JOIN churn_events ce
ON s.account_id = ce.account_id
GROUP BY s.plan_tier
ORDER BY churn_rate DESC;


/* =====================================================
Step 6 (corrected): plan tier at time of churn
Goal: Identify the subscription plan active when the
churn event occurred.
===================================================== */

SELECT 
    s.plan_tier,
    COUNT(*) AS churn_count
FROM churn_events ce
JOIN subscriptions s
    ON ce.account_id = s.account_id
WHERE ce.churn_date BETWEEN s.start_date 
                        AND COALESCE(s.end_date, '2099-12-31')
GROUP BY s.plan_tier
ORDER BY churn_count DESC;

/* Observation:
Initial churn analysis grouped by subscriptions table produced
misleading results because customers may appear in multiple plan
tiers due to upgrades or downgrades.
A corrected query identifies the plan tier active at the time
of churn.*/


/* =====================================================
Step 7: Support ticket activity by customer
Goal: Explore whether ticket volume correlates with
churn behavior.
-- =====================================================*/

SELECT 
    a.account_id,
    COUNT(st.ticket_id) AS ticket_count,
    CASE 
        WHEN ce.account_id IS NULL THEN 'active'
        ELSE 'churned'
    END AS customer_status
FROM accounts a
LEFT JOIN support_tickets st
    ON a.account_id = st.account_id
LEFT JOIN churn_events ce
    ON a.account_id = ce.account_id
GROUP BY a.account_id
LIMIT 10;

/* Observation:
Support ticket activity varies across customers, indicating
different levels of interaction with the support system.
This metric will be used to explore whether customer support
interactions correlate with churn behavior.*/


/* =====================================================
Step 8: Average ticket count by churn status
Observation: Active customers submit slightly more
tickets than churned customers.
Insight: Ticket volume alone may represent engagement
rather than dissatisfaction.
-- ===================================================== */

SELECT 
    CASE
        WHEN ce.account_id IS NULL THEN 'active'
        ELSE 'churned'
    END AS customer_status,
    AVG(ticket_counts.ticket_count) AS avg_ticket
FROM (
    SELECT 
        a.account_id,
        COUNT(st.ticket_id) AS ticket_count
    FROM accounts a
    LEFT JOIN support_tickets st
        ON a.account_id = st.account_id
    GROUP BY a.account_id
) ticket_counts
LEFT JOIN churn_events ce
    ON ticket_counts.account_id = ce.account_id
GROUP BY customer_status;

/* Observation:
Active customers submit slightly more support tickets than
churned customers on average.
This suggests that ticket volume alone may represent customer
engagement rather than dissatisfaction.*/

/* -- =====================================================
Step 9: Product engagement analysis
Goal: test whether lower product engagement correlates with churn.
Engagement is measured using feature usage frequency and duration.
=====================================================*/
-- Total usage per customer

SELECT
    a.account_id,
    SUM(fu.usage_count) AS total_usage,
    SUM(fu.usage_duration_secs) AS total_duration,
    CASE
        WHEN ce.account_id IS NULL THEN 'active'
        ELSE 'churned'
	END AS customer_status
FROM accounts a
LEFT JOIN subscriptions s
     ON a.account_id = s.account_id
LEFT JOIN feature_usage fu
     ON s.subscription_id = fu.subscription_id
LEFT JOIN churn_events ce 
     ON a.account_id = ce.account_id
GROUP BY a.account_id;

-- Average enagement by customer status
SELECT 
    customer_status,
    AVG(total_usage) AS avg_usage,
    AVG(total_duration) AS avg_duration
FROM (
    SELECT 
        a.account_id,
        SUM(fu.usage_count) AS total_usage,
        SUM(fu.usage_duration_secs) AS total_duration,
        CASE 
            WHEN ce.account_id IS NULL THEN 'active'
            ELSE 'churned'
        END AS customer_status
    FROM accounts a
    LEFT JOIN subscriptions s
        ON a.account_id = s.account_id
    LEFT JOIN feature_usage fu
        ON s.subscription_id = fu.subscription_id
    LEFT JOIN churn_events ce
        ON a.account_id = ce.account_id
    GROUP BY a.account_id
) engagement_summary
GROUP BY customer_status;

/* Observation:
Contrary to the initial hypothesis, churned customers show higher
lifetime feature usage and usage duration than active customers.
This suggests churn may occur among highly engaged users whose
expectations were not met, rather than disengaged users.

Because this metric uses lifetime usage totals, it may mask
engagement decline shortly before churn. */

/* =====================================================
Step 10: Product errors vs churn
Goal: Test whether customers experiencing more errors
are more likely to churn.
======================================================== */

SELECT 
	customer_status,
    AVG(total_errors) AS avg_errors
FROM (
    SELECT
		a.account_id,
        SUM(fu.error_count) as total_errors,
        CASE
            WHEN ce.account_id IS NULL THEN 'active'
            ELSE 'churned'
		END AS customer_status
	FROM accounts a 
    LEFT JOIN subscriptions s 
         ON a.account_id = s.account_id
	LEFT JOIN feature_usage fu
         ON s.subscription_id = fu.subscription_id
	LEFT JOIN churn_events ce
         ON a.account_id = ce.account_id
	GROUP BY a.account_id
) error_summary
GROUP BY customer_status;

/* Observation:
Churned customers experience significantly higher product error counts
compared to active customers.

Avg errors (churned): ~48
Avg errors (active):  ~28

This suggests product reliability issues may contribute to churn,
making error frequency a strong candidate feature for churn prediction. */

/* =====================================================
Step 11: Feature diversity per customer
Goal : Measure how many unique product features each
customer interacts with?
Hypothesis : Customers using more features may have 
deeper product adoption and lower churn risk.
======================================================== */

SELECT 
    a.account_id,
    COUNT(DISTINCT fu.feature_name) AS unique_features_used,
    CASE 
        WHEN ce.account_id IS NULL THEN 'active'
        ELSE 'churned'
    END AS customer_status
FROM accounts a
LEFT JOIN subscriptions s
    ON a.account_id = s.account_id
LEFT JOIN feature_usage fu
    ON s.subscription_id = fu.subscription_id
LEFT JOIN churn_events ce
    ON a.account_id = ce.account_id
GROUP BY a.account_id order by unique_features_used asc limit 5;

select * from churn_events where account_id = 'A-751bd4'; 
-- 40 feature usage - reason_code: Support - Feedback_text: too expensive
-- 9 feature usage - reason_code: Budget - Feedback_text: blank

-- Step 12: Average feature diversity by churn status

SELECT 
    customer_status,
    AVG(unique_features_used) AS avg_features_used
FROM (
    SELECT 
        a.account_id,
        COUNT(DISTINCT fu.feature_name) AS unique_features_used,
        CASE 
            WHEN ce.account_id IS NULL THEN 'active'
            ELSE 'churned'
        END AS customer_status
    FROM accounts a
    LEFT JOIN subscriptions s
        ON a.account_id = s.account_id
    LEFT JOIN feature_usage fu
        ON s.subscription_id = fu.subscription_id
    LEFT JOIN churn_events ce
        ON a.account_id = ce.account_id
    GROUP BY a.account_id
) feature_summary
GROUP BY customer_status;

/* Observation:
The average number of unique features used is nearly identical
for churned and active customers (~27 features).

This suggests feature diversity alone does not explain churn.
Both highly engaged and lightly engaged customers can churn
for different reasons such as pricing, support issues, or budget.*/

/* =====================================================
Step 13: churn reason distribution
Goal: identify the most common reasons customers cite
when cancelling subscriptions.
===================================================== */

SELECT 
    reason_code,
    COUNT(*) AS churn_count,
    ROUND(COUNT(*) * 100.0 / SUM(COUNT(*)) OVER(),2) AS percent_share
FROM churn_events
GROUP BY reason_code
ORDER BY churn_count DESC;

/* Observation:
Product-related reasons (features and support) represent
a large share of churn events, suggesting product quality
and capability gaps may be key retention challenges.
If we group them conceptually:
___________________________________________________
Category	        | Reasons	           | Share |
Product experience	| Features + Support   | 36%   |
Financial	        | Budget + Pricing	   | 32%   |
Market competition	| Competitor	       | 15%   |

That means over one-third of churn relates to product 
capability or support experience.*/

/* =====================================================
Step 14: Average product errors by churn reason
Goal: determine whether specific churn reasons are
associated with higher product error frequency.
===================================================== */

SELECT 
    ce.reason_code,
    AVG(fu.error_count) AS avg_errors
FROM churn_events ce
JOIN subscriptions s
    ON ce.account_id = s.account_id
JOIN feature_usage fu
    ON s.subscription_id = fu.subscription_id
GROUP BY ce.reason_code
ORDER BY avg_errors DESC;

-- Product errors do not strongly differentiate churn reasons.


/* =====================================================
Step 15: feature usage by churn reason
Goal: evaluate whether engagement levels differ across
churn reasons.
===================================================== */

SELECT 
    ce.reason_code,
    AVG(fu.usage_count) AS avg_usage
FROM churn_events ce
JOIN subscriptions s
    ON ce.account_id = s.account_id
JOIN feature_usage fu
    ON s.subscription_id = fu.subscription_id
GROUP BY ce.reason_code
ORDER BY avg_usage DESC;

-- Feature usage levels are similar across churn reasons.

/* Observation:
Feature usage and product error rates show minimal variation
across different churn reasons. This suggests behavioral
engagement metrics alone do not fully explain the motivations
behind customer churn.

However, overall churn analysis earlier indicated that churned
customers experience significantly higher error counts than
active customers, suggesting product reliability may still be
an important retention factor. */

/* =====================================================
Step 16: Customer lifetime before churn
Goal: measure how long customers stay before churn.
This helps determine whether churn occurs early in
the customer lifecycle or after long-term usage.
===================================================== */

SELECT 
    ce.account_id,
    DATEDIFF(ce.churn_date, a.signup_date) AS lifetime_days
FROM churn_events ce
JOIN accounts a
    ON ce.account_id = a.account_id;
 
 
-- Step 17: Average lifetime before churn

SELECT 
    AVG(DATEDIFF(ce.churn_date, a.signup_date)) AS avg_lifetime_days,
    MIN(DATEDIFF(ce.churn_date, a.signup_date)) AS min_lifetime_days,
    MAX(DATEDIFF(ce.churn_date, a.signup_date)) AS max_lifetime_days
FROM churn_events ce
JOIN accounts a
    ON ce.account_id = a.account_id;
    
-- The average customer stays about 6 months before churning.

-- Step 18: churn lifecycle stage

SELECT 
    CASE
        WHEN DATEDIFF(ce.churn_date, a.signup_date) <= 90 THEN 'early churn'
        WHEN DATEDIFF(ce.churn_date, a.signup_date) <= 365 THEN 'mid-term churn'
        ELSE 'late churn'
    END AS churn_stage,
    COUNT(*) AS churn_count
FROM churn_events ce
JOIN accounts a
    ON ce.account_id = a.account_id
GROUP BY churn_stage;

-- Most churn occurs within the first year of customer lifecycle.

/* Observation:
Customer lifetime analysis shows that most churn occurs within
the first year of the customer lifecycle. Early and mid-term churn
together represent approximately 85% of all churn events.

This suggests that onboarding experience, early product value,
and initial customer satisfaction may play a critical role in
long-term retention.*/

/* ===========================================================
Step 19: churned customers and currently active customers
==============================================================*/
-- customer acquisition by year

SELECT 
    YEAR(signup_date) AS signup_year,
    COUNT(*) AS customers_acquired
FROM accounts
GROUP BY signup_year
ORDER BY signup_year;

-- churned customers

SELECT 
    COUNT(DISTINCT account_id) AS churned_customers
FROM churn_events;

-- currently active customers

SELECT 
    COUNT(DISTINCT account_id) AS active_customers
FROM subscriptions
WHERE end_date IS NULL;

SELECT 
    COUNT(*) AS reactivations
FROM churn_events
WHERE is_reactivation = TRUE;

-- Latest subscription per customer

SELECT COUNT(*) AS current_active_customers
FROM (
    SELECT 
        account_id,
        MAX(start_date) AS latest_start
    FROM subscriptions
    GROUP BY account_id
) latest
JOIN subscriptions s
ON latest.account_id = s.account_id
AND latest.latest_start = s.start_date
WHERE s.end_date IS NULL;

/* Observation:
After accounting for subscription lifecycle, the number of
currently active customers is 483 out of 500 acquired accounts.

This indicates that many customers who churned earlier later
reactivated and resumed using the product.
The dataset therefore represents a customer lifecycle model
where churn does not always imply permanent customer loss.*/

-- Step 20: Revenue lost by churn reason

SELECT 
    ce.reason_code,
    SUM(s.mrr_amount) AS revenue_lost
FROM churn_events ce
JOIN subscriptions s
    ON ce.account_id = s.account_id
WHERE ce.churn_date BETWEEN s.start_date 
                        AND COALESCE(s.end_date, '2099-12-31')
GROUP BY ce.reason_code
ORDER BY revenue_lost DESC;

/* Observation:
Revenue impact analysis shows that feature-related churn results
in the highest financial loss (~1.33M), followed by budget and
support-related churn.

This suggests that product capability gaps and customer support
experience may be the most critical drivers of revenue loss.
Addressing these areas could significantly improve retention.*/

/* =====================================================
Step 21: Support experience vs churn
Goal: Compare support experience between churned
and active customers
========================================================*/

SELECT 
    CASE 
        WHEN ce.account_id IS NULL THEN 'active'
        ELSE 'churned'
    END AS customer_status,
    
    AVG(st.first_response_time_minutes) AS avg_first_response_time,
    AVG(st.resolution_time_hours) AS avg_resolution_time,
    AVG(st.satisfaction_score) AS avg_satisfaction_score

FROM support_tickets st
LEFT JOIN churn_events ce
    ON st.account_id = ce.account_id

GROUP BY customer_status;

/* Observation: 
Support response speed and resolution time do not strongly differentiate churned vs active customers.
Customer support performance does not appear to be a major driver of churn in this dataset.*/

-- Escalation rate by customer churn status
SELECT 
    CASE 
        WHEN ce.account_id IS NULL THEN 'active'
        ELSE 'churned'
    END AS customer_status,    
    COUNT(*) AS total_tickets,
    SUM(st.escalation_flag) AS escalated_tickets,    
    ROUND(
        SUM(st.escalation_flag) / COUNT(*) * 100,
        2
    ) AS escalation_rate_percent

FROM support_tickets st
LEFT JOIN churn_events ce
    ON st.account_id = ce.account_id

GROUP BY customer_status;

/* Observation:
Customers who experience severe issues are more likely to churn.
Escalation rate is higher for churned customers.
5.36% vs 3.97%*/

-- Plan change behavior before churn ?

SELECT 
    COUNT(*) AS total_churn_events,
    
    SUM(preceding_upgrade_flag) AS churn_after_upgrade,
    
    SUM(preceding_downgrade_flag) AS churn_after_downgrade

FROM churn_events;
-- A significant portion of customers churn shortly after upgrading their plan.

/*Customers actively use the product but experience higher error rates and occasional severe issues. 
Feature limitations and unmet expectations, especially after upgrading plans, contribute significantly to churn. 
These feature-related churn events represent the largest source of revenue loss for the business.*/

-- =====================================================
-- MODEL DATASET (CLEAN VERSION)
-- One row per account with behavioral signals
-- =====================================================

WITH usage_metrics AS (

    SELECT
        s.account_id,
        SUM(fu.usage_count) AS total_usage,
        SUM(fu.error_count) AS total_errors,
        COUNT(DISTINCT fu.feature_name) AS features_used
    FROM subscriptions s
    LEFT JOIN feature_usage fu
        ON s.subscription_id = fu.subscription_id
    GROUP BY s.account_id

),

ticket_metrics AS (

    SELECT
        account_id,
        COUNT(ticket_id) AS ticket_count,
        AVG(satisfaction_score) AS avg_satisfaction_score
    FROM support_tickets
    GROUP BY account_id

)

SELECT
    a.account_id,
    a.plan_tier,
    a.seats,

    COALESCE(u.total_usage,0) AS total_usage,
    COALESCE(u.total_errors,0) AS total_errors,
    COALESCE(u.features_used,0) AS features_used,

    COALESCE(t.ticket_count,0) AS ticket_count,
    COALESCE(t.avg_satisfaction_score,0) AS avg_satisfaction_score,

    a.churn_flag

FROM accounts a

LEFT JOIN usage_metrics u
    ON a.account_id = u.account_id

LEFT JOIN ticket_metrics t
    ON a.account_id = t.account_id;


CREATE VIEW churn_model_dataset AS
WITH usage_metrics AS (

    SELECT
        s.account_id,
        SUM(fu.usage_count) AS total_usage,
        SUM(fu.error_count) AS total_errors,
        COUNT(DISTINCT fu.feature_name) AS features_used
    FROM subscriptions s
    LEFT JOIN feature_usage fu
        ON s.subscription_id = fu.subscription_id
    GROUP BY s.account_id

),

ticket_metrics AS (

    SELECT
        account_id,
        COUNT(ticket_id) AS ticket_count,
        AVG(satisfaction_score) AS avg_satisfaction_score
    FROM support_tickets
    GROUP BY account_id

)

SELECT
    a.account_id,
    a.plan_tier,
    a.seats,

    COALESCE(u.total_usage,0) AS total_usage,
    COALESCE(u.total_errors,0) AS total_errors,
    COALESCE(u.features_used,0) AS features_used,

    COALESCE(t.ticket_count,0) AS ticket_count,
    COALESCE(t.avg_satisfaction_score,0) AS avg_satisfaction_score,

    a.churn_flag

FROM accounts a

LEFT JOIN usage_metrics u
    ON a.account_id = u.account_id

LEFT JOIN ticket_metrics t
    ON a.account_id = t.account_id;

SELECT count(*) FROM churn_model_dataset;

SELECT * FROM churn_model_dataset;

