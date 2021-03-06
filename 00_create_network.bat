#!/bin/bash
set -euxo pipefail

# ----------------
# load roads
# ----------------
ogr2ogr \
  -t_srs EPSG:3005 \
  -f PostgreSQL "PG:host=localhost port=5434 user=postgres dbname=thb password=None" \
  -lco OVERWRITE=YES \
  -lco GEOMETRY_NAME=geom \
  -nln roads \
  -dim XY \
  -nlt LINESTRING \
  data/01_working.gdb/ \
  Roadnet_only2_1_1splitn_1
# add pgrouting required source/target columns
psql -p 5434 -U postgres thb -c "ALTER TABLE roads ADD COLUMN source integer;"
psql -p 5434 -U postgres thb -c "ALTER TABLE roads ADD COLUMN target integer;"

# ----------------
# load destinations (manuall cleaned csv from source arcgis layer)
# ----------------
psql -p 5434 -U postgres thb -c "DROP TABLE IF EXISTS destinations"
psql -p 5434 -U postgres thb -c "CREATE TABLE destinations (destination_id integer primary key, name text, x double precision, y double precision)"
psql -p 5434 -U postgres thb -c "\copy destinations FROM 'data/destinations.csv' delimiter ',' csv header"
psql -p 5434 -U postgres thb -c "ALTER TABLE destinations ADD COLUMN geom geometry(Point, 3005)"
psql -p 5434 -U postgres thb -c "UPDATE destinations SET geom = ST_Transform(ST_SetSRID(ST_Point(x, y), 4326), 3005)"
psql -p 5434 -U postgres thb -c "ALTER TABLE destinations DROP COLUMN x"
psql -p 5434 -U postgres thb -c "ALTER TABLE destinations DROP COLUMN y"

# ----------------
# load origins (manually cleaned csv taken from source csv)
# ----------------
# rather than messing with ogr2ogr syntax, load origins coordinates directly and convert to geom in the db
psql -p 5434 -U postgres thb -c "DROP TABLE IF EXISTS origins"
psql -p 5434 -U postgres thb -c "CREATE TABLE origins (origin_id integer primary key, x double precision, y double precision)"
psql -p 5434 -U postgres thb -c "\copy origins FROM 'data/origins.csv' delimiter ',' csv header"
psql -p 5434 -U postgres thb -c "ALTER TABLE origins ADD COLUMN geom geometry(Point, 3005)"
psql -p 5434 -U postgres thb -c "UPDATE origins SET geom = ST_Transform(ST_SetSRID(ST_Point(x, y), 4326), 3005)"
psql -p 5434 -U postgres thb -c "ALTER TABLE origins DROP COLUMN x"
psql -p 5434 -U postgres thb -c "ALTER TABLE origins DROP COLUMN y"

# ----------------
# build the network topology - this takes about 11min on my machine
# ----------------
time psql -p 5434 -U postgres thb -c "SELECT pgr_createTopology('roads', 0.000001, 'geom', 'objectid');"
