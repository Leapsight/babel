

# Module babel_index_partition #
* [Data Types](#types)
* [Function Index](#index)
* [Function Details](#functions)

<a name="types"></a>

## Data Types ##




### <a name="type-t">t()</a> ###


<pre><code>
t() = <a href="riakc_map.md#type-crdt_map">riakc_map:crdt_map()</a>
</code></pre>

<a name="index"></a>

## Function Index ##


<table width="100%" border="1" cellspacing="0" cellpadding="2" summary="function index"><tr><td valign="top"><a href="#created_ts-1">created_ts/1</a></td><td></td></tr><tr><td valign="top"><a href="#data-1">data/1</a></td><td></td></tr><tr><td valign="top"><a href="#delete-5">delete/5</a></td><td></td></tr><tr><td valign="top"><a href="#fetch-4">fetch/4</a></td><td></td></tr><tr><td valign="top"><a href="#fetch-5">fetch/5</a></td><td></td></tr><tr><td valign="top"><a href="#id-1">id/1</a></td><td></td></tr><tr><td valign="top"><a href="#last_updated_ts-1">last_updated_ts/1</a></td><td></td></tr><tr><td valign="top"><a href="#lookup-5">lookup/5</a></td><td></td></tr><tr><td valign="top"><a href="#new-1">new/1</a></td><td></td></tr><tr><td valign="top"><a href="#size-1">size/1</a></td><td></td></tr><tr><td valign="top"><a href="#store-5">store/5</a></td><td></td></tr><tr><td valign="top"><a href="#update_data-2">update_data/2</a></td><td></td></tr></table>


<a name="functions"></a>

## Function Details ##

<a name="created_ts-1"></a>

### created_ts/1 ###

<pre><code>
created_ts(Partition::<a href="#type-t">t()</a>) -&gt; non_neg_integer() | no_return()
</code></pre>
<br />

<a name="data-1"></a>

### data/1 ###

<pre><code>
data(Partition::<a href="#type-t">t()</a>) -&gt; <a href="riakc_map.md#type-crdt_map">riakc_map:crdt_map()</a> | no_return()
</code></pre>
<br />

<a name="delete-5"></a>

### delete/5 ###

<pre><code>
delete(Conn::pid(), BucketType::binary(), BucketPrefix::binary(), Key::binary(), Opts::<a href="#type-req_opts">req_opts()</a>) -&gt; ok | {error, not_found | term()}
</code></pre>
<br />

<a name="fetch-4"></a>

### fetch/4 ###

<pre><code>
fetch(Conn::pid(), BucketType::binary(), BucketPrefix::binary(), Key::binary()) -&gt; <a href="#type-t">t()</a> | no_return()
</code></pre>
<br />

<a name="fetch-5"></a>

### fetch/5 ###

<pre><code>
fetch(Conn::pid(), BucketType::binary(), BucketPrefix::binary(), Key::binary(), Opts::<a href="#type-req_opts">req_opts()</a>) -&gt; <a href="#type-t">t()</a> | no_return()
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
last_updated_ts(Partition::<a href="#type-t">t()</a>) -&gt; non_neg_integer() | no_return()
</code></pre>
<br />

<a name="lookup-5"></a>

### lookup/5 ###

<pre><code>
lookup(Conn::pid(), BucketType::binary(), BucketPrefix::binary(), Key::binary(), Opts::<a href="#type-req_opts">req_opts()</a>) -&gt; {ok, <a href="#type-t">t()</a>} | {error, not_found | term()}
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
store(Conn::pid(), BucketType::binary(), BucketPrefix::binary(), Key::binary(), Partition::<a href="#type-t">t()</a>) -&gt; ok | {error, any()}
</code></pre>
<br />

<a name="update_data-2"></a>

### update_data/2 ###

<pre><code>
update_data(Fun::<a href="riakc_map.md#type-update_fun">riakc_map:update_fun()</a>, Partition0::<a href="#type-t">t()</a>) -&gt; <a href="#type-t">t()</a>
</code></pre>
<br />

