%% -----------------------------------------------------------------------------
%% @doc
%% @end
%% -----------------------------------------------------------------------------
-module(babel).
-include_lib("kernel/include/logger.hrl").


-define(WORKFLOW_ID, babel_workflow_id).
-define(WORKFLOW_LEVEL, babel_workflow_count).
-define(WORKFLOW_GRAPH, babel_digraph).


-type opts()            ::  #{
    on_terminate => fun((Reason :: any()) -> any())
}.

-type work_item()       ::  reliable_storage_backend:work_item()
                            | fun(() -> reliable_storage_backend:work_item()).

-type workflow_item_id()    ::  term().
-type workflow_item()   ::  {
                                Id :: workflow_item_id(),
                                {update | delete, work_item()}
                            }.

-export_type([work_item/0]).
-export_type([workflow_item_id/0]).
-export_type([workflow_item/0]).
-export_type([opts/0]).


%% -export([add_index/2]).
%% -export([remove_index/2]).
-export([abort/1]).
-export([add_workflow_items/1]).
-export([add_workflow_precedence/2]).
-export([create_collection/2]).
-export([create_index/2]).
-export([delete_collection/1]).
-export([delete_index/2]).
-export([is_in_workflow/0]).
-export([rebuild_index/4]).
-export([update_indices/3]).
-export([workflow/1]).
-export([workflow/2]).
-export([workflow_id/0]).
-export([workflow_nesting_level/0]).
-export([get_workflow_item/1]).
-export([find_workflow_item/1]).


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
%% @doc Returns the current worflow nesting level.
%% @end
%% -----------------------------------------------------------------------------
-spec workflow_nesting_level() -> pos_integer().

workflow_nesting_level() ->
    get(?WORKFLOW_LEVEL).


%% -----------------------------------------------------------------------------
%% @doc Returns the workflow identifier or undefined not currently within a
%% workflow.
%% @end
%% -----------------------------------------------------------------------------
-spec workflow_id() -> binary() | undefined.

