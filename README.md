# Transporting Harvested Biomass

Estimate transportation distances from forest polygons to selected destinations.

## Requirements

- Postgresql/PostGIS/PGRouting (v13/3.1/3.1.3)
- Python>=3.6
- Docker (optional, for easy installation of a test database)

## Setup

Local installation and configuration of the postgresql/postgis/pgrouting database is not covered here.
To quickly set up a test database, consider using Docker as outlined in `docker_setup.bat`. Modify the port as needed to avoid conflict with any local postgresql installations.

Installation/setup of the Python and GDAL dependencies is easiest via `conda`.
Once your database is set up, modify the postgres database connection environment variables in `environment.yml`:
```
  PGHOST: localhost
  PGUSER: postgres
  PGPORT: 5434
  PGDATABASE: thb
  DATABASE_URL: postgresql://postgres@localhost:5434/thb
```
The provided default parameters match the connection parameters for the db created in the Docker script (the port is mapped to `5434` to avoid collision with any local db at the usual `5432`)

Once your environment variables are set, create and activate the environment:

```
conda env create -f environment.yml
conda activate thbenv
```

## Network data load

Edit `load.bat`, modifying paths to transportation feature data (roads/rail/water) and the database connection parameters as required.
When ready, run `load.bat` to load features to the database, build network from all transportation features, and build the turn restrictions table (modelling a cost of $2 to transfer between transportation modes).

Output network/turn restriction tables are:

```
                                            Table "public.network_test"
    Column    |           Type            | Collation | Nullable |                     Default
--------------+---------------------------+-----------+----------+--------------------------------------------------
 network_id   | integer                   |           | not null | nextval('network_test_network_id_seq'::regclass)
 data_source  | character varying(5)      |           |          |
 rd_surface   | character varying(12)     |           |          |
 road_class   | character varying(12)     |           |          |
 awater       | double precision          |           |          |
 awaterinterp | double precision          |           |          |
 aboat        | double precision          |           |          |
 acityspoke   | double precision          |           |          |
 aloose       | double precision          |           |          |
 aovergrown   | double precision          |           |          |
 apaved       | double precision          |           |          |
 arough       | double precision          |           |          |
 aseasonal    | double precision          |           |          |
 aunknown     | double precision          |           |          |
 arail        | double precision          |           |          |
 cost         | double precision          |           |          |
 geom         | geometry(LineString,3005) |           |          |
 source       | integer                   |           |          |
 target       | integer                   |           |          |
Indexes:
    "network_test_pkey" PRIMARY KEY, btree (network_id)
    "network_test_geom_idx" gist (geom)
    "network_test_source_idx" btree (source)
    "network_test_target_idx" btree (target)


                                           Table "public.restrictions"
     Column     |       Type       | Collation | Nullable |                       Default
----------------+------------------+-----------+----------+------------------------------------------------------
 restriction_id | integer          |           | not null | nextval('restrictions_restriction_id_seq'::regclass)
 to_cost        | double precision |           |          |
 target_id      | integer          |           |          |
 via_path       | text             |           |          |
Indexes:
    "restrictions_pkey" PRIMARY KEY, btree (restriction_id)

```


## Route processing

A single script `thb.py` is provided, with several commands:

```
(thbenv) python thb.py --help
Usage: thb.py [OPTIONS] COMMAND [ARGS]...

Options:
  --help  Show this message and exit.

Commands:
  create-origins     Create origin point csv from input raster.
  load-destinations  Load destinations csv to postgres and create geometry.
  load-origins       Load origins csv to postgres and create geometry.
  run-routing        Calculate least-cost routes from orgins to
                     destinations...
```

Usage help is available for each command, for example:

```
(thbenv) python thb.py run-routing --help
Usage: thb.py run-routing [OPTIONS]

  Calculate least-cost routes from orgins to destinations and report on -
  cost - distance by type Write output to csv

Options:
  -v, --verbose              Increase verbosity.
  -q, --quiet                Decrease verbosity.
  -db, --db_url TEXT         SQLAlchemy database url
  -o, --out_csv TEXT         Path to output csv
  -n, --n_processes INTEGER  Maximum number of parallel processes
  --help                     Show this message and exit.
```

#### `create-origins`

Create origin centroids from an input raster (geotiff).
For example, with the provided input geotiff in the /data folder:

    python thb.py create-origins data/00_input.tif data/origins.csv


#### `load-origins`

Load origins from csv to table `origins` in the database.

- origins csv must be of format (`origin_id,biomass,count,x,y`) and must include a header
- origin x/y coordinates must be lon/lat EPSG:4326

For example, to load the origins file created from the sample geotiff:

    python thb.py load-origins data/origins.csv


#### `load-destinations`

Load (manually crated) destinations from csv to table `destinations` in the database.

- destinations csv must be of format (`destination_id,destination_name,x,y`) and must include a header
- destination x/y coordinates must be lon/lat EPSG:4326

For example:

    python thb.py load-destinations data/destinations.csv


#### `run-routing`

Find least cost paths for all combinations of records in the `origins` and `destinations` tables, then dump output Origin-Destination cost matrix to csv:

For example, running on up to 10 cores and outputing to `my_output_file.csv`:

    python thb.py run-routing -n 10 -o my_output_file.csv

Notes:

1. For more detailed usage for each command, see the help.

2. In the db, the tool creates and populates the table `origin_destinations_cost_matrix`. This table records the cost/length of travel between given nodes in the network. Once calculated for a given road segment, these costs do not have to be recaluclated on each run of the tool and subseqeunt runs of the tool with similar inputs should be faster.

3. A general progress bar is displayed during routing to indicate the work is continuing. Because the progress bar iterates over the internal tiles rather than the individual origins (and number of points per tile will vary widely), the time indicated may not provide a good guide to completion time.

## QA Summary

Scripts in `qa` were used to check against provided results from ArcGIS.
(Note that `qa.sh` is a bash script and has some dependencies not included in the conda environment)


### Comparison of scikit-image/numpy centroids to ArcGIS centroids

For the provided data, data assoicated with all origins (sum of pixels, biomass) is exactly the same for all 744 locations. Centroid locations differ slightly. This table summarizes the distance between centroids for the same cutblock between the two sources, where the maximum difference was 583m.

| distance | count |
| -------- |:-----:|
| 0-1m     | 338 |
| 1-10m    | 209 |
| 10-25m   | 41  |
| 25-50m   | 44  |
| 50-75m   | 40  |
| 75-100m  | 17  |
| >= 100m  | 55  |

### Comparisons of cost/distance matrix outputs

