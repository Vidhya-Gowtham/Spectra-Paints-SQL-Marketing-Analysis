-- Spectra Paints: SQL Marketing Analysis (MySQL)

-- 1. Business snapshot
SELECT COUNT(DISTINCT Item_Category) FROM sqlproject_item;                       -- 5 categories
SELECT COUNT(DISTINCT couponType)    FROM sqlproject_couponmapping;              -- 2 coupon types
SELECT COUNT(DISTINCT State)         FROM sqlproject_citydata;                   -- 21 states
SELECT COUNT(DISTINCT OrderType)     FROM sqlproject_customertransactiondata;    -- 3 order types

-- 2. Transactions by year, quarter, year-month
SELECT YEAR(PurchaseDate) AS yr, COUNT(Trans_Id) AS transactions
FROM sqlproject_customertransactiondata
GROUP BY YEAR(PurchaseDate) ORDER BY transactions DESC;

SELECT QUARTER(PurchaseDate) AS qtr, COUNT(Trans_Id) AS transactions
FROM sqlproject_customertransactiondata
GROUP BY QUARTER(PurchaseDate) ORDER BY transactions DESC;

SELECT YEAR(PurchaseDate) AS yr, MONTH(PurchaseDate) AS mth, COUNT(Trans_Id) AS transactions
FROM sqlproject_customertransactiondata
GROUP BY YEAR(PurchaseDate), MONTH(PurchaseDate) ORDER BY transactions DESC;

-- 3. Total purchase amount by category
SELECT pi.Item_Category, SUM(ct.PurchasingAmt) AS total_sales
FROM sqlproject_customertransactiondata ct
LEFT JOIN sqlproject_item pi ON ct.item_id = pi.Item_Id
GROUP BY pi.Item_Category ORDER BY total_sales DESC;

-- 4. Total purchase amount by year and quarter
SELECT YEAR(PurchaseDate) AS yr, QUARTER(PurchaseDate) AS qtr, SUM(PurchasingAmt) AS total_sales
FROM sqlproject_customertransactiondata
GROUP BY YEAR(PurchaseDate), QUARTER(PurchaseDate) ORDER BY total_sales DESC;

-- 5. Total purchase amount by order type
SELECT OrderType, SUM(PurchasingAmt) AS total_sales
FROM sqlproject_customertransactiondata
GROUP BY OrderType ORDER BY total_sales DESC;

-- 6. Total purchase amount by city tier
SELECT cd.CityTier, SUM(ct.PurchasingAmt) AS total_sales
FROM sqlproject_customertransactiondata ct
LEFT JOIN sqlproject_customer c  ON ct.Cust_Id = c.Customer_Id
LEFT JOIN sqlproject_citydata cd ON c.City_Id  = cd.City_Id
GROUP BY cd.CityTier ORDER BY total_sales DESC;

-- 7. Transactions with vs without a campaign coupon
SELECT COUNT(Trans_Id) FROM sqlproject_customertransactiondata WHERE campaign_id IS NULL
UNION
SELECT COUNT(Trans_Id) FROM sqlproject_customertransactiondata WHERE campaign_id IS NOT NULL;

-- 8. Customers whose first purchase used / did not use a campaign coupon
WITH vid AS (
    SELECT Cust_Id, campaign_id,
           ROW_NUMBER() OVER (PARTITION BY Cust_Id ORDER BY PurchaseDate) AS rn
    FROM sqlproject_customertransactiondata
)
SELECT SUM(campaign_id IS NOT NULL) AS first_purchase_with_coupon,
       SUM(campaign_id IS NULL)     AS first_purchase_without_coupon
FROM vid WHERE rn = 1;

-- 9. Yearly growth: quantity, sales and customers
SELECT YEAR(PurchaseDate) AS yr, SUM(quantity) AS units_sold,
       SUM(PurchasingAmt) AS sales, COUNT(DISTINCT Cust_Id) AS customers
FROM sqlproject_customertransactiondata
GROUP BY YEAR(PurchaseDate) ORDER BY yr;

-- 10. Distinct customers by order type
SELECT OrderType, COUNT(DISTINCT Cust_Id) AS customers
FROM sqlproject_customertransactiondata GROUP BY OrderType;

-- 11. Household income classes (percent rank) and top 2 products per class
WITH hh_cust AS (
    SELECT DISTINCT Cust_Id FROM sqlproject_customertransactiondata WHERE OrderType = 'Household'
),
ranked AS (
    SELECT c.Customer_Id, PERCENT_RANK() OVER (ORDER BY c.Income_bracket) AS pr
    FROM sqlproject_customer c JOIN hh_cust h ON c.Customer_Id = h.Cust_Id
),
classes AS (
    SELECT Customer_Id,
           CASE WHEN pr <= 0.33 THEN 'low class'
                WHEN pr <= 0.66 THEN 'middle class'
                ELSE 'high class' END AS income_class
    FROM ranked
),
product_counts AS (
    SELECT cl.income_class, t.item_id, COUNT(*) AS times_bought
    FROM sqlproject_customertransactiondata t
    JOIN classes cl ON t.Cust_Id = cl.Customer_Id
    WHERE t.OrderType = 'Household'
    GROUP BY cl.income_class, t.item_id
),
final AS (
    SELECT *, DENSE_RANK() OVER (PARTITION BY income_class ORDER BY times_bought DESC) AS drk
    FROM product_counts
)
SELECT income_class, item_id, times_bought, drk
FROM final WHERE drk <= 2 ORDER BY income_class, drk;

-- 12. Customers below age 12
WITH vid AS (
    SELECT Customer_Id,
           TIMESTAMPDIFF(YEAR, STR_TO_DATE(Birthdate, '%Y-%m-%d'), CURDATE()) AS age
    FROM sqlproject_customer
)
SELECT COUNT(*) AS total_customers_below_12 FROM vid WHERE age < 12;   -- 0

-- 13. Product pairs bought by the same customer (customer-level market basket)
SELECT C1.item_id AS id1, C2.item_id AS id2, COUNT(DISTINCT C1.Cust_Id) AS customers
FROM sqlproject_customertransactiondata C1
JOIN sqlproject_customertransactiondata C2
  ON C1.Cust_Id = C2.Cust_Id AND C1.OrderType = C2.OrderType
WHERE C1.item_id < C2.item_id
GROUP BY C1.item_id, C2.item_id
HAVING COUNT(DISTINCT C1.Cust_Id) >= 3
ORDER BY customers DESC;