workflow_id() ->
    get(?WORKFLOW_ID).


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
%% @doc Equivalent to calling {@link workflow/2} with and empty map passed as
%% the `Opts' argument.
%% @end
%% -----------------------------------------------------------------------------
-spec workflow(Fun :: fun(() -> any())) ->
    {ok, Id :: binary()} | {error, any()}.

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
%% @doc
%% @end
%% -----------------------------------------------------------------------------
-spec add_workflow_items([workflow_item()]) -> ok.

add_workflow_items(L) ->
    G = get(?WORKFLOW_GRAPH),
    {Ids, WorkItem} = lists:unzip(L),
    _ = put(?WORKFLOW_GRAPH, babel_digraph:add_vertices(G, Ids, WorkItem)),
    ok.


%% -----------------------------------------------------------------------------
%% @doc
%% @end
%% -----------------------------------------------------------------------------
-spec add_workflow_precedence(
    As :: workflow_item_id() | [workflow_item_id()],
    Bs :: workflow_item_id() | [workflow_item_id()]) -> ok.

add_workflow_precedence(As, Bs) when is_list(As) andalso is_list(Bs) ->
    G0 = get(?WORKFLOW_GRAPH),
    Comb = [{A, B} || A <- As, B <- Bs],
    G1 = lists:foldl(
        fun({A, B}, G) -> babel_digraph:add_edge(G, A, B) end,
        G0,
        Comb
    ),
    _ = put(?WORKFLOW_GRAPH, G1),
    ok;

add_workflow_precedence(As, B) when is_list(As) ->
    add_workflow_precedence(As, [B]);

add_workflow_precedence(A, Bs) when is_list(Bs) ->
    add_workflow_precedence([A], Bs);

add_workflow_precedence(A, B) ->
    add_workflow_precedence([A], [B]).


%% -----------------------------------------------------------------------------
%% @doc
%% @end
%% -----------------------------------------------------------------------------
- spec get_workflow_item(workflow_item_id()) ->
    workflow_item() | no_return().

get_workflow_item(Id) ->
    case babel_digraph:vertex(get(?WORKFLOW_GRAPH), Id) of
        {Id, _} = Item ->
            Item;
        false ->
            error(badkey)
    end.


%% -----------------------------------------------------------------------------
%% @doc
%% @end
%% -----------------------------------------------------------------------------
-spec find_workflow_item(workflow_item_id()) ->
    {ok, workflow_item()} | error.

find_workflow_item(Id) ->
    case babel_digraph:vertex(get(?WORKFLOW_GRAPH), Id) of
        {Id, _} = Item ->
            {ok, Item};
        false ->
            error
    end.


%% -----------------------------------------------------------------------------
%% @doc Schedules the creation of an index collection using Reliable.
%% Fails if the collection already existed
%%
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
    CollectionId = babel_index_collection:id(Collection),

    %% We need to avoid the situation were we create a collection we
    %% have previously initialised in the workflow graph
    ok = maybe_already_exists(CollectionId),

    WorkItem = fun() -> babel_index_collection:to_update_item(Collection) end,
    WorkflowItem = {CollectionId, {update, WorkItem}},
    ok = add_workflow_items([WorkflowItem]),

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
    ok = ensure_in_workflow(),

    CollectionId = babel_index_collection:id(Collection),
    WorkItem = fun() -> babel_index_collection:to_delete_item(Collection) end,
    WorkflowItem = {CollectionId, {delete, WorkItem}},

    add_workflow_items([WorkflowItem]).


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

    CollectionId = babel_index_collection:id(Collection),

    %% It is an error add and index to a collection scheduled to be deleted
    ok = ensure_not_deleted(CollectionId),

    IndexName = babel_index:name(Index),

    case babel_index_collection:index(IndexName, Collection) of
        error ->
            Partitions = babel_index:create_partitions(Index),
            PartitionItems = [
                begin
                    WorkItem = fun() ->
                        babel_index:to_update_item(Index, P)
                    end,
                    %% We ensure the name of the partition is unique within the
                    %% workflow graph
                    Id = {CollectionId, IndexName, babel_index_partition:id(P)},
                    {Id, {update, WorkItem}}

                end || P <- Partitions
            ],

            NewCollection = babel_index_collection:add_index(Index, Collection),
            CollWorkItem = fun() ->
                babel_index_collection:to_update_item(NewCollection)
            end,
            CollWorkflowItem = {CollectionId, {update, CollWorkItem}},
            ok = add_workflow_items([CollWorkflowItem | PartitionItems]),

            %% Index partitions write will be scheduled prior to the collection
            %% write so that if the index is present in a subsequent read of
            %% the collection, it means its partitions have been already
            %% written to Riak.
            add_workflow_precedence(
                [Id || {Id, _} <- PartitionItems], CollectionId
            );
        _ ->
            %% The index already exists so we should not create its partitions
            %% to protect data already stored
            throw({already_exists, IndexName})
    end.



%% %% -----------------------------------------------------------------------------
%% %% @doc Adds
%% %% @end
%% %% -----------------------------------------------------------------------------
%% -spec add_index(
%%     Index :: babel_index:t(),
%%     Collection :: babel_index_collection:t()) ->
%%     babel_index_collection:t() | no_return().

%% add_index(Index, Collection0) ->
%%     Collection = babel_index_collection:add_index(Index, Collection0),
%%     CollectionId = babel_index_collection:id(Collection),
%%     WorkItem = babel_index_collection:to_update_item(Collection),
%%     IndexName = {index, babel_index:name(Index)},

%%     ok = add_workflow_items([{CollectionId, WorkItem}]),
%%     ok = add_workflow_precedence([IndexName], CollectionId),

%%     Collection.


%% %% -----------------------------------------------------------------------------
%% %% @doc Removes an index at identifier `IndexName' from collection `Collection'.
%% %% @end
%% %% -----------------------------------------------------------------------------
%% -spec remove_index(
%%     IndexName :: binary(),
%%     Collection :: babel_index_collection:t()) ->
%%     babel_index_collection:t() | no_return().

%% remove_index(IndexName, Collection0) ->
%%     Collection = babel_index_collection:delete_index(IndexName, Collection0),
%%     CollectionId = babel_index_collection:id(Collection),
%%     WorkItem = babel_index_collection:to_update_item(Collection),

