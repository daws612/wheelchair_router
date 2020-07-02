
-- CREATE TABLE izmit.routes
-- (
--     distance double precision,
--     route_id bigint NOT NULL GENERATED ALWAYS AS IDENTITY ( INCREMENT 1 START 1 MINVALUE 1 MAXVALUE 9223372036854775807 CACHE 1 ),
--     route_name text COLLATE pg_catalog."default",
--     duration double precision,
--     dest_lat double precision NOT NULL,
--     dest_lon double precision NOT NULL,
--     orig_lat double precision NOT NULL,
--     orig_lon double precision NOT NULL,
--     trip_id integer,
--     CONSTRAINT routes_pkey PRIMARY KEY (route_id),
--     CONSTRAINT origin_destination_name_unique UNIQUE (dest_lat, dest_lon, orig_lat, orig_lon, route_name)
-- )
-- WITH (
--     OIDS = FALSE
-- )
-- TABLESPACE pg_default;

-- CREATE TABLE izmit.segments
-- (
--     segment_id bigint NOT NULL GENERATED ALWAYS AS IDENTITY ( INCREMENT 1 START 1 MINVALUE 1 MAXVALUE 9223372036854775807 CACHE 1 ),
--     incline double precision,
--     length double precision,
--     is_accessible boolean,
--     end_lat double precision NOT NULL,
--     end_lon double precision NOT NULL,
--     start_lat double precision NOT NULL,
--     start_lon double precision NOT NULL,
--     CONSTRAINT segments_pkey PRIMARY KEY (segment_id),
--     CONSTRAINT start_end_unique UNIQUE (end_lon, end_lat, start_lat, start_lon)
-- )
-- WITH (
--     OIDS = FALSE
-- )
-- TABLESPACE pg_default;

-- CREATE TABLE izmit.users
-- (
--     user_id bigint NOT NULL GENERATED ALWAYS AS IDENTITY ( INCREMENT 1 START 1 MINVALUE 1 MAXVALUE 9223372036854775807 CACHE 1 ),
--     name character varying(255) COLLATE pg_catalog."default",
--     firebase_id character varying(255) COLLATE pg_catalog."default" NOT NULL,
--     gender character varying(255) COLLATE pg_catalog."default",
--     age integer,
--     wheelchair_type character varying(255) COLLATE pg_catalog."default",
--     is_deleted boolean NOT NULL DEFAULT false,
--     created_at timestamp without time zone,
--     updated_at timestamp without time zone,
--     CONSTRAINT users_pkey PRIMARY KEY (user_id)
-- )
-- WITH (
--     OIDS = FALSE
-- )
-- TABLESPACE pg_default;

-- CREATE TABLE izmit.route_segments
-- (
--     id bigint NOT NULL GENERATED ALWAYS AS IDENTITY ( INCREMENT 1 START 1 MINVALUE 1 MAXVALUE 9223372036854775807 CACHE 1 ),
--     route_id bigint NOT NULL,
--     segment_id bigint NOT NULL,
--     sequence bigint NOT NULL,
--     CONSTRAINT route_segments_pkey PRIMARY KEY (id),
--     CONSTRAINT route_segment_unique UNIQUE (route_id, segment_id),
--     CONSTRAINT fk_routes FOREIGN KEY (route_id)
--         REFERENCES izmit.routes (route_id) MATCH SIMPLE
--         ON UPDATE NO ACTION
--         ON DELETE NO ACTION,
--     CONSTRAINT fk_segments FOREIGN KEY (segment_id)
--         REFERENCES izmit.segments (segment_id) MATCH SIMPLE
--         ON UPDATE NO ACTION
--         ON DELETE NO ACTION
-- )
-- WITH (
--     OIDS = FALSE
-- )
-- TABLESPACE pg_default;

