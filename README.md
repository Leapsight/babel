# riak_utils

## Riak Configuration

```shell
riak-admin bucket-type create index_collection '{"props":{"datatype":"map", "n_val":3, "pw":"quorum", "pr":"quorum"}}'
riak-admin bucket-type activate index_collection
```

```shell
riak-admin bucket-type create index_data '{"props":{"datatype":"map", "n_val":3, "pw":"quorum", "pr":"quorum", "notfound_ok":false, "basic_quorum":true}}'
riak-admin bucket-type activate index_data
```


