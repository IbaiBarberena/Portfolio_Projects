/*

The dataset for these exercises is for a newly created country club, with a set of members, facilities such as tennis courts, and booking history for those facilities.

Skills used: Joins and Subqueries, CTE, Window functions, Aggregate Functions, data modification, Constraints, Indexes, Views

*/

-- EXPLORATORY ANALYSIS --

-- Select associates that Joined in August of 2012
Select firstname, surname
From ex.affiliate 
Where extract('year' From Joindate) = 2012 AND extract('month' From Joindate) = 8
Order By Joindate DESC;

-- Select all members as well as those that recommended them
Select f.firstname AS member_name, f.surname AS member_surname, s.firstname AS ref_name, s.surname AS ref_surname
From ex.affiliate f
Left Outer Join ex.affiliate s
ON s.member_id = f.recommendedby;

--Produce a list of reservations or 10 September which will cost the member (or guest) more than $50. The guest user is always ID 0. 

Select CONCAT(a.firstname, ' ' , a.surname) AS member, c.name, CASE WHEN b.member_id = 0 THEN c.guestcost * slots ELSE c.membercost * slots END AS cost
																
From ex.affiliate a
Inner Join ex.reservations b
	ON a.member_id = b.member_id
Inner Join ex.facilities c
	ON b.equip_id = c.equip_id
Where date_trunc('day', b.starttime) = '2012-09-14' AND ((b.member_id = 0 AND c.guestcost * slots > 50) OR (b.member_id != 0 AND c.membercost * slots > 50))
Order By cost DESC;

--Using CTE. Produce a list of reservations or 10 September which will cost the member (or guest) more than $50. The guest user is always ID 0. 

WITH costs AS (
Select CASE WHEN b.member_id = 0 THEN guestcost * slots ELSE membercost * slots END AS cost, c.name, b.member_id
  From ex.reservations b
  INNER Join ex.facilities c
  on b.equip_id = c.equip_id
  Where date_trunc('day', b.starttime)= '2012-09-15'
)

Select CONCAT(a.firstname,' ' , a.surname) as member, d.name as facility, d.cost
From costs d
INNER Join ex.affiliate a
ON d.member_id = a.member_id
Where d.cost > 50
ORDER BY cost DESC;

-- facilities booked per facility and per month

Select equip_id, DATE_PART('month', starttime) AS month, SUM(slots) AS "Total Slots"
From ex.reservations
Where DATE_PART('year', starttime) = 2012
Group BY equip_id, month
ORDER BY equip_id, month;

-- Top five revenue generating facilities

Select name, rank From (
	Select b.name as name, rank() over (order by sum(case
				when member_id = 0 then slots * b.guestcost
				else slots * membercost
			end) desc) as rank
		From ex.reservations a
		inner Join ex.facilities b
			on a.member_id = b.equip_id
		Group by b.name
	) as subq
	Where rank <= 5
order by rank; 

-- Facility classification based on their revenue (ntile on window function)

Select name, case when class=1 then 'high revenue'
				when class=2 then 'medium revenue'
				else 'low revenue'
				end revenue
	From (
		Select a.name as name, ntile(3) over (order by sum(case
				when member_id = 0 then slots * a.guestcost
				else slots * membercost
			end) desc) as class
		From ex.reservations bks
		inner Join ex.facilities a
			on b.equip_id = a.equip_id
		Group by a.name
	) as subq
order by class, name;



-- TABLE UPDATING & PERFORMANCE OPTIMIZATION -- 


-- Adding  new facilities ('spa', 'squash') into Facilities table

INSERT INTO ex.facilities (name, membercost, guestcost, initialoutlay, monthlymaintenance)
	VALUES (9, 'Spa', 15, 30, 140000, 700),
		(10, 'New Squash Court', 2.5, 14, 2000, 80);

-- Altering the price of the second tennis court so that it costs 10% more than the first one

UPDATE ex.facilities

	SET membercost = 1.1 * (Select membercost From ex.facilities Where name = 'Tennis Court 1'),
	guestcost = 1.1 * (Select guestcost From ex.facilities Where name = 'Tennis Court 1')
	
	Where name = 'Tennis Court 2';

-- Deleting a member that has never made a booking (using a subquery)

DELETE From ex.affiliate

	Where member_id NOT IN (Select DISTINCT member_id From ex.reservations);

-- View creation to store data for later

Create View total_names as

Select surname 
	From ex.affiliate
union
Select name
	From ex.facilities;

-- Constraint in a column: Monthlymaintenance lower than 50,000. Adding one exception: Spa can be higher than 50,000

ALTER TABLE ex.facilities
ADD CONSTRAINT monthly_maintenance_cost
CHECK (monthlymaintenance < 50000);

-- Dropping Foreign Key:

ALTER TABLE ex.facilities DROP CONSTRAINT facilities.fk

-- Index creation to speed up data retrieval. B-Tree Index creation for Primary Key on Reservations.

CREATE INDEX ix_reservation ON ex.reservations USING BTREE
(
    bookid
);

-- Checking the performance of the Index within the Table (Explain command):

EXPLAIN ANALYZE

Select * From ex.reservations Where EXTRACT('year' From starttime) = 2012




