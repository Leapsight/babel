

# Module babel_index_collection #
* [Description](#description)
* [Data Types](#types)
* [Function Index](#index)
* [Function Details](#functions)

A babel_index_collection is a Riak Map representing a mapping from
binary keys to [`babel_index`](babel_index.md) objects, where keys are the value of the
[`babel_index:name/1`](babel_index.md#name-1) property.

<a name="description"></a>

## Description ##

An Index Collection has a name that typically represents the name of a
resource (or entity) name in your domain model e.g. accounts, users.

A babel collection object is stored in Riak KV under a bucket_type that
should be defined through configuration using the
`index_collection_bucket_type` configuration option; and a bucket name which
results from concatenating a prefix provided as argument in this module
functions and the suffix "/index_collection".

## Configuring the bucket type

The bucket type needs to be configured and activated
in Riak KV before using this module. The `datatype` property of the bucket
type should be configured to `map`.

The following example shows how to configure and activate the
bucket type with the recommeded default replication
properties, for the example we asume the application property
`index_collection_bucket_type` maps to "index_collection"
bucket type name.

```
     shell
  riak-admin bucket-type create index_collection '{"props":
  {"datatype":"map",
  "n_val":3, "pw":"quorum", "pr":"quorum", "notfound_ok":false,
  "basic_quorum":true}}'
  riak-admin bucket-type activate index_collection
```

## Default replication properties

All functions in this module resulting in reading or writing to Riak KV
allow an optional map with Riak KV's replication properties, but we
recommend to use of the functions which provide the default replication
properties.

<a name="types"></a>

## Data Types ##


<a name="fold_fun()"></a>


### fold_fun() ###


<pre><code>
fold_fun() = fun((Key::<a href="#type-key">key()</a>, Value::any(), AccIn::any()) -&gt; AccOut::any())
</code></pre>


<a name="riak_object()"></a>


### riak_object() ###


<pre><code>
riak_object() = <a href="riakc_map.md#type-crdt_map">riakc_map:crdt_map()</a>
</code></pre>


<a name="t()"></a>


### t() ###


<pre><code>
t() = #babel_index_collection{id = binary(), bucket = binary(), object = <a href="#type-riak_object">riak_object()</a>}
</code></pre>


<a name="functions"></a>

## Function Details ##

<a name="add_index-2"></a>

### add_index/2 ###

<pre><code>
add_index(Index::<a href="babel_index.md#type-t">babel_index:t()</a>, Collection::<a href="#type-t">t()</a>) -&gt; <a href="#type-t">t()</a> | no_return()
</code></pre>
<br />

Returns a copy of collection `Collection` where the index `Index` has
been added.
If the an index with the same name existed in the collection, it will be
replaced by `Index`.

!> **Important**. This is a private API. If you want to add an index to the
collection and create the index in Riak KV use [`babel:create_index/3`](babel.md#create_index-3)
instead.

<a name="bucket-1"></a>

### bucket/1 ###

<pre><code>
bucket(Collection::<a href="#type-t">t()</a>) -&gt; binary()
</code></pre>
<br />

<a name="data-1"></a>

### data/1 ###

<pre><code>
data(Collection::<a href="#type-t">t()</a>) -&gt; <a href="orddict.md#type-orddict">orddict:orddict()</a>
</code></pre>
<br />

<a name="delete-3"></a>

### delete/3 ###

<pre><code>
delete(BucketPrefix::binary(), Key::binary(), Opts::<a href="babel.md#type-opts">babel:opts()</a>) -&gt; ok | {error, not_found | term()}
</code></pre>
<br />

<a name="delete_index-2"></a>

### delete_index/2 ###

<pre><code>
delete_index(Id::binary() | <a href="babel_index.md#type-t">babel_index:t()</a>, Collection::<a href="#type-t">t()</a>) -&gt; <a href="#type-t">t()</a> | no_return()
</code></pre>
<br />

<a name="fetch-3"></a>

### fetch/3 ###

<pre><code>
fetch(BucketPrefix::binary(), Key::binary(), Opts::<a href="babel.md#type-opts">babel:opts()</a>) -&gt; <a href="#type-t">t()</a> | no_return()
</code></pre>
<br />

<a name="fold-3"></a>

### fold/3 ###

<pre><code>
fold(Fun::<a href="#type-fold_fun">fold_fun()</a>, Acc::any(), Collection::<a href="#type-t">t()</a>) -&gt; any()
</code></pre>
<br />

<a name="from_riak_object-1"></a>

### from_riak_object/1 ###

<pre><code>
from_riak_object(Object::<a href="#type-riak_object">riak_object()</a>) -&gt; Collection::<a href="#type-t">t()</a>
</code></pre>
<br />

<a name="id-1"></a>

### id/1 ###

<pre><code>
id(Collection::<a href="#type-t">t()</a>) -&gt; binary()
</code></pre>
<br />

<a name="index-2"></a>

### index/2 ###

<pre><code>
index(IndexName::binary(), Collection::<a href="#type-t">t()</a>) -&gt; <a href="babel_index.md#type-t">babel_index:t()</a> | no_return()
</code></pre>
<br />

Returns the babel index associated with name `IndexName` in collection
`Collection`. This function assumes that the name is present in the
collection. An exception is generated if it is not.

<a name="index_names-1"></a>

### index_names/1 ###

<pre><code>
index_names(Collection::<a href="#type-t">t()</a>) -&gt; [binary()]
</code></pre>
<br />

<a name="indices-1"></a>

### indices/1 ###

<pre><code>
indices(Collection::<a href="#type-t">t()</a>) -&gt; [<a href="babel_index.md#type-t">babel_index:t()</a>]
</code></pre>
<br />

Returns all the indices in the collection.

<a name="is_index-2"></a>

### is_index/2 ###

<pre><code>
is_index(IndexName::binary(), Collection::<a href="#type-t">t()</a>) -&gt; <a href="babel_index.md#type-t">babel_index:t()</a> | no_return()
</code></pre>
<br />

<a name="lookup-3"></a>

### lookup/3 ###

<pre><code>
lookup(BucketPrefix::binary(), Key::binary(), Opts::<a href="babel.md#type-opts">babel:opts()</a>) -&gt; {ok, <a href="#type-t">t()</a>} | {error, not_found | term()}
</code></pre>
<br />

<a name="new-2"></a>

### new/2 ###

<pre><code>
new(BucketPrefix::binary(), Name::binary()) -&gt; <a href="#type-t">t()</a>
</code></pre>
<br />

Creates a new index collection object.
The value for `bucket` is computed by concatenating `BucketPrefix` with the
suffix `/index_collection`.

<a name="size-1"></a>

### size/1 ###

<pre><code>
size(Collection::<a href="#type-t">t()</a>) -&gt; non_neg_integer()
</code></pre>
<br />

Returns the number of elements in the collection `Collection`.

<a name="store-2"></a>

### store/2 ###

<pre><code>
store(Collection::<a href="#type-t">t()</a>, Opts::<a href="babel.md#type-opts">babel:opts()</a>) -&gt; {ok, Index::<a href="#type-t">t()</a>} | {error, Reason::any()}
</code></pre>
<br />

Stores an index collection in Riak KV.
The collection will be stored under the bucket type configured
for the application option `index_collection_bucket_type`, bucket name
will be the value returned by [`bucket/1`](#bucket-1), and the key will be the
value returned by [`id/1`](#id-1).

<a name="to_delete_task-1"></a>

### to_delete_task/1 ###

<pre><code>
to_delete_task(Collection::<a href="#type-t">t()</a>) -&gt; <a href="/Volumes/Work/Leapsight/babel/_build/default/lib/reliable/doc/reliable.md#type-action">reliable:action()</a>
</code></pre>
<br />

<a name="to_riak_object-1"></a>

### to_riak_object/1 ###

<pre><code>
to_riak_object(Collection::<a href="#type-t">t()</a>) -&gt; Object::<a href="#type-riak_object">riak_object()</a>
</code></pre>
<br />

<a name="to_update_task-1"></a>

### to_update_task/1 ###

<pre><code>
to_update_task(Collection::<a href="#type-t">t()</a>) -&gt; <a href="/Volumes/Work/Leapsight/babel/_build/default/lib/reliable/doc/reliable.md#type-action">reliable:action()</a>
</code></pre>
<br />

