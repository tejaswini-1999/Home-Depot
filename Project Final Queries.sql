--Q1

-- Which store has highest customer retention (flag for determining purchased online or offline - order table) 
-- insert more customers


WITH returning_customers AS ( 
SELECT customerID, COUNT(DISTINCT orderID) AS No_of_orders, Quarter, storeid 
FROM (SELECT orderid, customerid, storeid,
        (CASE WHEN EXTRACT(MONTH from orderdate) BETWEEN 01 AND 03 THEN 'Q1'
            WHEN EXTRACT(MONTH from orderdate) BETWEEN 04 AND 06 THEN 'Q2'
            WHEN EXTRACT(MONTH from orderdate) BETWEEN 07 AND 09 THEN 'Q3'
            ELSE 'Q4' END) as Quarter
    FROM orders) order_quarter
WHERE storeid IS NOT NULL
GROUP BY customerID, Quarter, storeid
HAVING COUNT(orderID) > 1
ORDER BY customerID) 

SELECT city || ', #' || rc.storeID AS StoreName,  COUNT(rc.customerid) AS CustomerCount
FROM returning_customers RC 
JOIN Store S ON RC.storeid = S.storeid
GROUP BY city || ', #' || rc.storeID;

-------------------------------------------------------------------------------------------------------------------

-- Q4 

/*
Identify the top 5 most valuable online customers in terms of their lifetime spending. For these top customers, determine average delivery 
fullfillment time, if there are any specific product categories that these customers frequently order. Provide a breakdown of revenue by product 
category for each of these top customers. (HomeDepot will get to know how to reduce the avg delivery times for these type of customers) */


WITH category_info AS (
    SELECT 
        o.CustomerID, o.orderid, sc.CategoryID, pc.C_name,
        SUM(od.Quantity * od.Unit_Price) AS Category_Spending,
        DENSE_RANK() OVER (partition by o.customerid ORDER BY SUM(od.Quantity * od.Unit_Price) DESC) AS rank_category
        --DENSE_RANK() OVER (PARTITION BY o.CustomerID ORDER BY COUNT(o.OrderID) DESC) AS rank_category
    FROM Orders o
    JOIN Order_details od ON od.OrderID = o.OrderID
    JOIN product P ON od.productID = P.productID
    JOIN SubCategory sc ON P.Sub_category_ID = sc.Sub_category_ID
    JOIN ProductCategory pc ON pc.CategoryID = sc.CategoryID
    WHERE UPPER(o.Order_Flag) = 'ONLINE'
    GROUP BY o.orderid, o.CustomerID, sc.CategoryID, pc.C_name
    ORDER BY o.CustomerID
)
SELECT 
    ci.CustomerID,
    SUM(od.Quantity * od.Unit_Price) AS order_total,
    round(AVG(d.Delivery_Date - cast(o.OrderDate as date)),3) AS avg_delivery_time,
    ci.C_name,
    ci.Category_Spending
FROM category_info ci
JOIN Order_details od ON od.OrderID = ci.OrderID
JOIN Delivery d ON d.Order_ID = od.OrderID
JOIN Orders o ON o.OrderID = od.OrderID
WHERE ci.rank_category = 1
GROUP BY ci.CustomerID, ci.C_name, ci.Category_Spending
ORDER BY order_total DESC
FETCH FIRST 5 ROWS WITH TIES;

-------------------------------------------------------------------------------------------------------------------


-- Q5

-- Sentiment analysis depending on keywork - bad or good quality. Make separate tables for positive and negative reviews. 

WITH rev AS (SELECT p.productid,p_name,
(CASE WHEN UPPER(review_description) LIKE UPPER('%bad%') OR  
    UPPER(review_description) LIKE UPPER('%waste%') OR 
    UPPER(review_description) LIKE UPPER('%pathetic%') OR 
    UPPER(review_description) LIKE UPPER('%worst%') THEN 'Negative' 
    WHEN UPPER(review_description) LIKE UPPER('%good%') OR  
    UPPER(review_description) LIKE UPPER('%great%') OR 
    UPPER(review_description) LIKE UPPER('%excellent%') OR 
    UPPER(review_description) LIKE UPPER('%best%') OR 
    UPPER(review_description) LIKE UPPER('%fantastic%') OR
    UPPER(review_description) LIKE UPPER('%amazing%') THEN 'Positive'
    END) AS Review_Type 
FROM Reviews r
JOIN product p ON p.productid = r.productid) 

