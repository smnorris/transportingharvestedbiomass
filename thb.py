import subprocess
import csv
import logging
import sys
import os
from urllib.parse import urlparse

import numpy as np
import rasterio
from skimage.measure import label, regionprops_table
import pandas as pd
import click
from cligj import verbose_opt, quiet_opt
import pgdata
import psycopg2


def configure_logging(verbosity):
    log_level = max(10, 30 - 10 * verbosity)
    logging.basicConfig(stream=sys.stderr, level=log_level)


def parse_db_url(db_url):
    """provided a db url, return a dict with connection properties
    """
    u = urlparse(db_url)
    db = {}
    db["database"] = u.path[1:]
    db["user"] = u.username
    db["host"] = u.hostname
    db["port"] = u.port
    db["password"] = u.password
    return db


@click.group()
def cli():
    pass


@cli.command()
@verbose_opt
@quiet_opt
@click.option(
    "--db_url",
    "-db",
    help="SQLAlchemy database url",
    default=os.environ.get("DATABASE_URL"),
)
@click.argument("in_file")
@click.argument("in_layer")
@click.argument("unique_id")
def create_network(in_file, in_layer, unique_id, db_url, verbose, quiet):
    """
    Load road file/layer to db, create network topology.

    Arguments:
    in_file  -- Path to input shape / .gdb folder or gpkg file
    in_layer -- Name of input shapefile / geodatabase-geopackage layer
    uniqe_id -- Name of unique identifer column in input layer
    db_url   -- See options above

    **NOTE**

    This is expected to work for the provided roads data only. If loading
    multiple layers to your network or loading to a different table, it is
    likely better to do the load in a separate custom set of ogr commands.
    """

    # for this command, default to INFO level logging
    # (echo the ogr2ogr commands by default)
    verbosity = verbose - quiet
    log_level = max(10, 20 - 10 * verbosity)
    logging.basicConfig(stream=sys.stderr, level=log_level)
    log = logging.getLogger(__name__)

    db = parse_db_url(db_url)
    click.echo(db_url)
    db_string = "PG:host={h} user={u} dbname={db} port={port}".format(
        h=db["host"], u=db["user"], db=db["database"], port=db["port"],
    )
    if db["password"]:
        db_string = db_string + " password={pwd}".format(pwd=db["password"])
    log = logging.getLogger(__name__)
    command = [
        "ogr2ogr",
        "-t_srs",
        "EPSG:3005",
        "-f",
        "PostgreSQL",
        db_string,
        "-lco",
        "OVERWRITE=YES",
        "-lco",
        "GEOMETRY_NAME=geom",
        "-nln",
        "roads",
        "-dim",
        "XY",
        "-nlt",
        "LINESTRING",
        in_file,
        in_layer,
    ]
    log.info(" ".join(command))
    subprocess.run(command)

    # add pgrouting required source/target columns
    db = pgdata.connect(db_url)
    db.execute("ALTER TABLE roads ADD COLUMN source integer")
    db.execute("ALTER TABLE roads ADD COLUMN target integer")

    # build the network topology - this takes about 11min on my machine
    log.info("Building routing topology")
    db.execute(f"SELECT pgr_createTopology('roads', 0.000001, 'geom', '{unique_id}')")


