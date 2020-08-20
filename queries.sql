-- 3

-- a)
select pb.id, string_agg(concat_ws(' ', m.last_name, m.first_name), ', ') as authors, pb.[subject], pb.publisher_name, pb."year"
from publications as pb
join members_publications as mb on mb.publication_id = pb.id
join members as m on m.id = mb.member_id
where pb."year" >= 2010 and pb."year" <= 2020
group by pb.id, pb.subject, pb.publisher_name, pb."year"

-- b tropos
select pb.id, Concat(m.last_name, ' ', m.first_name) as authors, pb.[subject], pb.publisher_name, pb."year"
from publications as pb
join members_publications as mb on mb.publication_id = pb.id
join members as m on m.id = mb.member_id
where pb."year" >= 2010 and pb."year" <= 2020
group by pb.id, Concat(m.last_name, ' ', m.first_name), pb.subject, pb.publisher_name, pb."year"

-- b)
select pb.id, string_agg(concat_ws(' ', m.last_name, m.first_name), ', ') as authors, pb.subject, pb.publisher_name, pb."year"
from publications as pb
join members_publications as mb on mb.publication_id = pb.id
join members as m on m.id = mb.member_id
where subject like '%Intro%'
group by pb.id, pb.subject, pb.publisher_name, pb."year"

-- c)
select m.id, concat(m.last_name, ' ', m.first_name) as author, pc.category, count(pb.id) as publications
from publications as pb
join members_publications as mb on mb.publication_id = pb.id
join members as m on m.id = mb.member_id
join publication_categories as pc on pc.id = pb.publication_category_id
where pb."year" >= 2010 and pb."year" <= 2021 and m.member_category_id = 1
group by m.id, pc.category, concat(m.last_name, ' ', m.first_name)

-- d)
select m.id, m.last_name, m.first_name, count(pb.id) as number_of_publications
from members as m
join members_publications as mb on mb.member_id = m.id
join publications as pb on pb.id = mb.publication_id
where pb."year" >= 2016 and pb."year" <= 2020 and m.member_category_id = 1
group by m.id, m.last_name, m.first_name
having count(pb.id) =  (
	select top (1) count(a.publication_id) from members_publications  as a
	join publications as pb on pb.id = a.publication_id
	where pb."year" >= 2016 and pb."year" <= 2020
	group by a.member_id
	order by count(a.publication_id) desc
)

-- e)
select m.id, m.last_name, m.first_name, pb.subject
from members as m
join members_publications as mb on mb.member_id = m.id
join publications as pb on pb.id = mb.publication_id
where pb."year" >= 2016 and pb."year" <= 2020 and m.member_category_id = 1
group by pb.subject, m.id, m.last_name, m.first_name


-- f)
select pb."year", count(pb."year") as publications, m.id, m.last_name, m.first_name
from members as m
join members_publications as mb on mb.member_id = m.id
join publications as pb on pb.id = mb.publication_id
group by pb."year", m.id, m.last_name, m.first_name
having count(pb."year") > 3

-- g)
select m.*, rp.budget
from members as m
join research_projects as rp on rp.scientific_director_member_id = m.id
where m.member_category_id = 1 and rp.starting_date >= '2017-01-01' and rp.ending_date <= '2020-12-31'
order by rp.budget desc

-- h)
select c.semester, c.title, m.first_name, m.last_name
from courses as c
join members_courses as mc on mc.course_id = c.id
join members as m on m.id = mc.member_id
where (m.member_category_id = 1 or m.member_category_id = 5) and mc.role = 'Teacher'
order by c.semester

-- i)
select rp.id, rp.title, mrp.starting_date, mrp.ending_date
from research_projects as rp
join members_research_projects as mrp on mrp.research_project_id = rp.id
join members as m on m.id = mrp.member_id
where m.email = 'xara_queen@hotmail.com' 

-- j)
select * from members
order by last_name
-- we have to create a non-clustered index for last_name column in order for this query to run efficiently

-- 4)
CREATE PROCEDURE [dbo].[publ_statistics_auditing] @yyyy int, @category int
AS
BEGIN
	declare @publ_statistics_exists bit;
	set @publ_statistics_exists = case when EXISTS (SELECT 1 FROM   information_schema.tables where table_name = 'publ_statistics')
	then 1 else 0 end;
	if @publ_statistics_exists = 0 
	begin
		CREATE TABLE dbo.publ_statistics (
			category_id int NOT NULL,
			"year" int NOT NULL,
			total_num int NOT NULL,
			time_created datetime NOT NULL
		);
	end;

	declare @year_exists bit;
	set @year_exists = case when exists (select "year" from publ_statistics where "year" = @yyyy and category_id = @category) 
	then 1 else 0 end;

	declare @publications_count int;
	select @publications_count = (select count(pc.id) from publications as pc where pc.publication_category_id = @category and pc."year" = @yyyy);
	if @year_exists = 1
	begin
		update dbo.publ_statistics
		set total_num=@publications_count, time_created=GETDATE()
		where "year" = @yyyy and category_id = @category;
	end
	else
	begin	
		insert into dbo.publ_statistics
		(category_id, "year", total_num, time_created)
		values(@category, @yyyy, @publications_count, GETDATE());
	end;	
END


-- 5)
CREATE TRIGGER [dbo].[update_current_project_trigger]
   ON  [dbo].[research_projects]
   AFTER INSERT,UPDATE
AS 
BEGIN
	declare @total_proj int;
	declare @total_budget float;
	select @total_proj = (select count(rp.id) from research_projects as rp where rp.status = 'In progress');
	select @total_budget = (select sum(rp.budget) from research_projects as rp where rp.status = 'In progress');
	INSERT INTO dbo.current_project
	("date", time_created, total_proj, total_budget)
	VALUES(CONVERT (date,GETDATE()), CONVERT (time ,GETDATE()), @total_proj, @total_budget);
END