use mintclassics;

-- Project: Mint Classics Inventory Optimization

show tables;

SELECT table_name FROM information_schema.tables WHERE table_schema = 'mintclassics';

describe products;
select * from products
limit 5;

-- Check total scale of the business
select distinct count(*) as total_customer from customers;
select distinct count(*) as total_employees from employees;

-- Audit order line values to understand revenue distribution
select max(quantityOrdered*priceEach) as max_line, 
min(quantityOrdered*priceEach) as min_line,
avg(quantityOrdered*priceEach) as avg_line from orderdetails;

-- SECTION 2: SALES PATTERN & DISCOUNT ANALYSIS
-- Investigating if price discounts (MSRP vs Actual Price) drive higher volume.
select o.productCode,p.productName, max(quantityOrdered*priceEach) as max_line,
min(quantityOrdered*priceEach) as min_line,
avg(quantityOrdered*priceEach) as avg_line
from orderdetails o
join products p using(productCode)
GROUP BY productCode
order by max_line desc;

select o.productCode,p.productName, (quantityOrdered*priceEach) as max_line from orderdetails o
join products p using(productCode)
where (quantityOrdered*priceEach) = 11503.14
;

-- SECTION 2: SALES PATTERN & DISCOUNT ANALYSIS
-- Investigating if price discounts (MSRP vs Actual Price) drive higher volume.
select o.productCode,p.productName,MSRP, count(*) total_orders, sum(quantityOrdered) as total_qty_sold,
avg(priceEach) as avg_price, (MSRP-avg(priceEach)) as discount from orderdetails O
left JOIN products p using(productCode)
group by o.productCode,p.productName,MSRP
order by discount desc;


select p.productCode,p.productName, p.quantityInStock,
(quantityInStock*0.95) as projectstock,
sum(o.quantityOrdered) as total_sold,
(p.quantityInStock / SUM(o.quantityOrdered)) AS years_of_inventory from products p
join orderDetails o using(productCode)
join orders ord using(orderNumber)
group by p.productCode,p.productName 
having sum(o.quantityOrdered) > (quantityInStock*0.95)
order by total_sold desc ;

-- SECTION 3: INVENTORY VELOCITY (THE "STOCKS-TO-SALES" RATIO)

select max(orderDate),min(orderDate),
datediff(max(orderDate),min(orderDate))/365 as total_years
from orders;

-- SECTION 4: WAREHOUSE PERFORMANCE (STRATEGIC RECOMMENDATION)
SELECT 
    p.productCode, 
    p.productName,
    p.quantityInStock,
    SUM(od.quantityOrdered) AS total_lifetime_sales,
    -- Step 1: Calculate total sales / 2.5 years
    (SUM(od.quantityOrdered) / 2.42) AS avg_annual_sales, 
    -- Step 2: Compare Stock to Annual Sales
    p.quantityInStock / (SUM(od.quantityOrdered) / 2.42) AS years_of_stock_remaining
FROM products p
JOIN orderdetails od USING (productCode)
JOIN orders o USING (orderNumber)
GROUP BY p.productCode
ORDER BY years_of_stock_remaining DESC;


SELECT 
    warehouseCode,
    COUNT(productCode) AS item_count,
    -- We calculate the average of (Current Stock / Annual Sales)
    AVG(quantityInStock / (total_sold / 2.42)) AS avg_years_of_stock
FROM (
    SELECT 
        p.productCode, 
        p.warehouseCode, 
        p.quantityInStock, 
        SUM(od.quantityOrdered) AS total_sold
    FROM products p
    JOIN orderdetails od USING (productCode)
    GROUP BY p.productCode, p.warehouseCode, p.quantityInStock
) AS product_sales_summary
GROUP BY warehouseCode
ORDER BY avg_years_of_stock DESC;


SELECT 
    p.productCode, 
    p.productName,
    p.warehouseCode,
    p.quantityInStock,
    SUM(od.quantityOrdered) AS total_lifetime_sales,
    -- Step 1: Calculate total sales / 2.5 years
    (SUM(od.quantityOrdered) / 2.42) AS avg_annual_sales, 
    -- Step 2: Compare Stock to Annual Sales
    p.quantityInStock / (SUM(od.quantityOrdered) / 2.42) AS years_of_stock_remaining
FROM products p
left JOIN orderdetails od USING (productCode)
left JOIN orders o USING (orderNumber)
GROUP BY p.productCode,p.warehouseCode
having years_of_stock_remaining > 15
ORDER BY years_of_stock_remaining DESC;

WITH ProductSales AS (
    SELECT 
        productCode, 
        SUM(quantityOrdered) AS total_sold
    FROM orderdetails
    GROUP BY productCode
)
SELECT 
    p.warehouseCode,
    COUNT(p.productCode) AS unique_products,
    ROUND(AVG(p.quantityInStock / (ps.total_sold / 2.42)), 2) AS avg_years_stock
FROM products p
JOIN ProductSales ps ON p.productCode = ps.productCode
GROUP BY p.warehouseCode
ORDER BY avg_years_stock DESC;


 -- SECTION 5: OUTLIER ANALYSIS (SUBQUERY PRACTICE)
-- Finding orders and warehouses that significantly exceed the average.
select orderNumber, sum(quantityOrdered * priceEach) as total_price from orderdetails
group by orderNumber
having sum(quantityOrdered * priceEach) > (select avg(total_price) from(
select orderNumber, sum(quantityOrdered * priceEach) as total_price from orderdetails
group by orderNumber) as order_summary)
;

select productName, sum(buyPrice) as total_price from products
group by productName
having sum(buyPrice) > (select avg(total_price) from (
select productName, sum(buyPrice) as total_price from products
group by productName)as product_sales);

select productCode, sum(quantityOrdered) as total_qty from orderdetails
group by productCode
having sum(quantityOrdered) >(select avg(total_qty) from (
select productCode, sum(quantityOrdered) as total_qty from orderdetails
group by productCode) as product_qty );

select orderNumber,sum(quantityOrdered) as total_ordered_qty from orderdetails
group by orderNumber
having sum(quantityOrdered) > (select avg(total_ordered_qty) from (
select  orderNumber,sum(quantityOrdered) as total_ordered_qty from orderdetails
group by orderNumber) as product_qty)
order by total_ordered_qty desc ;

with employee_customer as (select salesRepEmployeeNumber, count(customerName) as total_customer from customers
group by salesRepEmployeeNumber)
select salesRepEmployeeNumber,total_customer from employee_customer
where total_customer > (select avg(total_customer) from employee_customer
where salesRepEmployeeNumber is not null ) ; 


with warehouse_qty as (select warehouseCode, sum(quantityInStock) as total_qty from products
group by warehouseCode)
select warehouseCode, total_qty from warehouse_qty
where total_qty >(select avg(total_qty) from warehouse_qty);