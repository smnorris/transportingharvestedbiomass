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
psql -p 5434 -U postgres postgres -c "CREATE DATABASE thb"
psql -p 5434 -U postgres thb -c "CREATE extension postgis;"
psql -p 5434 -U postgres thb -c "CREATE extension pgrouting;"