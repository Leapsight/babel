# Babel - Riak Datatypes and Secondary Indexing

Babel is an Erlang OTP application that allows you to work with Riak KV conflict-free replicated datatypes (CRDTs) and also maintain application-managed secondary indices.


## Required Riak KV configuration

The following two bucket types need to be created in Riak KV previous to using this application.

```shell
riak-admin bucket-type create index_collection '{"props":{"datatype":"map", "n_val":3, "pw":"quorum", "pr":"quorum"}}'
riak-admin bucket-type activate index_collection
```

```shell
riak-admin bucket-type create index_data '{"props":{"datatype":"map", "n_val":3, "pw":"quorum", "pr":"quorum", "notfound_ok":false, "basic_quorum":true}}'
riak-admin bucket-type activate index_data
```
