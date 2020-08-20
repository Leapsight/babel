

# Module babel_index_collection #
* [Description](#description)
* [Data Types](#types)
* [Function Index](#index)
* [Function Details](#functions)

A babel_index_collection is a Riak Map, that maps
binary keys to [`babel_index`](babel_index.md) objects (also a Riak Map).

<a name="description"></a>

## Description ##

Keys typically represent a resource (or entity) name in your domain model
e.g. accounts, users.

A babel collection object is stored in Riak KV under a bucket_type that
should be defined through configuration using the
`index_collection_bucket_type` configuration option; and a bucket name which
results from concatenating a prefix provided as argument in this module
functions a key separator and the suffix "_index_collection".

## Configuring the bucket type

The bucket type needs to be configured and activated
in Riak KV before using this module. The `datatype` property of the bucket
type should be configured to `map`.

The following example shows how to configure and activate the
bucket type with the recommeded default replication
properties, for the example we asume the application property
`index_collection_bucket_type` maps to "my_index_collection" bucket type
name.

```
     shell
  riak-admin bucket-type create my_index_collection '{"props":
  {"datatype":"map",
  "n_val":3, "pw":"quorum", "pr":"quorum", "notfound_ok":false,
  "basic_quorum":true}}'
  riak-admin bucket-type activate my_index_collection
```

## Default replication properties

All functions in this module resulting in reading or writing to Riak KV
allow an optional map with Riak KV's replication properties, but we
recommend to use of the functions which provide the default replication
properties.

<a name="types"></a>

## Data Types ##




### <a name="type-data">data()</a> ###


<pre><code>
data() = <a href="riakc_map.md#type-crdt_map">riakc_map:crdt_map()</a>
</code></pre>




### <a name="type-t">t()</a> ###


<pre><code>
t() = #babel_index_collection{id = binary(), bucket = binary(), data = <a href="#type-data">data()</a>}
</code></pre>

<a name="index"></a>

## Function Index ##


<table width="100%" border="1" cellspacing="0" cellpadding="2" summary="function index"><tr><td valign="top"><a href="#add_index-2">add_index/2</a></td><td></td></tr><tr><td valign="top"><a href="#bucket-1">bucket/1</a></td><td></td></tr><tr><td valign="top"><a href="#data-1">data/1</a></td><td></td></tr><tr><td valign="top"><a href="#delete-3">delete/3</a></td><td></td></tr><tr><td valign="top"><a href="#delete-4">delete/4</a></td><td></td></tr><tr><td valign="top"><a href="#delete_index-2">delete_index/2</a></td><td></td></tr><tr><td valign="top"><a href="#fetch-3">fetch/3</a></td><td></td></tr><tr><td valign="top"><a href="#fetch-4">fetch/4</a></td><td></td></tr><tr><td valign="top"><a href="#id-1">id/1</a></td><td></td></tr><tr><td valign="top"><a href="#index-2">index/2</a></td><td>Returns the babel index associated with key <code>Key</code> in collection
<code>Collection</code>.</td></tr><tr><td valign="top"><a href="#lookup-3">lookup/3</a></td><td></td></tr><tr><td valign="top"><a href="#lookup-4">lookup/4</a></td><td></td></tr><tr><td valign="top"><a href="#new-2">new/2</a></td><td>Takes a list of pairs (property list) or map of binary keys to values
of type <code>babel_index:t()</code> and returns an index collection.</td></tr><tr><td valign="top"><a href="#new-3">new/3</a></td><td>Takes a list of pairs (property list) or map of binary keys to values
of type <code>babel_index:t()</code> and returns an index collection.</td></tr><tr><td valign="top"><a href="#size-1">size/1</a></td><td>Returns the number of elements in the collection <code>Collection</code>.</td></tr><tr><td valign="top"><a href="#store-2">store/2</a></td><td>Stores an index collection in Riak KV under a bucket name which results
from contenating the prefix <code>BucketPrefix</code> to suffix "/index_collection" and
key <code>Key</code>.</td></tr><tr><td valign="top"><a href="#store-3">store/3</a></td><td>Stores an index collection in Riak KV under a bucket name which results
from contenating the prefix <code>BucketPrefix</code> to suffix "/index_collection" and
key <code>Key</code>.</td></tr><tr><td valign="top"><a href="#to_work_item-1">to_work_item/1</a></td><td>Returns.</td></tr></table>


<a name="functions"></a>

## Function Details ##

<a name="add_index-2"></a>

### add_index/2 ###

<pre><code>
add_index(Index::<a href="babel_index.md#type-t">babel_index:t()</a>, Collection::<a href="#type-t">t()</a>) -&gt; <a href="#type-t">t()</a> | no_return()
</code></pre>
<br />

<a name="bucket-1"></a>

### bucket/1 ###

<pre><code>
bucket(Collection::<a href="#type-t">t()</a>) -&gt; binary()
</code></pre>
<br />

<a name="data-1"></a>

### data/1 ###

<pre><code>
data(Collection::<a href="#type-t">t()</a>) -&gt; <a href="#type-data">data()</a>
</code></pre>
<br />

<a name="delete-3"></a>

### delete/3 ###

<pre><code>
delete(Conn::pid(), BucketPrefix::binary(), Key::binary()) -&gt; ok | {error, not_found | term()}
</code></pre>
<br />

<a name="delete-4"></a>

### delete/4 ###

<pre><code>
delete(Conn::pid(), BucketPrefix::binary(), Key::binary(), Opts::<a href="#type-req_opts">req_opts()</a>) -&gt; ok | {error, not_found | term()}
</code></pre>
<br />

<a name="delete_index-2"></a>

### delete_index/2 ###

<pre><code>
delete_index(Id::binary(), Collection::<a href="#type-t">t()</a>) -&gt; <a href="#type-t">t()</a> | no_return()
</code></pre>
<br />

<a name="fetch-3"></a>

### fetch/3 ###

<pre><code>
fetch(Conn::pid(), BucketPrefix::binary(), Key::binary()) -&gt; <a href="#type-t">t()</a> | no_return()
</code></pre>
<br />

<a name="fetch-4"></a>

### fetch/4 ###

<pre><code>
fetch(Conn::pid(), BucketPrefix::binary(), Key::binary(), Opts::<a href="#type-req_opts">req_opts()</a>) -&gt; <a href="#type-t">t()</a> | no_return()
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
index(Key::binary(), Collection::<a href="#type-t">t()</a>) -&gt; <a href="babel_index.md#type-t">babel_index:t()</a>
</code></pre>
<br />

Returns the babel index associated with key `Key` in collection
`Collection`. This function assumes that the key is present in the
collection. An exception is generated if the key is not in the collection.

<a name="lookup-3"></a>

### lookup/3 ###

<pre><code>
lookup(Conn::pid(), BucketPrefix::binary(), Key::binary()) -&gt; {ok, <a href="#type-t">t()</a>} | {error, not_found | term()}
</code></pre>
<br />

<a name="lookup-4"></a>

### lookup/4 ###

<pre><code>
lookup(Conn::pid(), BucketPrefix::binary(), Key::binary(), Opts::<a href="#type-req_opts">req_opts()</a>) -&gt; {ok, <a href="#type-t">t()</a>} | {error, not_found | term()}
</code></pre>
<br />

<a name="new-2"></a>

### new/2 ###

<pre><code>
new(BucketPrefix::binary(), Name::binary()) -&gt; <a href="#type-t">t()</a>
</code></pre>
<br />

Takes a list of pairs (property list) or map of binary keys to values
of type `babel_index:t()` and returns an index collection.

<a name="new-3"></a>

### new/3 ###

<pre><code>
new(BucketPrefix::binary(), Name::binary(), Indices::[{binary(), <a href="babel_index.md#type-t">babel_index:t()</a>}]) -&gt; <a href="#type-t">t()</a>
</code></pre>
<br />

Takes a list of pairs (property list) or map of binary keys to values
of type `babel_index:t()` and returns an index collection.

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
store(Conn::pid(), Collection::<a href="#type-t">t()</a>) -&gt; {ok, Index::<a href="#type-t">t()</a>} | {error, Reason::any()}
</code></pre>
<br />

Stores an index collection in Riak KV under a bucket name which results
from contenating the prefix `BucketPrefix` to suffix "/index_collection" and
key `Key`.

<a name="store-3"></a>

### store/3 ###

<pre><code>
store(Conn::pid(), Collection::<a href="#type-t">t()</a>, ReqOpts::<a href="#type-req_opts">req_opts()</a>) -&gt; {ok, Index::<a href="#type-t">t()</a>} | {error, Reason::any()}
</code></pre>
<br />

Stores an index collection in Riak KV under a bucket name which results
from contenating the prefix `BucketPrefix` to suffix "/index_collection" and
key `Key`.

<a name="to_work_item-1"></a>

### to_work_item/1 ###

<pre><code>
to_work_item(Collection::<a href="#type-t">t()</a>) -&gt; <a href="babel.md#type-work_item">babel:work_item()</a>
</code></pre>
<br />

Returns

