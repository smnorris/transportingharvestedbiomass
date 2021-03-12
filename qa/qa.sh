#----------------
# Using provided data files:
# - compare origins csv files created by arc / thb.py
# - compare output of routing (using origins created with thb.py) created by arc / thb.py
# ---------------


# ------ load and process data
# create new origins csv
python thb.py create-origins data/00_input.tif data/origins_thb.csv

# load new origins csv to db
python thb.py load-origins data/origins_thb.csv

# directly load and tidy the provided destinations table rather than converting to csv and using `thb.py load-destinations`
psql -c "DROP TABLE IF EXISTS destinations"
ogr2ogr \
  -t_srs EPSG:3005 \
  -f PostgreSQL "PG:host=localhost port=5434 user=postgres dbname=thb password=None" \
  -lco OVERWRITE=YES \
  -lco GEOMETRY_NAME=geom \
  -nln destinations \
  -dim XY \
  data/01_working.gdb \
  Destinations10
# correct the ids
psql -c "UPDATE destinations SET sel = 1 WHERE name = 'Terrace'"
psql -c "UPDATE destinations SET sel = 2 WHERE name = 'Vancouver'"
psql -c "UPDATE destinations SET sel = 3 WHERE name = 'Mackenzie'"
psql -c "UPDATE destinations SET sel = 4 WHERE name = 'Prince George'"
psql -c "UPDATE destinations SET sel = 5 WHERE name = 'Quesnel'"
psql -c "UPDATE destinations SET sel = 6 WHERE name = 'Williams Lake'"
psql -c "UPDATE destinations SET sel = 7 WHERE name = 'McMahon Gas Plant'"
psql -c "UPDATE destinations SET sel = 8 WHERE name = 'Kamloops'"
psql -c "UPDATE destinations SET sel = 9 WHERE name = 'Castlegar'"
psql -c "UPDATE destinations SET sel = 10 WHERE name = 'Elkford'"

psql -c "ALTER TABLE destinations DROP COLUMN objectid_1"
psql -c "ALTER TABLE destinations DROP COLUMN objectid"
psql -c "ALTER TABLE destinations DROP COLUMN long_x"
psql -c "ALTER TABLE destinations DROP COLUMN lat_y"
psql -c "ALTER TABLE destinations DROP COLUMN frequency"
psql -c "ALTER TABLE destinations DROP COLUMN first_data"
psql -c "ALTER TABLE destinations RENAME COLUMN sel to destination_id"
psql -c "ALTER TABLE destinations RENAME COLUMN name TO destination_name"
psql -c "ALTER TABLE destinations ADD PRIMARY KEY (destination_id)"

# process
python thb.py run-routing -n 2 -o cost_matrix_pg.csv

# load output csv back to db for running comparison
csvsql --db postgresql://postgres@localhost:5434/thb --table cost_matrix_pg --insert cost_matrix_pg.csv

# load arc generated origins csv to db
csvsql --db postgresql://postgres@localhost:5434/thb --table origins_arc --insert data/00_output.csv
psql -c "ALTER TABLE origins_arc ADD COLUMN geom geometry(Point, 3005)"
psql -c 'UPDATE origins_arc SET geom = ST_Transform(ST_SetSRID(ST_Point("POINT_X", "POINT_Y"), 4326), 3005)'

# load arc generated cost-matrix to db
csvsql --db postgresql://postgres@localhost:5434/thb --table cost_matrix_arc --insert data/01_output.csv

# ------ now compare the data

# compare the centroid coordinates in the two origin files
psql2csv < origin_centroid_comparison.sql > origin_centroid_comparison.csv

# compare the two cost matrix outputs where no rail or water transport occured in the arc version
psql2csv < output_comparison.sql > output_comparison.csv