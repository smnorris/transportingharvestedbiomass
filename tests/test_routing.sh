# test some scenarios

# get municipal boundaries for test destinations
bcdata bc2pg whse_legal_admin_boundaries.abms_municipalities_sp

# --------
# test 1 - original 744 origins and 10 random destinations, all at once
# --------
python ../thb.py load-origins data/origins_01_small.csv
psql -c "DROP TABLE IF EXISTS destinations"
psql -c "CREATE TABLE destinations AS
 SELECT
  row_number() over() AS destination_id,
  admin_area_name AS destination_name,
  ST_PointOnSurface(geom) as geom
FROM whse_legal_admin_boundaries.abms_municipalities_sp
WHERE admin_area_group_name NOT IN
(
  'Strathcona Regional District',
  'Regional District of Alberni-Clayoquot',
  'Regional District of Nanaimo',
  'Comox Valley Regional District',
  'Capital Regional District',
  'Cowichan Valley Regional District',
  'Regional District of Mount Waddington'
)
AND admin_area_name NOT IN
(
  'Village of Queen Charlotte',
  'Village of Masset',
  'Village of Port Clements'
)
ORDER BY random() LIMIT 10"
time psql2csv < test_routing.sql > test_744_10.csv # 1m20.597s


# --------
# test 2 - original 744 origins and 20 random destinations, all at once
# --------
python ../thb.py load-origins data/origins_01_small.csv
psql -c "DROP TABLE IF EXISTS destinations"
psql -c "CREATE TABLE destinations AS
 SELECT
  row_number() over() AS destination_id,
  admin_area_name AS destination_name,
  ST_PointOnSurface(geom) as geom
FROM whse_legal_admin_boundaries.abms_municipalities_sp
WHERE admin_area_group_name NOT IN
(
  'Strathcona Regional District',
  'Regional District of Alberni-Clayoquot',
  'Regional District of Nanaimo',
  'Comox Valley Regional District',
  'Capital Regional District',
  'Cowichan Valley Regional District',
  'Regional District of Mount Waddington'
)
AND admin_area_name NOT IN
(
  'Village of Queen Charlotte',
  'Village of Masset',
  'Village of Port Clements'
)
ORDER BY random() LIMIT 20"
time psql2csv < test_routing.sql > test_744_20.csv # 1m54.400s

# --------
# test 3 - original 744 origins and 50 random destinations, all at once
# --------
python ../thb.py load-origins data/origins_01_small.csv
psql -c "DROP TABLE IF EXISTS destinations"
psql -c "CREATE TABLE destinations AS
 SELECT
  row_number() over() AS destination_id,
  admin_area_name AS destination_name,
  ST_PointOnSurface(geom) as geom
FROM whse_legal_admin_boundaries.abms_municipalities_sp
WHERE admin_area_group_name NOT IN
(
  'Strathcona Regional District',
  'Regional District of Alberni-Clayoquot',
  'Regional District of Nanaimo',
  'Comox Valley Regional District',
  'Capital Regional District',
  'Cowichan Valley Regional District',
  'Regional District of Mount Waddington'
)
AND admin_area_name NOT IN
(
  'Village of Queen Charlotte',
  'Village of Masset',
  'Village of Port Clements'
)
ORDER BY random() LIMIT 50"
time psql2csv < test_routing.sql > test_744_50.csv #6m4.516s


# --------
# test 4 - medium size origins file and 10 destinations
# --------
python ../thb.py load-origins data/origins_02_medium.csv
psql -c "DROP TABLE IF EXISTS destinations"
psql -c "CREATE TABLE destinations AS
 SELECT
  row_number() over() AS destination_id,
  admin_area_name AS destination_name,
  ST_PointOnSurface(geom) as geom
FROM whse_legal_admin_boundaries.abms_municipalities_sp
WHERE admin_area_group_name NOT IN
(
  'Strathcona Regional District',
  'Regional District of Alberni-Clayoquot',
  'Regional District of Nanaimo',
  'Comox Valley Regional District',
  'Capital Regional District',
  'Cowichan Valley Regional District',
  'Regional District of Mount Waddington'
)
AND admin_area_name NOT IN
(
  'Village of Queen Charlotte',
  'Village of Masset',
  'Village of Port Clements'
)
ORDER BY random() LIMIT 10"
time psql2csv < test_routing.sql > test_67364_10.csv

# bails after 1.5hrs, not sure if this is because I was testing in another connection though
# psql:test_routing.sql:73: server closed the connection unexpectedly
#   This probably means the server terminated abnormally
#   before or while processing the request.
# psql:test_routing.sql:73: fatal: connection to server was lost
#
# real  89m15.725s
#

# --------
# test 4 - try single tile of 10km hex tiling scheme, using unchanged origins/destinations
# --------
time psql2csv < test_tile_1.sql > test_tile_1.csv #0m42.523s (380 origins in the tile)

# --------
# test 5 - try making above a bit smarter
# --------
time psql2csv < test_tile_2.sql > test_tile_2.csv #0m42.038s (no difference, the db discards the dups automatically)

# --------
# test 5 - try two tiles at the same time
# --------
time psql2csv < test_tile_3.sql > test_tile_3.csv #1m32.774s (looks promising for parallelization)

# --------
# test 6 - try running the tiles in parallel
# --------
time psql -t -P border=0,footer=no \
-c "SELECT ''''||tile_id||'''' FROM tiles WHERE tile_id IN (3931, 3930)" \
    | sed -e '$d' \
    | parallel --colsep ' ' psql -f test_tile_4.sql -v tile={1}
# real  0m44.590s - looking good. We don't want to write to the csv in parallel though, write to a temp table
# (and this makes sense, we want to only process something if it has not already been run)

