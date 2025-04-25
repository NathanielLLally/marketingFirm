select hour, coalesce("mail.obiseo.net", 0) as "mail.obiseo.net", 
	coalesce("mail.winblows98.com",0) as "mail.winblows98.com", total
from crosstab(
$$with cte as (
	select concat(date_part('day',sent),'-',to_char(date_part('hour',sent), 'fm00')) as hour, pending, count(*) as ct
	from track_email
	where sent is not null
	group by concat(date_part('day',sent),'-',to_char(date_part('hour',sent), 'fm00')), pending
	union all
	select concat(date_part('day',sent),'-',to_char(date_part('hour',sent), 'fm00')), 'total'::text as pending, count(*) as ct
	from track_email
	where sent is not null
	group by concat(date_part('day',sent),'-',to_char(date_part('hour',sent), 'fm00'))
	order by hour,pending
)
table cte
union all
select 'total'::text as hour, pending, sum(ct) as ct
from cte
group by 1,2
order by 1
$$,
$$VALUES ('mail.obiseo.net'), ('mail.winblows98.com'), ('total')$$
) as t("hour" text, "mail.obiseo.net" integer, "mail.winblows98.com" integer, "total" integer);