SELECT p_name, P_count_rev as Positive_Reviews, N_count_rev as Negative_Reviews,
    (CASE WHEN P_count_rev/(P_count_rev + N_count_rev) >= 0.6 THEN 'Good Quality'
        WHEN N_count_rev/(P_count_rev + N_count_rev) >= 0.6 THEN 'Bad Quality'
        ELSE 'Neutral' END) as Quality 
FROM rev
PIVOT ( 
    COUNT(productid) AS count_rev 
    FOR review_type IN ('Positive' AS P, 'Negative' AS N))
ORDER BY Positive_Reviews DESC ;
-- FETCH FIRST 10 ROWS WITH TIES

-------------------------------------------------------------------------------------------------------------------

-- Q10

/* The company wants to monitor changes in the quantity of products in stock over time to identify trends and potential issues, comparing the current
stock quantity with the previous and next periods */

SELECT ProductID, Stock_date, TO_CHAR(Current_Quantity) Current_Quantity, 
TO_CHAR(Previous_Quantity) Previous_Quantity,  
COALESCE(TO_CHAR(Former_Quantity), 'NA') Former_Quantity, 
COALESCE(TO_CHAR((Current_Quantity - Previous_Quantity)), 'NA') AS Difference, 
COALESCE(ROUND(((Current_Quantity - Previous_Quantity)/Previous_Quantity*100),2),0) || '%' AS Percent_Change 
FROM ( 
    SELECT ProductID, Stock_date, Quantity AS Current_Quantity, 
    LAG(Quantity) OVER (PARTITION BY ProductID ORDER BY Stock_date) AS Previous_Quantity, 
    LAG(Quantity, 2) OVER (PARTITION BY ProductID ORDER BY Stock_date) AS Former_Quantity 
    FROM Stock  
    ORDER BY ProductID, Stock_date) 
WHERE Previous_Quantity IS NOT NULL;

-------------------------------------------------------------------------------------------------------------------

-- Q11 

-- Query to find which products are available online or offline exclusively

WITH store_prods AS (
    SELECT p_name, SP.productID
    FROM store_product SP
    JOIN product P ON SP.productID = P.productID
    MINUS
    SELECT p_name, OP.productID
    FROM online_product OP
    JOIN product P ON OP.productID = P.productID),
    
online_prods AS (
    SELECT p_name, OP.productID
    FROM online_product OP
    JOIN product P ON OP.productID = P.productID
    MINUS
    SELECT p_name, SP.productID
    FROM store_product SP
    JOIN product P ON SP.productID = P.productID)

SELECT 'Store', productID, p_name FROM store_prods
UNION
SELECT 'Online', productID, p_name  FROM online_prods;

-------------------------------------------------------------------------------------------------------------------

--Q12

-- Query to calculate and provide insights on the sales performance of different subcategories of products.

SELECT SC_Name AS Subcategory_Name, SUM(OD.Quantity) AS Total_Quantity_Sold, 
TO_CHAR(SUM(OD.Quantity * OD.Unit_Price), '$999,999,999.99') AS Total_Revenue, 
CONCAT(ROUND((SUM(OD.Quantity * OD.Unit_Price) / (SELECT SUM(OD.Quantity * OD.Unit_Price) 
    FROM ProductCategory PC 
    JOIN Subcategory SC ON PC.categoryID = SC.categoryID 
    JOIN Product P ON P.Sub_category_ID = SC.Sub_category_ID 
    JOIN Order_Details OD ON P.PRODUCTID = OD.PRODUCTID 
    JOIN Orders O ON OD.OrderID = O.OrderID)),4) * 100, '%') AS Revenue_Percentage 
FROM ProductCategory PC 
JOIN Subcategory SC ON PC.categoryID = SC.categoryID 
JOIN Product P ON P.Sub_category_ID = SC.Sub_category_ID 
JOIN Order_Details OD ON P.PRODUCTID = OD.PRODUCTID 
JOIN Orders O ON OD.OrderID = O.OrderID 
GROUP BY ROLLUP (SC_Name) 
HAVING sc_name IS NOT NULL 
ORDER BY revenue_percentage desc; 

