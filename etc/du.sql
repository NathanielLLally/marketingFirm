--
-- PostgreSQL database dump
--

-- Dumped from database version 16.9
-- Dumped by pg_dump version 16.9

SET statement_timeout = 0;
SET lock_timeout = 0;
SET idle_in_transaction_session_timeout = 0;
SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;
SELECT pg_catalog.set_config('search_path', '', false);
SET check_function_bodies = false;
SET xmloption = content;
SET client_min_messages = warning;
SET row_security = off;

--
-- Name: disk_size_vw; Type: VIEW; Schema: public; Owner: postgres
--

CREATE VIEW public.disk_size_vw AS
 SELECT table_name,
    pg_size_pretty(table_size) AS table_size,
    pg_size_pretty(indexes_size) AS indexes_size,
    pg_size_pretty(total_size) AS total_size
   FROM ( SELECT all_tables.table_name,
            pg_table_size((all_tables.table_name)::regclass) AS table_size,
            pg_indexes_size((all_tables.table_name)::regclass) AS indexes_size,
            pg_total_relation_size((all_tables.table_name)::regclass) AS total_size
           FROM ( SELECT (((('"'::text || (tables.table_schema)::text) || '"."'::text) || (tables.table_name)::text) || '"'::text) AS table_name
                   FROM information_schema.tables) all_tables
          ORDER BY (pg_total_relation_size((all_tables.table_name)::regclass)) DESC) pretty_sizes;


ALTER VIEW public.disk_size_vw OWNER TO postgres;

--
-- PostgreSQL database dump complete
--

