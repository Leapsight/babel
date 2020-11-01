%% =============================================================================
%%  babel.erl -
%%
%%  Copyright (c) 2020 Leapsight Holdings Limited. All rights reserved.
%%
%%  Licensed under the Apache License, Version 2.0 (the "License");
%%  you may not use this file except in compliance with the License.
%%  You may obtain a copy of the License at
%%
%%     http://www.apache.org/licenses/LICENSE-2.0
%%
%%  Unless required by applicable law or agreed to in writing, software
%%  distributed under the License is distributed on an "AS IS" BASIS,
%%  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
%%  See the License for the specific language governing permissions and
%%  limitations under the License.
%% =============================================================================

%% -----------------------------------------------------------------------------
%% @doc This module acts as entry point for a number of Babel features and
%% provides some of the `riakc_pb_socket' module functions adapted for babel
%% datatypes.
%% @end
%% -----------------------------------------------------------------------------
-module(babel).
-include("babel.hrl").
-include_lib("kernel/include/logger.hrl").


-type datatype()        ::  babel_map:t() | babel_set:t().
-type type_spec()       ::  babel_map:type_spec() | babel_set:type_spec().
-type riak_op()         ::  riakc_datatype:update(term()).

-export_type([datatype/0]).
-export_type([riak_op/0]).

-export([create_collection/2]).
-export([create_index/2]).
-export([delete_collection/1]).
-export([delete_index/2]).
-export([rebuild_index/4]).
-export([update_indices/3]).
-export([workflow/1]).
-export([workflow/2]).
-export([validate_riak_opts/1]).
-export([get_connection/1]).
-export([execute/2]).
-export([execute/1]).
-export([put/5]).
-export([delete/3]).
-export([get/4]).
-export([type/1]).
-export([module/1]).


%% =============================================================================
%% API
%% =============================================================================


%% -----------------------------------------------------------------------------
%% @doc
%% @end
%% -----------------------------------------------------------------------------
-spec type(term()) -> set | map | counter | flag | register.

type(Term) ->
    case module(Term) of
        undefined -> register;
        Mod -> Mod:type()
    end.


%% -----------------------------------------------------------------------------
%% @doc
%% @end
%% -----------------------------------------------------------------------------
-spec module(Term :: any()) -> module() | undefined.

module(Term) when is_tuple(Term) ->
    Mods = [babel_map, babel_set, babel_counter, babel_flag],
    Fun = fun(Mod, Acc) ->
        case (catch Mod:is_type(Term)) of
            true ->
                throw({module, Mod});
            _ ->
                Acc
        end
    end,

    try
        lists:foldl(Fun, undefined, Mods)
    catch
        throw:{module, Mod} -> Mod
    end;

module(_) ->
    %% We do not have a wrapper module for registers
    undefined.



%% -----------------------------------------------------------------------------
%% @doc
%% @end
%% -----------------------------------------------------------------------------
-spec get(
    TypedBucket :: bucket_and_type(),
    Key :: binary(),
    Spec :: type_spec(),
    Opts :: map()) ->
    ok
    | {ok, Datatype :: datatype()}
    | {error, Reason :: term()}.

get(TypedBucket, Key, Spec, Opts0) ->
    Opts = validate_riak_opts(Opts0),
    Conn = get_connection(Opts),
    ReqOpts = babel_utils:opts_to_riak_opts(Opts),

    case riakc_pb_socket:fetch_type(Conn, TypedBucket, Key, ReqOpts) of
        {ok, Object} ->
            Type = riak_type(Object),
            {ok, to_babel_datatype(Type, Object, Spec)};
        {error, {notfound, _}} ->
            {error, not_found};
        {error, _} = Error ->
            Error
    end.


%% -----------------------------------------------------------------------------
%% @doc
%% > This function is workflow aware
%% @end
%% -----------------------------------------------------------------------------
-spec put(
    TypedBucket :: bucket_and_type(),
    Key :: binary(),
    Datatype :: datatype(),
    Spec :: type_spec(),
    Opts :: map()) ->
    ok
    | {ok, Datatype :: datatype()}
    | {ok, Key :: binary(), Datatype :: datatype()}
    | {scheduled, WorkflowId :: {bucket_and_type(), key()}}
    | {error, Reason :: term()}.

put(TypedBucket, Key, Datatype, Spec, Opts) ->
    case reliable:is_in_workflow() of
        false ->
            do_put(TypedBucket, Key, Datatype, Spec, Opts);
        true ->
            schedule_put(TypedBucket, Key, Datatype, Spec, Opts)
    end.


%% -----------------------------------------------------------------------------
%% @doc
%% > This function is workflow aware
%% @end
%% -----------------------------------------------------------------------------
-spec delete(
    TypedBucket :: bucket_and_type(), Key :: binary(), Opts :: map()) ->
    ok
    | {scheduled, WorkflowId :: {bucket_and_type(), key()}}
    | {error, Reason :: term()}.

delete(TypedBucket, Key, Opts) ->
    case reliable:is_in_workflow() of
        false ->
            do_delete(TypedBucket, Key, Opts);
        true ->
            schedule_delete(TypedBucket, Key, Opts)
    end.


%% -----------------------------------------------------------------------------
%% @doc
%% @end
%% -----------------------------------------------------------------------------
-spec execute(Fun :: fun((RiakConn :: pid()) -> Result :: any())) ->
    {ok, Result :: any()} | {error, Reason :: any()}.

execute(Fun) ->
    execute(Fun, #{}).


%% -----------------------------------------------------------------------------
%% @doc Executes a number of operations using the same Riak cclient connection.
%% @end
%% -----------------------------------------------------------------------------
-spec execute(
    Fun :: fun((RiakConn :: pid()) -> Result :: any()),
    RiakOpts :: map()) ->
    {ok, Result :: any()} | {error, Reason :: any()}.

execute(Fun, #{connection := Pid} = Opts) when is_pid(Pid) ->
    try
        Res = Fun(Pid),
        ok = on_execute(normal, Opts),
        Res
    catch
        _:Reason:Stacktrace ->
            ok = on_execute(Reason, Opts),
            error(Reason, Stacktrace)
    after
        ok
    end;

execute(Fun, #{connection := GetConn} = Opts) when is_function(GetConn) ->
    execute(Fun, Opts#{connection => GetConn()});

execute(_, #{connection := _}) ->
    error(badarg);

execute(Fun, Opts) ->
    %% TODO get connection from pool
    %% TODO use a timeout and fail elegantly
    Pid = undefined,
    Checkin = fun(_) -> ok end, %% TODO fun to return conn to pool
    execute(Fun, Opts#{connection => Pid, on_execute => Checkin}).


%% -----------------------------------------------------------------------------
%% @doc Equivalent to calling {@link workflow/2} with and empty map passed as
%% the `Opts' argument.
%% @end
%% -----------------------------------------------------------------------------
-spec workflow(Fun :: fun(() -> any())) ->
    {ok, ResultOfFun :: any()}
    | {scheduled, WorkRef :: reliable_work_ref:t(), ResultOfFun :: any()}
    | {error, Reason :: any()}
    | no_return().

