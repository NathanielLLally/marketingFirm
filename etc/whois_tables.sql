--
-- PostgreSQL database dump
--

-- Dumped from database version 16.8
-- Dumped by pg_dump version 16.8

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

SET default_tablespace = '';

SET default_table_access_method = heap;

--
-- Name: whois_contact; Type: TABLE; Schema: wi; Owner: postgres
--

CREATE TABLE wi.whois_contact (
    id integer NOT NULL,
    name character varying(1024),
    organization character varying(1024),
    street character varying(1024),
    city character varying(1024),
    state character varying(1024),
    zip character varying(1024),
    country character varying(1024),
    phone character varying(1024),
    phone_ext character varying(1024),
    fax character varying(1024),
    fax_ext character varying(1024),
    email character varying(1024)
);


ALTER TABLE wi.whois_contact OWNER TO postgres;

--
-- Name: whois_nfo; Type: TABLE; Schema: wi; Owner: postgres
--

CREATE TABLE wi.whois_nfo (
    id integer NOT NULL,
    domain character varying(255),
    created timestamp with time zone not null,
    updated timestamp with time zone not null,
    registrant integer,
    admin integer,
    tech integer
);


ALTER TABLE wi.whois_nfo OWNER TO postgres;

--
-- Name: whois_contact whois_contact_pkey; Type: CONSTRAINT; Schema: wi; Owner: postgres
--

ALTER TABLE ONLY wi.whois_contact
    ADD CONSTRAINT whois_contact_pkey PRIMARY KEY (id);


--
-- Name: whois_contact whois_contact_street_zip_phone_email_key; Type: CONSTRAINT; Schema: wi; Owner: postgres
--

ALTER TABLE ONLY wi.whois_contact
    ADD CONSTRAINT whois_contact_street_zip_phone_email_key UNIQUE NULLS NOT DISTINCT (street, zip, phone, email);

ALTER TABLE ONLY wi.whois_contact
    ADD CONSTRAINT whois_contact_valid_email CHECK (public.emailIsValid(email));

--
-- Name: whois_nfo whois_nfo_domain_key; Type: CONSTRAINT; Schema: wi; Owner: postgres
--

ALTER TABLE ONLY wi.whois_nfo
    ADD CONSTRAINT whois_nfo_domain_key UNIQUE (domain);


--
-- Name: whois_nfo whois_nfo_pkey; Type: CONSTRAINT; Schema: wi; Owner: postgres
--

ALTER TABLE ONLY wi.whois_nfo
    ADD CONSTRAINT whois_nfo_pkey PRIMARY KEY (id);


--
-- PostgreSQL database dump complete
--

