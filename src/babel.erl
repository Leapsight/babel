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
    on_error => fun((Reason :: any()) -> any())
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
%% @doc Executes the functional object `Fun' as a Reliable workflow.
%% The code that executes inside the workflow should call one or more functions
%% in this module to schedule work.
%%
%% If something goes wrong inside the workflow as a result of a user
%% error or general exception, the entire workflow is terminated and the
%% function returns the tuple `{error, Reason}'.
%%
%% If everything goes well the function returns the triple
%% `{ok, WorkId, ResultOfFun}' where `WorkId' is the identifier for the
%% workflow schedule by Reliable and `ResultOfFun' is the value of the last
%% expression in `Fun'.
%%
%% > Notice that calling this function schedules the work to Reliable, you need
%% to use the WorkId to check with Reliable the status of the workflow
%% execution.
%%
%% @end
%% -----------------------------------------------------------------------------
-spec workflow(Fun ::fun(() -> any()), Opts :: opts()) ->
    {ok, WorkId :: binary(), ResultOfFun :: any()}
    | {error, Reason :: any()}.

workflow(Fun, Opts) ->
    {ok, WorkId} = init_workflow(Opts),
    try
        %% Fun should use this module functions which are workflow aware.
        Result = Fun(),
        ok = maybe_schedule_workflow(),
        {ok, WorkId, Result}
    catch
        throw:Reason:Stacktrace ->
            ?LOG_ERROR(
                "Error while executing workflow; reason=~p, stacktrace=~p",
                [Reason, Stacktrace]
            ),
            ok = on_error(Reason, Opts),
            maybe_throw(Reason);
        _:Reason:Stacktrace ->
            %% A user exception, we need to raise it again up the
            %% nested transation stack and out
            ?LOG_ERROR(
                "Error while executing workflow; reason=~p, stacktrace=~p",
                [Reason, Stacktrace]
            ),
            ok = on_error(Reason, Opts),
            error(Reason)
    after
        ok = maybe_terminate_workflow()
    end.



%% -----------------------------------------------------------------------------
%% @doc Schedules the creation of an index and its partitions according to
%% `Config'.
%% > This function needs to be called within a workflow functional object,
%% see {@link workflow/1,2}.
%%
%% The index collection `Collection' has to exist in the database, otherwise it
%% fails with an exception, terminating the workflow. See {@link
%% create_collection/3} to create a collection within the same workflow
%% execution.
%%
%% Example: Creating an index and adding it to an existing collection
%%
%% ```erlang
%% > babel:workflow(
%%     fun() ->
%%          Collection = babel_index_collection:fetch(
%%              Conn, <<"foo">>, <<"users">>),
%%          _ = babel:create_index(Collection, Config),
%%          ok
%%     end).
%% > {ok, <<"00005mrhDMaWqo4SSFQ9zSScnsS">>}
%% '''
%%
%% Example: Creating an index and adding it to a newly created collection
%%
%% ```erlang
%% > babel:workflow(
%%      fun() ->
%%          Collection = babel:create_collection(<<"foo">>, <<"users">>),
%%          _ = babel:create_index(Collection, Config),
%%          ok
%%      end
%% ).
%% > {ok, <<"00005mrhDMaWqo4SSFQ9zSScnsS">>}
%% '''
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
    WorkId = get(?WORKFLOW_ID),
    G = get(?WORKFLOW_GRAPH),

    case babel_digraph:topsort(G) of
        false ->
            {error, no_work};
        Vertices ->
            Work = pack_work(Vertices, G),
            reliable:enqueue(WorkId, Work)
    end.


%% -----------------------------------------------------------------------------
%% @private
%% @doc
%% @end
%% -----------------------------------------------------------------------------
pack_work(Vertices, G) ->
    pack_work(Vertices, G, 1, []).


%% -----------------------------------------------------------------------------
%% @private
%% @doc
%% @end
%% -----------------------------------------------------------------------------
pack_work([], _, _, Acc) ->
    Acc;

pack_work([{index, _} = H|T], G, N, Acc) ->
    case babel_digraph:out_neighbours(G, H) of
        [] ->
            %% Index has to be added to a collection
            throw(dangling_index);
        _ ->
            pack_work(T, G, N, Acc)
    end;

pack_work([{_, _} = H|T], G, N, Acc) ->
    {H, Work} = babel_digraph:vertex(G, H),
    pack_work(T, G, N + 1, [{N, Work}|Acc]).



%% -----------------------------------------------------------------------------
%% @private
%% @doc
%% @end
%% -----------------------------------------------------------------------------
maybe_terminate_workflow() ->
    ok = decrement_nested_count(),
    case get(?WORKFLOW_COUNT) == 0 of
        true ->
            terminate_workflow();
        false ->
            ok
    end.


%% -----------------------------------------------------------------------------
%% @private
%% @doc
%% @end
%% -----------------------------------------------------------------------------
terminate_workflow() ->
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
on_error(Reason, #{on_error := Fun}) when is_function(Fun, 0) ->
    _ = Fun(Reason),
    ok;

on_error(_, _) ->
    ok.
