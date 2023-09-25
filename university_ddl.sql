use university_ddl;
-- Find the names of all the instructors from Biology department
select name, dept_name from instructor where dept_name = "Biology";
-- Find the names of courses in Computer science department which have 3 credits
select * from course where dept_name = "Comp. Sci." and credits = 3;
-- For the student with ID 12345 (or any other value), 
-- show all course_id and title of all courses registered for by the student.
select id,takes.course_id, course.title, semester, year, grade, credits from takes
	join course
    on takes.course_id = course.course_id
	where takes.id = 14563;
-- As above, but show the total number of credits for such courses (taken by that student). 
-- Don't display the tot_creds value from the student table, 
-- you should use SQL aggregation on courses taken by the student.
select * from student where id = 14563;
select * from course;
select sum(credits) from takes
	join course
    on takes.course_id = course.course_id
    where id = 14563;
-- As above, but display the total credits for each of the students, 
-- along with the ID of the student; don't bother about the name of the student. 
-- (Don't bother about students who have not registered for any course, they can be omitted)
select id, sum(credits) from takes
	join course
    on takes.course_id = course.course_id
    group by id;
-- Find the names of all students who have taken any Comp. Sci. course ever 
-- (there should be no duplicate names).
select distinct student.name from student 
	join takes
    on student.ID = takes.ID
    join course
    on takes.course_id = course.course_id
    where course.dept_name = "Comp. Sci.";
-- Display the IDs of all instructors who have never taught a couse (Notesad1) 
-- Oracle uses the keyword minus in place of except; 
-- (2) interpret "taught" as "taught or is scheduled to teach")
select distinct instructor.ID from instructor
	left join teaches
    on instructor.id = teaches.id
    where teaches.id is null;
-- As above, but display the names of the instructors also, not just the IDs.
select distinct instructor.ID, name from instructor
	left join teaches
    on instructor.id = teaches.id
    where teaches.id is null;
/* Find the maximum and minimum enrollment across all sections, 
considering only sections that had some enrollment, 
don't worry about those that had no students taking that section
*/
with enroll as (select course.title, count(takes.ID) as enrollment from course 
	join takes 
    on course.course_id = takes.course_id
    group by course.course_ID)
    select max(enrollment), min(enrollment)
    from enroll;
use university_ddl;
-- Find all sections that had the maximum enrollment (along with the enrollment), using a subquery.
WITH enroll AS (
select count(id) as enrollment, course_id, sec_id, semester, year
	from takes
    group by course_id, sec_id,semester, year
    order by count(id) desc
)
SELECT *
FROM enroll
WHERE enrollment = (SELECT MAX(enrollment) FROM enroll);
/* As in in Q1, but now also include sections with no students taking them; 
the enrollment for such sections should be treated as 0. 
Do this in two different ways (and create require data for testing)
1. Using a scalar subquery
2. Using aggregation on a left outer join (use the SQL natural left outer join syntax)
*/
-- using a scaler subquery.
select course_id from course
	where course_id not in (select course_id from takes);
-- Using aggregation on a left outer join (use the SQL natural left outer join syntax)
select course.course_id
	from course
    left outer join takes
    on course.course_id = takes.course_id
    group by takes.course_id, course.course_id, sec_id, semester, year
    having count(id) = 0;
-- Find all courses whose identifier starts with the string "CS-1"
select course_id from course
 where title like "%Comp%";
/* Find instructors who have taught all the above courses
1. Using the "not exists ... except ..." structure
2. Using matching of counts which we covered in class 
(don't forget the distinct clause!). */
use university_ddl;
SELECT i.ID, i.name 
FROM instructor i
WHERE NOT EXISTS (
    SELECT 1 
    FROM course c1
    LEFT JOIN teaches t ON c1.course_id = t.course_id AND t.ID = i.ID
    WHERE c1.course_id LIKE 'CS-1%' AND t.course_id IS NULL
);
SELECT i.ID, i.name
FROM instructor i
JOIN teaches t ON i.ID = t.ID
JOIN course c ON t.course_id = c.course_id
WHERE c.course_id LIKE 'CS-1%'
GROUP BY i.ID, i.name
HAVING COUNT(DISTINCT c.course_id) = (SELECT COUNT(DISTINCT course_id) FROM course WHERE course_id LIKE 'CS-1%');
-- Insert each instructor as a student, with tot_creds = 0, in the same department.
insert into student (ID, name, dept_name, tot_cred) 
select ID, name, dept_name, 0 from 
	instructor where id != '76543';