@cli.command()
@verbose_opt
@quiet_opt
@click.argument("in_tif", type=click.Path(exists=True))
@click.argument("out_csv")
def create_origins(in_tif, out_csv, verbose, quiet):
    """
    Create origin point csv from input raster.

    - any raster format readable by rasterio/gdal should work
    - coordinates in the output csv will match the CRS of input raster

    Arguments:
    in_tiff -- Path to input harvesting raster
    out_csv -- Path to output origins csv (centroid poitns with format (origin_id, biomass, count, x, y)
    """
    verbosity = verbose - quiet
    log_level = max(10, 20 - 10 * verbosity)
    logging.basicConfig(stream=sys.stderr, level=log_level)
    log = logging.getLogger(__name__)
    # load source image
    log.info(f"Reading input raster {in_tif}")
    with rasterio.open(in_tif) as src:
        img_source = src.read(1)
        transform = src.transform

    # keep only values greater than 1 and convert to integer
    img_integer = np.where(img_source > 1, img_source, 0).astype(int)

    # label - find connected regions/groups of pixels with the same value,
    # using the 8 surrounding cells
    # https://scikit-image.org/docs/stable/api/skimage.morphology.html?highlight=label#label
    img_label = label(img_integer, connectivity=2)

    # find sum of values (in source float array) within each label/group of pixels
    # basically a raster based zonalstats
    # https://numpy.org/doc/stable/reference/generated/numpy.bincount.html
    sum_per_label = np.bincount(img_label.flatten(), weights=img_source.flatten())

    # load label ids and centroids into a pandas data frame
    # https://scikit-image.org/docs/dev/api/skimage.measure.html#skimage.measure.regionprops_table
    df = pd.DataFrame(regionprops_table(img_label, properties=["centroid"]))

    # convert the cell references to lat/lon
    # https://rasterio.readthedocs.io/en/latest/api/rasterio.transform.html#rasterio.transform.xy
    xs, ys = rasterio.transform.xy(transform, df["centroid-0"], df["centroid-1"])
    coordpairs = zip(
        sum_per_label[1:], xs, ys
    )  # note that sum_per_label includes the summary for 0s - remove by stepping up by 1

    # dump results to csv
    log.info(f"Writing origin coordinates to {out_csv}")
    with open(out_csv, "w", newline="") as csvfile:
        writer = csv.writer(
            csvfile, delimiter=",", quotechar='"', quoting=csv.QUOTE_MINIMAL
        )
        # header
        writer.writerow(["origin_id", "biomass", "x", "y"])
        for i, row in enumerate(coordpairs, start=1):
            writer.writerow([i, row[0], row[1], row[2]])


@cli.command()
@click.option(
    "--db_url",
    "-db",
    help="SQLAlchemy database url",
    default=os.environ.get("DATABASE_URL"),
)
@click.argument("in_csv")
def load_origins(in_csv, db_url):
    """
    Load origins csv to postgres and create geometry.

    Origins csv must be of format: (origin_id,biomass,count,x,y)
    Coordinates must be lon/lat EPSG:4326

    Arguments:
    in_csv -- Path to input origins csv
    """
    db = pgdata.connect()
    db.execute("DROP TABLE IF EXISTS origins")
    db.execute(
        """
        CREATE TABLE origins (
          origin_id integer primary key,
          biomass double precision,
          count integer,
          x double precision,
          y double precision)
    """
    )
    conn = db.engine.raw_connection()
    cur = conn.cursor()
    with open(in_csv, 'r') as f:
        next(f)                             # Skip the header row.
        cur.copy_from(f, 'origins', sep=',')
    conn.commit()
    cur.close()
    conn.close()
    db.execute("ALTER TABLE origins ADD COLUMN geom geometry(Point, 3005)")
    db.execute(
        "UPDATE origins SET geom = ST_Transform(ST_SetSRID(ST_Point(x, y), 4326), 3005)"
    )
    db.execute("ALTER TABLE origins DROP COLUMN x")
    db.execute("ALTER TABLE origins DROP COLUMN y")


@cli.command()
@click.option(
    "--db_url",
    "-db",
    help="SQLAlchemy database url",
    default=os.environ.get("DATABASE_URL"),
)
@click.argument("in_csv")
def load_destinations(in_csv, db_url):
    """
    Load destinations csv to postgres and create geometry.

    Destinations csv must be of format: (destination_id,destination_name,x,y)
    Coordinates must be lon/lat EPSG:4326

    Arguments:
    in_csv -- Path to input destinations csv
    """
    db = pgdata.connect(db_url)
    db.execute("DROP TABLE IF EXISTS destinations")
    db.execute(
        """
        CREATE TABLE destinations (
        destination_id integer primary key,
        destination_name text,
        x double precision,
        y double precision)
    """
    )
    conn = db.engine.raw_connection()
    cur = conn.cursor()
    with open(in_csv, 'r') as f:
        next(f)                             # Skip the header row.
        cur.copy_from(f, 'destinations', sep=',')
    conn.commit()
    cur.close()
    conn.close()
    db.execute("ALTER TABLE destinations ADD COLUMN geom geometry(Point, 3005)")
    db.execute(
        "UPDATE destinations SET geom = ST_Transform(ST_SetSRID(ST_Point(x, y), 4326), 3005)"
    )
    db.execute("ALTER TABLE destinations DROP COLUMN x")
    db.execute("ALTER TABLE destinations DROP COLUMN y")


if __name__ == "__main__":
    cli()
