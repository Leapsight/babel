-module(babel_reliable).
-include_lib("kernel/include/logger.hrl").


-define(WORKFLOW_ID, babel_workflow_id).
-define(WORKFLOW_LEVEL, babel_workflow_count).
-define(WORKFLOW_GRAPH, babel_digraph).
-define(BABEL_PARTITION_KEY, babel_partition_key).


-type opts()            ::  #{
    partition_key => binary(),
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


-export([abort/1]).
-export([add_workflow_items/1]).
-export([add_workflow_precedence/2]).
-export([is_in_workflow/0]).
-export([ensure_in_workflow/0]).
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
%% @private
%% @doc
%% @end
%% -----------------------------------------------------------------------------
-spec ensure_in_workflow() -> ok | no_return().

ensure_in_workflow() ->
    is_in_workflow() orelse error(no_workflow),
    ok.


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



%% =============================================================================
%% PRIVATE
%% =============================================================================



%% -----------------------------------------------------------------------------
%% @private
%% @doc
%% @end
%% -----------------------------------------------------------------------------
init_workflow(Opts) ->
    case get(?WORKFLOW_ID) of
        undefined ->
            %% We are initiating a new workflow
            %% We store the worflow state in the process dictionary
            Id = ksuid:gen_id(millisecond),
            undefined = put(?WORKFLOW_ID, Id),
            undefined = put(?WORKFLOW_LEVEL, 1),
            undefined = put(?WORKFLOW_GRAPH, babel_digraph:new()),
            undefined = put(
                ?BABEL_PARTITION_KEY,
                maps:get(partition_key, Opts, undefined)
            ),
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
    PartitionKey = get(?BABEL_PARTITION_KEY),

    case prepare_work() of
        {ok, Work} when PartitionKey == undefined ->
            reliable:enqueue(get(?WORKFLOW_ID), Work);
        {ok, Work} ->
            reliable:enqueue(get(?WORKFLOW_ID), Work, PartitionKey);
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

prepare_work([H|T], G, N0, Acc0) ->
    {_Id, {_, ItemOrFun}} = babel_digraph:vertex(G, H),
    {N1, Acc1} = case to_work_item(ItemOrFun) of
        undefined ->
            {N0, Acc0};
        Work ->
            {N0 + 1, [{N0, Work}|Acc0]}
    end,
    prepare_work(T, G, N1, Acc1).


%% -----------------------------------------------------------------------------
%% @private
%% @doc
%% @end
%% -----------------------------------------------------------------------------

to_work_item(undefined) ->
    undefined;

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
on_terminate(Reason, #{on_terminate := Fun}) when is_function(Fun, 0) ->
    _ = Fun(Reason),
    ok;

on_terminate(_, _) ->
    ok.
