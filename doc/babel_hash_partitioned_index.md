

# Module babel_hash_partitioned_index #
* [Description](#description)
* [Data Types](#types)
* [Function Index](#index)
* [Function Details](#functions)

A hash-partitioned index is an index whose contents (index entries)
have been partitioned amongst a fixed number of parts (called partitions)
using a hashing algorithm to determine in which partition and entry should be
located.

__Behaviours:__ [`babel_index`](babel_index.md).

<a name="description"></a>

## Description ##

By partitioning an index into multiple physical parts, you are accessing much
smaller objects which makes it faster and more reliable.

With hash partitioning, an index entry is placed into a partition based
on the result of passing the partitioning key into a hashing algorithm.

This object is immutable.

<a name="types"></a>

## Data Types ##




### <a name="type-fields">fields()</a> ###


<pre><code>
fields() = [<a href="babel_key_value.md#type-key">babel_key_value:key()</a>]
</code></pre>




### <a name="type-iterator">iterator()</a> ###


<pre><code>
iterator() = #babel_hash_partitioned_index_iter{partition = <a href="babel_index_partition.md#type-t">babel_index_partition:t()</a> | undefined, sort_ordering = asc | desc, key = binary() | undefined, values = map() | undefined, typed_bucket = {binary(), binary()}, first = binary() | undefined, keys = [binary()], partition_identifiers = [<a href="babel_index.md#type-partition_id">babel_index:partition_id()</a>], riak_opts = <a href="babel_index.md#type-riak_opts">babel_index:riak_opts()</a>, done = boolean()}
</code></pre>




### <a name="type-t">t()</a> ###


<pre><code>
t() = #{sort_ordering =&gt; asc | desc, number_of_partitions =&gt; integer(), partition_algorithm =&gt; atom(), partition_identifier_prefix =&gt; binary(), partition_identifiers =&gt; [binary()], partition_by =&gt; <a href="#type-fields">fields()</a>, index_by =&gt; <a href="#type-fields">fields()</a>, aggregate_by =&gt; <a href="#type-fields">fields()</a>, covered_fields =&gt; <a href="#type-fields">fields()</a>, cardinality =&gt; one | many}
</code></pre>

<a name="index"></a>

## Function Index ##


<table width="100%" border="1" cellspacing="0" cellpadding="2" summary="function index"><tr><td valign="top"><a href="#aggregate_by-1">aggregate_by/1</a></td><td></td></tr><tr><td valign="top"><a href="#covered_fields-1">covered_fields/1</a></td><td></td></tr><tr><td valign="top"><a href="#distinguished_key_paths-1">distinguished_key_paths/1</a></td><td></td></tr><tr><td valign="top"><a href="#from_riak_dict-1">from_riak_dict/1</a></td><td></td></tr><tr><td valign="top"><a href="#index_by-1">index_by/1</a></td><td></td></tr><tr><td valign="top"><a href="#init-2">init/2</a></td><td></td></tr><tr><td valign="top"><a href="#init_partitions-1">init_partitions/1</a></td><td></td></tr><tr><td valign="top"><a href="#iterator-3">iterator/3</a></td><td></td></tr><tr><td valign="top"><a href="#iterator_done-1">iterator_done/1</a></td><td></td></tr><tr><td valign="top"><a href="#iterator_key-1">iterator_key/1</a></td><td></td></tr><tr><td valign="top"><a href="#iterator_move-3">iterator_move/3</a></td><td></td></tr><tr><td valign="top"><a href="#iterator_values-1">iterator_values/1</a></td><td></td></tr><tr><td valign="top"><a href="#match-3">match/3</a></td><td></td></tr><tr><td valign="top"><a href="#number_of_partitions-1">number_of_partitions/1</a></td><td></td></tr><tr><td valign="top"><a href="#partition_algorithm-1">partition_algorithm/1</a></td><td>Returns the partition algorithm name configured for this index.</td></tr><tr><td valign="top"><a href="#partition_by-1">partition_by/1</a></td><td></td></tr><tr><td valign="top"><a href="#partition_identifier-2">partition_identifier/2</a></td><td></td></tr><tr><td valign="top"><a href="#partition_identifier_prefix-1">partition_identifier_prefix/1</a></td><td></td></tr><tr><td valign="top"><a href="#partition_identifiers-2">partition_identifiers/2</a></td><td></td></tr><tr><td valign="top"><a href="#sort_ordering-1">sort_ordering/1</a></td><td>Returns the sort ordering configured for this index.</td></tr><tr><td valign="top"><a href="#to_riak_object-1">to_riak_object/1</a></td><td></td></tr><tr><td valign="top"><a href="#update_partition-3">update_partition/3</a></td><td></td></tr></table>


<a name="functions"></a>

## Function Details ##

<a name="aggregate_by-1"></a>

### aggregate_by/1 ###

<pre><code>
aggregate_by(X1::<a href="#type-t">t()</a>) -&gt; [binary()]
</code></pre>
<br />

<a name="covered_fields-1"></a>

### covered_fields/1 ###

<pre><code>
covered_fields(X1::<a href="#type-t">t()</a>) -&gt; [binary()]
</code></pre>
<br />

<a name="distinguished_key_paths-1"></a>

### distinguished_key_paths/1 ###

<pre><code>
distinguished_key_paths(Config::<a href="#type-t">t()</a>) -&gt; [<a href="babel_key_value.md#type-path">babel_key_value:path()</a>]
</code></pre>
<br />

<a name="from_riak_dict-1"></a>

### from_riak_dict/1 ###

<pre><code>
from_riak_dict(Dict::<a href="orddict.md#type-orddict">orddict:orddict()</a>) -&gt; Config::<a href="#type-t">t()</a>
</code></pre>
<br />

<a name="index_by-1"></a>

### index_by/1 ###

<pre><code>
index_by(X1::<a href="#type-t">t()</a>) -&gt; [binary()]
</code></pre>
<br />

<a name="init-2"></a>

### init/2 ###

<pre><code>
init(IndexId::binary(), ConfigData::map()) -&gt; {ok, <a href="#type-t">t()</a>} | {error, any()}
</code></pre>
<br />

<a name="init_partitions-1"></a>

### init_partitions/1 ###

<pre><code>
init_partitions(X1::<a href="#type-t">t()</a>) -&gt; {ok, [<a href="babel_index_partition.md#type-t">babel_index_partition:t()</a>]} | {error, any()}
</code></pre>
<br />

<a name="iterator-3"></a>

### iterator/3 ###

<pre><code>
iterator(Index::<a href="babel_index.md#type-t">babel_index:t()</a>, Config::<a href="babel_index.md#type-config">babel_index:config()</a>, Opts::<a href="#type-riak_opts">riak_opts()</a>) -&gt; Iterator::<a href="#type-iterator">iterator()</a>
</code></pre>
<br />

<a name="iterator_done-1"></a>

### iterator_done/1 ###

<pre><code>
iterator_done(Iterator::any()) -&gt; boolean()
</code></pre>
<br />

<a name="iterator_key-1"></a>

### iterator_key/1 ###

<pre><code>
iterator_key(Iterator::any()) -&gt; Key::<a href="babel_index.md#type-index_key">babel_index:index_key()</a>
</code></pre>
<br />

<a name="iterator_move-3"></a>

### iterator_move/3 ###

<pre><code>
iterator_move(Action::<a href="babel_index.md#type-iterator_action">babel_index:iterator_action()</a>, Iterator::<a href="#type-iterator">iterator()</a>, Config::<a href="#type-t">t()</a>) -&gt; <a href="#type-iterator">iterator()</a>
</code></pre>
<br />

<a name="iterator_values-1"></a>

### iterator_values/1 ###

<pre><code>
iterator_values(Iterator::any()) -&gt; Key::<a href="babel_index.md#type-index_values">babel_index:index_values()</a>
</code></pre>
<br />

<a name="match-3"></a>

### match/3 ###

`match(Pattern, Partition, Config) -> any()`

<a name="number_of_partitions-1"></a>

### number_of_partitions/1 ###

<pre><code>
number_of_partitions(X1::<a href="#type-t">t()</a>) -&gt; pos_integer()
</code></pre>
<br />

<a name="partition_algorithm-1"></a>

### partition_algorithm/1 ###

<pre><code>
partition_algorithm(X1::<a href="#type-t">t()</a>) -&gt; atom()
</code></pre>
<br />

Returns the partition algorithm name configured for this index.

<a name="partition_by-1"></a>

### partition_by/1 ###

<pre><code>
partition_by(X1::<a href="#type-t">t()</a>) -&gt; [binary()]
</code></pre>
<br />

<a name="partition_identifier-2"></a>

### partition_identifier/2 ###

<pre><code>
partition_identifier(KeyValue::<a href="babel_index.md#type-key_value">babel_index:key_value()</a>, Config::<a href="#type-t">t()</a>) -&gt; <a href="babel_index.md#type-partition_id">babel_index:partition_id()</a> | no_return()
</code></pre>
<br />

<a name="partition_identifier_prefix-1"></a>

### partition_identifier_prefix/1 ###

<pre><code>
partition_identifier_prefix(X1::<a href="#type-t">t()</a>) -&gt; binary()
</code></pre>
<br />

<a name="partition_identifiers-2"></a>

### partition_identifiers/2 ###

<pre><code>
partition_identifiers(Order::asc | desc, Config::<a href="#type-t">t()</a>) -&gt; [<a href="babel_index.md#type-partition_id">babel_index:partition_id()</a>]
</code></pre>
<br />

<a name="sort_ordering-1"></a>

### sort_ordering/1 ###

<pre><code>
sort_ordering(X1::<a href="#type-t">t()</a>) -&gt; asc | desc
</code></pre>
<br />

Returns the sort ordering configured for this index. The result can be
the atoms `asc` or `desc`.

<a name="to_riak_object-1"></a>

### to_riak_object/1 ###

<pre><code>
to_riak_object(Config::<a href="#type-t">t()</a>) -&gt; ConfigCRDT::<a href="babel_index.md#type-riak_object">babel_index:riak_object()</a>
</code></pre>
<br />

<a name="update_partition-3"></a>

### update_partition/3 ###

<pre><code>
update_partition(ActionData::<a href="babel_index.md#type-update_action">babel_index:update_action()</a> | [<a href="babel_index.md#type-update_action">babel_index:update_action()</a>], Partition::<a href="babel_index_partition.md#type-t">babel_index_partition:t()</a>, Config::<a href="#type-t">t()</a>) -&gt; <a href="babel_index_partition.md#type-t">babel_index_partition:t()</a> | no_return()
</code></pre>
<br />

