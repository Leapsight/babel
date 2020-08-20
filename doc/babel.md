

# Module babel #
* [Data Types](#types)
* [Function Index](#index)
* [Function Details](#functions)

<a name="types"></a>

## Data Types ##




### <a name="type-context">context()</a> ###


<pre><code>
context() = map()
</code></pre>




### <a name="type-opts">opts()</a> ###


<pre><code>
opts() = #{on_terminate =&gt; fun((Reason::any()) -&gt; any())}
</code></pre>




### <a name="type-work_item">work_item()</a> ###


<pre><code>
work_item() = <a href="reliable_storage_backend.md#type-work_item">reliable_storage_backend:work_item()</a>
</code></pre>

<a name="index"></a>

## Function Index ##


<table width="100%" border="1" cellspacing="0" cellpadding="2" summary="function index"><tr><td valign="top"><a href="#add_index-2">add_index/2</a></td><td>Adds.</td></tr><tr><td valign="top"><a href="#create_collection-2">create_collection/2</a></td><td>Schedules the creation of an index collection.</td></tr><tr><td valign="top"><a href="#create_index-1">create_index/1</a></td><td>Schedules the creation of an index and its partitions according to
<code>Config</code>.</td></tr><tr><td valign="top"><a href="#is_in_workflow-0">is_in_workflow/0</a></td><td>Returns true if the process has a workflow context.</td></tr><tr><td valign="top"><a href="#remove_index-2">remove_index/2</a></td><td>Removes an index at identifier <code>IndexId</code> from collection <code>Collection</code>.</td></tr><tr><td valign="top"><a href="#workflow-1">workflow/1</a></td><td>Equivalent to calling <a href="#workflow-2"><code>workflow/2</code></a> with and empty list passed as
the <code>Opts</code> argument.</td></tr><tr><td valign="top"><a href="#workflow-2">workflow/2</a></td><td>Executes the functional object <code>Fun</code> as a Reliable workflow, i.e.</td></tr></table>


<a name="functions"></a>

## Function Details ##

<a name="add_index-2"></a>

### add_index/2 ###

<pre><code>
add_index(Index::<a href="babel_index.md#type-t">babel_index:t()</a>, Collection::<a href="babel_index_collection.md#type-t">babel_index_collection:t()</a>) -&gt; <a href="babel_index_collection.md#type-t">babel_index_collection:t()</a> | no_return()
</code></pre>
<br />

Adds

<a name="create_collection-2"></a>

### create_collection/2 ###

<pre><code>
create_collection(BucketPrefix::binary(), Name::binary()) -&gt; <a href="babel_index_collection.md#type-t">babel_index_collection:t()</a> | no_return()
</code></pre>
<br />

Schedules the creation of an index collection.

<a name="create_index-1"></a>

### create_index/1 ###

<pre><code>
create_index(Config::map()) -&gt; <a href="babel_index.md#type-t">babel_index:t()</a> | no_return()
</code></pre>
<br />

Schedules the creation of an index and its partitions according to
`Config`.
> This function needs to be called within a workflow functional object,
see [`workflow/1`](#workflow-1).

Example: Creating an index and adding it to an existing collection

```
  > babel:workflow(
      fun() ->
           Collection0 = babel_index_collection:fetch(Conn, BucketPrefix, Key),
           Index = babel:create_index(Config),
           _Collection1 = babel:add_index(Index, Collection0),
           ok
      end).
  > {ok, <<"00005mrhDMaWqo4SSFQ9zSScnsS">>}
```


<a name="is_in_workflow-0"></a>

### is_in_workflow/0 ###

<pre><code>
is_in_workflow() -&gt; boolean()
</code></pre>
<br />

Returns true if the process has a workflow context.

<a name="remove_index-2"></a>

### remove_index/2 ###

<pre><code>
remove_index(IndexId::binary(), Collection::<a href="babel_index_collection.md#type-t">babel_index_collection:t()</a>) -&gt; <a href="babel_index_collection.md#type-t">babel_index_collection:t()</a> | no_return()
</code></pre>
<br />

Removes an index at identifier `IndexId` from collection `Collection`.

<a name="workflow-1"></a>

### workflow/1 ###

<pre><code>
workflow(Fun::fun(() -&gt; any())) -&gt; {ok, Id::binary()} | {error, any()}
</code></pre>
<br />

Equivalent to calling [`workflow/2`](#workflow-2) with and empty list passed as
the `Opts` argument.

<a name="workflow-2"></a>

### workflow/2 ###

<pre><code>
workflow(Fun::fun(() -&gt; any()), Opts::<a href="#type-opts">opts()</a>) -&gt; {ok, WorkId::binary(), ResultOfFun::any()} | {error, Reason::any()} | no_return()
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
           CollectionX0 = create_collection(<<"foo">>, <<"bar">>),
           CollectionY0 = babel_index_collection:fetch(
               Conn, <<"foo">>, <<"users">>),
           IndexA = babel:create_index(ConfigA),
           IndexB = babel:create_index(ConfigB),
           CollectionX1 = babel:add_index(IndexA, CollectionX0),
           CollectionY1 = babel:add_index(IndexB, CollectionY0),
           ok
      end).
  > {ok, <<"00005mrhDMaWqo4SSFQ9zSScnsS">>}
```

The resulting workflow execution will schedule the writes in the order that
results from the dependency graph constructed using the index partitions and
index resulting from the [`create_index/1`](#create_index-1) call and the collection
resulting from the [`create_collection/2`](#create_collection-2) and {@link add_index/2}.
This ensures partitions are created first and then collections. Notice that
indices are not persisted per se and need to be added to a collection, the
workflow will fail with a `{dangling, IndexId}` exception if that is the
case.

The `Opts` argument offers the following options:

* `on_terminate` – a functional object `fun((Reason :: any()) -> ok)`. This
function will be evaluated before the call terminates. In case of succesful
termination the value `normal` is passed as argument. Otherwise, in case of
error, the error reason will be passed as argument. This allows you to
perform a cleanup after the workflow execution e.g. returning a riak
connection object to a pool.

