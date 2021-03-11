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
)

SELECT
   o.origin_id,
   d.destination_id,
   rank() over(PARTITION BY o.origin_id ORDER BY odm.total_cost) as destination_rank,
   d.destination_name,
   odm.total_cost,
   odm.total_length,
   odm.total_apaved,
   odm.total_aloose,
   odm.total_arough,
   odm.total_aovergrown,
   odm.total_aseasonal,
   odm.total_aunknown,
   odm.total_acityspoke,
   odm.total_awater,
   odm.total_awaterinterp,
   odm.total_aboat
  FROM origin_destination_cost_matrix odm
  INNER JOIN origins o ON odm.origin_node_id = o.node
  INNER JOIN destinations d ON odm.destination_node_id = d.node
  ORDER BY o.origin_id, odm.total_cost