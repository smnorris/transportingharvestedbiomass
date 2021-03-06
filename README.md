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

## Processing

A single script `thb.py` is provided, with a seperate command for each part of the job:

```
(thbenv) python thb.py --help
Usage: thb.py [OPTIONS] COMMAND [ARGS]...

Options:
  --help  Show this message and exit.

Commands:
  create-network     Load road file/layer to db, create network topology.
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



#### `create-network`

Load the roads layer to the database and create the network with pg_routing.
For example, with the provided .gdb, having `objectid` as the existing unique id.

    python thb.py create-network data/01_working.gdb Roadnet_only2_1_1splitn_1 objectid

The output table is `network`, with primary key renamed to `network_id`. All other existing fields are retained as is.
In addtion to an existing unique identifier, the network table must contain these numeric columns (plus the geometries):
```
 awater
 awaterinterp
 aboat
 acityspoke
 aloose
 aovergrown
 apaved
 arough
 aseasonal
 aunknown
 cost
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

Because the networks are not identical (no rail or water in the version used in postgis), not all records are comparable.
However, we can compare all output routes that did not include rail/water in the arc analysis:

- 253 rows have a different output destination rank (of 1), mostly when comparing McMahon Gas Plant with Kamloops or Quesnel.
- the average total cost difference between the two methods is $.00867
- the average total distance difference between the two methods is 125m

Some of the difference can likely be attributed to the shift in centroid locations, but it is difficult to determine what other sources may contribute to these differences.

See the [summary csv](qa/output_comparison.csv) to review the exact differences in the sample data (for routes that did not include rail/water in the ArcGIS version)