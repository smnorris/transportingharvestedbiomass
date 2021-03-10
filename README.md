# Transporting Harvested Biomass

## Requirements

- Postgresql/PostGIS/PGRouting (tested with v13/3.1/3.1.3)
- Python>=3.6
- Docker (optional, for easy installation of a test database)

## Setup

Local installation and configuration of the postgresql/postgis/pgrouting database is not covered here.
To quickly set up a test database, consider using Docker as outlined in `docker_setup.bat`. Modify the port as needed to avoid conflict with any local postgresql installations.

Installation/setup of the Python and GDAL dependencies is easiest via `conda`.
Once your database is set up, edit the postgresql connection environment varialbles in `environment.yml` as required:
```
  PGHOST: localhost
  PGUSER: postgres
  PGPORT: 5434
  PGDATABASE: thb
  PGOGR: 'host=localhost user=postgres dbname=thb password=postgres port=5434'
```
The provided default parameters match the connection parameters for the db created in the Docker script (port mapped to 5434 to avoid collision with any local db at the usual 5432)

Once your environment variables are set in `environment.yml`, create and activate the environment:

```
conda env create -f environment.yml
conda activate thbenv
```

## Processing

#### Create the network

Load your roads layer to the database and create the network with pg_routing:

    python thb.py create-network <path to in network layer>


#### Create origin points (cutblock centroids)

Create origin centroids from an input raster (a geotiff or any gdal supported raster):

    python thb.py create-origins <path to input raster> <output centroids csv>


#### Load origins and destinations

Load origins locations from csv to the database:

    python thb.py load-origins <path to origins csv>

Load destination locations from csv to the database:

    python thb.py load-destinations <path to desintations csv>


#### Run the routing analysis

Run the routing analysis and dump output Origin-Destination table to csv:

    python thb.py routing <origins csv> <destinations csv> <output OD csv>