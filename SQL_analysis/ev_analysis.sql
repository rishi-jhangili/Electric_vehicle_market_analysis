# Create a database 
CREATE DATABASE `electric_vehicle`;

USE electric_vehicle;

# Use encoded csv file to import data 
CREATE TABLE dim (
`date` DATE PRIMARY KEY,
fiscal_year INT,
`quarter` CHAR(5)
);


CREATE TABLE ev_makers(
`date` DATE,
vehicle_category VARCHAR(45),
maker VARCHAR(60),
electric_vehicles_sold INT,
FOREIGN KEY(`date`) REFERENCES dim(`date`)
);

CREATE TABLE ev_state(
`date` DATE,
state VARCHAR(90),
vehicle_category VARCHAR(45),
electric_vehicles_sold INT,
total_vehicles_sold INT,
FOREIGN KEY(`date`) REFERENCES dim(`date`)
);


# Over view of all the tables in a database

SELECT * FROM dim;
SELECT * FROM ev_makers;
SELECT * FROM ev_state;


# Preliminary Research Questions:
-- 1. List the top 3 and bottom 3 makers for the fiscal years 2023 and 2024 in terms of the number of 2-wheelers sold.

SELECT * FROM ev_makers;

CREATE OR REPLACE VIEW fiscal_year AS
	SELECT
		ev_makers.`date`,
		fiscal_year,
        `quarter`,
        vehicle_category,
        maker,
        electric_vehicles_sold
	FROM 
		ev_makers
	INNER JOIN dim ON ev_makers.date = dim.date;

SELECT * FROM fiscal_year;


CREATE OR REPLACE VIEW top_and_bottom_makers AS
SELECT
	maker,
	fiscal_year,
	SUM(electric_vehicles_sold) AS total_electric_vehicles_sold,
	ROW_NUMBER() OVER(PARTITION BY fiscal_year ORDER BY SUM(electric_vehicles_sold) DESC) AS rank_
FROM 
	fiscal_year
WHERE vehicle_category = '2-Wheelers' AND fiscal_year IN ('2023', '2024')
GROUP BY maker, fiscal_year
ORDER BY total_electric_vehicles_sold DESC;

SELECT
	maker,
    total_electric_vehicles_sold AS total_ev_sold_23
FROM 
	top_and_bottom_makers
WHERE fiscal_year = 2023 AND rank_ IN (1,2,3,11,12,13);



SELECT
	maker,
    total_electric_vehicles_sold AS total_ev_sold_24
FROM 
	top_and_bottom_makers
WHERE fiscal_year = 2024 AND rank_ IN (1,2,3,11,12,13);


-- 2. Identify the top 5 states with the highest penetration rate in 2-wheeler and 4-wheeler EV sales in FY 2024.

SELECT *FROM ev_state;

CREATE OR REPLACE VIEW penitration_rate_ AS
	SELECT
		fiscal_year,
		state,
		vehicle_category,
		SUM(electric_vehicles_sold) AS total_ev_sold,
		SUM(total_vehicles_sold) AS total_vehicles_sold,
        SUM(electric_vehicles_sold/total_vehicles_sold)*100 AS penitration_rate
	FROM 
		ev_state
	INNER JOIN dim ON ev_state.date = dim.date
	GROUP BY fiscal_year, state, vehicle_category;

SELECT * FROM penitration_rate_;


WITH two_wheelers AS(
	SELECT 
		state,
        vehicle_category AS two_wheelers,
        penitration_rate
	FROM 
		penitration_rate_
	WHERE vehicle_category = '2-Wheelers' AND fiscal_year = 2024
),four_wheelers AS(
	SELECT
		state,
        vehicle_category AS four_wheelers,
        penitration_rate
	FROM
		penitration_rate_
	WHERE vehicle_category = '4-Wheelers' AND fiscal_year = 2024
)
SELECT
	two_wheelers.state,
    two_wheelers.penitration_rate AS penitration_rate_2W,
    four_wheelers.penitration_rate AS penitration_rate_4W,
    SUM(two_wheelers.penitration_rate + four_wheelers.penitration_rate) AS overall
FROM 
	two_wheelers
		JOIN four_wheelers ON two_wheelers.state = four_wheelers.state
GROUP BY two_wheelers.state, penitration_rate_2W, penitration_rate_4W
ORDER BY overall DESC
LIMIT 5;
        


-- List the states with negative penetration (decline) in EV sales from 2022 to 2024?

