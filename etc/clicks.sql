select hour,
coalesce("viewed",0) as "viewed",
coalesce("readmore",0) as "readmore",
coalesce("contact_us",0) as "contact_us",
coalesce("header",0) as "header",
coalesce("unsubscribe",0 ) as "unsubscribe"
from crosstab(
	$ct$
	with cte as (
		select concat(date_part('day',clicked),'-',to_char(date_part('hour',clicked), 'fm00')) as hour, tag, count(*) as ct
		from track_email_clicks
		group by 1,2
		order by 1
	)
table cte
union all
select 'total'::text as hour, tag, sum(ct) as ct
from cte
group by 1,2
order by 1

$ct$,
$$VALUES ('viewed'),('readmore'), ('contact_us'), ('header'),('unsubscribe')$$
) as t("hour" text, "viewed" integer, "readmore" integer, "contact_us" integer,"header" int, "unsubscribe" int);
