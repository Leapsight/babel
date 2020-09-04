

# Module babel #
* [Function Index](#index)
* [Function Details](#functions)

<a name="index"></a>

## Function Index ##


<table width="100%" border="1" cellspacing="0" cellpadding="2" summary="function index"><tr><td valign="top"><a href="#create_collection-2">create_collection/2</a></td><td>Schedules the creation of an index collection using Reliable.</td></tr><tr><td valign="top"><a href="#create_index-2">create_index/2</a></td><td>Schedules the creation of an index and its partitions according to
<code>Config</code> using Reliable.</td></tr><tr><td valign="top"><a href="#delete_collection-1">delete_collection/1</a></td><td>Schedules the delete of a collection, all its indices and their
partitions.</td></tr><tr><td valign="top"><a href="#delete_index-2">delete_index/2</a></td><td></td></tr><tr><td valign="top"><a href="#get_connection-1">get_connection/1</a></td><td></td></tr><tr><td valign="top"><a href="#rebuild_index-4">rebuild_index/4</a></td><td></td></tr><tr><td valign="top"><a href="#update_indices-3">update_indices/3</a></td><td></td></tr><tr><td valign="top"><a href="#validate_riak_opts-1">validate_riak_opts/1</a></td><td>Validates and returns the options in proplist format as expected by
Riak KV.</td></tr><tr><td valign="top"><a href="#workflow-1">workflow/1</a></td><td>Equivalent to calling <a href="#workflow-2"><code>workflow/2</code></a> with and empty map passed as
the <code>Opts</code> argument.</td></tr><tr><td valign="top"><a href="#workflow-2">workflow/2</a></td><td>Executes the functional object <code>Fun</code> as a Reliable workflow, i.e.</td></tr></table>


<a name="functions"></a>

## Function Details ##

<a name="create_collection-2"></a>

### create_collection/2 ###

<pre><code>
create_collection(BucketPrefix::binary(), Name::binary()) -&gt; <a href="babel_index_collection.md#type-t">babel_index_collection:t()</a> | no_return()
</code></pre>
<br />

Schedules the creation of an index collection using Reliable.
Fails if the collection already existed

> This function needs to be called within a workflow functional object,
see [`workflow/1`](#workflow-1).

<a name="create_index-2"></a>

### create_index/2 ###

<pre><code>
create_index(Index::<a href="babel_index.md#type-t">babel_index:t()</a>, Collection::<a href="babel_index_collection.md#type-t">babel_index_collection:t()</a>) -&gt; <a href="babel_index_collection.md#type-t">babel_index_collection:t()</a> | no_return()
</code></pre>
<br />

Schedules the creation of an index and its partitions according to
`Config` using Reliable.

> This function needs to be called within a workflow functional object,
see [`workflow/1`](#workflow-1).

Example: Creating an index and adding it to an existing collection

```
  > babel:workflow(
      fun() ->
           Collection0 = babel_index_collection:fetch(Conn, BucketPrefix, Key),
           Index = babel_index:new(Config),
           ok = babel:create_index(Index, Collection0),
           ok
      end).
  > {ok, <<"00005mrhDMaWqo4SSFQ9zSScnsS">>}
```


<a name="delete_collection-1"></a>

### delete_collection/1 ###

<pre><code>
delete_collection(Collection::<a href="babel_index_collection.md#type-t">babel_index_collection:t()</a>) -&gt; ok | no_return()
</code></pre>
<br />

Schedules the delete of a collection, all its indices and their
partitions.

<a name="delete_index-2"></a>

### delete_index/2 ###

<pre><code>
delete_index(Index::<a href="babel_index.md#type-t">babel_index:t()</a>, Collection0::<a href="babel_index_collection.md#type-t">babel_index_collection:t()</a>) -&gt; <a href="babel_index_collection.md#type-t">babel_index_collection:t()</a>
</code></pre>
<br />

<a name="get_connection-1"></a>

### get_connection/1 ###

`get_connection(X1) -> any()`

<a name="rebuild_index-4"></a>

### rebuild_index/4 ###

<pre><code>
rebuild_index(Index::<a href="babel_index.md#type-t">babel_index:t()</a>, BucketType::binary(), Bucket::binary(), Opts::<a href="#type-riak_opts">riak_opts()</a>) -&gt; ok | no_return()
</code></pre>
<br />

<a name="update_indices-3"></a>

### update_indices/3 ###

<pre><code>
update_indices(Actions::[{<a href="babel_index.md#type-action">babel_index:action()</a>, <a href="babel_index.md#type-object">babel_index:object()</a>}], CollectionOrIndices::<a href="babel_index_collection.md#type-t">babel_index_collection:t()</a>, RiakOpts::map()) -&gt; ok | no_return()
</code></pre>
<br />

<a name="validate_riak_opts-1"></a>

### validate_riak_opts/1 ###

<pre><code>
validate_riak_opts(Opts::map()) -&gt; <a href="#type-maybe_no_return">maybe_no_return</a>(map())
</code></pre>
<br />

Validates and returns the options in proplist format as expected by
Riak KV.

<a name="workflow-1"></a>

### workflow/1 ###

<pre><code>
workflow(Fun::fun(() -&gt; any())) -&gt; {ok, WorkId::binary(), ResultOfFun::any()} | {error, Reason::any()} | no_return()
</code></pre>
<br />

Equivalent to calling [`workflow/2`](#workflow-2) with and empty map passed as
the `Opts` argument.

<a name="workflow-2"></a>

### workflow/2 ###

<pre><code>
workflow(Fun::fun(() -&gt; any()), Opts::<a href="babel_workflow.md#type-opts">babel_workflow:opts()</a>) -&gt; {ok, WorkId::binary(), ResultOfFun::any()} | {error, Reason::any()} | no_return()
</code></pre>
<br />

Executes the functional object `Fun` as a Reliable workflow, i.e.
ordering and scheduling all resulting Riak KV object writes.

The code that executes inside the workflow should call one or more functions
in this module to schedule writes in Riak KV. For example, if you wanted to
schedule an index creation you should use [`create_index/2`](#create_index-2) instead of
[`babel_index_collection`](babel_index_collection.md), [`babel_index`](babel_index.md) and [`babel_index_partition`](babel_index_partition.md) functions directly.

Any other operation, including reading and writing from/to Riak KV directly
or by using the API provided by other Babel modules will work as normal and
will not affect the workflow, only the special functions in this module will
add work items to the workflow.

If something goes wrong inside the workflow as a result of a user
error or general exception, the entire workflow is terminated and the
function raises an exception. In case of an internal error, the function
returns the tuple `{error, Reason}`.

If everything goes well, the function returns the triple
`{ok, WorkId, ResultOfFun}` where `WorkId` is the identifier for the
workflow schedule by Reliable and `ResultOfFun` is the value of the last
expression in `Fun`.

> Notice that calling this function schedules the work to Reliable, you need
to use the WorkId to check with Reliable the status of the workflow
execution.

Example: Creating various babel objects and scheduling

```
  > babel:workflow(
      fun() ->
           CollectionX0 = babel_index_collection:new(<<"foo">>, <<"bar">>),
           CollectionY0 = babel_index_collection:fetch(
  Conn, <<"foo">>, <<"users">>),
           IndexA = babel_index:new(ConfigA),
           IndexB = babel_index:new(ConfigB),
           _CollectionX1 = babel:create_index(IndexA, CollectionX0),
           _CollextionY1 = babel:create_index(IndexB, CollectionY0),
           ok
      end).
  > {ok, <<"00005mrhDMaWqo4SSFQ9zSScnsS">>, ok}
```

The resulting workflow execution will schedule the writes in the order that
results from the dependency graph constructed using the results of this
module functions. This ensures partitions are created first and then
collections.

The `Opts` argument offers the following options:

* `on_terminate` – a functional object `fun((Reason :: any()) -> ok)`. This
function will be evaluated before the call terminates. In case of succesful
termination the value `normal` is passed as argument. Otherwise, in case of
error, the error reason will be passed as argument. This allows you to
perform a cleanup after the workflow execution e.g. returning a riak
connection object to a pool.

