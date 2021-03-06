# Transporting Harvested Biomass

## Requirements

- Docker
- miniconda
- postgresql client (psql available at the command line)

## Setup

Use docker to create a postgis/pgrouting enabled database, and use conda to set up the python environment and install dependencies:
If necessary, edit the port number to avoid conflicts with any existing postgres installations:

        setup.bat

## Processing

- load transport data, create network (edit .bat file as required to point to your data file):

        00_create_network.bat

- create origin centroids csv from input raster:

        python 01_create_origins.py <input raster> <centroids.csv>

- run the routing analysis and dump output Origin-Destination table to csv:

        python 02_create_od.py <origins csv> <destinations csv> <output OD csv>