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


-export([add_index/2]).
% -export([delete_index/2]).
-export([remove_index/2]).
-export([create_collection/2]).
-export([create_index/1]).
-export([is_in_workflow/0]).
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
%%          CollectionX0 = create_collection(<<"foo">>, <<"bar">>),
%%          CollectionY0 = babel_index_collection:fetch(
%%              Conn, <<"foo">>, <<"users">>),
%%          IndexA = babel:create_index(ConfigA),
%%          IndexB = babel:create_index(ConfigB),
%%          CollectionX1 = babel:add_index(IndexA, CollectionX0),
%%          CollectionY1 = babel:add_index(IndexB, CollectionY0),
%%          ok
%%     end).
%% > {ok, <<"00005mrhDMaWqo4SSFQ9zSScnsS">>}
%% '''
%%
%% The resulting workflow execution will schedule the writes in the order that
%% results from the dependency graph constructed using the index partitions and
%% index resulting from the {@link create_index/1} call and the collection
%% resulting from the {@link create_collection/2} and @{@link add_index/2}.
%% This ensures partitions are created first and then collections. Notice that
%% indices are not persisted per se and need to be added to a collection, the
%% workflow will fail with a `{dangling, IndexId}' exception if that is the
%% case.
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
            ?LOG_ERROR(
                "Error while executing workflow; reason=~p, stacktrace=~p",
                [Reason, Stacktrace]
            ),
            ok = on_terminate(Reason, Opts),
            maybe_throw(Reason);
        _:Reason:Stacktrace ->
            %% A user exception, we need to raise it again up the
            %% nested transation stack and out
            ?LOG_ERROR(
                "Error while executing workflow; reason=~p, stacktrace=~p",
                [Reason, Stacktrace]
            ),
            ok = on_terminate(Reason, Opts),
            error(Reason)
    after
        ok = maybe_cleanup()
    end.



%% -----------------------------------------------------------------------------
%% @doc Schedules the creation of an index and its partitions according to
%% `Config'.
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
%%          Index = babel:create_index(Config),
%%          _Collection1 = babel:add_index(Index, Collection0),
%%          ok
%%     end).
%% > {ok, <<"00005mrhDMaWqo4SSFQ9zSScnsS">>}
%% '''
%%
%% @end
%% -----------------------------------------------------------------------------
-spec create_index(Config :: map()) -> babel_index:t() | no_return().

create_index(Config) ->
    ok = ensure_in_workflow(),

    Index = babel_index:new(Config),
    IndexId = babel_index:id(Index),
    Partitions = babel_index:create_partitions(Index),

    PartitionItems = [
        {
            {partition, babel_index_partition:id(P)},
            babel_index:to_work_item(Index, P)
        } || P <- Partitions
    ],

    ok = add_workflow_items([{{index, IndexId}, undefined} | PartitionItems]),
    ok = add_workflow_precedence(
        [Id || {Id, _} <- PartitionItems],
        {index, IndexId}
    ),

    Index.


%% -----------------------------------------------------------------------------
%% @doc Schedules the creation of an index collection.
%% @end
%% -----------------------------------------------------------------------------
-spec create_collection(BucketPrefix :: binary(), Name :: binary()) ->
    babel_index_collection:t() | no_return().

create_collection(BucketPrefix, Name) ->
    Collection = babel_index_collection:new(BucketPrefix, Name, []),
    CollectionId = babel_index_collection:id(Collection),
    WorkItem = babel_index_collection:to_work_item(Collection),
    ok = add_workflow_items([{{collection, CollectionId}, WorkItem}]),
    Collection.


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
%% @doc
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
    {ok, Acc};

prepare_work([{index, Id} = H|T], G, N, Acc) ->
    case babel_digraph:out_neighbours(G, H) of
        [] ->
            %% Index has to be added to a collection
            throw({dangling_index, Id});
        _ ->
            prepare_work(T, G, N, Acc)
    end;

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
