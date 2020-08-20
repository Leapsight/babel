

# Module babel_hash_partitioned_index #
* [Data Types](#types)
* [Function Index](#index)
* [Function Details](#functions)

__Behaviours:__ [`babel_index`](babel_index.md).

<a name="types"></a>

## Data Types ##




### <a name="type-action">action()</a> ###


<pre><code>
action() = {<a href="babel_index.md#type-action">babel_index:action()</a>, <a href="babel_index.md#type-data">babel_index:data()</a>}
</code></pre>




### <a name="type-fields">fields()</a> ###


<pre><code>
fields() = [<a href="babel_key_value.md#type-key">babel_key_value:key()</a> | [<a href="babel_key_value.md#type-key">babel_key_value:key()</a>]]
</code></pre>




### <a name="type-t">t()</a> ###


<pre><code>
t() = #{sort_ordering =&gt; asc | desc, number_of_partitions =&gt; integer(), partition_algorithm =&gt; atom(), partition_identifier_prefix =&gt; binary(), partition_identifiers =&gt; [binary()], partition_by =&gt; <a href="#type-fields">fields()</a>, index_by =&gt; <a href="#type-fields">fields()</a>, aggregate_by =&gt; <a href="#type-fields">fields()</a>, covered_fields =&gt; <a href="#type-fields">fields()</a>}
</code></pre>

<a name="index"></a>

## Function Index ##


<table width="100%" border="1" cellspacing="0" cellpadding="2" summary="function index"><tr><td valign="top"><a href="#aggregate_by-1">aggregate_by/1</a></td><td></td></tr><tr><td valign="top"><a href="#covered_fields-1">covered_fields/1</a></td><td></td></tr><tr><td valign="top"><a href="#from_crdt-1">from_crdt/1</a></td><td></td></tr><tr><td valign="top"><a href="#index_by-1">index_by/1</a></td><td></td></tr><tr><td valign="top"><a href="#init-2">init/2</a></td><td></td></tr><tr><td valign="top"><a href="#init_partitions-1">init_partitions/1</a></td><td></td></tr><tr><td valign="top"><a href="#number_of_partitions-1">number_of_partitions/1</a></td><td></td></tr><tr><td valign="top"><a href="#partition_algorithm-1">partition_algorithm/1</a></td><td>Returns the partition algorithm name configured for this index.</td></tr><tr><td valign="top"><a href="#partition_by-1">partition_by/1</a></td><td></td></tr><tr><td valign="top"><a href="#partition_identifier-2">partition_identifier/2</a></td><td></td></tr><tr><td valign="top"><a href="#partition_identifier_prefix-1">partition_identifier_prefix/1</a></td><td></td></tr><tr><td valign="top"><a href="#partition_identifiers-2">partition_identifiers/2</a></td><td></td></tr><tr><td valign="top"><a href="#partition_size-2">partition_size/2</a></td><td></td></tr><tr><td valign="top"><a href="#sort_ordering-1">sort_ordering/1</a></td><td>Returns the sort ordering configured for this index.</td></tr><tr><td valign="top"><a href="#to_crdt-1">to_crdt/1</a></td><td></td></tr><tr><td valign="top"><a href="#update_partition-3">update_partition/3</a></td><td></td></tr></table>


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

<a name="from_crdt-1"></a>

### from_crdt/1 ###

<pre><code>
from_crdt(Object::<a href="babel_index.md#type-config_crdt">babel_index:config_crdt()</a>) -&gt; Config::<a href="#type-t">t()</a>
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
init_partitions(X1::<a href="#type-t">t()</a>) -&gt; [<a href="babel_index_partition.md#type-t">babel_index_partition:t()</a>]
</code></pre>
<br />

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
partition_identifier(Data::<a href="babel_index.md#type-data">babel_index:data()</a>, Config::<a href="#type-t">t()</a>) -&gt; <a href="babel_index.md#type-partition_id">babel_index:partition_id()</a>
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

<a name="partition_size-2"></a>

### partition_size/2 ###

<pre><code>
partition_size(Partition::<a href="babel_index_partition.md#type-t">babel_index_partition:t()</a>, Config::<a href="#type-t">t()</a>) -&gt; non_neg_integer()
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

<a name="to_crdt-1"></a>

### to_crdt/1 ###

<pre><code>
to_crdt(Config::<a href="#type-t">t()</a>) -&gt; ConfigCRDT::<a href="babel_index.md#type-config_crdt">babel_index:config_crdt()</a>
</code></pre>
<br />

<a name="update_partition-3"></a>

### update_partition/3 ###

<pre><code>
update_partition(ActionData::<a href="#type-action">action()</a> | [<a href="#type-action">action()</a>], Partition::<a href="babel_index_partition.md#type-t">babel_index_partition:t()</a>, Config::<a href="#type-t">t()</a>) -&gt; <a href="babel_index_partition.md#type-t">babel_index_partition:t()</a> | no_return()
</code></pre>
<br />

