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
  CROSS JOIN LATERAL
  (SELECT
     n.source,
     n.target,
     ST_LineLocatePoint(n.geom, o.geom) as segment_pct
   FROM network n
   ORDER BY n.geom <-> o.geom
   LIMIT 1
 ) as nn
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
)

  SELECT
   o.origin_id,
   d.destination_id,
   row_number() over(ORDER BY ROUND(SUM(x.cost)::numeric, 2)) as destination_rank,
   d.destination_name,
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
    (SELECT array_agg(node) FROM origins),
    (SELECT array_agg(node) FROM destinations),
    FALSE
    ) x
  INNER JOIN network n ON x.edge = n.network_id
  INNER JOIN destinations d ON x.end_vid = d.node
  INNER JOIN origins o ON x.start_vid = o.node
  GROUP BY o.origin_id, d.destination_id, d.destination_name;