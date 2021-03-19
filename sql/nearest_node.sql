-- find and load closest node/intersection in network to each point in input table

WITH nearest_node AS
(
  SELECT
      o.{id},
      CASE
        WHEN segment_pct < 0.5
        THEN nn.source
        ELSE nn.target
      END as node_id
    FROM {in_table} o
    CROSS JOIN LATERAL
    (SELECT
       n.source,
       n.target,
       ST_LineLocatePoint(n.geom, o.geom) as segment_pct
     FROM network n
     ORDER BY n.geom <-> o.geom
     LIMIT 1
     ) AS nn
)

UPDATE {in_table} a
SET node_id = n.node_id
FROM nearest_node n
WHERE a.{id} = n.{id}
