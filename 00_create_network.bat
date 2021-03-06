REM ----------------
REM load roads
REM ----------------
ogr2ogr ^
  -t_srs EPSG:3005 ^
  -f PostgreSQL "PG:host=localhost port=5434 user=postgres dbname=thb password=None" ^
  -lco OVERWRITE=YES ^
  -lco GEOMETRY_NAME=geom ^
  -nln roads ^
  -dim XY ^
  -nlt LINESTRING ^
  data\01_working.gdb ^
  Roadnet_only2_1_1splitn_1

REM add pgrouting required source/target columns
psql -p 5434 -U postgres thb -c "ALTER TABLE roads ADD COLUMN source integer;"
psql -p 5434 -U postgres thb -c "ALTER TABLE roads ADD COLUMN target integer;"


REM ----------------
REM build the network topology - this takes about 11min on my machine
REM ----------------
psql -p 5434 -U postgres thb -c "SELECT pgr_createTopology('roads', 0.000001, 'geom', 'objectid');"
