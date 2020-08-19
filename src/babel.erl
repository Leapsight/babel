%% -----------------------------------------------------------------------------
%% @doc
%% @end
%% -----------------------------------------------------------------------------
-module(babel).
-include_lib("kernel/include/logger.hrl").


-define(WORKFLOW_ID, babel_workflow_id).
-define(WORKFLOW_COUNT, babel_workflow_count).
-define(WORKFLOW_ITEMS, babel_workflow_items).
-define(WORKFLOW_CONN, babel_workflow_connection).


-type context()     ::  map().
-type work_item()   ::  reliable_storage_backend:work_item().

-type opts()        ::  #{
    on_error_abort => boolean(),
    connection => pid(),
    connection_pool => atom()
}.

-export_type([context/0]).
-export_type([work_item/0]).
-export_type([opts/0]).



-export([is_in_workflow/0]).
-export([workflow/1]).
-export([workflow/2]).

-export([get_collection/2]).
-export([create_index/1]).



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
%% @doc Equivalent to calling {@link workflow/2 with and empty list passed as
%% the `Opts' argument.
%% @end
%% -----------------------------------------------------------------------------
-spec workflow(Fun ::fun(() -> any())) ->
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
        %% Fun should use this module function which are workflow aware.
        %% If the option on_error_abort was set to true, then any error in
        %% the functions used within the function block will throw
        %% an exception which we catch below.
        Result = Fun(),
        ok = maybe_schedule_workflow(),
        {ok, WorkId, Result}
    catch
        throw:Reason:Stacktrace ->
            ?LOG_DEBUG(
                "Error while executing workflow; reason=~p, stacktrace=~p", [Reason, Stacktrace]
            ),
            maybe_throw(Reason);
        _:Reason:Stacktrace ->
            %% A user exception, we need to raise it again up the
            %% nested transation stack and out
            ?LOG_DEBUG(
                "Error while executing workflow; reason=~p, stacktrace=~p", [Reason, Stacktrace]
            ),
            error(Reason)
    after
        ok = maybe_terminate_workflow(),
        % ok = maybe_return_connection()
        ok
    end.



%% -----------------------------------------------------------------------------
%% @doc Schedules the creation of an index and its partitions according to
%% `Config'.
%% > This function needs to be called within a workflow functional object,
%% see {@link workflow/1,2}.
%%
%% Example:
%%
%% ```erlang
%% > babel:workflow(fun() -> babel:create_index(Config) end).
%% > {ok, <<"00005mrhDMaWqo4SSFQ9zSScnsS">>}
%% '''
%% @end
%% -----------------------------------------------------------------------------
-spec create_index(Config :: map()) ->
    ok | no_return().

create_index(Config) ->
    ok = ensure_in_workflow(),
    Index =  babel_index:new(Config),
    Partitions = babel_index:create_partitions(Index),
    L = [
        babel_index:to_work_item(Index, Partition)
        || Partition <- Partitions
    ],
    ok = append_workflow_items(L),
    ok.



% compute_indices(<<"accounts">>, Acc1) ->
%     WorkItems
%     workflow:eneuque(WorkdID, WorItems),


%% -----------------------------------------------------------------------------
%% @doc Returns the collection for a given name `Name'
%% @end
%% -----------------------------------------------------------------------------
-spec get_collection(BucketPrefix :: binary(), Key :: binary()) ->
    babel_index_collection:t() | {error, any()}.

get_collection(BucketPrefix, Key) ->
    try cache:get(babel_index_collection, {BucketPrefix, Key}, 5000) of
        undefined ->
            % TODO
            Conn = undefined,
            case label_collection:lookup(Conn, BucketPrefix, Key) of
               {ok, _}  = OK ->
                   OK;
               {error, Reason} ->
                   throw(Reason)
            end;

        Collection ->
            Collection
    catch
        throw:Reason ->
            {error, Reason};
        _:timeout ->
            {error, timeout}
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
            Id = ksuid:gen_id(millisecond),
            undefined = put(?WORKFLOW_ID, Id),
            undefined = put(?WORKFLOW_COUNT, 1),
            undefined = put(?WORKFLOW_ITEMS, []),
            Conn = get_connection(Opts),
            undefined = put(?WORKFLOW_CONN, Conn),
            {ok, Id};
        Id ->
            %% This is a nested call, we are joining an existing workflow
            ok = increment_nested_count(),
            {ok, Id}
    end.


%% @private
get_connection(#{connection := Conn}) ->
    Conn;

get_connection(#{connection_pool_name := _PoolName}) ->
    error(not_implemented).


%% -----------------------------------------------------------------------------
%% @private
%% @doc Returns the connection to the pool
%% @end
%% -----------------------------------------------------------------------------

return_connection() ->
    %% @TODO
    ok.


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
    case get(?WORKFLOW_ITEMS) of
        [] ->
            ok;
        L ->
            WorkItems = lists:flatten(lists:reverse(L)),
            Work = lists:zip(
                lists:seq(1, length(WorkItems)),
                WorkItems
            ),
            WorkId = get(?WORKFLOW_ID),
            reliable:enqueue(WorkId, Work)
    end.


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
    ok = return_connection(),
    %% We cleanup the process dictionary
    _ = erase(?WORKFLOW_ID),
    _ = erase(?WORKFLOW_ITEMS),
    _ = erase(?WORKFLOW_COUNT),
    _ = erase(?WORKFLOW_CONN),
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
-spec append_workflow_items([work_item()]) -> ok.

append_workflow_items(L) ->
    Acc0 = get(?WORKFLOW_ITEMS),
    Acc1 = [L | Acc0],
    _ = put(?WORKFLOW_ITEMS, Acc1),
    ok.
