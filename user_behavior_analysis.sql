WITH cleaned_users AS (
    SELECT
        user_id,
        promo_signup_flag,
        SPLIT_PART(
            REPLACE(REPLACE(TRIM(signup_datetime), '.', '-'), '/', '-'),
            ' ',
            1
        ) AS signup_datetime_clean
    FROM cohort_users_raw
),
users_parsed AS (
    SELECT
        user_id,
        promo_signup_flag,
        CASE
            WHEN signup_datetime_clean ~ '^\d{1,2}-\d{1,2}-\d{4}$'
            THEN TO_DATE(signup_datetime_clean, 'DD-MM-YYYY')
            WHEN signup_datetime_clean ~ '^\d{1,2}-\d{1,2}-\d{2}$'
            THEN TO_DATE(signup_datetime_clean, 'DD-MM-YY')
            ELSE NULL
        END AS signup_date
    FROM cleaned_users
),

cleaned_events AS (
    SELECT
        event_id,
        user_id,
        event_type,
        revenue,
        SPLIT_PART(
            REPLACE(REPLACE(TRIM(event_datetime), '.', '-'), '/', '-'),
            ' ',
            1
        ) AS event_datetime_clean
    FROM cohort_events_raw
),

events_parsed AS (
    SELECT
        event_id,
        user_id,
        event_type,
        revenue,
        CASE
            WHEN event_datetime_clean ~ '^\d{1,2}-\d{1,2}-\d{4}$'
            THEN TO_DATE(event_datetime_clean, 'DD-MM-YYYY')
            WHEN event_datetime_clean ~ '^\d{1,2}-\d{1,2}-\d{2}$'
            THEN TO_DATE(event_datetime_clean, 'DD-MM-YY')
            ELSE NULL
        END AS event_date
    FROM cleaned_events
),

joined_data AS (
    SELECT
        u.user_id,
        u.promo_signup_flag,
        DATE_TRUNC('month', u.signup_date)::date AS cohort_month,
        DATE_TRUNC('month', e.event_date)::date AS event_month,
        (
            EXTRACT(YEAR FROM DATE_TRUNC('month', e.event_date)) * 12 +
            EXTRACT(MONTH FROM DATE_TRUNC('month', e.event_date))
            -
            EXTRACT(YEAR FROM DATE_TRUNC('month', u.signup_date)) * 12 -
            EXTRACT(MONTH FROM DATE_TRUNC('month', u.signup_date))
        ) AS month_offset
    FROM users_parsed u
    JOIN events_parsed e
        ON u.user_id = e.user_id
    WHERE u.signup_date IS NOT NULL
      AND e.event_date IS NOT NULL
      AND e.event_type IS NOT NULL
      AND e.event_type != 'test_event'
)

SELECT
    promo_signup_flag,
    cohort_month,
    month_offset,
    COUNT(DISTINCT user_id) AS users_total
FROM joined_data
WHERE event_month BETWEEN DATE '2025-01-01' AND DATE '2025-06-30'
GROUP BY
    promo_signup_flag,
    cohort_month,
    month_offset
ORDER BY
    promo_signup_flag,
    cohort_month,
    month_offset;
