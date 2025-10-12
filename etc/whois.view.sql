with c as (
  select id, concat_ws('|',name,organization,street,city,state,zip,country,phone,email) as p
  from wi.vc
)
select * from
(
select domain, created, updated,expires,
  ( select c.p from c where c.id = registrant ) as registrant,
  ( select c.p from c where c.id = admin ) as admin,
  ( select c.p from c where c.id = tech ) as tech,
  ( select c.p from c where c.id = billing ) as billing
from wi.nfo
) sq where sq.registrant is not null or sq.admin is not null or sq.tech is not null or sq.billing is not null
limit 1000;