-------------------------------------------------------------------------------------------------------------------

commit;

-------------------------------------------------------------------------------------------------------------------

-- TRIGGER 1

-- When an employee is inserted, then it is entered correctly into it's corresponding subclass

CREATE OR REPLACE TRIGGER complex_employee_shift_assignment
AFTER INSERT ON EMPLOYEES
FOR EACH ROW
BEGIN
 IF :NEW.Job_title = 'Manager' THEN
   INSERT INTO STORE_EMPLOYEE (EMPLOYEE_ID, STORE_EMPLOYEE_TYPE) VALUES (:NEW.EMPLOYEE_ID, 'Manager');
   INSERT INTO MANAGERS (EMPLOYEEID) VALUES (:NEW.EMPLOYEE_ID);
 ELSIF :NEW.Job_title = 'Cashier' THEN
   INSERT INTO STORE_EMPLOYEE (EMPLOYEE_ID, STORE_EMPLOYEE_TYPE) VALUES (:NEW.EMPLOYEE_ID, 'Cashier');
   INSERT INTO CASHIER (EMPLOYEEID) VALUES (:NEW.EMPLOYEE_ID);
 ELSIF :NEW.Job_title = 'Attendant' THEN
   INSERT INTO STORE_EMPLOYEE (EMPLOYEE_ID, STORE_EMPLOYEE_TYPE) VALUES (:NEW.EMPLOYEE_ID, 'Attendant');
   INSERT INTO ATTENDANTS (EMPLOYEEID) VALUES (:NEW.EMPLOYEE_ID);
 END IF;
END;
/



------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

-- TESTING

-- Insert statement for Cashier (E101)
INSERT INTO employees (EMPLOYEE_ID, JOB_TITLE, EXPERIENCE, EMAIL_ID, CONTACTNO, HIREDATE, L_NAME, F_NAME, STREET, CITY, ZIPCODE, APTNO, EMPLOYEE_TYPE)
VALUES ('E101', 'Cashier', 2, 'e101@example.com', '123-456-7890', '15-JAN-1997', 'Doe', 'John', '123 Main St', 'Anytown', '12345', 'Apt 101', 'Store');
 
-- Insert statement for Manager (E102)
INSERT INTO employees (EMPLOYEE_ID, JOB_TITLE, EXPERIENCE, EMAIL_ID, CONTACTNO, HIREDATE, L_NAME, F_NAME, STREET, CITY, ZIPCODE, APTNO, EMPLOYEE_TYPE)
VALUES ('E102', 'Manager', 5, 'e102@example.com', '987-654-3210', '15-FEB-1971', 'Smith', 'Jane', '456 Oak St', 'Cityville', '56789', 'Suite 202', 'Store');
 
-- Insert statement for Attendant (E103)
INSERT INTO employees (EMPLOYEE_ID, JOB_TITLE, EXPERIENCE, EMAIL_ID, CONTACTNO, HIREDATE, L_NAME, F_NAME, STREET, CITY, ZIPCODE, APTNO, EMPLOYEE_TYPE)
VALUES ('E103', 'Attendant', 1, 'e103@example.com', '555-123-4567', '15-DEC-1989', 'Johnson', 'Robert', '789 Pine St', 'Villagetown', '67890', 'Apt 303', 'Store');


SELECT * FROM STORE_EMPLOYEE;
SELECT * FROM CASHIER;
SELECT * FROM MANAGERS;
SELECT * FROM ATTENDANTS;
SELECT * FROM EMPLOYEES;


-- DELETE STATEMENTS

DELETE FROM store_employee
WHERE employee_id in ('E101', 'E102', 'E103');
DELETE FROM Cashier
WHERE employeeid in ('E101', 'E102', 'E103');
DELETE FROM Managers
WHERE employeeid in ('E101', 'E102', 'E103');
DELETE FROM Attendants
WHERE employeeid in ('E101', 'E102', 'E103');
DELETE FROM Employees
WHERE employee_id in ('E101', 'E102', 'E103');

------------------------------------------------------------------------------------------------------------------------------------------------------------------------------



------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

--TRIGGER 2

-- When an order is placed, it should update the avaialability of that product in the corresponding table