WITH penitration_2022 AS(
	SELECT
		state,
        SUM(penitration_rate) AS penitration_rate_2022
	FROM
		penitration_rate_
	WHERE fiscal_year = 2022
	GROUP BY state
),penitration_2023 AS(
	SELECT
		state,
        SUM(penitration_rate) AS penitration_rate_2023
	FROM
		penitration_rate_
	WHERE fiscal_year = 2023
	GROUP BY state
),penitration_2024 AS(
	SELECT
		state,
        SUM(penitration_rate) AS penitration_rate_2024
	FROM
		penitration_rate_
	WHERE fiscal_year = 2024
	GROUP BY state
)
SELECT 
	penitration_2022.state,
    penitration_2022.penitration_rate_2022,
    penitration_2023.penitration_rate_2023,
    penitration_2024.penitration_rate_2024,
    (penitration_rate_2024 - penitration_rate_2023) AS decline
FROM
	penitration_2022
		INNER JOIN penitration_2023 ON penitration_2022.state = penitration_2023.state
		INNER JOIN penitration_2024 ON penitration_2022.state = penitration_2024.state
HAVING decline < 0
ORDER BY decline;

    
-- What are the quarterly trends based on sales volume for the top 5 EV makers (4-wheelers) from 2022 to 2024?

SELECT
	maker,
	SUM(electric_vehicles_sold) AS total_electric_vehicles_sold
FROM 
	fiscal_year
WHERE vehicle_category = '4-Wheelers' 
GROUP BY maker
ORDER BY total_electric_vehicles_sold DESC
LIMIT 5;


WITH quarter1 AS(
	SELECT 
		maker,
		SUM(electric_vehicles_sold) AS Q1
	FROM 
		fiscal_year
	WHERE vehicle_category = '4-Wheelers' AND quarter = 'Q1'
	GROUP BY maker
),quarter2 AS(
	SELECT 
		maker,
		SUM(electric_vehicles_sold) AS Q2
	FROM 
		fiscal_year
	WHERE vehicle_category = '4-Wheelers' AND quarter = 'Q2'
	GROUP BY maker
),quarter3 AS(
	SELECT 
		maker,
		SUM(electric_vehicles_sold) AS Q3
	FROM 
		fiscal_year
	WHERE vehicle_category = '4-Wheelers' AND quarter = 'Q3'
	GROUP BY maker
),quarter4 AS(
	SELECT 
		maker,
		SUM(electric_vehicles_sold) AS Q4
	FROM 
		fiscal_year
	WHERE vehicle_category = '4-Wheelers' AND quarter = 'Q4'
	GROUP BY maker
)
SELECT
	quarter1.maker,
    quarter1.Q1,
    quarter2.Q2,
    quarter3.Q3,
    quarter4.Q4,
    SUM(quarter1.Q1 + quarter2.Q2 + quarter3.Q3 + quarter4.Q4) AS overall
FROM 
	quarter1
		JOIN quarter2 ON quarter1.maker = quarter2.maker
        JOIN quarter3 ON quarter2.maker = quarter3.maker
        JOIN quarter4 ON quarter3.maker = quarter4.maker
GROUP BY quarter1.maker, Q1, Q2, Q3, Q4
ORDER BY overall DESC
LIMIT 5;

-- How do the EV sales and penetration rates in Delhi compare to Karnataka for 2024?

SELECT
	state,
    SUM(total_ev_sold) AS ev_sales,
    SUM(penitration_rate) AS penitration_rates
FROM
	penitration_rate_
WHERE fiscal_year = 2024 AND state IN ('Delhi', 'Karnataka')
GROUP BY state;

-- List down the compounded annual growth rate (CAGR) in 4-wheeler units for the top 5 makers from 2022 to 2024.

SELECT * FROM fiscal_year;

WITH top_makers AS(
	SELECT 
		maker,
		SUM(electric_vehicles_sold) AS ev_sales
	FROM 
		fiscal_year
	WHERE vehicle_category = '4-Wheelers'
	GROUP BY maker
	ORDER BY ev_sales DESC
),year_22 AS(
	SELECT
		maker,
        SUM(electric_vehicles_sold) AS year_2022
	FROM 
		fiscal_year
	WHERE vehicle_category = '4-Wheelers' AND fiscal_year = 2022
	GROUP BY maker
),year_24 AS(
	SELECT
		maker,
        SUM(electric_vehicles_sold) AS year_2024
	FROM 
		fiscal_year
	WHERE vehicle_category = '4-Wheelers' AND fiscal_year = 2024
	GROUP BY maker
)
SELECT
	top_makers.maker,
    year_2022,
    year_2024,
    power(year_2024/year_2022, 1.0/2) - 1 AS CAGR
