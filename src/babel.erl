%% -----------------------------------------------------------------------------
%% @doc
%% @end
%% -----------------------------------------------------------------------------
-module(babel).
-include_lib("kernel/include/logger.hrl").


-define(WORKFLOW_ID, babel_workflow_id).
-define(WORKFLOW_COUNT, babel_workflow_count).
-define(WORKFLOW_GRAPH, babel_digraph).


-type context()     ::  map().
-type work_item()   ::  reliable_storage_backend:work_item().

-type opts()        ::  #{
    on_terminate => fun((Reason :: any()) -> any())
}.

-export_type([context/0]).
-export_type([work_item/0]).
-export_type([opts/0]).


-export([abort/1]).
-export([add_index/2]).
-export([create_collection/2]).
-export([create_index/2]).
-export([delete_index/2]).
-export([is_in_workflow/0]).
-export([rebuild_index/4]).
-export([remove_index/2]).
-export([update_indices/3]).
-export([workflow/1]).
-export([workflow/2]).



%% =============================================================================
%% API
%% =============================================================================



%% -----------------------------------------------------------------------------
%% @doc Returns true if the process has a workflow context.
%% @end
%% -----------------------------------------------------------------------------
-spec is_in_workflow() -> boolean().

is_in_workflow() ->
    get(?WORKFLOW_ID) =/= undefined.


%% -----------------------------------------------------------------------------
%% @doc When called within the functional object in {@link workflow/1},
%% makes the workflow silently return the tuple {aborted, Reason} as the
%% error reason.
%%
%% Termination of a Babel workflow means that an exception is thrown to an
%% enclosing catch. Thus, the expression `catch babel:abort(foo)' does not
%% terminate the workflow.
%% @end
%% -----------------------------------------------------------------------------
-spec abort(Reason :: any()) -> no_return().

abort(Reason) ->
    throw({aborted, Reason}).



%% -----------------------------------------------------------------------------
%% @doc Equivalent to calling {@link workflow/2} with and empty list passed as
%% the `Opts' argument.
%% @end
%% -----------------------------------------------------------------------------
-spec workflow(Fun :: fun(() -> any())) ->
    {ok, Id :: binary()} | {error, any()}.

workflow(Fun) ->
    workflow(Fun, []).


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
%% ```
%% > babel:workflow(
%%     fun() ->
%%          CollectionX0 = babel_index_collection:new(<<"foo">>, <<"bar">>),
%%          CollectionY0 = babel_index_collection:fetch(
%% Conn, <<"foo">>, <<"users">>),
%%          IndexA = babel_index:new(ConfigA),
%%          IndexB = babel_index:new(ConfigB),
%%          ok = babel:create_index(IndexA, CollectionX0),
%%          ok = babel:create_index(IndexB, CollectionY0),
%%          ok
%%     end).
%% > {ok, <<"00005mrhDMaWqo4SSFQ9zSScnsS">>, ok}
%% '''
%%
%% The resulting workflow execution will schedule the writes in the order that
%% results from the dependency graph constructed using the results of this
%% module functions. This ensures partitions are created first and then
%% collections.
%%
%% The `Opts' argument offers the following options:
%%
%% * `on_terminate` – a functional object `fun((Reason :: any()) -> ok)'. This
%% function will be evaluated before the call terminates. In case of succesful
%% termination the value `normal' is passed as argument. Otherwise, in case of
%% error, the error reason will be passed as argument. This allows you to
%% perform a cleanup after the workflow execution e.g. returning a riak
%% connection object to a pool.
%%
%% @end
%% -----------------------------------------------------------------------------
-spec workflow(Fun ::fun(() -> any()), Opts :: opts()) ->
    {ok, WorkId :: binary(), ResultOfFun :: any()}
    | {error, Reason :: any()}
    | no_return().

workflow(Fun, Opts) ->
    {ok, WorkId} = init_workflow(Opts),
    try
        %% Fun should use this module functions which are workflow aware.
        Result = Fun(),
        ok = maybe_schedule_workflow(),
        ok = on_terminate(normal, Opts),
        {ok, WorkId, Result}
    catch
        throw:Reason:Stacktrace ->
            ?LOG_ERROR(#{
                message => "Error while executing workflow",
                reason => Reason,
                stacktrace => Stacktrace
            }),
            ok = on_terminate(Reason, Opts),
            maybe_throw(Reason);
        _:Reason:Stacktrace ->
            %% A user exception, we need to raise it again up the
            %% nested transation stack and out
            ?LOG_ERROR(#{
                message => "Error while executing workflow",
                reason => Reason,
                stacktrace => Stacktrace
            }),
            ok = on_terminate(Reason, Opts),
            error(Reason)
    after
        ok = maybe_cleanup()
    end.



%% -----------------------------------------------------------------------------
%% @doc Schedules the creation of an index collection using Reliable.
%% Fails if the collection already existed
%% > This function needs to be called within a workflow functional object,
%% see {@link workflow/1}.
%%
%% @end
%% -----------------------------------------------------------------------------
-spec create_collection(BucketPrefix :: binary(), Name :: binary()) ->
    babel_index_collection:t() | no_return().

