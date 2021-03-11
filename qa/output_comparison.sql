-- this is a bit fussy because origin ids are not the same in each dataset,
-- join based on biomass and geom rather than the ids


WITH cm_arc AS
(
    SELECT
      a."OriginID" as origin_id,
      b.geom as geom,
      ROUND(b."znsums_SUM"::numeric, 4) as biomass,
      a."DestinationID" as destination_id,
      a."Name" as destination_name,
      a."DestinationRank" as destination_rank,
      ROUND(a."Total_Cost"::numeric, 2) as total_cost,
      ROUND(a."Total_Length"::numeric, 2) as total_length
    FROM cost_matrix_arc a
    INNER JOIN origins_arc b
    ON a."OriginID" = b."znsums_Value"
),

cm_pg AS
(
    SELECT
      a.origin_id,
      a.geom as geom,
      ROUND(a.biomass::numeric, 4) as biomass,
      b.destination_id,
      b.destination_name,
      b.destination_rank,
      b.total_cost,
      b.total_length
    FROM origins a
    LEFT JOIN cost_matrix_pg b
    ON a.origin_id = b.origin_id
),

-- generate origin_id lookup
origin_lookup AS
(
SELECT DISTINCT ON (a.origin_id)
  a.origin_id as origin_id_arc,
  b.origin_id as origin_id_pg
FROM cm_arc a
INNER JOIN cm_pg b
ON ST_Dwithin(a.geom, b.geom, 1000)
AND a.biomass = b.biomass
ORDER BY a.origin_id, ST_Distance(a.geom, b.geom)
),

-- now we can join results based on geom and biomass of origin, plus destination id
data AS (

SELECT
  arc.origin_id as origin_id_arc,
  pg.origin_id as origin_id_pg,
  arc.biomass,
  arc.destination_id,
  pg.destination_name,
  arc.destination_rank as destination_rank_arc,
  pg.destination_rank as destination_rank_pg,
  arc.total_cost as total_cost_arc,
  pg.total_cost as total_cost_pg,
  arc.total_length as total_length_arc,
  pg.total_length as total_length_pg
FROM cm_arc as arc
INNER JOIN origin_lookup as lut
ON arc.origin_id = lut.origin_id_arc
LEFT OUTER JOIN cm_pg as pg
ON lut.origin_id_pg = pg.origin_id
AND arc.destination_id = pg.destination_id
ORDER BY arc.origin_id, arc.destination_id
)

-- what are the differences?

SELECT
 origin_id_pg,
 destination_id,
 destination_name,
 destination_rank_arc - destination_rank_pg  as rank_diff,
 total_cost_arc - total_cost_pg as cost_diff,
 total_length_arc - total_length_pg as length_diff
FROM data;