-- CREATE TABLE izmit.route_ratings
-- (
--     id bigint NOT NULL GENERATED ALWAYS AS IDENTITY ( INCREMENT 1 START 1 MINVALUE 1 MAXVALUE 9223372036854775807 CACHE 1 ),
--     route_id bigint NOT NULL,
--     user_id bigint NOT NULL,
--     rating integer,
--     comment text COLLATE pg_catalog."default",
--     route_sections character varying(255) COLLATE pg_catalog."default",
--     orig_lat double precision,
--     orig_lon double precision,
--     dest_lat double precision,
--     dest_lon double precision,
--     "timestamp" timestamp without time zone NOT NULL DEFAULT now(),
--     CONSTRAINT route_ratings_pkey PRIMARY KEY (id),
--     CONSTRAINT fk_routes FOREIGN KEY (route_id)
--         REFERENCES izmit.routes (route_id) MATCH SIMPLE
--         ON UPDATE NO ACTION
--         ON DELETE NO ACTION,
--     CONSTRAINT fk_users FOREIGN KEY (user_id)
--         REFERENCES izmit.users (user_id) MATCH SIMPLE
--         ON UPDATE NO ACTION
--         ON DELETE NO ACTION
-- )
-- WITH (
--     OIDS = FALSE
-- )
-- TABLESPACE pg_default;

-- CREATE TABLE izmit.log_types
-- (
--     id bigint NOT NULL GENERATED ALWAYS AS IDENTITY ( INCREMENT 1 START 1 MINVALUE 1 MAXVALUE 9223372036854775807 CACHE 1 ),
--     description text COLLATE pg_catalog."default",
--     log_type character varying(255) COLLATE pg_catalog."default" NOT NULL,
--     CONSTRAINT log_types_pkey PRIMARY KEY (id)
-- )
-- WITH (
--     OIDS = FALSE
-- )
-- TABLESPACE pg_default;

-- CREATE TABLE izmit.logs
-- (
--     id bigint NOT NULL GENERATED ALWAYS AS IDENTITY ( INCREMENT 1 START 1 MINVALUE 1 MAXVALUE 9223372036854775807 CACHE 1 ),
--     log_id bigint NOT NULL,
--     user_id bigint NOT NULL,
--     description text COLLATE pg_catalog."default",
--     "timestamp" timestamp without time zone NOT NULL DEFAULT now(),
--     CONSTRAINT logs_pkey PRIMARY KEY (id),
--     CONSTRAINT fk_log_type FOREIGN KEY (log_id)
--         REFERENCES izmit.log_types (id) MATCH SIMPLE
--         ON UPDATE NO ACTION
--         ON DELETE NO ACTION
--         NOT VALID,
--     CONSTRAINT fk_user_id FOREIGN KEY (user_id)
--         REFERENCES izmit.users (user_id) MATCH SIMPLE
--         ON UPDATE NO ACTION
--         ON DELETE NO ACTION
--         NOT VALID
-- )
-- WITH (
--     OIDS = FALSE
-- )
-- TABLESPACE pg_default;

-- CREATE OR REPLACE PROCEDURE izmit.saverouteinfo(
-- 	originlat double precision,
-- 	originlon double precision,
-- 	destlat double precision,
-- 	destlon double precision,
-- 	slope double precision,
-- 	sequence integer,
-- 	accessible boolean,
-- 	routeid bigint)
-- LANGUAGE 'plpgsql'

-- AS $BODY$
-- DECLARE
-- segid bigint;

-- BEGIN

-- INSERT INTO izmit.segments(start_lat, start_lon, end_lat, end_lon, incline, length, is_accessible) 
-- VALUES(	originlat, originlon, destlat, destlon,
-- 	slope,
-- 	ST_Distance(
-- 		ST_SetSRID(ST_MakePoint(originlon, originlat), 4326),
-- 		ST_SetSRID(ST_MakePoint(destlon, destlat), 4326),
-- 		true
-- 	),
-- 	accessible
-- ) ON CONFLICT (start_lat, start_lon, end_lat, end_lon) DO UPDATE SET is_accessible = EXCLUDED.is_accessible RETURNING segment_id INTO segid;