workflow(Fun) ->
    workflow(Fun, #{}).


%% -----------------------------------------------------------------------------
%% @doc Executes the functional object `Fun' as a Reliable workflow, i.e.
%% ordering and scheduling all resulting Riak KV object writes.
%%
%% The code that executes inside the workflow should call one or more functions
%% in this module to schedule writes in Riak KV. For example, if you wanted to
%% schedule an index creation you should use {@link create_index/2} instead of
%% {@link babel_index_collection}, {@link babel_index} and {@link
%% babel_index_partition} functions directly.
%%
%% Any other operation, including reading and writing from/to Riak KV directly
%% or by using the API provided by other Babel modules will work as normal and
%% will not affect the workflow, only the special functions in this module will
%% add work items to the workflow.
%%
%% If something goes wrong inside the workflow as a result of a user
%% error or general exception, the entire workflow is terminated and the
%% function raises an exception. In case of an internal error, the function
%% returns the tuple `{error, Reason}'.
%%
%% If everything goes well, the function returns the triple
%% `{ok, WorkId, ResultOfFun}' where `WorkId' is the identifier for the
%% workflow schedule by Reliable and `ResultOfFun' is the value of the last
%% expression in `Fun'.
%%
%% > Notice that calling this function schedules the work to Reliable, you need
%% to use the WorkId to check with Reliable the status of the workflow
%% execution.
%%
%% Example: Creating various babel objects and scheduling
%%
%% ```erlang
%% > babel:workflow(
%%     fun() ->
%%          CollectionX0 = babel_index_collection:new(<<"foo">>, <<"bar">>),
%%          CollectionY0 = babel_index_collection:fetch(
%% Conn, <<"foo">>, <<"users">>),
%%          IndexA = babel_index:new(ConfigA),
%%          IndexB = babel_index:new(ConfigB),
%%          _CollectionX1 = babel:create_index(IndexA, CollectionX0),
%%          _CollextionY1 = babel:create_index(IndexB, CollectionY0),
%%          ok
%%     end).
%% > {scheduled, <<"00005mrhDMaWqo4SSFQ9zSScnsS">>, ok}
%% '''
%%
%% The resulting workflow execution will schedule the writes and deletes in the
%% order defined by the dependency graph constructed using the results
%% of this module functions. This ensures partitions are created first and then
%% collections.
%%
%% The `Opts' argument offers the following options:
%%
%% * `on_terminate` – a functional object `fun((Reason :: any()) -> ok)'. This
%% function will be evaluated before the call terminates. In case of succesful
%% termination the value `normal' will be  passed as argument. Otherwise, in
%% case of error, the error reason will be passed as argument. This allows you
%% to perform a cleanup after the workflow execution e.g. returning a riak
%% connection object to a pool. Notice that this function might be called
%% multiple times in the case of nested workflows. If you need to conditionally
%% perform a cleanup operation you might use the function `is_nested_worflow/0'
%% to take a decision.
%%
%% @end
%% -----------------------------------------------------------------------------
-spec workflow(Fun ::fun(() -> any()), Opts :: babel_workflow:opts()) ->
    {ok, ResultOfFun :: any()}
    | {scheduled, WorkRef :: reliable_work_ref:t(), ResultOfFun :: any()}
    | {error, Reason :: any()}
    | no_return().

workflow(Fun, Opts) ->
    reliable:workflow(Fun, Opts).


%% -----------------------------------------------------------------------------
%% @doc Schedules the creation of an empty index collection using Reliable.
%% Fails if the collection already exists.
%%
%% The collection will be stored in Riak KV under the bucket type configured
%% for the application option `index_collection_bucket_type', bucket name
%% resulting from concatenating the value of `BucketPrefix' to the suffix `/
%% index_collection' and the key will be the value of `Name'.
%%
%% > This function needs to be called within a workflow functional object,
%% see {@link workflow/1}.
%%
%% @end
%% -----------------------------------------------------------------------------
-spec create_collection(BucketPrefix :: binary(), Name :: binary()) ->
    babel_index_collection:t() | no_return().

create_collection(BucketPrefix, Name) ->
    ok = reliable:ensure_in_workflow(),

    Collection = babel_index_collection:new(BucketPrefix, Name),
    CollectionId = babel_index_collection:id(Collection),

    %% We need to avoid the situation were we create a collection we
    %% have previously initialised in the workflow graph
    ok = maybe_already_exists(CollectionId),

    Task = fun() -> babel_index_collection:to_update_task(Collection) end,
    WorkflowItem = {CollectionId, {update, Task}},
    ok = reliable:add_workflow_items([WorkflowItem]),

    Collection.


%% -----------------------------------------------------------------------------
%% @doc Schedules the delete of a collection, all its indices and their
%% partitions.
%%
%% @end
%% -----------------------------------------------------------------------------
-spec delete_collection(Collection :: babel_index_collection:t()) ->
    ok | no_return().

delete_collection(Collection) ->
    ok = reliable:ensure_in_workflow(),

    CollectionId = babel_index_collection:id(Collection),
    Task = fun() -> babel_index_collection:to_delete_task(Collection) end,
    WorkflowItem = {CollectionId, {delete, Task}},

    reliable:add_workflow_items([WorkflowItem]).


%% -----------------------------------------------------------------------------
%% @doc Schedules the creation of an index and its partitions according to
%% `Config' using Reliable.
%%
%% > This function needs to be called within a workflow functional object,
%% see {@link workflow/1}.
%%
%%
%% Example: Creating an index and adding it to an existing collection
%%
%% ```
%% > babel:workflow(
%%     fun() ->
%%          Collection0 = babel_index_collection:fetch(Conn, BucketPrefix, Key),
%%          Index = babel_index:new(Config),
%%          ok = babel:create_index(Index, Collection0),
%%          ok
%%     end).
%% > {scheduled, <<"00005mrhDMaWqo4SSFQ9zSScnsS">>, ok}
%% '''
%%
%% @end
%% -----------------------------------------------------------------------------
-spec create_index(
    Index :: babel_index:t(), Collection :: babel_index_collection:t()) ->
    babel_index_collection:t() | no_return().

create_index(Index, Collection) ->
    ok = reliable:ensure_in_workflow(),

    %% It is an error add and index to a collection scheduled to be deleted
    ok = ensure_not_deleted(babel_index_collection:id(Collection)),

    IndexName = babel_index:name(Index),

    try
        _ = babel_index_collection:index(IndexName, Collection),
        %% The index already exists so we should not create its partitions
        %% to protect data already stored
        throw({already_exists, IndexName})
    catch
        error:badindex ->
            do_create_index(Index, Collection)
    end.


%% -----------------------------------------------------------------------------
%% @doc Validates and returns the options in proplist format as expected by
%% Riak KV.
%% @end
%% -----------------------------------------------------------------------------
-spec validate_riak_opts(map()) -> maybe_no_return(map()).

validate_riak_opts(#{'$validated' := true} = Opts) ->
    Opts;

validate_riak_opts(Opts) ->
    Opts1 = maps_utils:validate(Opts, ?RIAK_OPTS_SPEC),
    Opts1#{'$validated' => true}.


%% -----------------------------------------------------------------------------
%% @doc
%% @end
%% -----------------------------------------------------------------------------
get_connection(#{connection := Conn}) when is_pid(Conn) ->
    Conn;

get_connection(#{connection := Get}) when is_function(Get, 0) ->
    Get().


%% -----------------------------------------------------------------------------
%% @doc
%% @end
%% -----------------------------------------------------------------------------
-spec rebuild_index(
    Index :: babel_index:t(),
    BucketType :: binary(),
    Bucket :: binary(),
    Opts :: riak_opts()) -> ok | no_return().

rebuild_index(_Index, _BucketType, _Bucket, _Opts) ->
    %% TODO call the manager
    ok.


%% -----------------------------------------------------------------------------
%% @doc
%% @end
%% -----------------------------------------------------------------------------
-spec update_indices(
    Actions :: [{babel_index:action(), babel_index:object()}],
    CollectionOrIndices :: babel_index_collection:t(),
    RiakOpts :: map()) ->
    ok | no_return().

update_indices(Actions, Collection, RiakOpts) when is_list(Actions) ->
    ok = reliable:ensure_in_workflow(),

    CollectionId = babel_index_collection:id(Collection),
    Indices = babel_index_collection:indices(Collection),
    ok = ensure_not_deleted(CollectionId),
    Opts = validate_riak_opts(RiakOpts),

    lists:foreach(
        fun(Index) ->
            Partitions = babel_index:update(Actions, Index, Opts),

            %% Tradeoff between memory intensive (lazy) or CPU
            %% intensive (eager) evaluation. We use eager here as we assume the
            %% user is smart enough to aggregate all operations for a
            %% collection and perform a single call to this function within a
            %% workflow.
            PartitionItems = partition_update_items(
                Collection, Index, Partitions, eager
            ),
            %% We have not modified the collection
            CollWorkflowItem = {CollectionId, undefined},

            ok = reliable:add_workflow_items(
                [CollWorkflowItem | PartitionItems]
            ),

            %% If there is an update on the collection we want it to occur
            %% before the partition updates
            reliable:add_workflow_precedence(
                CollectionId, [Id || {Id, _} <- PartitionItems]
            )
        end,
        Indices
    ).


%% -----------------------------------------------------------------------------
%% @doc
%% @end
%% -----------------------------------------------------------------------------
-spec delete_index(
    Index :: babel_index:t(), Collection0 :: babel_index_collection:t()) ->
    babel_index_collection:t().

delete_index(Index, Collection0) ->
    ok = reliable:ensure_in_workflow(),
    IndexName = babel_index:name(Index),

    try
        %% We validate the collection has this index
        Index = babel_index_collection:index(IndexName, Collection0),
        Collection = babel_index_collection:delete_index(Index, Collection0),
        CollectionId = babel_index_collection:id(Collection),
        CollectionItem = {
            CollectionId,
            {
                update,
                fun() -> babel_index_collection:to_update_task(Collection) end
            }
        },
        PartitionItems = [
            {
                {CollectionId, IndexName, X},
                {
                    delete,
                    fun() -> babel_index:to_delete_task(Index, X) end
                }
            }
            || X <- babel_index:partition_identifiers(Index)
        ],

        ok = reliable:add_workflow_items(
            [CollectionItem | PartitionItems]
        ),

        %% We need to first remove the index from the collection so that no more
        %% entries are added to the partitions, then we need to remove the partition
        _ = [
            reliable:add_workflow_precedence([CollectionId], X)
            || {X, _} <- PartitionItems
        ],

        Collection

    catch
        error:badindex ->
            Collection0
    end.




%% =============================================================================
%% PRIVATE
%% =============================================================================



%% @private
do_put(TypedBucket, Key, Datatype, Spec, Opts0) ->
    Opts = validate_riak_opts(Opts0),
    Conn = get_connection(Opts),
    RiakOpts = maps:to_list(Opts),
    Type = type(Datatype),
    Op = datatype_to_op(Type, Datatype, Spec),

    case riakc_pb_socket:update_type(Conn, TypedBucket, Key, Op, RiakOpts) of
        ok ->
            ok;
        {ok, Object} ->
            {ok, to_babel_datatype(Type, Object, Spec)};
        {ok, Key, Object} ->
            {ok, Key, to_babel_datatype(Type, Object, Spec)};
        {error, _Reason} = Error ->
            %% TODO Retries, deadlines, backoff, etc
            Error
    end.


%% @private
schedule_put(TypedBucket, Key, Datatype, Spec, _Opts0) ->
    ok = reliable:ensure_in_workflow(),
    Id = {TypedBucket, Key},
    Type = type(Datatype),
    Task = to_update_task(Type, TypedBucket, Key, Datatype, Spec),
    WorkflowItem = {Id, {update, Task}},
    ok = reliable:add_workflow_items([WorkflowItem]),
    {scheduled, Id}.


%% @private
do_delete(TypedBucket, Key, Opts0) ->
    Opts = validate_riak_opts(Opts0),
    Conn = get_connection(Opts),
    RiakOpts = babel_utils:opts_to_riak_opts(Opts),

    case riakc_pb_socket:delete(Conn, TypedBucket, Key, RiakOpts) of
        ok ->
            ok;
        {error, _Reason} = Error ->
            %% TODO Retries, deadlines, backoff, etc
            Error
    end.


%% @private
schedule_delete(TypedBucket, Key, _Opts0) ->
    ok = reliable:ensure_in_workflow(),
    Id = {TypedBucket, Key},
    Task = to_delete_task(TypedBucket, Key),
    WorkflowItem = {Id, {delete, Task}},
    ok = reliable:add_workflow_items([WorkflowItem]),
    {scheduled, Id}.


%% -----------------------------------------------------------------------------
%% @private
%% @doc
%% @end
%% -----------------------------------------------------------------------------
do_create_index(Index, Collection) ->
    CollectionId = babel_index_collection:id(Collection),
    Partitions = babel_index:create_partitions(Index),
    PartitionItems = partition_update_items(
        Collection, Index, Partitions, lazy
    ),

    NewCollection = babel_index_collection:add_index(Index, Collection),
    CollTask = fun() ->
        babel_index_collection:to_update_task(NewCollection)
    end,
    CollWorkflowItem = {CollectionId, {update, CollTask}},
    ok = reliable:add_workflow_items(
        [CollWorkflowItem | PartitionItems]
    ),

    %% Index partitions write will be scheduled prior to the collection
    %% write so that if the index is present in a subsequent read of
    %% the collection, it means its partitions have been already
    %% written to Riak.
    ok = reliable:add_workflow_precedence(
        [Id || {Id, _} <- PartitionItems], CollectionId
    ),

    NewCollection.


%% -----------------------------------------------------------------------------
%% @private
%% @doc
%% @end
%% -----------------------------------------------------------------------------
maybe_already_exists(Id) ->
    case reliable:find_workflow_item(Id) of
        {ok, _} ->
            throw({already_exists, Id});
        error ->
            ok
    end.


%% -----------------------------------------------------------------------------
%% @private
%% @doc
%% @end
%% -----------------------------------------------------------------------------
ensure_not_deleted(Id) ->
    case reliable:find_workflow_item(Id) of
        {ok, {Id, {delete, _}}} ->
            throw({scheduled_for_delete, Id});
        {ok, {Id, _}} ->
            ok;
        error ->
            ok
    end.


-spec partition_update_items(
    babel_index_collection:t(),
    babel_index:t(),
    [babel_index_partition:t()],
    Mode :: eager | lazy) ->
    [reliable:workflow_item()].

partition_update_items(Collection, Index, Partitions, Mode) ->
    [
        begin
            CollectionId = babel_index_collection:id(Collection),
            IndexName = babel_index:name(Index),
            %% We ensure the name of the partition is unique within the
            %% workflow graph
            Id = {CollectionId, IndexName, babel_index_partition:id(P)},

            Task = case Mode of
                eager ->
                    babel_index:to_update_task(Index, P);
                lazy ->
                    fun() -> babel_index:to_update_task(Index, P) end
            end,

            {Id, {update, Task}}

        end || P <- Partitions
    ].


%% @private
datatype_to_op(map, Datatype, Spec) ->
    babel_map:to_riak_op(Datatype, Spec);

datatype_to_op(set, Datatype, Spec) ->
    babel_set:to_riak_op(Datatype, Spec);

datatype_to_op(counter, _Datatype, _Spec) ->
    error(not_implemented);

datatype_to_op(flag, _Datatype, _Spec) ->
    error(not_implemented).


%% @private
to_babel_datatype(map, RiakDatatype, Spec) ->
    babel_map:from_riak_map(RiakDatatype, Spec);

to_babel_datatype(set, Datatype, Spec) ->
    babel_set:from_riak_set(Datatype, Spec);

to_babel_datatype(counter, _Datatype, _Spec) ->
    error(not_implemented);

to_babel_datatype(flag, _Datatype, _Spec) ->
    error(not_implemented).


%% @private
to_update_task(map, TypedBucket, Key, Datatype, Spec) ->
    Op = babel_map:to_riak_op(Datatype, Spec),
    to_update_task(TypedBucket, Key, Op);

to_update_task(set, TypedBucket, Key, Datatype, Spec) ->
    Op = babel_set:to_riak_op(Datatype, Spec),
    to_update_task(TypedBucket, Key, Op);

to_update_task(counter, _TypedBucket, _Key, _Datatype, _Spec) ->
    error(not_implemented);

to_update_task(flag, _TypedBucket, _Key, _Datatype, _Spec) ->
    error(not_implemented).


%% @private
to_update_task(TypedBucket, Key, Op) ->
    Args = [TypedBucket, Key, Op],
    reliable_task:new(
        node(), riakc_pb_socket, update_type, [{symbolic, riakc} | Args]
    ).


%% @private
to_delete_task(TypedBucket, Key) ->
    Args = [TypedBucket, Key],
    reliable_task:new(
        node(), riakc_pb_socket, delete, [{symbolic, riakc} | Args]
    ).


%% -----------------------------------------------------------------------------
%% @private
%% @doc
%% @end
%% -----------------------------------------------------------------------------
on_execute(Reason, #{on_execute := Fun}) when is_function(Fun, 1) ->
    _ = Fun(Reason),
    ok;

on_execute(_, _) ->
    ok.


%% @private
-spec riak_type(term()) -> set | map | counter | flag.

riak_type(Term) when is_tuple(Term) ->
    Mods = [riakc_set, riakc_map, riakc_counter, riakc_flag],
    Fun = fun(Mod, Acc) ->
        case (catch Mod:is_type(Term)) of
            true ->
                throw({type, Mod:type()});
            _ ->
                Acc
        end
    end,

    try
        error = lists:foldl(Fun, error, Mods),
        error(badarg)
    catch
        throw:{type, Mod} -> Mod
    end.