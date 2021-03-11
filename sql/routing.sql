WITH origins AS
 ( SELECT
    o.origin_id,
    -- find closest node/intersection
    CASE
      WHEN segment_pct < 0.5
      THEN nn.source
      ELSE nn.target
    END as node
  FROM origins o
  INNER JOIN tiles t
  ON ST_Intersects(o.geom, t.geom)
  CROSS JOIN LATERAL
  (SELECT
     n.source,
     n.target,
     ST_LineLocatePoint(n.geom, o.geom) as segment_pct
   FROM network n
   ORDER BY n.geom <-> o.geom
   LIMIT 1
 ) as nn
 WHERE t.tile_id = %s
),

destinations AS
(
 SELECT
    d.destination_id,
    d.destination_name,
    -- find closest node/intersection
    CASE
      WHEN segment_pct < 0.5
      THEN nn.source
      ELSE nn.target
    END as node
  FROM destinations d
  CROSS JOIN LATERAL
  (
    SELECT
      n.source,
      n.target,
      ST_LineLocatePoint(n.geom, d.geom) as segment_pct
    FROM network n
    ORDER BY n.geom <-> d.geom
    LIMIT 1
  ) AS nn
),

combinations AS
(
  SELECT DISTINCT
    o.node as origin_node_id,
    d.node as destination_node_id
  FROM origins o
  CROSS JOIN destinations d
),

not_already_computed AS
(
  SELECT
    c.origin_node_id,
    c.destination_node_id
  FROM combinations c
  LEFT OUTER JOIN origin_destination_cost_matrix m
  ON c.origin_node_id = m.origin_node_id
  AND c.destination_node_id = m.destination_node_id
  WHERE m.total_cost IS NULL
)

INSERT INTO origin_destination_cost_matrix (
  origin_node_id,
  destination_node_id,
  total_cost,
  total_length,
  total_apaved,
  total_aloose,
  total_arough,
  total_aovergrown,
  total_aseasonal,
  total_aunknown,
  total_acityspoke,
  total_awater,
  total_awaterinterp,
  total_aboat
)
SELECT
  c.origin_node_id,
  c.destination_node_id,
  ROUND(SUM(x.cost)::numeric, 2) AS total_cost,
  ROUND(SUM(ST_Length(n.geom))::numeric, 2) as total_length,
  ROUND(SUM(n.apaved)::numeric, 2) AS total_apaved,
  ROUND(SUM(n.aloose)::numeric, 2) AS total_aloose,
  ROUND(SUM(n.arough)::numeric, 2) AS total_arough,
  ROUND(SUM(n.aovergrown)::numeric, 2) AS total_aovergrown,
  ROUND(SUM(n.aseasonal)::numeric, 2) AS total_aseasonal,
  ROUND(SUM(n.aunknown)::numeric, 2) AS total_aunknown,
  ROUND(SUM(n.acityspoke)::numeric, 2) AS total_acityspoke,
  ROUND(SUM(n.awater)::numeric, 2) AS total_awater,
  ROUND(SUM(n.awaterinterp)::numeric, 2) AS total_awaterinterp,
  ROUND(SUM(n.aboat)::numeric, 2) AS total_aboat
FROM
  pgr_Dijkstra(
    'SELECT network_id as id, source, target, cost FROM network',
    (SELECT array_agg(origin_node_id) FROM (SELECT DISTINCT origin_node_id FROM combinations) AS f),
    (SELECT array_agg(destination_node_id) FROM (SELECT DISTINCT destination_node_id FROM combinations) AS b),
    FALSE
) x
INNER JOIN network n ON x.edge = n.network_id
INNER JOIN combinations c ON x.end_vid = c.destination_node_id AND x.start_vid = c.origin_node_id
GROUP BY c.origin_node_id, c.destination_node_id
ORDER BY c.origin_node_id, SUM(x.cost)
-- conflicts are possible because of parallel processing - an origin can be present in > 1 tile,
-- and not_already_computed above may be calculated before an adjacent tile is complete
ON CONFLICT DO NOTHING;