-- INSERT INTO izmit.route_segments(route_id, segment_id, sequence) 
-- VALUES(routeid, segid, sequence) ON CONFLICT (route_id, segment_id) DO NOTHING;

-- END
-- $BODY$;


----- 
    -- ogr2ogr -f "PostgreSQL" PG:"dbname=wheelchair_routing schemas=izmit user=postgres" "/home/firdaws/Documents/Thesis/izmit_sidewalk_geojson.geojson"

------

-- ALTER TABLE izmit.izmit
--     ADD COLUMN source bigint,
--     ADD COLUMN target bigint,
--     ADD COLUMN cost_len double precision,
--     ADD COLUMN cost_time double precision,
--     ADD COLUMN rcost_len double precision,
--     ADD COLUMN rcost_time double precision,
--     ADD COLUMN x1 double precision,
--     ADD COLUMN y1 double precision,
--     ADD COLUMN x2 double precision,
--     ADD COLUMN y2 double precision,
--     ADD COLUMN to_cost double precision,
--     ADD COLUMN rule text,
--     ADD COLUMN isolated integer;
	
--   UPDATE izmit.izmit SET x1 = ST_X(ST_startpoint(ST_geometryn(wkb_geometry,1)));
--   UPDATE izmit.izmit SET y1 = ST_Y(ST_startpoint(ST_geometryn(wkb_geometry,1)));
--   UPDATE izmit.izmit SET x2 = ST_X(ST_endpoint(ST_geometryn(wkb_geometry,1)));
--   UPDATE izmit.izmit SET y2 = ST_Y(ST_endpoint(ST_geometryn(wkb_geometry,1)));

-- UPDATE izmit.izmit SET cost_time = st_lengthspheroid(ST_geometryn(wkb_geometry,1), 'SPHEROID["WGS84",6378137,298.25728]')/16;
-- UPDATE izmit.izmit SET rcost_time = st_lengthspheroid(ST_geometryn(wkb_geometry,1), 'SPHEROID["WGS84",6378137,298.25728]')/16;

-- VACUUM ANALYZE  izmit.izmit;
  
-- select pgr_createTopology('izmit.izmit', 0.000001, the_geom:='wkb_geometry', id:='id');
-- select pgr_analyzegraph('izmit.izmit', 0.000001,  the_geom:='wkb_geometry', id:='id');

-- ALTER TABLE izmit.izmit
--  ALTER COLUMN wkb_geometry TYPE geometry(LineString,4326)
--   USING ST_LineMerge(wkb_geometry);
  
-- select pgr_nodeNetwork('izmit.izmit', 0.01, the_geom:='wkb_geometry', id:='id'); -- WORKING after alter

-- select pgr_createTopology('izmit.izmit_noded', 0.000001, the_geom:='wkb_geometry', id:='id');
-- delete from izmit.izmit_noded where source is null;

-- select pgr_createVerticesTable('izmit.izmit_noded','wkb_geometry','source','target');
-- select pgr_analyzegraph('izmit.izmit_noded', 0.000001,  the_geom:='wkb_geometry', id:='id');
-- select pgr_analyzeOneway('izmit.izmit_noded', 0.000001,  the_geom:='wkb_geometry', id:='id');


-- CREATE TABLE izmit.elevation_path
-- (
--     id bigint NOT NULL GENERATED ALWAYS AS IDENTITY ( INCREMENT 1 START 1 MINVALUE 1 MAXVALUE 9223372036854775807 CACHE 1 ),
--     elevation_json json NOT NULL,
--     origin character varying(255) COLLATE pg_catalog."default" NOT NULL,
--     destination character varying(255) COLLATE pg_catalog."default" NOT NULL,
--     CONSTRAINT elevation_path_pkey PRIMARY KEY (id)
-- )
-- WITH (
--     OIDS = FALSE
-- )
-- TABLESPACE pg_default;

