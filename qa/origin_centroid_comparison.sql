-- the biomass and count values dereived by both tools are the same,
-- but the centroids are not - what are the distances between the centroids?

WITH stats AS
(SELECT DISTINCT ON (a.origin_id)
  a.origin_id,
  ROUND(b."znsums_SUM"::numeric, 4) as biomass_arc,
  ROUND(a.biomass::numeric, 4) as biomass_thb,
  b."znsums_COUNT" as count_arc,
  a.count as count_thb,
  ROUND(ST_Distance(a.geom, b.geom)::numeric, 3) as dist
FROM origins a
INNER JOIN origins_arc b
ON ST_Dwithin(a.geom, b.geom, 1000)
AND ROUND(b."znsums_SUM"::numeric, 4) = ROUND(a.biomass::numeric, 4)
order by a.origin_id, ST_Distance(a.geom, b.geom)
),

buckets AS
(SELECT
  CASE
    WHEN dist < 1 then '00-01m'
    WHEN dist >=1 and dist < 10 then '01-10m'
    WHEN dist >=10 and dist < 25 then '10-25m'
    WHEN dist >=25 and dist < 50 then '25-50m'
    WHEN dist >=50 and dist < 75 then '50-75m'
    WHEN dist >=75 and dist < 100 then '75-100m'
    WHEN dist >= 100 THEN 'gt100m'
  END as dist_bucket
FROM stats)

SELECT
 dist_bucket,
 count(*)
FROM buckets
GROUP BY dist_bucket
ORDER BY dist_bucket;