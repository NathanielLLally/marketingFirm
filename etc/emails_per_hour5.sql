select hour, coalesce("mail.obiseo.net", 0) as "mail.obiseo.net", 
	coalesce("mail.winblows98.com",0) as "mail.winblows98.com", 
	coalesce("mail.accurateleadinfo.com",0) as "mail.accurateleadinfo.com", 
        total
from crosstab(
$$with cte as (
  select to_char(hour::timestamp,'DD/MM HH24') as hour,pending, ct from (
	select to_timestamp(to_char(sent,'DD/MM HH24'),'DD/MM HH24') as hour, pending, count(*) as ct
	from track_email
	where sent is not null
	group by to_char(sent,'DD/MM HH24'), pending
	union all
	select to_timestamp(to_char(sent,'DD/MM HH24'),'DD/MM HH24') as hour, 'total'::text as pending, count(*) as ct
	from track_email
	where sent is not null
	group by to_char(sent,'DD/MM HH24')
	order by hour,pending
      ) sq
)
table cte
union all
select 'total'::text as hour, pending, sum(ct) as ct
from cte
group by 1,2
$$,
$$VALUES ('mail.obiseo.net'), ('mail.winblows98.com'), ('mail.accurateleadinfo.com'),('total')$$
) as t("hour" text, "mail.obiseo.net" integer, "mail.winblows98.com" integer, "mail.accurateleadinfo.com" integer, "total" integer);