-- CREATE TABLE izmit.polyline_path
-- (
--     id bigint NOT NULL GENERATED ALWAYS AS IDENTITY ( INCREMENT 1 START 1 MINVALUE 1 MAXVALUE 9223372036854775807 CACHE 1 ),
--     polyline_json json NOT NULL,
--     origin character varying(255) COLLATE pg_catalog."default" NOT NULL,
--     destination character varying(255) COLLATE pg_catalog."default" NOT NULL,
--     mode character varying(255) COLLATE pg_catalog."default" NOT NULL,
--     CONSTRAINT polyline_path_pkey PRIMARY KEY (id)
-- )
-- WITH (
--     OIDS = FALSE
-- )
-- TABLESPACE pg_default;

-- ALTER TABLE izmit.polyline_path
--     OWNER to wheelchair_routing;


-- TODO ADD USER_IDS

-- CREATE OR REPLACE PROCEDURE izmit.getRecommendedRoutes(
-- 	originlat double precision,
-- 	originlon double precision,
-- 	destlat double precision,
-- 	destlon double precision,
-- 	radius double precision,
-- 	min_score double precision, 
-- 	cluster_userids text,
-- 	inout rec text[])
-- AS $BODY$
-- DECLARE
	
-- 	sections text[];
-- 	route_section text;
-- 	score double precision;
-- 	recommendations text[];

-- BEGIN

-- 	sections:= Array( select distinct route_sections from 
-- 	(
-- 		SELECT r.route_id,  coalesce(round(avg(rating),2),0) as rating, rr.route_sections,
-- 		ST_DistanceSphere(st_point(originlon, originlat), st_point(rr.orig_lon, rr.orig_lat)) as orig_dist_m,
-- 		ST_DistanceSphere(st_point(destlon, destlat), st_point(rr.dest_lon, rr.dest_lat)) as dest_dist_m
-- 		FROM izmit.route_ratings rr 
-- 		LEFT JOIN izmit.routes r ON r.route_id = rr.route_id 
-- 		WHERE ST_DistanceSphere(st_point(originlon, originlat), st_point(rr.orig_lon, rr.orig_lat)) < radius
-- 		AND ST_DistanceSphere(st_point(destlon, destlat), st_point(rr.dest_lon, rr.dest_lat)) < radius
-- 		and user_id = any(string_to_array(cluster_userids, ',')::bigint[])
-- 		GROUP BY r.route_id, rr.orig_lon, rr.orig_lat, rr.dest_lon, rr.dest_lat, rr.route_sections
-- 		Order by orig_dist_m, dest_dist_m
-- 	) rates);
	
-- 	Raise info 'Found Route Sections are: %', sections;
	
-- 	FOREACH route_section SLICE 0 IN ARRAY sections
-- 	  LOOP
-- 		RAISE INFO 'Getting average of %', route_section;
-- 		select coalesce(round(avg(section_rating),2),0) into score from (
-- 			select coalesce(round(avg(rating),2),0) as section_rating 
-- 			from izmit.route_ratings
-- 			where route_id = any(string_to_array(route_section, ',')::bigint[])
-- 			and user_id = any(string_to_array(cluster_userids, ',')::bigint[])
-- 			group by route_id) avg_of_sections;
-- 		raise info 'Score: %', score;
		
-- 		IF score >= min_score THEN
-- 			raise info 'Add to Recommendation: %', route_section;
-- 			recommendations := array_append(recommendations, route_section);
-- 		END IF;
-- 	  END LOOP;

-- 	Raise info 'Recommendations %', recommendations;
-- 	rec := recommendations; -- array_to_string(recommendations, ',');
-- 	Raise info 'Rec %', rec;
-- END
-- $BODY$ LANGUAGE 'plpgsql';