FROM 
	top_makers
		INNER JOIN year_22 ON top_makers.maker = year_22.maker
        INNER JOIN year_24 ON year_22.maker = year_24.maker
ORDER BY CAGR DESC
LIMIT 5;

-- List down the top 10 states that had the highest compounded annual growth rate (CAGR) from 2022 to 2024 in total vehicles sold.


SELECT * FROM penitration_rate_;

WITH top_states AS(
	SELECT
		state,
		SUM(total_vehicles_sold) AS total_sales
	FROM 
		penitration_rate_
	GROUP BY state
),year_22 AS(
	SELECT
		state,
        SUM(total_vehicles_sold) AS year_2022
	FROM 
		penitration_rate_
	WHERE fiscal_year = 2022
	GROUP BY state
),year_24 AS(
	SELECT
		state,
        SUM(total_vehicles_sold) AS year_2024
	FROM 
		penitration_rate_
	WHERE fiscal_year = 2024
	GROUP BY state
)
SELECT 
	top_states.state,
    year_22.year_2022,
    year_24.year_2024,
    (POWER(year_2024/year_2022, 1.0/2) - 1) AS CAGR
FROM 
	top_states
		JOIN year_22 ON top_states.state = year_22.state
        JOIN year_24 ON year_22.state = year_24.state
ORDER BY CAGR DESC
LIMIT 10;


WITH year_22 AS(
	SELECT
		state,
        SUM(total_vehicles_sold) AS year_2022
	FROM 
		penitration_rate_
	WHERE fiscal_year = 2022
	GROUP BY state
),year_24 AS(
	SELECT
		state,
        SUM(total_vehicles_sold) AS year_2024
	FROM 
		penitration_rate_
	WHERE fiscal_year = 2024
	GROUP BY state
)
SELECT
	year_22.state,
    year_22.year_2022,
    year_24.year_2024,
    (POWER(year_2024/year_2022, 1.0/2) - 1 )*100 AS CAGR
FROM 
	year_22
        JOIN year_24 ON year_22.state = year_24.state
ORDER BY CAGR DESC
LIMIT 10;


-- What are the peak and low season months for EV sales based on the data from 2022 to 2024?

WITH year_22 AS(
	SELECT
		EXTRACT(MONTH FROM `date`) AS year_month_22,
		SUM(electric_vehicles_sold) AS sales
	FROM 
		fiscal_year
	WHERE fiscal_year = 2022
	GROUP BY year_month_22
),year_23 AS(
	SELECT
		EXTRACT(MONTH FROM `date`) AS year_month_23,
		SUM(electric_vehicles_sold) AS sales
	FROM 
		fiscal_year
	WHERE fiscal_year = 2023
	GROUP BY year_month_23
),year_24 AS(
	SELECT
		EXTRACT(MONTH FROM `date`) AS year_month_24,
		SUM(electric_vehicles_sold) AS sales
	FROM 
		fiscal_year
	WHERE fiscal_year = 2024
	GROUP BY year_month_24
)
SELECT
	CASE
		WHEN year_month_22 = 1 THEN 'January'
        WHEN year_month_22 = 2 THEN 'Feruary'
        WHEN year_month_22 = 3 THEN 'March'
        WHEN year_month_22 = 4 THEN 'April'
        WHEN year_month_22 = 5 THEN 'May'
        WHEN year_month_22 = 6 THEN 'June'
        WHEN year_month_22 = 7 THEN 'July'
        WHEN year_month_22 = 8 THEN 'August'
        WHEN year_month_22 = 9 THEN 'September'
        WHEN year_month_22 = 10 THEN 'October'
        WHEN year_month_22 = 11 THEN 'November'
        WHEN year_month_22 = 12 THEN 'December'
        ELSE NULL
	END AS month_,
    year_22.sales AS year_2022,
    year_23.sales AS year_2023,
    year_24.sales AS year_2024
FROM
	year_22
		INNER JOIN year_23 ON year_22.year_month_22 = year_23.year_month_23
        INNER JOIN year_24 ON year_23.year_month_23 = year_24.year_month_24
ORDER BY 
	year_month_22;
     
     
    
-- What is the projected number of EV sales (including 2-wheelers and 4- wheelers) for the top 10 states by penetration rate in 2030, based on the compounded annual growth rate (CAGR) from previous years?


