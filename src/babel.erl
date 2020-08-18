%% -----------------------------------------------------------------------------
%% @doc
%% @end
%% -----------------------------------------------------------------------------
-module(babel).
-include_lib("kernel/include/logger.hrl").


-define(WORKFLOW_ID, babel_workflow_id).
-define(WORKFLOW_COUNT, babel_workflow_count).
-define(WORKFLOW_ITEMS, babel_work_items).


-type context()     ::  map().

-type opts()        ::  #{
    on_error_abort => boolean(),
    connection => pid(),
    connection_pool => atom()
}.

-export_type([context/0]).
-export_type([opts/0]).



-export([is_in_workflow/0]).
-export([workflow/1]).
-export([workflow/2]).

-export([get_collection/2]).
% -export([create_index/2]).



%% =============================================================================
%% API
%% =============================================================================



%% -----------------------------------------------------------------------------
%% @doc
%% @end
%% -----------------------------------------------------------------------------
-spec is_in_workflow() -> boolean().

is_in_workflow() ->
    get(?WORKFLOW_ID) =/= undefined.


%% -----------------------------------------------------------------------------
%% @doc
%% @end
%% -----------------------------------------------------------------------------
-spec workflow(Fun ::fun(() -> any())) ->
    {ok, Id :: binary()} | {error, any()}.

workflow(Fun) ->
    workflow(Fun, []).


%% -----------------------------------------------------------------------------
%% @doc
%% @end
%% -----------------------------------------------------------------------------
-spec workflow(Fun ::fun(() -> any()), Opts :: opts()) ->
    ok | {error, any()}.

workflow(Fun, Opts) ->
    ok = init_workflow(Opts),
    try
        %% Fun should use this module function which are workflow aware.
        %% If the option on_error_abort was set to true, then any error in
        %% the functions used within the function block will throw
        %% an exception which we catch below.
        Result = Fun(),
        ok = maybe_schedule_workflow(),
        Result
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
%% @doc
%% @end
%% -----------------------------------------------------------------------------
-spec create_index(BucketPrefix :: binary(), Config :: map()) ->
    ok | {error, any()}.

create_index(_BucketPrefix, _Config) ->
    % babel_index:new(Config),
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
            undefined = put(?WORKFLOW_ID, ksuid:gen_id(millisecond)),
            undefined = put(?WORKFLOW_COUNT, 1),
            undefined = put(?WORKFLOW_ITEMS, []),
            ok;
        _ ->
            %% This is a nested call, we are joining an existing workflow
            increment_nested_count()
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
        Items ->
            WorkId = get(?WORKFLOW_ID),
            reliable:enqueue(WorkId, Items)
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
    %% We cleanup the process dictionary
    _ = erase(?WORKFLOW_ID),
    _ = erase(?WORKFLOW_ITEMS),
    _ = erase(?WORKFLOW_COUNT),
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
