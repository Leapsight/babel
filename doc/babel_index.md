

# Module babel_index #
* [Description](#description)
* [Data Types](#types)
* [Function Index](#index)
* [Function Details](#functions)

An object that specifies the type and configuration of an application
maintained index in Riak KV and the location
`({bucket_type(), bucket()}, key()})` of its partitions
[`babel_index_partition`](babel_index_partition.md) in Riak KV.

__This module defines the `babel_index` behaviour.__<br /> Required callback functions: `init/2`, `init_partitions/1`, `from_riak_object/1`, `to_riak_object/1`, `number_of_partitions/1`, `partition_identifier/2`, `partition_identifiers/2`, `update_partition/3`, `match/3`, `iterator/3`, `iterator_move/3`, `iterator_done/1`, `iterator_key/1`, `iterator_values/1`.

<a name="description"></a>

## Description ##

Every Index has one or more partition objects which are modelled as Riak KV
maps.

An Index is persisted as a read-only CRDT Map as part of an Index Collection
[`babel_index_collection`](babel_index_collection.md). An Index Collection aggregates all indices
for a domain entity or resource e.g. accounts.

<a name="types"></a>

## Data Types ##




### <a name="type-action">action()</a> ###


<pre><code>
action() = insert | delete
</code></pre>




### <a name="type-config">config()</a> ###


<pre><code>
config() = map()
</code></pre>




### <a name="type-config_object">config_object()</a> ###


<pre><code>
config_object() = <a href="riakc_map.md#type-crdt_map">riakc_map:crdt_map()</a>
</code></pre>




### <a name="type-fold_fun">fold_fun()</a> ###


<pre><code>
fold_fun() = fun((<a href="#type-index_key">index_key()</a>, <a href="#type-index_values">index_values()</a>, any()) -&gt; any())
</code></pre>




### <a name="type-fold_opts">fold_opts()</a> ###


<pre><code>
fold_opts() = #{first =&gt; binary(), sort_ordering =&gt; asc | desc}
</code></pre>




### <a name="type-foreach_fun">foreach_fun()</a> ###


<pre><code>
foreach_fun() = fun((<a href="#type-index_key">index_key()</a>, <a href="#type-index_values">index_values()</a>) -&gt; any())
</code></pre>




### <a name="type-index_key">index_key()</a> ###


<pre><code>
index_key() = binary()
</code></pre>




### <a name="type-index_values">index_values()</a> ###


<pre><code>
index_values() = map()
</code></pre>




### <a name="type-key_value">key_value()</a> ###


<pre><code>
key_value() = <a href="babel_key_value.md#type-t">babel_key_value:t()</a>
</code></pre>




### <a name="type-local_key">local_key()</a> ###


<pre><code>
local_key() = binary()
</code></pre>




### <a name="type-partition_id">partition_id()</a> ###


<pre><code>
partition_id() = binary()
</code></pre>




### <a name="type-partition_key">partition_key()</a> ###


<pre><code>
partition_key() = binary()
</code></pre>




### <a name="type-query_opts">query_opts()</a> ###


<pre><code>
query_opts() = #{max_results =&gt; non_neg_integer() | all, continuation =&gt; any(), return_body =&gt; any(), timeout =&gt; timeout(), pagination_sort =&gt; boolean(), stream =&gt; boolean()}
</code></pre>




### <a name="type-riak_object">riak_object()</a> ###


<pre><code>
riak_object() = <a href="riakc_map.md#type-crdt_map">riakc_map:crdt_map()</a>
</code></pre>




### <a name="type-t">t()</a> ###


<pre><code>
t() = #{bucket =&gt; binary(), bucket_type =&gt; binary(), config =&gt; term(), name =&gt; binary(), type =&gt; atom()}
</code></pre>

<a name="index"></a>

## Function Index ##


<table width="100%" border="1" cellspacing="0" cellpadding="2" summary="function index"><tr><td valign="top"><a href="#bucket-1">bucket/1</a></td><td>Returns the Riak KV bucket were this index partitions are stored.</td></tr><tr><td valign="top"><a href="#bucket_type-1">bucket_type/1</a></td><td>Returns the Riak KV bucket type associated with this index.</td></tr><tr><td valign="top"><a href="#config-1">config/1</a></td><td>Returns the configuration associated with this index.</td></tr><tr><td valign="top"><a href="#create_partitions-1">create_partitions/1</a></td><td></td></tr><tr><td valign="top"><a href="#foreach-2">foreach/2</a></td><td></td></tr><tr><td valign="top"><a href="#from_riak_object-1">from_riak_object/1</a></td><td></td></tr><tr><td valign="top"><a href="#match-3">match/3</a></td><td>Returns a list of matching index entries.</td></tr><tr><td valign="top"><a href="#name-1">name/1</a></td><td>Returns name of this index.</td></tr><tr><td valign="top"><a href="#new-1">new/1</a></td><td>Returns a new index based on the specification map.</td></tr><tr><td valign="top"><a href="#partition_identifier-2">partition_identifier/2</a></td><td></td></tr><tr><td valign="top"><a href="#partition_identifiers-1">partition_identifiers/1</a></td><td>Returns the list of Riak KV keys under which the partitions are stored,
in ascending order.</td></tr><tr><td valign="top"><a href="#partition_identifiers-2">partition_identifiers/2</a></td><td>Returns the list of Riak KV keys under which the partitions are stored
in a defined order i.e.</td></tr><tr><td valign="top"><a href="#to_delete_item-2">to_delete_item/2</a></td><td>Returns the representation of this object as a Reliable Delete work
item.</td></tr><tr><td valign="top"><a href="#to_riak_object-1">to_riak_object/1</a></td><td></td></tr><tr><td valign="top"><a href="#to_update_item-2">to_update_item/2</a></td><td>Returns the representation of this object as a Reliable Update work
item.</td></tr><tr><td valign="top"><a href="#type-1">type/1</a></td><td>Returns the type of this index.</td></tr><tr><td valign="top"><a href="#typed_bucket-1">typed_bucket/1</a></td><td>Returns the Riak KV <code>typed_bucket()</code> associated with this index.</td></tr><tr><td valign="top"><a href="#update-3">update/3</a></td><td></td></tr></table>


<a name="functions"></a>

## Function Details ##

<a name="bucket-1"></a>

### bucket/1 ###

<pre><code>
bucket(X1::<a href="#type-t">t()</a>) -&gt; <a href="#type-maybe_no_return">maybe_no_return</a>(binary())
</code></pre>
<br />

Returns the Riak KV bucket were this index partitions are stored.

<a name="bucket_type-1"></a>

### bucket_type/1 ###

<pre><code>
bucket_type(X1::<a href="#type-t">t()</a>) -&gt; <a href="#type-maybe_no_return">maybe_no_return</a>(binary())
</code></pre>
<br />

Returns the Riak KV bucket type associated with this index.

<a name="config-1"></a>

### config/1 ###

<pre><code>
config(X1::<a href="#type-t">t()</a>) -&gt; <a href="#type-maybe_no_return">maybe_no_return</a>(<a href="riakc_map.md#type-crdt_map">riakc_map:crdt_map()</a>)
</code></pre>
<br />

Returns the configuration associated with this index.
The configuration depends on the index type [`babel:type/1`](babel.md#type-1).

<a name="create_partitions-1"></a>

### create_partitions/1 ###

<pre><code>
create_partitions(X1::<a href="#type-t">t()</a>) -&gt; [<a href="babel_index_partition.md#type-t">babel_index_partition:t()</a>] | no_return()
</code></pre>
<br />

<a name="foreach-2"></a>

### foreach/2 ###

<pre><code>
foreach(Fun::<a href="#type-foreach_fun">foreach_fun()</a>, Index::<a href="#type-t">t()</a>) -&gt; any()
</code></pre>
<br />

<a name="from_riak_object-1"></a>

### from_riak_object/1 ###

<pre><code>
from_riak_object(ConfigCRDT::<a href="#type-riak_object">riak_object()</a>) -&gt; Index::<a href="#type-t">t()</a>
</code></pre>
<br />

<a name="match-3"></a>

### match/3 ###

<pre><code>
match(Index::<a href="#type-t">t()</a>, Pattern::<a href="babel_index.md#type-key_value">babel_index:key_value()</a>, RiakOpts::<a href="#type-riak_opts">riak_opts()</a>) -&gt; [{<a href="#type-index_key">index_key()</a>, <a href="#type-index_values">index_values()</a>}] | no_return()
</code></pre>
<br />

Returns a list of matching index entries

<a name="name-1"></a>

### name/1 ###

<pre><code>
name(X1::<a href="#type-t">t()</a>) -&gt; binary()
</code></pre>
<br />

Returns name of this index

<a name="new-1"></a>

### new/1 ###

<pre><code>
new(IndexData::map()) -&gt; Index::<a href="#type-t">t()</a> | no_return()
</code></pre>
<br />

Returns a new index based on the specification map. It fails in case
the specification in invalid.

A specification is map with the following fields (required fields are in
bold):

**name** :: binary() – a unique name for this index within a collection.
**bucket_type** :: binary() | atom() – the bucket type used to store the
babel_index_partition:t() objects. This bucket type should have a datatype
of `map`.
**bucket** :: binary() | atom() – the bucket name used to store the
babel_index_partition:t() objects of this index. Typically the name of an
entity in plural form e.g.`accounts'.
**type** :: atom() – the index type (Erlang module) used by this index.
config :: map() – the configuration data for the index type used by this
index.

<a name="partition_identifier-2"></a>

### partition_identifier/2 ###

<pre><code>
partition_identifier(KeyValue::<a href="#type-key_value">key_value()</a>, Index::<a href="#type-t">t()</a>) -&gt; binary()
</code></pre>
<br />

<a name="partition_identifiers-1"></a>

### partition_identifiers/1 ###

<pre><code>
partition_identifiers(Index::<a href="#type-t">t()</a>) -&gt; <a href="#type-maybe_no_return">maybe_no_return</a>([binary()])
</code></pre>
<br />

Returns the list of Riak KV keys under which the partitions are stored,
in ascending order.
This is equivalent to the call `partition_identifiers(Index, asc)`.

<a name="partition_identifiers-2"></a>

### partition_identifiers/2 ###

<pre><code>
partition_identifiers(Index::<a href="#type-t">t()</a>, Order::asc | desc) -&gt; <a href="#type-maybe_no_return">maybe_no_return</a>([binary()])
</code></pre>
<br />

Returns the list of Riak KV keys under which the partitions are stored
in a defined order i.e. `asc` or `desc`.

<a name="to_delete_item-2"></a>

### to_delete_item/2 ###

<pre><code>
to_delete_item(Index::<a href="babel_index.md#type-t">babel_index:t()</a>, PartitionId::binary()) -&gt; <a href="babel.md#type-work_item">babel:work_item()</a>
</code></pre>
<br />

Returns the representation of this object as a Reliable Delete work
item.

<a name="to_riak_object-1"></a>

### to_riak_object/1 ###

<pre><code>
to_riak_object(Index::<a href="#type-t">t()</a>) -&gt; IndexCRDT::<a href="#type-riak_object">riak_object()</a>
</code></pre>
<br />

<a name="to_update_item-2"></a>

### to_update_item/2 ###

<pre><code>
to_update_item(Index::<a href="babel_index.md#type-t">babel_index:t()</a>, Partition::<a href="#type-t">t()</a>) -&gt; <a href="babel.md#type-work_item">babel:work_item()</a>
</code></pre>
<br />

Returns the representation of this object as a Reliable Update work
item.

<a name="type-1"></a>

### type/1 ###

<pre><code>
type(X1::<a href="#type-t">t()</a>) -&gt; <a href="#type-maybe_no_return">maybe_no_return</a>(module())
</code></pre>
<br />

Returns the type of this index. A type is a module name implementing
the babel_index behaviour i.e. a type of index.

<a name="typed_bucket-1"></a>

### typed_bucket/1 ###

<pre><code>
typed_bucket(X1::<a href="#type-t">t()</a>) -&gt; <a href="#type-maybe_no_return">maybe_no_return</a>({binary(), binary()})
</code></pre>
<br />

Returns the Riak KV `typed_bucket()` associated with this index.

<a name="update-3"></a>

### update/3 ###

<pre><code>
update(Actions::[{<a href="#type-action">action()</a>, <a href="#type-key_value">key_value()</a>}], Index::<a href="#type-t">t()</a>, RiakOpts::<a href="#type-riak_opts">riak_opts()</a>) -&gt; <a href="#type-maybe_no_return">maybe_no_return</a>([<a href="babel_index_partition.md#type-t">babel_index_partition:t()</a>])
</code></pre>
<br />