SELECT * FROM penitration_rate_;

WITH top_states AS( 
	 SELECT
		state,
		SUM(penitration_rate) AS rate
	FROM 
		penitration_rate_
	WHERE fiscal_year = 2024
	GROUP BY state
	ORDER BY rate DESC
    LIMIT 10
),year_22 AS(
	SELECT 
		state,
        SUM(total_ev_sold) AS year_2022
	FROM 
		penitration_rate_
	WHERE fiscal_year = 2022
	GROUP BY state
),year_24 AS(
	SELECT
		state,
        SUM(total_ev_sold) AS year_2024
	FROM
		penitration_rate_
	WHERE fiscal_year = 2024
    GROUP BY state
),compund_growth AS(
	SELECT
		top_states.state,
        year_22.year_2022,
        year_24.year_2024,
        (POWER(year_2024/year_2022, 1.0/2) - 1) AS CAGR
	FROM
		top_states
			JOIN year_22 ON top_states.state = year_22.state
            JOIN year_24 ON year_22.state = year_24.state
	ORDER BY CAGR DESC
)
SELECT 
	state,
    year_2024,
    ROUND((year_2024 * POWER(1 + (CAGR/100), 6))) AS projected
FROM
	compund_growth
ORDER BY projected DESC;


-- Estimate the revenue growth rate of 4-wheeler and 2-wheelers EVs in India for 2022 vs 2024 and 2023 vs 2024, assuming an average unit price. 
-- 2-Wheelers Average price per unit = 85,000 INR
-- 4-Wheelers Average price per unit = 15,00,000 INR

CREATE TABLE revenue(
vehicle_category VARCHAR(30) PRIMARY KEY,
average_price INT
);



INSERT INTO revenue VALUES
('2-Wheelers', 85000),
('4-Wheelers', 1500000);


SELECT * FROM revenue;


SELECT * FROM fiscal_year;

SELECT
	vehicle_category,
    SUM(electric_vehicles_sold) AS total_units
FROM 
	fiscal_year
GROUP BY vehicle_category;

CREATE OR REPLACE VIEW revenue_growth AS
	WITH year_22 AS(
		SELECT
			vehicle_category,
			SUM(electric_vehicles_sold) AS total_units_22
		FROM
			fiscal_year
		WHERE fiscal_year = 2022
		GROUP BY vehicle_category
	),year_23 AS(
		SELECT
			vehicle_category,
			SUM(electric_vehicles_sold) AS total_units_23
		FROM
			fiscal_year
		WHERE fiscal_year = 2023
		GROUP BY vehicle_category
	),year_24 AS(
		SELECT
			vehicle_category,
			SUM(electric_vehicles_sold) AS total_units_24
		FROM
			fiscal_year
		WHERE fiscal_year = 2024
		GROUP BY vehicle_category
	),year_22_vs_year_24 AS(
		SELECT
			year_22.vehicle_category,
			FORMAT(year_22.total_units_22 * revenue.average_price,0) AS revenue_2022,
			FORMAT(year_24.total_units_24 * revenue.average_price,0) AS revenue_2024
		FROM
			year_22
				INNER JOIN revenue ON year_22.vehicle_category = revenue.vehicle_category
				INNER JOIN year_24 ON revenue.vehicle_category = year_24.vehicle_category
	),year_23_vs_year_24 AS(
		SELECT
			year_23.vehicle_category,
			FORMAT(year_23.total_units_23 * revenue.average_price,0) AS revenue_2023,
			FORMAT(year_24.total_units_24 * revenue.average_price,0) AS revenue_2024
		FROM
			year_23
				INNER JOIN revenue ON year_23.vehicle_category = revenue.vehicle_category
				INNER JOIN year_24 ON revenue.vehicle_category = year_24.vehicle_category
	)
    SELECT
		year_22_vs_year_24.vehicle_category,
        year_22_vs_year_24.revenue_2022,
        year_23_vs_year_24.revenue_2023,
        year_22_vs_year_24.revenue_2024
	FROM 
		year_22_vs_year_24
			JOIN year_23_vs_year_24 ON year_22_vs_year_24.vehicle_category = year_23_vs_year_24.vehicle_category;


SELECT 
	vehicle_category,
    revenue_2022,
    revenue_2024
FROM revenue_growth;
    

SELECT 
	vehicle_category,
    revenue_2023,
    revenue_2024
FROM revenue_growth;


	

        
 
    











