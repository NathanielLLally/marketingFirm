select count(*) from (
  select 'registrant' as type, name,organization,street,city,state,zip,country,email
  from whois_contact cr 
  join whois_nfo nfo on nfo.registrant = cr.id 
  where created is not null and updated > created and emailIsValid(email) 
  union all
  select 'admin' as type, name,organization,street,city,state,zip,country,email
  from whois_contact cr 
  join whois_nfo nfo on nfo.admin = cr.id 
  where created is not null and updated > created and emailIsValid(email) 
  union all
  select 'tech' as type, name,organization,street,city,state,zip,country,email
  from whois_contact cr 
  join whois_nfo nfo on nfo.tech = cr.id 
  where created is not null and updated > created and emailIsValid(email)
) contacts;
