#!/bin/bash

# set -e

docker exec -it fleet-riakkv riak-admin bucket-type create index_collection '{"props":{"datatype":"map", "n_val":3, "pw":"quorum", "pr":"quorum"}}'
docker exec -it fleet-riakkv riak-admin bucket-type activate index_collection
docker exec -it fleet-riakkv riak-admin bucket-type create index_data '{"props":{"datatype":"map", "n_val":3, "pw":"quorum", "pr":"quorum", "notfound_ok":false, "basic_quorum":true}}'
docker exec -it fleet-riakkv riak-admin bucket-type activate index_data
docker exec -it fleet-riakkv riak-admin bucket-type create test_map '{"props":{"datatype":"map"}}'
docker exec -it fleet-riakkv riak-admin bucket-type activate test_map