%%     ok = add_workflow_items([{CollectionId, WorkItem}]),

%%     Collection.


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
    Collection :: babel_index_collection:t(),
    Object :: key_value:t(),
    Opts :: map()) ->
    ok | no_return().

update_indices(_Collection, _Object, _Opts) ->
    ok = ensure_in_workflow(),
    %% TODO
    ok.


%% -----------------------------------------------------------------------------
%% @doc
%% @end
%% -----------------------------------------------------------------------------
-spec delete_index(
    Index :: babel_index:t(), Collection0 :: babel_index_collection:t()) ->
    babel_index_collection:t() | no_return().

delete_index(Index, Collection0) ->
    IndexName = babel_index:name(Index),

    %% We validate the collection has this index
    Index = babel_index_collection:index(IndexName),
    Index =/= error orelse throw(not_found),

    Collection = babel_index_collection:remove_index(Index, Collection0),

    CollectionId = babel_index_collection:id(Collection),

    CollectionItem = {
        CollectionId,
        {
            update,
            fun() -> babel_index_collection:to_update_item(Collection) end
        }
    },

    PartitionItems = [
        {
            {CollectionId, IndexName, X},
            {
                delete,
                fun() -> babel_index:to_delete_item(Index, X) end
            }
        }
        || X <- babel_index:partition_identifiers(Index)
    ],

    ok = add_workflow_items([CollectionItem | PartitionItems]),

    %% We need to first remove the index from the collection so that no more
    %% entries are added to the partitions, then we need to remove the partition
    _ = [
        add_workflow_precedence([CollectionId], X)
        || {X, _} <- PartitionItems
    ],

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
            undefined = put(?WORKFLOW_LEVEL, 1),
            undefined = put(?WORKFLOW_GRAPH, babel_digraph:new()),
            {ok, Id};
        Id ->
            %% This is a nested call, we are joining an existing workflow
            ok = increment_nesting_level(),
            {ok, Id}
    end.


%% -----------------------------------------------------------------------------
%% @private
%% @doc
%% @end
%% -----------------------------------------------------------------------------
increment_nesting_level() ->
    N = get(?WORKFLOW_LEVEL),
    N = put(?WORKFLOW_LEVEL, N + 1),
    ok.


%% -----------------------------------------------------------------------------
%% @private
%% @doc
%% @end
%% -----------------------------------------------------------------------------
is_nested_workflow() ->
    get(?WORKFLOW_LEVEL) > 1.


%% -----------------------------------------------------------------------------
%% @private
%% @doc
%% @end
%% -----------------------------------------------------------------------------
decrement_nested_count() ->
    N = get(?WORKFLOW_LEVEL),
    N = put(?WORKFLOW_LEVEL, N - 1),
    ok.


%% -----------------------------------------------------------------------------
%% @private
%% @doc
%% @end
%% -----------------------------------------------------------------------------
maybe_already_exists(Id) ->
    case find_workflow_item(Id) of
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
    case babel_digraph:vertex(get(?WORKFLOW_GRAPH), Id) of
        {Id, {delete, _}} ->
            throw({scheduled_for_delete, Id});
        {Id, _} ->
            ok;
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

prepare_work([H|T], G, N, Acc) ->
    {_Id, {_, ItemOrFun}} = babel_digraph:vertex(G, H),
    Work = to_work_item(ItemOrFun),
    prepare_work(T, G, N + 1, [{N, Work}|Acc]).


%% -----------------------------------------------------------------------------
%% @private
%% @doc
%% @end
%% -----------------------------------------------------------------------------
to_work_item(Fun) when is_function(Fun, 0) ->
    Fun();

to_work_item(WorkItem) when tuple_size(WorkItem) == 4 ->
    WorkItem.



%% -----------------------------------------------------------------------------
%% @private
%% @doc
%% @end
%% -----------------------------------------------------------------------------
maybe_cleanup() ->
    ok = decrement_nested_count(),
    case get(?WORKFLOW_LEVEL) == 0 of
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
    _ = erase(?WORKFLOW_LEVEL),
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
