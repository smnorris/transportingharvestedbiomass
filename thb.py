import csv
import logging
import sys
import os
from urllib.parse import urlparse
import multiprocessing
from pathlib import Path
from functools import partial

import numpy as np
import rasterio
from skimage.measure import label, regionprops_table
import pandas as pd
import click
from cligj import verbose_opt, quiet_opt
from psycopg2 import sql
from psycopg2 import extras
import pgdata


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


def batched_routing_query(query, chunk):
    """Execute sql for specified chunk of records using a non-pooled connection
    """
    # specify multiprocessing when creating to disable connection pooling
    db = pgdata.connect(multiprocessing=True)
    conn = db.engine.raw_connection()
    cur = conn.cursor()
    # Turn off parallel execution for this connection, because we are
    # handling the parallelization ourselves
    cur.execute("SET max_parallel_workers_per_gather = 0")
    # find o-d pairs to process
    cur.execute("SELECT origin_node_id, destination_node_id FROM temp_origin_destinations WHERE chunk = %s", (chunk,))
    od_pairs = cur.fetchall()
    results = []
    for od in od_pairs:
        print(od[0], od[1])
        cur.execute(query, (od[0], od[1], od[0], od[1]))
        r = cur.fetchall()
        results.append(r)
    return results


def add_nearest_node(in_table, id):
    """add the id of the nearest network node to the input table
    """
    db = pgdata.connect()
    db.execute(f"ALTER TABLE {in_table} ADD COLUMN IF NOT EXISTS node_id integer")
    query = sql.SQL(Path(Path.cwd() / "sql" / "nearest_node.sql").read_text()).format(
        in_table=sql.Identifier(in_table),
        id=sql.Identifier(id)
    )
    conn = db.engine.raw_connection()
    cur = conn.cursor()
    cur.execute(query)
    conn.commit()
    conn.close()
    db.execute(f"CREATE INDEX ON {in_table} (node_id)")


@click.group()
def cli():
    pass


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
    df = pd.DataFrame(regionprops_table(img_label, properties=["area", "centroid"]))

    # convert the cell references to lat/lon
    # https://rasterio.readthedocs.io/en/latest/api/rasterio.transform.html#rasterio.transform.xy
    xs, ys = rasterio.transform.xy(transform, df["centroid-0"], df["centroid-1"])

    # record count of cells per label
    count = df["area"]

    # note that sum_per_label includes the summary for 0s, remove by stepping up by 1
    coordpairs = zip(sum_per_label[1:], count, xs, ys)

    # dump results to csv
    log.info(f"Writing origin coordinates to {out_csv}")
    with open(out_csv, "w", newline="") as csvfile:
        writer = csv.writer(
            csvfile, delimiter=",", quotechar='"', quoting=csv.QUOTE_MINIMAL
        )
        # header
        writer.writerow(["origin_id", "biomass", "count", "x", "y"])
        for i, row in enumerate(coordpairs, start=1):
            writer.writerow([i, row[0], row[1], row[2], row[3]])


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
    with open(in_csv, "r") as f:
        next(f)  # Skip the header row.
        cur.copy_from(f, "origins", sep=",")
    conn.commit()
    cur.close()
    conn.close()
    db.execute("ALTER TABLE origins ADD COLUMN geom geometry(Point, 3005)")
    db.execute(
        "UPDATE origins SET geom = ST_Transform(ST_SetSRID(ST_Point(x, y), 4326), 3005)"
    )
    db.execute("ALTER TABLE origins DROP COLUMN x")
    db.execute("ALTER TABLE origins DROP COLUMN y")
    db.execute("CREATE INDEX ON origins USING GIST (geom)")

    # add the id of the nearest network node to the table
    add_nearest_node("origins", "origin_id")


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
    with open(in_csv, "r") as f:
        next(f)  # Skip the header row.
        cur.copy_from(f, "destinations", sep=",")
    conn.commit()
    cur.close()
    conn.close()
    db.execute("ALTER TABLE destinations ADD COLUMN geom geometry(Point, 3005)")
    db.execute(
        "UPDATE destinations SET geom = ST_Transform(ST_SetSRID(ST_Point(x, y), 4326), 3005)"
    )
    db.execute("ALTER TABLE destinations DROP COLUMN x")
    db.execute("ALTER TABLE destinations DROP COLUMN y")
    db.execute("CREATE INDEX ON destinations USING GIST (geom)")

    # add the id of the nearest network node to the table
    add_nearest_node("destinations", "destination_id")


