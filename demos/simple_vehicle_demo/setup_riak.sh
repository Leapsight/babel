#!/bin/bash

# set -e

docker exec -it riakkv riak-admin bucket-type create demo_index_collection '{"props":{"datatype":"map", "n_val":3, "pw":"quorum", "pr":"quorum"}}'
docker exec -it riakkv riak-admin bucket-type activate demo_index_collection
docker exec -it riakkv riak-admin bucket-type create demo_index_collection '{"props":{"datatype":"map", "n_val":3, "pw":"quorum", "pr":"quorum", "notfound_ok":false, "basic_quorum":true}}'
docker exec -it riakkv riak-admin bucket-type activate demo_index_collection
docker exec -it riakkv riak-admin bucket-type create vehicles '{"props":{"datatype":"map"}}'
docker exec -it riakkv riak-admin bucket-type activate vehicles