-- Now delete all the newly added "students" above 
-- (note: already existing students who happened to have tot_creds = 0 should not get deleted)
DELETE FROM student
WHERE id IN (
    SELECT id FROM (
        SELECT s.id 
        FROM student s
        JOIN instructor i ON i.id = s.id 
        WHERE i.name = s.name 
        AND i.dept_name = s.dept_name
        AND s.tot_cred = 0
    ) AS tmp
);
-- Some of you may have noticed that the tot_creds value for 
-- students did not match the credits from courses they have taken. 
-- Write and execute query to update tot_creds based on the credits passed, 
-- to bring the database back to consistency. (This query is provided in the book/slides.)
update student s
	set s.tot_cred = (select sum(credits)
		from course, takes
        where course.course_id = takes.course_id 
        and s.id = takes.id
        and takes.grade <> 'F'
        and takes.grade is not null);
-- Update the salary of each instructor to 10000 times the number of course sections they have taught.
update instructor i
	set i.salary = (
	select 
		case 
			when count(t.sec_id)*10000 <= 29000 then 30000
            else count(t.sec_id)*10000
		end as new_salary
    from teaches t
    where i.id = t.id
	group by id)
where i.id in (select distinct id from teaches);
-- Create your own query: define what you want to do in English, 
-- then write the query in SQL. Make it as difficult as you wish, the harder the better.
with num_student as (select course_id, grade, count(grade) as num_stud from takes 
	where course_id in 
	(select course_id from course where dept_name = 'English')
    group by course_id, grade
    order by course_id, grade),
total_num as (select course_id, sum(num_stud) as total from num_student 
	group by course_id)
select n.course_id, n.grade, n.num_stud, concat(round(n.num_stud/t.total*100,2),'%') as percentage from num_student n
	join total_num t
    on t.course_id = n.course_id;
-- The university rules allow an F grade to be overridden by any pass grade (A, B, C, D). 
-- Now, create a view that lists information about all fail grades that have not been overridden 
-- (the view should contain all attributes from the takes relation).
-- code below excludes failed overridden F.
create view overridden_takes as
select * from takes t1
where 
	(case 
		when grade = 'F' and not exists (select 1 from takes t2
	where grade <> 'F'
    and t1.id = t2.id
    and t1.course_id = t2.course_id) then 1
		when grade <> 'F' then 1
        when grade is null then 1
		else 0
	end) > 0;
-- Failed overridden 
select * from takes t1
where 
	(case 
		when grade = 'F' and not exists (select 1 from takes t2
	where grade <> 'F'
    and t1.id = t2.id
    and t1.course_id = t2.course_id) then 0
		when grade <> 'F' then 0
        when grade is null then 0
		else 1
	end) > 0;
-- Find all students who have 2 or more non-overridden F 
-- grades as per the takes relation, and list them along with the F grades.
select id, course_id, grade from takes t1
where grade in ('F') and exists (
select 1 from takes t2
	where grade in ('A','A-','A+','B','B+','B-','C','C-','C+', 'D')
    and t2.id = t1.id
    and t2.course_id = t1.course_id);
/* Grades are mapped to a grade point as follows: 
A:10, B:8, C:6, D:4 and F:0. Create a table to store these mappings, 
and write a query to find the CPI of each student, using this table. 
Make sure students who have not got a non-null grade in any course are displayed with a CPI of null.*/
use university_ddl;
with highest_point as (select id, course_id, max(grade_point) as max_point
	from (select *, 
	(case 
		when grade in ('A','A+','A-') then 10
        when grade in ('B','B+','B-') then 8 
        when grade in ('C','C+','C-') then 6
        when grade = 'D' then 4
        when grade = 'F' then 0
        else null
	end) as grade_point
	from takes) as grade_pointed 
    group by id, course_id)
select id, round(sum(max_point)/count(course_id),2) as cpi
	from highest_point
    where max_point is not null
    group by id
    order by cpi desc;
/*Find all rooms that have been assigned to more than one section at the same time. 
Display the rooms along with the assigned sections; 
I suggest you use a with clause or a view to simplify this query.*/
use university_ddl;
select * from 
	(select course_id, room_number, time_slot_id, count(course_id) 
    over(partition by time_slot_id, room_number) as over_assigned from section) as assigned
where over_assigned > 1;
-- Create a view faculty showing only the ID, name, and department of instructors.
create view faculty as 
	(select id, name, dept_name 
	from instructor);
-- Create a view CSinstructors, showing all information about instructors from the Comp. Sci. department.
create view CSinstructor as 
	(select * from instructor
	where dept_name = 'Comp. Sci.');
/* Insert appropriate tuple into each of the views faculty and CSinstructors, 
to see what updates your database allows on views; explain what happens.*/
update CSinstructor 
	set name = 'Bondi K'
    where id = '34175';
select * from CSinstructor;
select * from faculty;
/* answer: the change happens at faculty and istructor as well*/