DROP TRIGGER check_stock_availability;

SET SERVEROUTPUT ON;

CREATE OR REPLACE TRIGGER check_stock_availability
BEFORE INSERT ON order_details
FOR EACH ROW
DECLARE
    store_quantity NUMBER;
    new_quantity NUMBER;
    new_storeid VARCHAR2(50);
    order_canceled EXCEPTION;
    
BEGIN

    SELECT storeid INTO new_storeid
    FROM orders 
    WHERE orderid = :new.orderid;
            
    SELECT quantity INTO store_quantity
        FROM (
            SELECT quantity, sadate
            FROM store_availability
            WHERE productid = :new.productid
              AND storeid = new_storeid
            ORDER BY sadate DESC
        )
        WHERE ROWNUM = 1;
        
    IF store_quantity < :new.quantity THEN        
        raise order_canceled;        
    ELSE
        new_quantity := store_quantity - :new.quantity;
        INSERT INTO store_availability VALUES (new_storeid, :new.productid, new_quantity, SYSDATE);
    END IF;
    
EXCEPTION
WHEN order_canceled THEN
    RAISE_APPLICATION_ERROR(-20001, 'Product canceled due to insufficient stock. 
    Not enough stock available for Product ID'  || :new.productid);    
END;
/

------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

--TESTING 

-- Inserting statements
INSERT INTO payments (PAYMENTID, PAYMENTDATE, PAYMENT_METHOD, EMPLOYEEID, PAYMENT_STATUS, PAYMENT_AMOUNT, FINALAMOUNT)
VALUES ('Pt201', TO_DATE('22-07-2023', 'DD-MM-YYYY'), 'Credit Card', 'E048', 'Paid', 180.00, 191.40);

INSERT INTO orders VALUES ('O201', 'C1001', 'Pt201', '01-JAN-2023',	'Confirmed', 'Offline', 'S005',	'Y');
INSERT INTO order_details VALUES ('O201', 140, 'P001', 149.99);

SELECT * FROM ORDERS;
SELECT * FROM ORDER_DETAILS;
SELECT * FROM STORE_AVAILABILITY
WHERE STOREID = 'S005' AND PRODUCTID = 'P001';

DELETE FROM ORDER_DETAILS
WHERE ORDERID = 'O201';

DELETE FROM ORDERS
WHERE ORDERID = 'O201';

DELETE FROM STORE_AVAILABILITY
WHERE QUANTITY = 10;

DELETE FROM PAYMENTS
WHERE PAYMENTID = 'Pt201';

COMMIT;

------------------------------------------------------------------------------------------------------------------------------------------------------------------------------


------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

-- PROCEDURE

CREATE OR REPLACE PROCEDURE adjust_prices_for_inflation
(p_category_name PRODUCTCATEGORY.C_name%TYPE,
p_percentage_increase NUMBER)
IS
  CURSOR product_cursor IS
    SELECT p.ProductID, p.price
    FROM PRODUCT p
    JOIN SUBCATEGORY sc ON p.sub_category_ID = sc.sub_category_ID
    JOIN PRODUCTCATEGORY pc ON sc.CategoryID = pc.CategoryID
    WHERE pc.C_name = p_category_name;
 
  v_product_id PRODUCT.ProductID%TYPE;
  v_price PRODUCT.price%TYPE;
  v_new_price NUMBER;
BEGIN
  OPEN product_cursor;
  LOOP
    FETCH product_cursor INTO v_product_id, v_price;
    EXIT WHEN product_cursor%NOTFOUND;
 
    -- Calculate the new price after inflation adjustment
    v_new_price := v_price + (v_price * (p_percentage_increase / 100));
 
    -- Update the product price
    UPDATE PRODUCT
    SET price = v_new_price
    WHERE ProductID = v_product_id;
  END LOOP;
 
  CLOSE product_cursor;
END adjust_prices_for_inflation;
/

------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

-- TESTING

SELECT * FROM PRODUCT2
where sub_category_id IN ('SC001','SC002', 'SC003','SC004');

SELECT * FROM PRODUCTCATEGORY;
select * from subcategory
WHERE categoryid = 'C001';


EXEC adjust_prices_for_inflation ('Power Tools', 10);


