

# Module babel_index_partition #
* [Data Types](#types)
* [Function Index](#index)
* [Function Details](#functions)

<a name="types"></a>

## Data Types ##


<a name="data()"></a>


### data() ###


<pre><code>
data() = <a href="riakc_map.md#type-crdt_map">riakc_map:crdt_map()</a> | <a href="riakc_set.md#type-riakc_set">riakc_set:riakc_set()</a>
</code></pre>


<a name="opts()"></a>


### opts() ###


<pre><code>
opts() = #{type =&gt; map | set}
</code></pre>


<a name="riak_object()"></a>


### riak_object() ###


<pre><code>
riak_object() = <a href="riakc_map.md#type-crdt_map">riakc_map:crdt_map()</a>
</code></pre>


<a name="t()"></a>


### t() ###


<pre><code>
t() = #babel_index_partition{id = binary(), created_ts = non_neg_integer(), last_updated_ts = non_neg_integer(), object = <a href="#type-riak_object">riak_object()</a>, type = map | set}
</code></pre>


<a name="functions"></a>

## Function Details ##

<a name="created_ts-1"></a>

### created_ts/1 ###

<pre><code>
created_ts(Partition::<a href="#type-t">t()</a>) -&gt; non_neg_integer()
</code></pre>
<br />

<a name="data-1"></a>

### data/1 ###

<pre><code>
data(Partition::<a href="#type-t">t()</a>) -&gt; <a href="#type-data">data()</a>
</code></pre>
<br />

<a name="delete-4"></a>

### delete/4 ###

<pre><code>
delete(BucketType::binary(), BucketPrefix::binary(), Key::binary(), Opts::<a href="babel.md#type-opts">babel:opts()</a>) -&gt; ok | {error, not_found | term()}
</code></pre>
<br />

<a name="fetch-3"></a>

### fetch/3 ###

<pre><code>
fetch(TypedBucket::{binary(), binary()}, Key::binary(), RiakOpts::<a href="babel.md#type-opts">babel:opts()</a>) -&gt; <a href="#type-t">t()</a> | no_return()
</code></pre>
<br />

<a name="fetch-4"></a>

### fetch/4 ###

<pre><code>
fetch(BucketType::binary(), BucketPrefix::binary(), Key::binary(), RiakOpts::<a href="babel.md#type-opts">babel:opts()</a>) -&gt; <a href="#type-t">t()</a> | no_return()
</code></pre>
<br />

<a name="from_riak_object-1"></a>

### from_riak_object/1 ###

<pre><code>
from_riak_object(Object::<a href="#type-riak_object">riak_object()</a>) -&gt; Partition::<a href="#type-t">t()</a>
</code></pre>
<br />

<a name="id-1"></a>

### id/1 ###

<pre><code>
id(Partition::<a href="#type-t">t()</a>) -&gt; binary() | no_return()
</code></pre>
<br />

<a name="last_updated_ts-1"></a>

### last_updated_ts/1 ###

<pre><code>
last_updated_ts(Partition::<a href="#type-t">t()</a>) -&gt; non_neg_integer()
</code></pre>
<br />

<a name="lookup-3"></a>

### lookup/3 ###

<pre><code>
lookup(TypedBucket::{binary(), binary()}, Key::binary(), Opts::<a href="babel.md#type-opts">babel:opts()</a>) -&gt; {ok, <a href="#type-t">t()</a>} | {error, not_found | term()}
</code></pre>
<br />

<a name="lookup-4"></a>

### lookup/4 ###

<pre><code>
lookup(BucketType::binary(), BucketPrefix::binary(), Key::binary(), Opts::<a href="babel.md#type-opts">babel:opts()</a>) -&gt; {ok, <a href="#type-t">t()</a>} | {error, not_found | term()}
</code></pre>
<br />

<a name="new-1"></a>

### new/1 ###

<pre><code>
new(Id::binary()) -&gt; <a href="#type-t">t()</a>
</code></pre>
<br />

<a name="new-2"></a>

### new/2 ###

<pre><code>
new(Id::binary(), Opts::<a href="#type-opts">opts()</a>) -&gt; <a href="#type-t">t()</a>
</code></pre>
<br />

<a name="size-1"></a>

### size/1 ###

<pre><code>
size(Partition::<a href="#type-t">t()</a>) -&gt; non_neg_integer()
</code></pre>
<br />

<a name="store-5"></a>

### store/5 ###

<pre><code>
store(BucketType::binary(), BucketPrefix::binary(), Key::binary(), Partition::<a href="#type-t">t()</a>, Opts::<a href="babel.md#type-opts">babel:opts()</a>) -&gt; ok | {error, any()}
</code></pre>
<br />

<a name="to_riak_object-1"></a>

### to_riak_object/1 ###

<pre><code>
to_riak_object(Index::<a href="#type-t">t()</a>) -&gt; IndexCRDT::<a href="#type-riak_object">riak_object()</a>
</code></pre>
<br />

<a name="type-1"></a>

### type/1 ###

<pre><code>
type(Partition::<a href="#type-t">t()</a>) -&gt; map | set
</code></pre>
<br />

<a name="update_data-2"></a>

### update_data/2 ###

<pre><code>
update_data(Fun::<a href="riakc_map.md#type-update_fun">riakc_map:update_fun()</a>, Babel_index_partition::<a href="#type-t">t()</a>) -&gt; <a href="#type-t">t()</a>
</code></pre>
<br />

