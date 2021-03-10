-- create a basic tiles table for parallelization

DROP TABLE IF EXISTS tiles;

CREATE TABLE tiles AS
SELECT
  row_number() over() as tile_id,
  geom
FROM
(
    SELECT
      geom
    FROM
      -- I am sure a square grid is just as good but this hex grid *might* group origins slightly better
      ST_HexagonGrid(10000, ST_SetSRID(ST_EstimatedExtent('network', 'geom'), 3005) ) AS hex
) AS f;

ALTER TABLE tiles ADD PRIMARY KEY (tile_id);

CREATE INDEX ON tiles USING GIST (geom);