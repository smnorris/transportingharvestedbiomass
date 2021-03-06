import csv
import numpy as np
import rasterio
from skimage.measure import label, regionprops_table
import pandas as pd
import click


@click.command()
@click.argument("in_tif", type=click.Path(exists=True))
@click.argument("out_csv")
def create_origins(in_tif, out_csv):
    """Create origins for the routing

    Arguments:
    in_tiff -- Path to input harvesting raster (geotiff)
    out_csv -- Path to output origins csv (centroid poitns with format (origin_id, biomass, count, x, y)
    """
    # load source image
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
    with open(out_csv, "w", newline="") as csvfile:
        writer = csv.writer(
            csvfile, delimiter=",", quotechar='"', quoting=csv.QUOTE_MINIMAL
        )
        # header
        writer.writerow(["origin_id", "biomass", "x", "y"])
        for i, row in enumerate(coordpairs, start=1):
            writer.writerow([i, row[0], row[1], row[2]])


if __name__ == "__main__":
    create_origins()
