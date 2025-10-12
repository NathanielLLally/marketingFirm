insert into test_pending_email values ('nathaniel.lally@gmail.com', uuid_generate_v4(), null,null,'OBIseo');
create table loadpages (address varchar(255), city varchar(80), email varchar(255), name varchar(255), phone varchar(255), state varchar(2), tags varchar(255), website varchar(2000) null, zip varchar(11));
\COPY loadpages FROM '/tmp/pages_sites_utf8.csv' WITH (FORMAT csv);

select address, city, state, name, phone, e.email from loadpages lp join email e on lp.website=e.website;

alter table track_email add constraint uniq_email unique (email);
insert into track_email (email,name,website) select e.email,name,lp.website from loadpages lp join email e on e.website = lp.website where check_email(e.email) on conflict do nothing;

cREATE TABLE public.test_pending_email (
    email character varying(255),
    uuid uuid NOT NULL,
    sent timestamp with time zone,
    viewed timestamp with time zone,
    name character varying(255),
    unsubscribe timestamp with time zone,
    clicked timestamp with time zone,
    header timestamp with time zone,
    tag timestamp with time zone,
    readmore timestamp with time zone,
    website character varying(2000)
);

--fix email addresses
create table fix_email(email varchar(255),website varchar(2000),hdrurl varchar(2000));
insert into fix_email select trim(leading '%20' from email) as email,website,hdrurl from email where email like '\%20%';
delete from email where email like '\%20%';
insert into email select email,website,hdrurl from fix_email on conflict do nothing;

select * into invalid_emails from email where not check_email(email);
delete from email where not check_email(email);

--rank select
select name,phone,address,city,state,e.email,lp.website,rank_hist
from loadpages lp join (
  select email,website,string_agg(concat(yyyymm::varchar(255),'|',rank::varchar(255)),',') as rank_hist 
  from email e 
  join drtopmil dr on e.fqdn_website = dr.domain or e.fqdn_hdrurl = dr.domain 
  group by email,website) e
on lp.website=e.website;

--new records from yellow pages
insert into pending (url) select yp.website as url from yellow_pages yp left join email e on yp.website = e.website where length(yp.website) > 0 and e.website is null on conflict do nothing;


--
insert into mx_domain select domain(website) as domain from yellow_pages where length(website) > 0 on conflict do nothing;


--latest registered domain
select domain,created from whois_nfo d join (select max(created) as mc from whois_nfo) m on d.created = m.mc


--whois queries
select category,email as tech,d.domain from yp.yellow_pages yp join domain d on d.id = yp.did join whois_nfo wn on wn.domain = d.domain join whois_contact wc on wn.tech = wc.id where check_email(email);

--sending email
insert into track_email (email,name,website) select email,name,website from (select distinct yp.name,yp.phone,string_agg(yp.category,',') as categories,yp.website,e.email from yp.yellow_pages yp join email e on yp.website = e.website join mx.verified v on e.email = v.email where v.error is null group by name,phone,e.email,yp.website);

--get rid of duplicate emails
delete from track_email a using track_email b where a.email = b.email and a.ctid < b.ctid and a.uuid not in (select email_uuid from track_email_clicks);

--check unsubs
select email from track_email_clicks c join track_email t on c.email_uuid = t.uuid where tag = 'unsubscribe';
select email from track_email_clicks c join track_email t on c.email_uuid = t.uuid where tag = 'unsubscribe' and sent is null or pending is null;

--#huh

--name,website of people who clicked on contact_us
select yp.name,yp.website,e.email from yp.yellow_pages yp join email e on e.website=yp.website join track_email t on t.email=e.email join track_email_clicks c on t.uuid = c.email_uuid where tag='contact_us';

--load emails
\copy track_email_load (email,name,website, cid) from '/tmp/dog_training.csv';
insert into track_email (email,name,website, cid) select email,name,website, cid from track_email_load on conflict (email,cid) do nothing;
