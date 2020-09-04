

# Module babel_reliable #
* [Data Types](#types)
* [Function Index](#index)
* [Function Details](#functions)

<a name="types"></a>

## Data Types ##




### <a name="type-opts">opts()</a> ###


<pre><code>
opts() = #{partition_key =&gt; binary(), on_terminate =&gt; fun((Reason::any()) -&gt; any())}
</code></pre>




### <a name="type-work_item">work_item()</a> ###


<pre><code>
work_item() = <a href="reliable_storage_backend.md#type-work_item">reliable_storage_backend:work_item()</a> | fun(() -&gt; <a href="reliable_storage_backend.md#type-work_item">reliable_storage_backend:work_item()</a>)
</code></pre>




### <a name="type-workflow_item">workflow_item()</a> ###


<pre><code>
workflow_item() = {Id::<a href="#type-workflow_item_id">workflow_item_id()</a>, {update | delete, <a href="#type-work_item">work_item()</a>}}
</code></pre>




### <a name="type-workflow_item_id">workflow_item_id()</a> ###


<pre><code>
workflow_item_id() = term()
</code></pre>

<a name="index"></a>

## Function Index ##


<table width="100%" border="1" cellspacing="0" cellpadding="2" summary="function index"><tr><td valign="top"><a href="#abort-1">abort/1</a></td><td>When called within the functional object in <a href="#workflow-1"><code>workflow/1</code></a>,
makes the workflow silently return the tuple {aborted, Reason} as the
error reason.</td></tr><tr><td valign="top"><a href="#add_workflow_items-1">add_workflow_items/1</a></td><td></td></tr><tr><td valign="top"><a href="#add_workflow_precedence-2">add_workflow_precedence/2</a></td><td></td></tr><tr><td valign="top"><a href="#find_workflow_item-1">find_workflow_item/1</a></td><td></td></tr><tr><td valign="top"><a href="#get_workflow_item-1">get_workflow_item/1</a></td><td></td></tr><tr><td valign="top"><a href="#is_in_workflow-0">is_in_workflow/0</a></td><td>Returns true if the process has a workflow context.</td></tr><tr><td valign="top"><a href="#workflow-1">workflow/1</a></td><td>Equivalent to calling <a href="#workflow-2"><code>workflow/2</code></a> with and empty map passed as
the <code>Opts</code> argument.</td></tr><tr><td valign="top"><a href="#workflow-2">workflow/2</a></td><td>Executes the functional object <code>Fun</code> as a Reliable workflow, i.e.</td></tr><tr><td valign="top"><a href="#workflow_id-0">workflow_id/0</a></td><td>Returns the workflow identifier or undefined not currently within a
workflow.</td></tr><tr><td valign="top"><a href="#workflow_nesting_level-0">workflow_nesting_level/0</a></td><td>Returns the current worflow nesting level.</td></tr></table>


<a name="functions"></a>

## Function Details ##

<a name="abort-1"></a>

### abort/1 ###

<pre><code>
abort(Reason::any()) -&gt; no_return()
</code></pre>
<br />

When called within the functional object in [`workflow/1`](#workflow-1),
makes the workflow silently return the tuple {aborted, Reason} as the
error reason.

Termination of a Babel workflow means that an exception is thrown to an
enclosing catch. Thus, the expression `catch babel:abort(foo)` does not
terminate the workflow.

<a name="add_workflow_items-1"></a>

### add_workflow_items/1 ###

<pre><code>
add_workflow_items(L::[<a href="#type-workflow_item">workflow_item()</a>]) -&gt; ok
</code></pre>
<br />

<a name="add_workflow_precedence-2"></a>

### add_workflow_precedence/2 ###

<pre><code>
add_workflow_precedence(As::<a href="#type-workflow_item_id">workflow_item_id()</a> | [<a href="#type-workflow_item_id">workflow_item_id()</a>], Bs::<a href="#type-workflow_item_id">workflow_item_id()</a> | [<a href="#type-workflow_item_id">workflow_item_id()</a>]) -&gt; ok
</code></pre>
<br />

<a name="find_workflow_item-1"></a>

### find_workflow_item/1 ###

<pre><code>
find_workflow_item(Id::<a href="#type-workflow_item_id">workflow_item_id()</a>) -&gt; {ok, <a href="#type-workflow_item">workflow_item()</a>} | error
</code></pre>
<br />

<a name="get_workflow_item-1"></a>

### get_workflow_item/1 ###

<pre><code>
get_workflow_item(Id::<a href="#type-workflow_item_id">workflow_item_id()</a>) -&gt; <a href="#type-workflow_item">workflow_item()</a> | no_return()
</code></pre>
<br />

<a name="is_in_workflow-0"></a>

### is_in_workflow/0 ###

<pre><code>
is_in_workflow() -&gt; boolean()
</code></pre>
<br />

Returns true if the process has a workflow context.

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
           CollectionX0 = babel_index_collection:new(<<"foo">>, <<"bar">>),
           CollectionY0 = babel_index_collection:fetch(
  Conn, <<"foo">>, <<"users">>),
           IndexA = babel_index:new(ConfigA),
           IndexB = babel_index:new(ConfigB),
           CollectionX1 = babel:create_index(IndexA, CollectionX0),
           CollectionY1 = babel:create_index(IndexB, CollectionY0),
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

<a name="workflow_id-0"></a>

### workflow_id/0 ###

<pre><code>
workflow_id() -&gt; binary() | undefined
</code></pre>
<br />

Returns the workflow identifier or undefined not currently within a
workflow.

<a name="workflow_nesting_level-0"></a>

### workflow_nesting_level/0 ###

<pre><code>
workflow_nesting_level() -&gt; pos_integer()
</code></pre>
<br />

Returns the current worflow nesting level.

