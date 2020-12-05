

# Module babel_simple_index #
* [Description](#description)
* [Data Types](#types)
* [Function Index](#index)
* [Function Details](#functions)

This object is immutable.

__Behaviours:__ [`babel_index`](babel_index.md).

<a name="description"></a>

## Description ##

<a name="types"></a>

## Data Types ##


<a name="fields()"></a>


### fields() ###


<pre><code>
fields() = [<a href="babel_key_value.md#type-key">babel_key_value:key()</a>]
</code></pre>


<a name="iterator()"></a>


### iterator() ###


<pre><code>
iterator() = term()
</code></pre>


<a name="t()"></a>


### t() ###


<pre><code>
t() = #{sort_ordering =&gt; asc | desc, partition_identifier_prefix =&gt; binary(), index_by =&gt; <a href="#type-fields">fields()</a>, covered_fields =&gt; <a href="#type-fields">fields()</a>}
</code></pre>


<a name="functions"></a>

## Function Details ##

<a name="covered_fields-1"></a>

### covered_fields/1 ###

<pre><code>
covered_fields(X1::<a href="#type-t">t()</a>) -&gt; [binary()]
</code></pre>
<br />

<a name="distinguished_key_paths-1"></a>

### distinguished_key_paths/1 ###

<pre><code>
distinguished_key_paths(Config::<a href="#type-t">t()</a>) -&gt; [<a href="babel_key_value.md#type-key">babel_key_value:key()</a>]
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

<a name="init_partition-2"></a>

### init_partition/2 ###

<pre><code>
init_partition(PartitionId::binary(), ConfigData::<a href="#type-t">t()</a>) -&gt; {ok, <a href="babel_index_partition.md#type-t">babel_index_partition:t()</a>} | {error, any()}
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
iterator(X1::<a href="babel_index.md#type-t">babel_index:t()</a>, X2::<a href="babel_index.md#type-config">babel_index:config()</a>, Opts::<a href="babel.md#type-riak_opts">babel:riak_opts()</a>) -&gt; Iterator::<a href="#type-iterator">iterator()</a>
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
number_of_partitions(X1::<a href="#type-t">t()</a>) -&gt; pos_integer() | undefined
</code></pre>
<br />

<a name="partition-3"></a>

### partition/3 ###

<pre><code>
partition(Pattern::<a href="babel_index.md#type-key_value">babel_index:key_value()</a>, Index::<a href="babel_index.md#type-t">babel_index:t()</a>, Opts::<a href="babel.md#type-opts">babel:opts()</a>) -&gt; <a href="babel_index.md#type-partition_id">babel_index:partition_id()</a> | no_return()
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
partition_identifiers(X1::asc | desc, X2::<a href="#type-t">t()</a>) -&gt; [<a href="babel_index.md#type-partition_id">babel_index:partition_id()</a>]
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