@cli.command()
@verbose_opt
@quiet_opt
@click.option(
    "--db_url",
    "-db",
    help="SQLAlchemy database url",
    default=os.environ.get("DATABASE_URL"),
)
@click.option("--out_csv", "-o", help="Path to output csv", default="cost_matrix.csv")
@click.option(
    "--n_processes", "-n", help="Maximum number of parallel processes", default=1
)
def run_routing(out_csv, db_url, n_processes, verbose, quiet):
    """Calculate origin-destination cost matrix and write output to csv.
    """
    verbosity = verbose - quiet
    log_level = max(10, 20 - 10 * verbosity)
    logging.basicConfig(stream=sys.stderr, level=log_level)
    log = logging.getLogger(__name__)

    db = pgdata.connect(db_url)

    # create tiles layer if it does not exist
#    if "public.tiles" not in db.tables:
#        log.info("Creating tiles table for parallelization")
#        db.execute(db.queries["create_tiles"])

    # create output table if it does not exist
    if "public.origin_destination_cost_matrix" not in db.tables:
        log.info("Creating output origin-destination cost matrix table")
        db.execute(db.queries["create_origin_destination_cost_matrix"])

    # find and load distinct origin-destination nodes not already in output
    query = sql.SQL(Path(Path.cwd() / "sql" / "temp_origin_destination.sql").read_text())
    conn = db.engine.raw_connection()
    cur = conn.cursor()
    cur.execute(query, (n_processes,))
    conn.commit()

    # Report on how many we are processing
    n = db.query("SELECT COUNT(*) FROM temp_origin_destinations").fetchone()[0]
    log.info(f"Processing {n} origin-destination pairs")
    query = sql.SQL(Path(Path.cwd() / "sql" / "routing.sql").read_text())

    """
    just loop in single process

    db = pgdata.connect(multiprocessing=True)
    conn = db.engine.raw_connection()
    cur = conn.cursor()
    cur.execute("SELECT origin_node_id, destination_node_id FROM temp_origin_destinations")
    od_pairs = cur.fetchall()
    results = []
    for od in od_pairs:
        cur.execute(query, (od[0], od[1], od[0], od[1]))
        r = cur.fetchall()
        results.append(r)
    for row in results:
        print(row)
    extras.execute_values(cur, "INSERT INTO public.origin_destination_cost_matrix VALUES %s", results, "(%s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s)")
    """

    # in n parallel processes

    # divide our o-d pairs into seperate piles per process/connection
    chunks = [i for i in range(1, n_processes + 1)]
    func = partial(batched_routing_query, query)
    pool = multiprocessing.Pool(processes=n_processes)
    # add a progress bar
    results_iter = pool.imap_unordered(func, chunks)
    with click.progressbar(results_iter, length=len(chunks)) as bar:
        for _ in bar:
            pass
    pool.close()
    pool.join()

    results_iter.join()

    # write result to db
    extras.execute_values(cur, "INSERT INTO public.origin_destination_cost_matrix VALUES %s", results_iter, "(%s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s)")

    # dump to csv
    """
    log.info(f"Dumping results to file {out_csv}")
    query_text = Path(Path.cwd() / "sql" / "report.sql").read_text()
    query_csv = f"COPY ({query_text}) TO STDOUT WITH CSV HEADER"
    conn = db.engine.raw_connection()
    cur = conn.cursor()
    with open(out_csv, "w") as f:
        cur.copy_expert(query_csv, f)
    conn.close()
    """


if __name__ == "__main__":
    cli()
