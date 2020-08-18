# Intended use in Magenta

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


## Use

Examples

* tenant_id global
* tenant_id lojack-ar
* account_id:account1
* user_id:user1

## Process

* Create a collection of indices
* New index
  * New Index partitions
    * Reliable -> put index and partitions
* Add Index to collection
  * Riak Put
* Index
* Activate Index