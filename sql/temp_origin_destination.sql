-- find all possible o-d combinations
DROP TABLE IF EXISTS temp_origin_destination;

CREATE TABLE temp_origin_destination AS

WITH combinations AS
(
  SELECT DISTINCT
    o.node_id as origin_node_id,
    d.node_id as destination_node_id
  FROM origins o
  CROSS JOIN destinations d
),

-- from above, find o-d combinations not already in output table
not_already_computed AS
(
  SELECT
    c.origin_node_id,
    c.destination_node_id
  FROM combinations c
  LEFT OUTER JOIN origin_destination_cost_matrix m
  ON c.origin_node_id = m.origin_node_id
  AND c.destination_node_id = m.destination_node_id
  WHERE m.origin_node_id IS NULL
)

-- load to temp table, adding an id for chunking the data

SELECT
  row_number() over() as id,
  ntile(%s) over() as chunk,
  origin_node_id,
  destination_node_id
FROM not_already_computed;