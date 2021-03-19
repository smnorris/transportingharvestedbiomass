DROP TABLE IF EXISTS network;

CREATE TABLE network (
  network_id           SERIAL PRIMARY KEY        ,
  data_source          character varying(5)      ,
  rd_surface           character varying(12)     ,
  road_class           character varying(12)     ,
  awater               double precision          ,
  awaterinterp         double precision          ,
  aboat                double precision          ,
  acityspoke           double precision          ,
  aloose               double precision          ,
  aovergrown           double precision          ,
  apaved               double precision          ,
  arough               double precision          ,
  aseasonal            double precision          ,
  aunknown             double precision          ,
  arail                double precision          ,
  cost                 double precision          ,
  geom                 geometry(LineString,3005) ,
  source               integer                   ,
  target               integer
 );

 INSERT INTO network
   (
     data_source ,
     rd_surface  ,
     road_class  ,
     acityspoke  ,
     aloose      ,
     aovergrown  ,
     apaved      ,
     arough      ,
     aseasonal   ,
     aunknown    ,
     cost        ,
     geom
   )
 SELECT
   'roads' as data_source,
   rd_surface  ,
   road_class  ,
   acityspoke  ,
   aloose      ,
   aovergrown  ,
   apaved      ,
   arough      ,
   aseasonal   ,
   aunknown    ,
   cost        ,
   geom
 FROM roads;

 INSERT INTO network
   (
     data_source ,
     awater      ,
     awaterinterp,
     aboat       ,
     cost        ,
     geom
   )
SELECT
  'water' as data_source,
  awater      ,
  awaterinterp,
  aboat       ,
  cost        ,
  geom
FROM water;

-- rail
INSERT INTO network
   (
     data_source,
     arail      ,
     cost       ,
     geom
   )
SELECT
  'rail' as data_source,
  arail,
  cost ,
  geom
FROM rail;

CREATE INDEX ON network USING GIST (geom);

SELECT pgr_createTopology('network', 0.000001, 'geom', 'network_id');

-- to build restriction table, find road edges that intersect with water edges
DROP TABLE IF EXISTS restrictions;
CREATE TABLE restrictions (
  restriction_id SERIAL PRIMARY KEY,
  to_cost float8,
  target_id integer,
  via_path text
);

-- road -> water cost
INSERT INTO restrictions (
  to_cost,
  target_id,
  via_path
)
SELECT
  2,
  a.network_id,
  b.network_id::text
FROM network a
INNER JOIN network b
ON ST_Intersects(a.geom, b.geom)
WHERE a.data_source = 'roads'
AND b.data_source = 'water';

-- water -> road cost
INSERT INTO restrictions (
  to_cost,
  target_id,
  via_path
)
SELECT
  2,
  a.network_id,
  b.network_id::text
FROM network a
INNER JOIN network b
ON ST_Intersects(a.geom, b.geom)
WHERE a.data_source = 'water'
AND b.data_source = 'roads';

-- road -> rail cost
INSERT INTO restrictions (
  to_cost,
  target_id,
  via_path
)
SELECT
  2,
  a.network_id,
  b.network_id::text
FROM network a
INNER JOIN network b
ON ST_Intersects(a.geom, b.geom)
WHERE a.data_source = 'roads'
AND b.data_source = 'rail';

-- rail -> road cost
INSERT INTO restrictions (
  to_cost,
  target_id,
  via_path
)
SELECT
  2,
  a.network_id,
  b.network_id::text
FROM network a
INNER JOIN network b
ON ST_Intersects(a.geom, b.geom)
WHERE a.data_source = 'rail'
AND b.data_source = 'roads';

-- water -> rail cost
INSERT INTO restrictions (
  to_cost,
  target_id,
  via_path
)
SELECT
  2,
  a.network_id,
  b.network_id::text
FROM network a
INNER JOIN network b
ON ST_Intersects(a.geom, b.geom)
WHERE a.data_source = 'water'
AND b.data_source = 'rail';

-- rail -> water cost
INSERT INTO restrictions (
  to_cost,
  target_id,
  via_path
)
SELECT
  2,
  a.network_id,
  b.network_id::text
FROM network a
INNER JOIN network b
ON ST_Intersects(a.geom, b.geom)
WHERE a.data_source = 'rail'
AND b.data_source = 'water';