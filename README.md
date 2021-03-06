# Transporting Harvested Biomass

## Requirements

- Docker
- miniconda

## Setup

Use docker to create a postgis/pgrouting enabled database, and use conda to set up the python environment and install dependencies:

`setup.bat`

## Processing

- load transport data, create network (edit .bat file as required to point to your data file):

        00_create_network.bat

- create origin centroids from input raster:

        python 01_create_origins.py <input raster> <centroids.csv>

- run the routing analysis and dump output Origin-Destination table to csv:

        python 02_create_od.py