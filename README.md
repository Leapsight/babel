# Babel

## Riak Configuration

```shell
cd ../magenta-env/resources/riak-kv/compose
docker-compose up -d
```

### Bucket Types

Open a shell on the riak docker and configure the following buckets


```shell
riak-admin bucket-type create index_collection '{"props":{"datatype":"map"}}'
riak-admin bucket-type activate index_collection
```

```shell
riak-admin bucket-type create index_data '{"props":{"datatype":"map"}}'
riak-admin bucket-type activate index_data
```