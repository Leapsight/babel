

# Module babel_index_partition #
* [Data Types](#types)
* [Function Index](#index)
* [Function Details](#functions)

<a name="types"></a>

## Data Types ##




### <a name="type-data">data()</a> ###


<pre><code>
data() = <a href="riakc_map.md#type-crdt_map">riakc_map:crdt_map()</a>
</code></pre>




### <a name="type-riak_object">riak_object()</a> ###


<pre><code>
riak_object() = <a href="riakc_map.md#type-crdt_map">riakc_map:crdt_map()</a>
</code></pre>




### <a name="type-t">t()</a> ###


<pre><code>
t() = #babel_index_partition{id = binary(), created_ts = non_neg_integer(), last_updated_ts = non_neg_integer(), object = <a href="#type-riak_object">riak_object()</a>}
</code></pre>

<a name="index"></a>

## Function Index ##


<table width="100%" border="1" cellspacing="0" cellpadding="2" summary="function index"><tr><td valign="top"><a href="#created_ts-1">created_ts/1</a></td><td></td></tr><tr><td valign="top"><a href="#data-1">data/1</a></td><td></td></tr><tr><td valign="top"><a href="#delete-4">delete/4</a></td><td></td></tr><tr><td valign="top"><a href="#fetch-3">fetch/3</a></td><td></td></tr><tr><td valign="top"><a href="#fetch-4">fetch/4</a></td><td></td></tr><tr><td valign="top"><a href="#from_riak_object-1">from_riak_object/1</a></td><td></td></tr><tr><td valign="top"><a href="#id-1">id/1</a></td><td></td></tr><tr><td valign="top"><a href="#last_updated_ts-1">last_updated_ts/1</a></td><td></td></tr><tr><td valign="top"><a href="#lookup-3">lookup/3</a></td><td></td></tr><tr><td valign="top"><a href="#lookup-4">lookup/4</a></td><td></td></tr><tr><td valign="top"><a href="#new-1">new/1</a></td><td></td></tr><tr><td valign="top"><a href="#size-1">size/1</a></td><td></td></tr><tr><td valign="top"><a href="#store-5">store/5</a></td><td></td></tr><tr><td valign="top"><a href="#to_riak_object-1">to_riak_object/1</a></td><td></td></tr><tr><td valign="top"><a href="#update_data-2">update_data/2</a></td><td></td></tr></table>


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
delete(BucketType::binary(), BucketPrefix::binary(), Key::binary(), Opts::<a href="#type-riak_opts">riak_opts()</a>) -&gt; ok | {error, not_found | term()}
</code></pre>
<br />

<a name="fetch-3"></a>

### fetch/3 ###

<pre><code>
fetch(TypedBucket::{binary(), binary()}, Key::binary(), RiakOpts::<a href="#type-riak_opts">riak_opts()</a>) -&gt; <a href="#type-t">t()</a> | no_return()
</code></pre>
<br />

<a name="fetch-4"></a>

### fetch/4 ###

<pre><code>
fetch(BucketType::binary(), BucketPrefix::binary(), Key::binary(), RiakOpts::<a href="#type-riak_opts">riak_opts()</a>) -&gt; <a href="#type-t">t()</a> | no_return()
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
lookup(TypedBucket::{binary(), binary()}, Key::binary(), Opts::<a href="#type-riak_opts">riak_opts()</a>) -&gt; {ok, <a href="#type-t">t()</a>} | {error, not_found | term()}
</code></pre>
<br />

<a name="lookup-4"></a>

### lookup/4 ###

<pre><code>
lookup(BucketType::binary(), BucketPrefix::binary(), Key::binary(), Opts::<a href="#type-riak_opts">riak_opts()</a>) -&gt; {ok, <a href="#type-t">t()</a>} | {error, not_found | term()}
</code></pre>
<br />

<a name="new-1"></a>

### new/1 ###

<pre><code>
new(Id::binary()) -&gt; <a href="#type-t">t()</a>
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
store(BucketType::binary(), BucketPrefix::binary(), Key::binary(), Partition::<a href="#type-t">t()</a>, RiakOpts::<a href="#type-riak_opts">riak_opts()</a>) -&gt; ok | {error, any()}
</code></pre>
<br />

<a name="to_riak_object-1"></a>

### to_riak_object/1 ###

<pre><code>
to_riak_object(Index::<a href="#type-t">t()</a>) -&gt; IndexCRDT::<a href="#type-riak_object">riak_object()</a>
</code></pre>
<br />

<a name="update_data-2"></a>

### update_data/2 ###

<pre><code>
update_data(Fun::<a href="riakc_map.md#type-update_fun">riakc_map:update_fun()</a>, Babel_index_partition::<a href="#type-t">t()</a>) -&gt; <a href="#type-t">t()</a>
</code></pre>
<br />

