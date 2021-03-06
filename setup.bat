REM ----------------
REM install postgres/postgis/pgrouting
REM ----------------
docker pull pgrouting/pgrouting:13-3.1-3.1.3
docker run -d ^
  -p 5434:5432 ^
  --name=pgrouting ^
  -e POSTGRES_HOST_AUTH_METHOD=trust ^
  pgrouting/pgrouting:13-3.1-3.1.3

REM ----------------
REM setup the database
REM ----------------
psql -p 5434 -U postgres postgres -c "CREATE DATABASE tbh"
psql -p 5434 -U postgres thb -c "CREATE extension postgis;"
psql -p 5434 -U postgres thb -c "CREATE extension pgrouting;"

REM ----------------
REM setup python environment, install dependencies
REM ----------------
conda create --n thbenv
conda activate thbenv
conda config --env --add channels conda-forge
conda config --env --set channel_priority strict

conda install rasterio
conda install scikit-image
conda install geopandas
conda install click