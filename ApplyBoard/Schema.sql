CREATE DATABASE applyboardinterview;

\c applyboardinterview

CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

CREATE TABLE public.user (
    id UUID NOT NULL PRIMARY KEY, 
    firstName varchar(50) NOT NULL, 
    lastName varchar(50), 
    age int, 
    gender int, 
    location varchar(50), 
    avatar varchar(50), 
    created_at TIMESTAMP, 
    updated_at TIMESTAMP, 
    deleted_at TIMESTAMP);

CREATE TABLE public.topic (
    id UUID NOT NULL PRIMARY KEY, 
    name varchar(50) NOT NULL, 
    created_at TIMESTAMP, 
    updated_at TIMESTAMP, 
    deleted_at TIMESTAMP);

CREATE TABLE public.events (
    id UUID NOT NULL PRIMARY KEY, 
    name varchar(50) NOT NULL, 
    topic_id UUID NOT NULL, 
    location varchar(50) NOT NULL,
    created_at TIMESTAMP, 
    updated_at TIMESTAMP, 
    deleted_at TIMESTAMP);

ALTER TABLE ONLY public.events ADD CONSTRAINT 
    event_topic_fid FOREIGN KEY (topic_id) 
    REFERENCES public.topic(id) 
    ON UPDATE CASCADE 
    ON DELETE RESTRICT;

CREATE TABLE public.userCommentRating (
    id UUID NOT NULL PRIMARY KEY, 
    user_id UUID NOT NULL, 
    event_id UUID NOT NULL, 
    comment varchar(3000), 
    rating smallint NOT NULL, 
    UNIQUE (user_id, event_id));

ALTER TABLE public.userCommentRating ADD CONSTRAINT 
    userCommentRating_userid_fid FOREIGN KEY (user_id) 
    REFERENCES public.user(id)  
    ON UPDATE CASCADE 
    ON DELETE RESTRICT;

ALTER TABLE public.userCommentRating ADD CONSTRAINT 
    userCommentRating_eventid_fid FOREIGN KEY (event_id) 
    REFERENCES public.events(id)  
    ON UPDATE CASCADE 
    ON DELETE RESTRICT;

CREATE TABLE public.event_rating (
    id UUID NOT NULL PRIMARY KEY, 
    event_id UUID NOT NULL UNIQUE, 
    avg_rating float,
    num_of_users int);

ALTER TABLE public.event_rating ADD CONSTRAINT 
    eventrating_event_fid FOREIGN KEY (event_id) 
    REFERENCES public.events(id) 
    ON UPDATE CASCADE 
    ON DELETE RESTRICT;

-- Import data into tables user, topic, event, userCommentrating from the csv files

-- Function to populate event_rating table with the average rating of each event

CREATE OR REPLACE FUNCTION populate_event_rating() RETURNS void AS $$
declare rr record;  
BEGIN
	FOR rr in  select event_id, avg(rating) as a, count(user_id) as c from "public".usercommentrating GROUP BY event_id Loop 
		raise notice 'Value : %', rr.a;
		raise notice 'Value : %', rr.c;
		raise notice 'Value : %', rr.event_id;
		INSERT INTO "public".event_rating values (uuid_generate_v4(), rr.event_id, rr.a, rr.c);
	END LOOP;
END;  $$
LANGUAGE PLPGSQL;

select populate_event_rating();

-- Trigger function that gets called whenever a new user rates a particular event
-- Calculates the new average rating and updates event_rating table
-- This avoids traversal of the entire DB every time new user adds a rating to an event

CREATE OR REPLACE FUNCTION populate_trigger() RETURNS TRIGGER AS $BODY$
declare r float; rr record;
BEGIN
	raise notice 'CALLED : %', NEW.event_id;
	for rr in select avg_rating, num_of_users from "public".event_rating where event_id = NEW.event_id LOOP
		r := ((rr.avg_rating * rr.num_of_users) + NEW.rating) / (rr.num_of_users + 1);
		raise notice 'Value : %', r;
		UPDATE "public".event_rating SET avg_rating = r where event_id = NEW.event_id;
	END LOOP;
	RETURN NEW;
END; $BODY$
LANGUAGE PLPGSQL;

CREATE TRIGGER modify_rating
  AFTER INSERT
  ON "public".usercommentrating
  FOR EACH ROW
  EXECUTE PROCEDURE populate_trigger();


-- To check if the trigger function is called properly, insert a new user, fetch the new user id and insert a new row into userCommentRating table. 
-- The corresponding avg_rating column value should change


CREATE OR REPLACE FUNCTION test_trigger() RETURNS void AS $$
Declare user_id UUID; rows RECORD;
BEGIN
	user_id := uuid_generate_v4();
	INSERT INTO VALUES public.user (user_id, 'A');
	FOR rows in Select id from public.events limit 1 Loop 
		INSERT INTO public.userCommentRating VALUES (uuid_generate_v4(), user_id, rows.id, null, 4.53);
	END LOOP;
END; $$
LANGUAGE PLPGSQL;

Select test_trigger();