create_collection(BucketPrefix, Name) ->

    ok = ensure_in_workflow(),

    Collection = babel_index_collection:new(BucketPrefix, Name, []),
    CollectionId = {collection, babel_index_collection:id(Collection)},

    %% We need to avoid the situation were we create a collection we
    %% have previously initialised in the workflow graph
    ok = maybe_already_exists(CollectionId),

    WorkItem = babel_index_collection:to_work_item(Collection),
    ok = add_workflow_items([{CollectionId, WorkItem}]),

    Collection.


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
%% > {ok, <<"00005mrhDMaWqo4SSFQ9zSScnsS">>}
%% '''
%%
%% @end
%% -----------------------------------------------------------------------------
-spec create_index(
    Index :: babel_index:t(), Collection :: babel_index_collection:t()) ->
    ok | no_return().

create_index(Index, Collection) ->
    ok = ensure_in_workflow(),

    Partitions = babel_index:create_partitions(Index),

    PartitionItems = [
        {
            {partition, babel_index_partition:id(P)},
            babel_index:to_work_item(Index, P)
        } || P <- Partitions
    ],

    NewCollection = babel_index_collection:add_index(Index, Collection),
    CollectionId = {collection, babel_index_collection:id(NewCollection)},
    WorkItem = babel_index_collection:to_work_item(NewCollection),

    ok = add_workflow_items([{CollectionId, WorkItem} | PartitionItems]),

    %% Index partitions write will be scheduled prior to the collection write
    %% so we know that if in a subsequent read of the collection, the index is
    %% present it means its partitions have been already written to Riak.
    ok = add_workflow_precedence(
        [Id || {Id, _} <- PartitionItems], CollectionId
    ),

    ok.



%% -----------------------------------------------------------------------------
%% @doc Adds
%% @end
%% -----------------------------------------------------------------------------
-spec add_index(
    Index :: babel_index:t(),
    Collection :: babel_index_collection:t()) ->
    babel_index_collection:t() | no_return().

add_index(Index, Collection0) ->
    Collection = babel_index_collection:add_index(Index, Collection0),
    CollectionId = {collection, babel_index_collection:id(Collection)},
    WorkItem = babel_index_collection:to_work_item(Collection),
    IndexId = {index, babel_index:id(Index)},

    ok = add_workflow_items([{CollectionId, WorkItem}]),
    ok = add_workflow_precedence([IndexId], CollectionId),

    Collection.


%% -----------------------------------------------------------------------------
%% @doc Removes an index at identifier `IndexId' from collection `Collection'.
%% @end
%% -----------------------------------------------------------------------------
-spec remove_index(
    IndexId :: binary(),
    Collection :: babel_index_collection:t()) ->
    babel_index_collection:t() | no_return().

remove_index(IndexId, Collection0) ->
    Collection = babel_index_collection:delete_index(IndexId, Collection0),
    CollectionId = {collection, babel_index_collection:id(Collection)},
    WorkItem = babel_index_collection:to_work_item(Collection),

    ok = add_workflow_items([{CollectionId, WorkItem}]),

    Collection.


%% -----------------------------------------------------------------------------
%% @doc
%% @end
%% -----------------------------------------------------------------------------
-spec rebuild_index(
    Index :: babel_index:t(),
    BucketType :: binary(),
    Bucket :: binary(),
    Opts :: map()) -> ok | no_return().

rebuild_index(_Index, _BucketType, _Bucket, _Opts) ->
    %% TODO call the manager
    ok.


%% -----------------------------------------------------------------------------
%% @doc
%% @end
%% -----------------------------------------------------------------------------
-spec update_indices(
    Object :: key_value:t(),
    Collection :: babel_index_collection:t(),
    Opts :: map()) ->
    ok | no_return().

update_indices(_Object, _Collection, _Opts) ->
    %% TODO
    ok.


%% -----------------------------------------------------------------------------
%% @doc
%% @end
%% -----------------------------------------------------------------------------
-spec delete_index(
    Index :: babel_index:t(), Collection :: babel_index_collection:t()) ->
    ok | no_return().

delete_index(_Index, _Collection) ->
    %% TODO
    ok.



%% =============================================================================
%% PRIVATE
%% =============================================================================



%% -----------------------------------------------------------------------------
%% @private
%% @doc
%% @end
%% -----------------------------------------------------------------------------
init_workflow(_Opts) ->
    case get(?WORKFLOW_ID) of
        undefined ->
            %% We are initiating a new workflow
            %% We store the worflow state in the process dictionary
            Id = ksuid:gen_id(millisecond),
            undefined = put(?WORKFLOW_ID, Id),
            undefined = put(?WORKFLOW_COUNT, 1),
            undefined = put(?WORKFLOW_GRAPH, babel_digraph:new()),
            {ok, Id};
        Id ->
            %% This is a nested call, we are joining an existing workflow
            ok = increment_nested_count(),
            {ok, Id}
    end.


%% -----------------------------------------------------------------------------
%% @private
%% @doc
%% @end
%% -----------------------------------------------------------------------------
increment_nested_count() ->
    N = get(?WORKFLOW_COUNT),
    N = put(?WORKFLOW_COUNT, N + 1),
    ok.


%% -----------------------------------------------------------------------------
%% @private
%% @doc
%% @end
%% -----------------------------------------------------------------------------
is_nested_workflow() ->
    get(?WORKFLOW_COUNT) > 1.


%% -----------------------------------------------------------------------------
%% @private
%% @doc
%% @end
%% -----------------------------------------------------------------------------
decrement_nested_count() ->
    N = get(?WORKFLOW_COUNT),
    N = put(?WORKFLOW_COUNT, N - 1),
    ok.


%% -----------------------------------------------------------------------------
%% @private
%% @doc Adds an
%% @end
%% -----------------------------------------------------------------------------
add_workflow_items(L) ->
    G = get(?WORKFLOW_GRAPH),
    {Ids, WorkItems} = lists:unzip(L),
    _ = put(?WORKFLOW_GRAPH, babel_digraph:add_vertices(G, Ids, WorkItems)),
    ok.


%% -----------------------------------------------------------------------------
%% @private
%% @doc
%% @end
%% -----------------------------------------------------------------------------
add_workflow_precedence(L, B) when is_list(L) ->
    G0 = get(?WORKFLOW_GRAPH),
    G1 = lists:foldl(
        fun(A, G) -> babel_digraph:add_edge(G, A, B) end,
        G0,
        L
    ),
    _ = put(?WORKFLOW_GRAPH, G1),
    ok.


%% -----------------------------------------------------------------------------
%% @private
%% @doc
%% @end
%% -----------------------------------------------------------------------------
maybe_already_exists(Id) ->
    case babel_digraph:vertex(get(?WORKFLOW_GRAPH), Id) of
        {Id, _} ->
            throw(already_exists);
        false ->
            ok
    end.


%% -----------------------------------------------------------------------------
%% @private
%% @doc
%% @end
%% -----------------------------------------------------------------------------
maybe_schedule_workflow() ->
    case is_nested_workflow() of
        true ->
            ok;
        false ->
            schedule_workflow()
    end.


%% -----------------------------------------------------------------------------
%% @private
%% @doc
%% @end
%% -----------------------------------------------------------------------------
schedule_workflow() ->
    case prepare_work() of
        {ok, Work} ->
            reliable:enqueue(get(?WORKFLOW_ID), Work);
        {error, _} = Error ->
            Error
    end.


%% -----------------------------------------------------------------------------
%% @private
%% @doc
%% @end
%% -----------------------------------------------------------------------------
prepare_work() ->
    G = get(?WORKFLOW_GRAPH),
    case babel_digraph:topsort(G) of
        false ->
            {error, no_work};
        Vertices ->
            prepare_work(Vertices, G, 1, [])
    end.


%% -----------------------------------------------------------------------------
%% @private
%% @doc
%% @end
%% -----------------------------------------------------------------------------
prepare_work([], _, _, Acc) ->
    {ok, lists:reverse(Acc)};

prepare_work([{_, _} = H|T], G, N, Acc) ->
    {H, Work} = babel_digraph:vertex(G, H),
    prepare_work(T, G, N + 1, [{N, Work}|Acc]).


%% -----------------------------------------------------------------------------
%% @private
%% @doc
%% @end
%% -----------------------------------------------------------------------------
maybe_cleanup() ->
    ok = decrement_nested_count(),
    case get(?WORKFLOW_COUNT) == 0 of
        true ->
            cleanup();
        false ->
            ok
    end.


%% -----------------------------------------------------------------------------
%% @private
%% @doc
%% @end
%% -----------------------------------------------------------------------------
cleanup() ->
    %% We cleanup the process dictionary
    _ = erase(?WORKFLOW_ID),
    _ = erase(?WORKFLOW_COUNT),
    _ = erase(?WORKFLOW_GRAPH),
    ok.


%% -----------------------------------------------------------------------------
%% @private
%% @doc
%% @end
%% -----------------------------------------------------------------------------
-spec maybe_throw(Reason :: any()) -> no_return() | {error, any()}.

maybe_throw(Reason) ->
    case is_nested_workflow() of
        true ->
            throw(Reason);
        false ->
            {error, Reason}
    end.


%% -----------------------------------------------------------------------------
%% @private
%% @doc
%% @end
%% -----------------------------------------------------------------------------
-spec ensure_in_workflow() -> ok | no_return().

ensure_in_workflow() ->
    is_in_workflow() orelse error(no_workflow),
    ok.


%% -----------------------------------------------------------------------------
%% @private
%% @doc
%% @end
%% -----------------------------------------------------------------------------
on_terminate(Reason, #{on_terminate := Fun}) when is_function(Fun, 0) ->
    _ = Fun(Reason),
    ok;

on_terminate(_, _) ->
    ok.
