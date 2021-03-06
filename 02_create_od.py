# ----------------
# load destinations
"DROP TABLE IF EXISTS destinations"
"CREATE TABLE destinations (destination_id integer primary key, name text, x double precision, y double precision)"
"\copy destinations FROM 'data/destinations.csv' delimiter ',' csv header"
"ALTER TABLE destinations ADD COLUMN geom geometry(Point, 3005)"
"UPDATE destinations SET geom = ST_Transform(ST_SetSRID(ST_Point(x, y), 4326), 3005)"
"ALTER TABLE destinations DROP COLUMN x"
"ALTER TABLE destinations DROP COLUMN y"

# ----------------
# load origins
"DROP TABLE IF EXISTS origins"
"CREATE TABLE origins (origin_id integer primary key, x double precision, y double precision)"
"\copy origins FROM 'data/origins.csv' delimiter ',' csv header"
"ALTER TABLE origins ADD COLUMN geom geometry(Point, 3005)"
"UPDATE origins SET geom = ST_Transform(ST_SetSRID(ST_Point(x, y), 4326), 3005)"
"ALTER TABLE origins DROP COLUMN x"
"ALTER TABLE origins DROP COLUMN y"