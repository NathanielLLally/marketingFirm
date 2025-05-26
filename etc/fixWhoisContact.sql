WITH plan AS (
   SELECT *
   FROM  (
      SELECT id, min(id) OVER (PARTITION BY name,organization,street,city,state,zip,country,phone,phone_ext,fax,fax_ext,email) AS master_id
      FROM  whois_contact 
      ) sub
   WHERE  id <> master_id  -- ... <> self
   ) 
 , upd_nfo_r AS (
   UPDATE whois_nfo nfo
   SET    registrant = p.master_id   -- link to master id
   FROM   plan p
   WHERE  nfo.registrant = p.id
   )
 , upd_nfo_a AS (
   UPDATE whois_nfo nfo
   SET    admin = p.master_id   -- link to master id
   FROM   plan p
   WHERE  nfo.admin = p.id
)
 , upd_nfo_t AS (
   UPDATE whois_nfo nfo
   SET    tech = p.master_id   -- link to master id
   FROM   plan p
   WHERE  nfo.tech = p.id
)
DELETE FROM whois_contact c
USING  plan p
WHERE  c.id = p.id
RETURNING c.id;
