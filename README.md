# Transporting Harvested Biomass

## Requirements

- Postgresql/PostGIS/PGRouting (tested with v13/3.1/3.1.3)
- Python>=3.6
- Docker (optional, for easy installation of a test database)

## Setup

Local installation and configuration of the postgresql/postgis/pgrouting database is not covered here.
To quickly set up a test database, consider using Docker as outlined in `docker_setup.bat`. Modify the port as needed to avoid conflict with any local postgresql installations.

Installation/setup of the Python and GDAL dependencies is easiest via `conda`.
Once your database is set up, modify the postgres database connection environment variables in the environment file:
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
  create-network  Load road file/layer to db, create network topology.
  create-origins  Create origin point csv from input raster.
```

#### `create-network`

Load the roads layer to the database and create the network with pg_routing.
For example, with the provided .gdb:

    python thb.py create-network data/01_working.gdb Roadnet_only2_1_1splitn_1 objectid


#### `create-origins`

Create origin centroids from an input raster (geotiff):
For example, with the provided input geotiff in the /data folder:

    python thb.py create-origins data/


#### `load-origins`

Load origins from csv to the database:

    python thb.py load-origins <path to origins csv>


#### `load-destinations`

Load (manually crated) destinations from csv to the database:

    python thb.py load-destinations <path to origins csv>


#### `run-routing`

Run the routing analysis and dump output Origin-Destination table to csv:

    python thb.py routing <origins csv> <destinations csv> <output OD csv>