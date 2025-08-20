CREATE OR REPLACE FUNCTION linkedin_page_url_insert()
returns trigger as $$
BEGIN
if NEW.page is null THEN
    NEW.page := regexp_replace(new.url,'.*/','');
end if;
RETURN NEW;
END;
$$
language plpgsql;

create trigger pending_lip_url_insert after insert on pending_lip for each row execute function linkedin_page_url_insert();
