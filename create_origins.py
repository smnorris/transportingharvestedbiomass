import csv
import numpy as np
import rasterio
from skimage.measure import label, regionprops_table
import pandas as pd

# load image
with rasterio.open(r"data/00_input.tif") as src:
    img_source = src.read(1)
    transform = src.transform

# keep only values greater than 1 and convert to integer
img_integer = np.where(img_source > 1, img_source, 0).astype(int)

# label - find connected groups of pixels with the same value
img_label = label(img_integer, connectivity=2)

# find sum of values (in source float array) within each label/group of pixels
sum_per_label = np.bincount(img_label.flatten(), weights=img_source.flatten())

# load label ids and centroids into a pandas data frame
df = pd.DataFrame(regionprops_table(img_label, properties=['centroid']))

# convert the cell references to lat/lon
xs, ys = rasterio.transform.xy(transform, df["centroid-0"], df["centroid-1"])
coordpairs = zip(sum_per_label[1:], xs, ys)  # remove the sum for 0 label by stepping up 1

# dump to csv
with open(r'data/origins_test.csv', 'w', newline='') as csvfile:
    writer = csv.writer(csvfile, delimiter=',', quotechar='"', quoting=csv.QUOTE_MINIMAL)
    # header
    writer.writerow(["origin_id", "znsums_SUM", "x", "y"])
    for i, row in enumerate(coordpairs, start=1):
        writer.writerow([i, row[0], row[1], row[2]])
