DROP TABLE IF EXISTS origin_destination_cost_matrix;
CREATE TABLE origin_destination_cost_matrix
(
  origin_node_id bigint,
  destination_node_id bigint,
  total_cost double precision,
  total_length double precision,
  total_apaved double precision,
  total_aloose double precision,
  total_arough double precision,
  total_aovergrown double precision,
  total_aseasonal double precision,
  total_aunknown double precision,
  total_acityspoke double precision,
  total_awater double precision,
  total_awaterinterp double precision,
  total_aboat double precision,
  PRIMARY KEY (origin_node_id, destination_node_id)
);