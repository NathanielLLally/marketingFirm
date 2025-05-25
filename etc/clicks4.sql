select hour,
coalesce("viewed",0) as "viewed",
coalesce("interested",0) as "interested",
coalesce("sitelink",0) as "sitelink",
coalesce("unsubscribe",0 ) as "unsubscribe"
from crosstab(
	$ct$
	with cte as (
          select to_char(hour, 'MM/DD HH24') as hour, tag, ct from (
		select to_timestamp(to_char(clicked,'MM/DD HH24'),'MM/DD HH24') as hour, tag, count(*) as ct
		from track_email_clicks tc
                join track_email t on tc.email_uuid = t.uuid
                where t.cid = 4
		group by 1,2
		order by 1
              ) sq
	)
table cte
union all
select 'total'::text as hour, tag, sum(ct) as ct
from cte
group by 1,2
order by 1

$ct$,
$$VALUES ('viewed'),('interested'),('sitelink'), ('unsubscribe')$$
) as t("hour" text, "viewed" integer, "interested" integer, "sitelink" integer, "unsubscribe" int);
