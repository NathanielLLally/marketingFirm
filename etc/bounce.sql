create or replace view mx.smtp_bounces as
with dbl as (
  select count(*) as ctd, mxdomain
    from mx.smtp_status
    where
    status_bounce like 'domain block%' 
    and updated > now() - interval '7 days'
    group by 2
), ubl as 
(
  select count(*) as ctu, mxdomain
    from mx.smtp_status 
    where
    status_bounce like 'user block%' 
    and updated > now() - interval '7 days'
    group by 2
) 
select ctd as domain_block, 0 as user_block, mxdomain
from dbl
union all
select 0 as domain_block, ctu as user_block, mxdomain
from ubl
