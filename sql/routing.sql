SELECT
  %s AS origin_node_id,
  %s AS destination_node_id,
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
pgr_trsp(
        'SELECT network_id as id, source, target, cost FROM network',
        %s,
        %s,
        false,
        false,
        'SELECT to_cost, target_id, via_path FROM restrictions'
) x
INNER JOIN network n ON x.id2 = n.network_id
GROUP BY origin_node_id, destination_node_id;