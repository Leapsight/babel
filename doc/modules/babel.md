

# Module babel #
* [Description](#description)
* [Data Types](#types)
* [Function Index](#index)
* [Function Details](#functions)

This module acts as entry point for a number of Babel features and
provides some of the `riakc_pb_socket` module functions adapted for babel
datatypes.

<a name="description"></a>

## Description ##

### Working with Babel Datatypes

### Working with Reliable Workflows
#### Workflow aware functions
A workflow aware function is a function that schedules its execution when it
is called inside a workflow context. Several functions in this module are
workflow aware e.g. [`put/5`](#put-5), [`delete/3`](#delete-3).

### Working with Babel Indices

<a name="types"></a>

## Data Types ##


<a name="datatype()"></a>


### datatype() ###


<pre><code>
datatype() = <a href="babel_map.md#type-t">babel_map:t()</a> | <a href="babel_set.md#type-t">babel_set:t()</a> | <a href="babel_counter.md#type-t">babel_counter:t()</a>
</code></pre>


<a name="opts()"></a>


### opts() ###


<pre><code>
opts() = #{connection =&gt; pid() | fun(() -&gt; pid()), riak_opts =&gt; <a href="#type-riak_opts">riak_opts()</a>, $validated =&gt; boolean()}
</code></pre>


<a name="riak_op()"></a>


### riak_op() ###


<pre><code>
riak_op() = <a href="riakc_datatype.md#type-update">riakc_datatype:update</a>(term())
</code></pre>


<a name="riak_opts()"></a>


### riak_opts() ###


<pre><code>
riak_opts() = #{r =&gt; <a href="#type-quorum">quorum()</a>, pr =&gt; <a href="#type-quorum">quorum()</a>, w =&gt; <a href="#type-quorum">quorum()</a>, dw =&gt; <a href="#type-quorum">quorum()</a>, pw =&gt; <a href="#type-quorum">quorum()</a>, notfound_ok =&gt; boolean(), basic_quorum =&gt; boolean(), sloppy_quorum =&gt; boolean(), timeout =&gt; timeout(), return_body =&gt; boolean()}
</code></pre>


<a name="type_spec()"></a>


### type_spec() ###


<pre><code>
type_spec() = <a href="babel_map.md#type-type_spec">babel_map:type_spec()</a> | <a href="babel_set.md#type-type_spec">babel_set:type_spec()</a> | <a href="babel_counter.md#type-type_spec">babel_counter:type_spec()</a>
</code></pre>


<a name="functions"></a>

## Function Details ##

<a name="create_collection-2"></a>

### create_collection/2 ###

<pre><code>
create_collection(BucketPrefix::binary(), Name::binary()) -&gt; <a href="babel_index_collection.md#type-t">babel_index_collection:t()</a> | no_return()
</code></pre>
<br />

Calls [`create_collection/3`](#create_collection-3) passing an empty `Opts`.

<a name="create_collection-3"></a>

### create_collection/3 ###

<pre><code>
create_collection(BucketPrefix::binary(), Name::binary(), Opts::<a href="#type-opts">opts()</a>) -&gt; {ok, WorflowItemId::any()} | {scheduled, WorkRef::<a href="reliable_work_ref.md#type-t">reliable_work_ref:t()</a>, ResultOfFun::any()} | {error, Reason::any()} | no_return()
</code></pre>
<br />

Schedules the creation of an empty index collection using Reliable.
Fails if the collection already exists.

The collection will be stored in Riak KV under the bucket type configured
for the application option `index_collection_bucket_type`, bucket name
resulting from concatenating the value of `BucketPrefix` to the suffix `/
index_collection` and the key will be the value of `Name`.

?> This function uses a workflow, see [`workflow/2`](#workflow-2) for an explanation
of the possible return values.

<a name="create_index-2"></a>

### create_index/2 ###

<pre><code>
create_index(Index::<a href="babel_index.md#type-t">babel_index:t()</a>, Collection::<a href="babel_index_collection.md#type-t">babel_index_collection:t()</a>) -&gt; {ok, WorflowItemId::any()} | {scheduled, WorkRef::<a href="reliable_work_ref.md#type-t">reliable_work_ref:t()</a>, ResultOfFun::any()} | {error, Reason::any()} | no_return()
</code></pre>
<br />

Calls [`create_index/3`](#create_index-3) passing the default options as third
argument.

<a name="create_index-3"></a>

### create_index/3 ###

<pre><code>
create_index(Index::<a href="babel_index.md#type-t">babel_index:t()</a>, Collection::<a href="babel_index_collection.md#type-t">babel_index_collection:t()</a>, Opts::<a href="#type-opts">opts()</a>) -&gt; {ok, WorflowItemId::any()} | {scheduled, WorkRef::<a href="reliable_work_ref.md#type-t">reliable_work_ref:t()</a>, ResultOfFun::any()} | {error, Reason::any()} | no_return()
</code></pre>
<br />

Schedules the creation of an index and its partitions according to
`Config` using Reliable.

!> **Important**, this function must be called within a workflow
functional object, see [`workflow/1`](#workflow-1).

<a name="delete-3"></a>

### delete/3 ###

<pre><code>
delete(TypedBucket::<a href="#type-bucket_and_type">bucket_and_type()</a>, Key::binary(), Opts::<a href="#type-opts">opts()</a>) -&gt; ok | {scheduled, WorkflowId::{<a href="#type-bucket_and_type">bucket_and_type()</a>, <a href="#type-key">key()</a>}} | {error, Reason::term()}
</code></pre>
<br />

?> This function is workflow aware

<a name="drop_collection-1"></a>

### drop_collection/1 ###

<pre><code>
drop_collection(Collection::<a href="babel_index_collection.md#type-t">babel_index_collection:t()</a>) -&gt; {ok, WorflowItemId::any()} | {scheduled, WorkRef::<a href="reliable_work_ref.md#type-t">reliable_work_ref:t()</a>, ResultOfFun::any()} | {error, Reason::any()} | no_return()
</code></pre>
<br />

Calls [`drop_collection/2`](#drop_collection-2)

<a name="drop_collection-2"></a>

### drop_collection/2 ###

<pre><code>
drop_collection(Collection::<a href="babel_index_collection.md#type-t">babel_index_collection:t()</a>, Opts::<a href="#type-opts">opts()</a>) -&gt; {ok, WorflowItemId::any()} | {scheduled, WorkRef::<a href="reliable_work_ref.md#type-t">reliable_work_ref:t()</a>, ResultOfFun::any()} | {error, Reason::any()} | no_return()
</code></pre>
<br />

Schedules the removal from Riak KV of collection `Collection`,
all its indices and their respective partitions.

?> This function uses a workflow, see [`workflow/2`](#workflow-2) for an explanation
of the possible return values.

<a name="drop_index-2"></a>

### drop_index/2 ###

<pre><code>
drop_index(Index::binary(), Collection0::<a href="babel_index_collection.md#type-t">babel_index_collection:t()</a>) -&gt; {ok, WorflowItemId::any()} | {scheduled, WorkRef::<a href="reliable_work_ref.md#type-t">reliable_work_ref:t()</a>, ResultOfFun::any()} | {error, Reason::any()} | no_return()
</code></pre>
<br />

<a name="drop_index-3"></a>

### drop_index/3 ###

<pre><code>
drop_index(Index::binary(), Collection::<a href="babel_index_collection.md#type-t">babel_index_collection:t()</a>, Opts::<a href="#type-opts">opts()</a>) -&gt; {ok, WorflowItemId::any()} | {scheduled, WorkRef::<a href="reliable_work_ref.md#type-t">reliable_work_ref:t()</a>, ResultOfFun::any()} | {error, Reason::any()} | no_return()
</code></pre>
<br />

Schedules the removal of the index with name `IndexName` from
collection `Collection` and all its index partitions from Riak KV.
In case the collection is itself being dropped by a parent workflow, the
collection will not be updated in Riak.

?> This function uses a workflow, see [`workflow/2`](#workflow-2) for an explanation
of the possible return values.

<a name="execute-3"></a>

### execute/3 ###

<pre><code>
execute(Poolname::atom(), Fun::fun((RiakConn::pid()) -&gt; Result::any()), Opts::<a href="#type-opts">opts()</a>) -&gt; {true, Result::any()} | {false, Reason::any()} | no_return()
</code></pre>
<br />

Executes a number of operations using the same Riak client connection
provided by riak_pool app.
`Poolname` must be an already started pool.

Options:

* timeout - time to get a connection from the pool

<a name="get-4"></a>

### get/4 ###

<pre><code>
get(TypedBucket::<a href="#type-bucket_and_type">bucket_and_type()</a>, Key::binary(), Spec::<a href="#type-type_spec">type_spec()</a>, Opts::<a href="#type-opts">opts()</a>) -&gt; {ok, Datatype::<a href="#type-datatype">datatype()</a>} | {error, Reason::term()}
</code></pre>
<br />

Retrieves a Riak Datatype (counter, set or map) from bucket type and
bucket `TypedBucket` and key `Key`. It uses type spec `Spec` to transform
the Riak Datatype into a Babel Datatype and if successful returns a [`babel_counter`](babel_counter.md), [`babel_set`](babel_set.md) or [`babel_map`](babel_map.md) respectively.

This function gets the riak client connection from the options `Opts` under
the key `connection` which can have the connection pid or a function object
returning a connection pid. This allows a lot of flexibility such as reusing
a given connection over several calls the babel function of using your own
connection pool and management.

In case the `connection` option does not provide a connection as explained
above, this function tries to use the `default` connection pool if it was
enabled through Babel's configuration options.

Returns `{error, not_found}` if the key is not on the server.

<a name="get_connection-1"></a>

### get_connection/1 ###

`get_connection(Opts) -> any()`

<a name="module-1"></a>

### module/1 ###

<pre><code>
module(Term::any()) -&gt; module() | undefined
</code></pre>
<br />

Returns the module associated with the type of term `Term`.

<a name="opts_to_riak_opts-1"></a>

### opts_to_riak_opts/1 ###

<pre><code>
opts_to_riak_opts(X1::map()) -&gt; list()
</code></pre>
<br />

<a name="put-5"></a>

### put/5 ###

<pre><code>
put(TypedBucket::<a href="#type-bucket_and_type">bucket_and_type()</a>, Key::binary(), Datatype::<a href="#type-datatype">datatype()</a>, Spec::<a href="#type-type_spec">type_spec()</a>, Opts::<a href="#type-opts">opts()</a>) -&gt; ok | {ok, Datatype::<a href="#type-datatype">datatype()</a>} | {ok, Key::binary(), Datatype::<a href="#type-datatype">datatype()</a>} | {scheduled, WorkflowId::{<a href="#type-bucket_and_type">bucket_and_type()</a>, <a href="#type-key">key()</a>}} | {error, Reason::term()}
</code></pre>
<br />

?> This function is workflow aware

<a name="rebuild_index-3"></a>

### rebuild_index/3 ###

<pre><code>
rebuild_index(Index::<a href="babel_index.md#type-t">babel_index:t()</a>, Collection::<a href="babel_index_collection.md#type-t">babel_index_collection:t()</a>, Opts::<a href="#type-riak_opts">riak_opts()</a>) -&gt; ok | no_return()
</code></pre>
<br />

<a name="status-1"></a>

### status/1 ###

<pre><code>
status(WorkRef::<a href="reliable_work_ref.md#type-t">reliable_work_ref:t()</a>) -&gt; {in_progress, Status::<a href="reliable_work.md#type-status">reliable_work:status()</a>} | {failed, Status::<a href="reliable_work.md#type-status">reliable_work:status()</a>} | {error, not_found | any()}
</code></pre>
<br />

Calls [`status/2`](#status-2).

<a name="status-2"></a>

### status/2 ###

<pre><code>
status(WorkRef::<a href="reliable_work_ref.md#type-t">reliable_work_ref:t()</a>, Timeout::timeout()) -&gt; {in_progress, Status::<a href="reliable_work.md#type-status">reliable_work:status()</a>} | {failed, Status::<a href="reliable_work.md#type-status">reliable_work:status()</a>} | {error, not_found | any()}
</code></pre>
<br />

Returns the status of a Reliable Work scheduled for execution.

!> **Important** notice that at the moment completed tasks are deleted, so
the abscense of a task is considered as either successful or failed, this
will change in the near future as we will be retaining tasks that are
discarded or completed.

<a name="type-1"></a>

### type/1 ###

<pre><code>
type(Term::term()) -&gt; set | map | counter | flag | register
</code></pre>
<br />

Returns the atom name for a babel datatype.

<a name="update_all_indices-3"></a>

### update_all_indices/3 ###

<pre><code>
update_all_indices(Actions::[<a href="babel_index.md#type-update_action">babel_index:update_action()</a>], Collection::<a href="babel_index_collection.md#type-t">babel_index_collection:t()</a>, RiakOpts::<a href="#type-opts">opts()</a>) -&gt; {ok, WorflowItemId::any()} | {scheduled, WorkRef::<a href="reliable_work_ref.md#type-t">reliable_work_ref:t()</a>, ResultOfFun::any()} | {error, Reason::any()} | no_return()
</code></pre>
<br />

Updates all the indices in the collection that are affected by he
provided Actions and schedules the update of the relevant index partitions
in the database i.e. persisting the index changes.

An index in collection `Collection` will always be affectd in case the
action is either `{insert, Data}` or
`{delete, Data}` or when the action is `{udpate, Old, New}` and the option
`force` was set to `true` or when `New` is not a babel map.

In case option object `New` is a babel map, and the option `force` is missing
or set to `false`, an index will be affected by an update action only if the
index's distinguished key paths have been updated or removed in the object
`New` (See [`babel_index:distinguished_key_paths/1`](babel_index.md#distinguished_key_paths-1))

?> This function uses a workflow, see [`workflow/2`](#workflow-2) for an explanation
of the possible return values.

<a name="update_indices-4"></a>

### update_indices/4 ###

<pre><code>
update_indices(Actions::[<a href="babel_index.md#type-update_action">babel_index:update_action()</a>], IndexNames::[binary()], Collection::<a href="babel_index_collection.md#type-t">babel_index_collection:t()</a>, Opts::<a href="#type-opts">opts()</a>) -&gt; {ok, WorflowItemId::any()} | {scheduled, WorkRef::<a href="reliable_work_ref.md#type-t">reliable_work_ref:t()</a>, ResultOfFun::any()} | {error, Reason::any()} | no_return()
</code></pre>
<br />

Updates all the indices in the collection with the provided Actions and
schedules the update of the relevant index partitions in the database i.e.
persisting the index changes.

?> This function uses a workflow, see [`workflow/2`](#workflow-2) for an explanation
of the possible return values.

<a name="validate_opts-1"></a>

### validate_opts/1 ###

<pre><code>
validate_opts(Opts::map()) -&gt; <a href="#type-maybe_no_return">maybe_no_return</a>(map())
</code></pre>
<br />

Validates the opts

<a name="validate_opts-2"></a>

### validate_opts/2 ###

<pre><code>
validate_opts(Opts::map(), Mode::strict | relaxed) -&gt; <a href="#type-maybe_no_return">maybe_no_return</a>(map())
</code></pre>
<br />

Validates the opts

<a name="workflow-1"></a>

### workflow/1 ###

<pre><code>
workflow(Fun::fun(() -&gt; any())) -&gt; {ok, ResultOfFun::any()} | {scheduled, WorkRef::<a href="reliable_work_ref.md#type-t">reliable_work_ref:t()</a>, ResultOfFun::any()} | {error, Reason::any()} | no_return()
</code></pre>
<br />

Equivalent to calling [`workflow/2`](#workflow-2) with and empty map passed as
the `Opts` argument.

> Notice subscriptions are not working at the moment
> See [`yield/2`](#yield-2) to track progress.

<a name="workflow-2"></a>

### workflow/2 ###

<pre><code>
workflow(Fun::fun(() -&gt; any()), Opts::<a href="babel_workflow.md#type-opts">babel_workflow:opts()</a>) -&gt; {ok, ResultOfFun::any()} | {scheduled, WorkRef::<a href="reliable_work_ref.md#type-t">reliable_work_ref:t()</a>, ResultOfFun::any()} | {error, Reason::any()} | no_return()
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

```erlang

  babel:workflow(fun() ->
   CollectionX0 = babel_index_collection:new(<<"foo">>, <<"bar">>),
   CollectionY0 = babel_index_collection:fetch(Conn, <<"foo">>, <<"users">>),
   IndexA = babel_index:new(ConfigA),
   IndexB = babel_index:new(ConfigB),
   _CollectionX1 = babel:create_index(IndexA, CollectionX0),
   _CollectionY1 = babel:create_index(IndexB, CollectionY0),
   ok
  end).
```

The resulting workflow execution will schedule the writes and deletes in the
order defined by the dependency graph constructed using the results
of this module functions. This ensures partitions are created first and then
collections.

The `Opts` argument offers the following options:

* `on_terminate` – a functional object `fun((Reason :: any()) -> ok)`. This
function will be evaluated before the call terminates. In case of succesful
termination the value `normal` will be  passed as argument. Otherwise, in
case of error, the error reason will be passed as argument. This allows you
to perform a cleanup after the workflow execution e.g. returning a riak
connection object to a pool. Notice that this function might be called
multiple times in the case of nested workflows. If you need to conditionally
perform a cleanup operation you might use the function `is_nested_worflow/0`
to take a decision.

!> **Important** notice subscriptions are not working at the moment

?> **Tip** See [`yield/2`](#yield-2) to track progress.

<a name="yield-1"></a>

### yield/1 ###

<pre><code>
yield(WorkRef::<a href="/Volumes/Work/Leapsight/babel/_build/default/lib/reliable/doc/reliable_worker.md#type-work_ref">reliable_worker:work_ref()</a>) -&gt; {ok, Payload::any()} | timeout
</code></pre>
<br />

Returns the value associated with the key `event_payload` when used as
option from a previous [`enqueue/2`](#enqueue-2). The calling process is suspended
until the work is completed or

!> **Important** notice the current implementation is not ideal as it
recursively reads the status from the database. So do not abuse it. Also at
the moment completed tasks are deleted, so the abscense of a task is
considered as either successful or failed, this will also change as we will
be retaining tasks that are discarded or completed.
This will be replaced by a pubsub version soon.

<a name="yield-2"></a>

### yield/2 ###

<pre><code>
yield(WorkRef::<a href="/Volumes/Work/Leapsight/babel/_build/default/lib/reliable/doc/reliable_worker.md#type-work_ref">reliable_worker:work_ref()</a>, Timeout::timeout()) -&gt; {ok, Payload::any()} | timeout
</code></pre>
<br />

Returns the value associated with the key `event_payload` when used as
option from a previous [`enqueue/2`](#enqueue-2) or `timeout` when `Timeout`
milliseconds has elapsed.

!> **Important** notice The current implementation is not ideal as it
recursively reads the status from the database. So do not abuse it. Also at
the moment complete tasks are deleted, so the abscense of a task is
considered as either succesful or failed, this will also change as we will
be retaining tasks that are discarded or completed.
This will be replaced by a pubsub version soon.

