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
time psql -f test_routing.sql > test_744_10.csv # 1m20.597s


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
time psql -f test_routing.sql > test_744_20.csv # 1m54.400s

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
time psql -f test_routing.sql > test_744_50.csv #6m4.516s


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
time psql -f test_routing.sql > test_67364_10.csv #1m22.412s

