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
%%
%% ### Working with Babel Datatypes
%%
%% ### Working with Reliable Workflows
%% #### Workflow aware functions
%% A workflow aware function is a function that schedules its execution when it
%% is called inside a workflow context. Several functions in this module are
%% workflow aware e.g. {@link put/5}, {@link delete/3}.
%%
%% ### Working with Babel Indices
%%
%% @end
%% -----------------------------------------------------------------------------
-module(babel).
-include("babel.hrl").
-include_lib("kernel/include/logger.hrl").

%% TODO
-define(DEFAULT_OPTS, #{}).

-define(BABEL_OPTS_SPEC, #{
    connection => #{
        required => false,
        datatype => [pid, function]
    },
    riak_opts => #{
        required => false,
        datatype => map,
        validator => ?RIAK_OPTS_SPEC
    }
}).

-define(RIAK_EC_TYPE, [non_neg_integer , {in, [one, all, quorum, default]}]).

-define(RIAK_OPTS_SPEC, #{
    n_val => #{
        alias => <<"n_val">>,
        key => n_val,
        required => false,
        allow_null => false,
        allow_undefined => false,
        datatype => non_neg_integer
    },
    r => #{
        alias => <<"r">>,
        key => r,
        required => false,
        allow_null => false,
        allow_undefined => false,
        datatype => ?RIAK_EC_TYPE
    },
    w => #{
        alias => <<"w">>,
        key => w,
        required => false,
        allow_null => false,
        allow_undefined => false,
        datatype => ?RIAK_EC_TYPE
    },
    dw => #{
        alias => <<"dw">>,
        key => dw,
        required => false,
        allow_null => false,
        allow_undefined => false,
        datatype => ?RIAK_EC_TYPE
    },
    pr => #{
        alias => <<"pr">>,
        key => pr,
        required => false,
        allow_null => false,
        allow_undefined => false,
        datatype => ?RIAK_EC_TYPE
    },
    pw => #{
        alias => <<"pw">>,
        key => pw,
        required => false,
        allow_null => false,
        allow_undefined => false,
        datatype => ?RIAK_EC_TYPE
    },
    rw => #{
        alias => <<"rw">>,
        key => rw,
        required => false,
        allow_null => false,
        allow_undefined => false,
        datatype => ?RIAK_EC_TYPE
    },
    notfound_ok => #{
        alias => <<"notfound_ok">>,
        key => notfound_ok,
        required => false,
        allow_null => false,
        allow_undefined => false,
        datatype => boolean
    },
    basic_quorum => #{
        alias => <<"basic_quorum">>,
        key => basic_quorum,
        required => false,
        allow_null => false,
        allow_undefined => false,
        datatype => boolean
    },
    sloppy_quorum => #{
        alias => <<"sloppy_quorum">>,
        key => sloppy_quorum,
        required => false,
        allow_null => false,
        allow_undefined => false,
        datatype => boolean
    },
    return_body => #{
        alias => <<"return_body">>,
        key => return_body,
        required => false,
        datatype => boolean
    },
    return_head => #{
        alias => <<"return_head">>,
        key => return_head,
        required => false,
        datatype => boolean
    },
    timeout => #{
        alias => <<"timeout">>,
        key => timeout,
        description => <<
            "The timeout for a Riak request. The default is 5 secs."
        >>,
        required => true,
        default => ?DEFAULT_REQ_TIMEOUT,
        datatype => timeout
    }
}).

-type datatype()        ::  babel_map:t() | babel_set:t() | babel_counter:t().
-type type_spec()       ::  babel_map:type_spec()
                            | babel_set:type_spec()
                            | babel_counter:type_spec().
-type riak_op()         ::  riakc_datatype:update(term()).

-type opts()      ::  #{
    connection => pid() | fun(() -> pid()),
    riak_opts => riak_opts(),
    '$validated' => boolean()
}.

-type riak_opts()   :: #{
    r => quorum(),
    pr => quorum(),
    w => quorum(),
    dw => quorum(),
    pw => quorum(),
    notfound_ok => boolean(),
    basic_quorum => boolean(),
    sloppy_quorum => boolean(),
    timeout => timeout(),
    return_body => boolean()
}.

-export_type([datatype/0]).
-export_type([type_spec/0]).
-export_type([riak_op/0]).
-export_type([opts/0]).
-export_type([riak_opts/0]).

%% API
-export([delete/3]).
-export([execute/3]).
-export([get/4]).
-export([get_connection/1]).
-export([module/1]).
-export([opts_to_riak_opts/1]).
-export([put/5]).
-export([type/1]).
-export([validate_opts/1]).
-export([validate_opts/2]).

%% API: WORKFLOW & WORKFLOW AWARE FUNCTIONS
-export([create_index/2]).
-export([create_index/3]).
-export([drop_index/2]).
-export([drop_index/3]).
-export([drop_all_indices/1]).
-export([drop_all_indices/2]).
-export([drop_indices/2]).
-export([drop_indices/3]).
-export([rebuild_index/3]).
-export([status/1]).
-export([status/2]).
-export([update_all_indices/3]).
-export([update_indices/4]).
-export([workflow/1]).
-export([workflow/2]).
-export([yield/1]).
-export([yield/2]).



%% =============================================================================
%% API
%% =============================================================================



%% -----------------------------------------------------------------------------
%% @doc Returns the atom name for a babel datatype.
%% @end
%% -----------------------------------------------------------------------------
-spec type(term()) -> set | map | counter | flag | register.

type(Term) ->
    case module(Term) of
        undefined -> register;
        Mod -> Mod:type()
    end.


%% -----------------------------------------------------------------------------
%% @doc Returns the module associated with the type of term `Term'.
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
    %% We do not have a wrapper module for register as we treat most Erlang
    %% types as registers through the transformations provided by
    %% babel_map:type_spec().
    undefined.



%% -----------------------------------------------------------------------------
%% @doc Retrieves a Riak Datatype (counter, set or map) from bucket type and
%% bucket `TypedBucket' and key `Key'. It uses type spec `Spec' to transform
%% the Riak Datatype into a Babel Datatype and if successful returns a {@link
%% babel_counter}, {@link babel_set} or {@link babel_map} respectively.
%%
%% This function gets the riak client connection from the options `Opts' under
%% the key `connection' which can have the connection pid or a function object
%% returning a connection pid. This allows a lot of flexibility such as reusing
%% a given connection over several calls the babel function of using your own
%% connection pool and management.
%%
%% In case the `connection' option does not provide a connection as explained
%% above, this function tries to use the `default' connection pool if it was
%% enabled through Babel's configuration options.
%%
%% Returns `{error, not_found}' if the key is not on the server.
%%
%% @end
%% -----------------------------------------------------------------------------
-spec get(
    TypedBucket :: bucket_and_type(),
    Key :: binary(),
    Spec :: type_spec(),
    Opts :: opts()) ->
    {ok, Datatype :: datatype()}
    | {error, Reason :: term()}.

get(TypedBucket, Key, Spec, Opts0) ->
    Opts = validate_opts(Opts0),
    Conn = get_connection(Opts),
    ReqOpts = babel:opts_to_riak_opts(Opts),

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
%% ?> This function is workflow aware
%% @end
%% -----------------------------------------------------------------------------
-spec put(
    TypedBucket :: bucket_and_type(),
    Key :: binary(),
    Datatype :: datatype(),
    Spec :: type_spec(),
    Opts :: opts()) ->
    ok
    | {true | false, reliable:wf_result()}
    | {error, Reason :: any()}
    | no_return().

put(TypedBucket, Key, Datatype, Spec, Opts) ->
    case reliable:is_in_workflow() of
        false ->
            do_put(TypedBucket, Key, Datatype, Spec, Opts);
        true ->
            schedule_put(TypedBucket, Key, Datatype, Spec, Opts)
    end.


%% -----------------------------------------------------------------------------
%% @doc
%% ?> This function is workflow aware
%% @end
%% -----------------------------------------------------------------------------
-spec delete(
    TypedBucket :: bucket_and_type(), Key :: binary(), Opts :: opts()) ->
    ok
    | {true | false, reliable:wf_result()}
    | {error, Reason :: any()}
    | no_return().

delete(TypedBucket, Key, Opts) ->
    case reliable:is_in_workflow() of
        false ->
            do_delete(TypedBucket, Key, Opts);
        true ->
            schedule_delete(TypedBucket, Key, Opts)
    end.



%% -----------------------------------------------------------------------------
%% @doc Executes a number of operations using the same Riak client connection
%% provided by riak_pool app.
%% `Poolname' must be an already started pool.
%%
%% Options:
%%
%% * timeout - time to get a connection from the pool
%% @end
%% -----------------------------------------------------------------------------
-spec execute(
    Poolname :: atom(),
    Fun :: fun((RiakConn :: pid()) -> Result :: any()),
    Opts :: opts()) ->
    {true, Result :: any()} | {false, Reason :: any()} | no_return().

execute(Poolname, Fun, Opts)  ->
    riak_pool:execute(Poolname, Fun, Opts).


%% -----------------------------------------------------------------------------
%% @doc Validates the opts
%% @param Opts an erlang map containing valid option keys
%% @equiv validate_opts(Opts, strict)
%% @see validate_opts/2
%% @end
%% -----------------------------------------------------------------------------
-spec validate_opts(opts()) -> maybe_no_return(opts()).

-dialyzer({nowarn_function, validate_opts/1}).

validate_opts(Opts) ->
    validate_opts(Opts, strict).


%% -----------------------------------------------------------------------------
%% @doc Validates the opts
%% @end
%% -----------------------------------------------------------------------------
-spec validate_opts(map(), strict | relaxed) -> maybe_no_return(map()).

-dialyzer({nowarn_function, validate_opts/1}).

validate_opts(#{'$validated' := true} = Opts, _) ->
    Opts;

validate_opts(Opts, Mode) ->
    Flag = Mode == relaxed orelse false,
    Opts1 = maps_utils:validate(
        Opts, ?BABEL_OPTS_SPEC, #{keep_unknown => Flag}
    ),
    Opts1#{'$validated' => true}.


%% -----------------------------------------------------------------------------
%% @doc
%% @end
%% -----------------------------------------------------------------------------
-spec opts_to_riak_opts(map()) -> list().

opts_to_riak_opts(#{riak_opts := Opts}) ->
    maps:to_list(Opts);

opts_to_riak_opts(_) ->
    [].


%% -----------------------------------------------------------------------------
%% @doc
%% @end
%% -----------------------------------------------------------------------------
get_connection(#{connection := Conn}) when is_pid(Conn) ->
    Conn;

get_connection(#{connection := Get}) when is_function(Get, 0) ->
    Get();

get_connection(Opts) ->
    case babel_config:get(default_pool, undefined) of
        undefined ->
            error(no_connection_provided);
        Poolname ->
            Timeout = maps:get(timeout, Opts, 5000),
            case riak_pool:checkout(Poolname, #{timeout => Timeout}) of
                {ok, Pid} -> Pid;
                {error, Reason} -> error(Reason)
            end
    end.




%% =============================================================================
%% API: WORKFLOW AND WORKFLOW-AWARE FUNCTIONS
%% =============================================================================



%% -----------------------------------------------------------------------------
%% @doc Equivalent to calling {@link workflow/2} with and empty map passed as
%% the `Opts' argument.
%%
%% > Notice subscriptions are not working at the moment
%% > See {@link yield/2} to track progress.
%%
%% @end
%% -----------------------------------------------------------------------------
-spec workflow(Fun :: fun(() -> any())) ->
    {true | false, reliable:wf_result()}
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
%% <pre lang="erlang"><![CDATA[
%% babel:workflow(fun() ->
%%  CollectionX0 = babel_index_collection:new(<<"foo">>, <<"bar">>),
%%  CollectionY0 = babel_index_collection:fetch(Conn, <<"foo">>, <<"users">>),
%%  IndexA = babel_index:new(ConfigA),
%%  IndexB = babel_index:new(ConfigB),
%%  _CollectionX1 = babel:create_index(IndexA, CollectionX0),
%%  _CollectionY1 = babel:create_index(IndexB, CollectionY0),
%%  ok
%% end).
%% ]]></pre>
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
%% !> **Important** notice subscriptions are not working at the moment
%%
%%
%% ?> **Tip** See {@link yield/2} to track progress.
%%
%% ?> **Note on Nested workflows**. No final scheduling will be done until the
%% top level workflow is terminated. So, although a nested worflow returns
%% `{true, Result}', if the enclosing parent workflow is aborted, the entire
%% nested workflow is aborted.
%%
%% @end
%% -----------------------------------------------------------------------------
-spec workflow(Fun ::fun(() -> any()), Opts :: babel_workflow:opts()) ->
    {true | false, reliable:wf_result()}
    | {error, Reason :: any()}
    | no_return().

workflow(Fun, Opts) ->
    reliable:workflow(Fun, Opts).


%% -----------------------------------------------------------------------------
%% @doc Calls {@link status/2}.
%% @end
%% -----------------------------------------------------------------------------
-spec status(WorkRef :: reliable_work_ref:t() | binary()) ->
    {in_progress, Status :: reliable_work:status()}
    | {failed, Status :: reliable_work:status()}
    | {error, not_found | any()}.

status(WorkerRef) ->
    reliable_partition_store:status(WorkerRef).


%% -----------------------------------------------------------------------------
%% @doc Returns the status of a Reliable Work scheduled for execution.
%%
%% !> **Important** notice that at the moment completed tasks are deleted, so
%% the abscense of a task is considered as either successful or failed, this
%% will change in the near future as we will be retaining tasks that are
%% discarded or completed.
%% @end
%% -----------------------------------------------------------------------------
-spec status(
    WorkRef :: reliable_work_ref:t() | binary(), Timeout :: timeout()) ->
    {in_progress, Status :: reliable_work:status()}
    | {failed, Status :: reliable_work:status()}
    | {error, not_found | any()}.

status(WorkerRef, Timeout) ->
    reliable_partition_store:status(WorkerRef, Timeout).


%% -----------------------------------------------------------------------------
%% @doc Returns the value associated with the key `event_payload' when used as
%% option from a previous {@link enqueue/2}. The calling process is suspended
%% until the work is completed or
%%
%%
%% !> **Important** notice the current implementation is not ideal as it
%% recursively reads the status from the database. So do not abuse it. Also at
%% the moment completed tasks are deleted, so the abscense of a task is
%% considered as either successful or failed, this will also change as we will
%% be retaining tasks that are discarded or completed.
%% This will be replaced by a pubsub version soon.
%% @end
%% -----------------------------------------------------------------------------
-spec yield(WorkRef :: reliable_worker:work_ref()) ->
    {ok, Payload :: any()} | timeout.

yield(WorkRef) ->
    yield(WorkRef, infinity).


%% -----------------------------------------------------------------------------
%% @doc Returns the value associated with the key `event_payload' when used as
%% option from a previous {@link enqueue/2} or `timeout' when `Timeout'
%% milliseconds has elapsed.
%%
%% !> **Important** notice The current implementation is not ideal as it
%% recursively reads the status from the database. So do not abuse it. Also at
%% the moment complete tasks are deleted, so the abscense of a task is
%% considered as either succesful or failed, this will also change as we will
%% be retaining tasks that are discarded or completed.
%% This will be replaced by a pubsub version soon.
%% @end
%% -----------------------------------------------------------------------------
-spec yield(WorkRef :: reliable_worker:work_ref(), Timeout :: timeout()) ->
    {ok, Payload :: any()} | timeout.

yield(WorkRef, Timeout) ->
    reliable:yield(WorkRef, Timeout).



%% -----------------------------------------------------------------------------
%% @doc Calls {@link create_index/3} passing the default options as third
%% argument.
%% @end
%% -----------------------------------------------------------------------------
-spec create_index(
    Index :: babel_index:t(), Collection :: babel_index_collection:t()) ->
    {true | false, reliable:wf_result()}
    | {error, Reason :: any()}
    | no_return().

create_index(Index, Collection) ->
    create_index(Index, Collection, ?DEFAULT_OPTS).


%% -----------------------------------------------------------------------------
%% @doc Schedules the creation of an index and its partitions according to
%% `Config' using Reliable.
%%
%% The updated collection is returned under the key `result' of the
%% `reliable:wf_result()'.
%%
%% ?> This function uses a workflow, see {@link workflow/2} for an explanation
%% of the possible return values.
%%
%% @end
%% -----------------------------------------------------------------------------
-spec create_index(
    Index :: babel_index:t(),
    Collection :: babel_index_collection:t(),
    Opts :: opts()) ->
    {true | false, reliable:wf_result()}
    | {error, Reason :: any()}
    | no_return().

create_index(Index, Collection, Opts0) ->
    Opts = validate_opts(Opts0),
    Fun = fun() ->
        %% It is an error to add and index to a collection scheduled to be
        %% deleted in a parent workflow
        ok = ensure_not_deleted(babel_index_collection:id(Collection)),

        try
            IndexName = babel_index:name(Index),
            _ = babel_index_collection:index(IndexName, Collection),
            %% The index already exists so we should not create its partitions
            %% to protect data already stored
            throw({already_exists, IndexName})
        catch
            error:badindex ->
                %% The index does not exist so we create it
                do_create_index(Index, Collection)
        end
    end,
    workflow(Fun, Opts).



%% -----------------------------------------------------------------------------
%% @doc
%% @end
%% -----------------------------------------------------------------------------
-spec rebuild_index(
    Index :: babel_index:t(),
    Collection :: babel_index_collection:t(),
    Opts :: riak_opts()) ->
    {true | false, reliable:wf_result()}
    | {error, Reason :: any()}
    | no_return().

rebuild_index(_IndexName, _Collection, _Opts) ->
    %% TODO call the manager
    {error, not_implemented}.


%% -----------------------------------------------------------------------------
%% @doc Updates all the indices in the collection with the provided Actions and
%% schedules the update of the relevant index partitions in the database i.e.
%% persisting the index changes.
%%
%% The names of the updated indices is returned under the key `result' of the
%% `reliable:wf_result()'.
%%
%% ?> This function uses a workflow, see {@link workflow/2} for an explanation
%% of the possible return values.
%% @end
%% -----------------------------------------------------------------------------
-spec update_indices(
    Actions :: [babel_index:update_action()],
    IdxNames :: [binary()],
    Collection :: babel_index_collection:t(),
    Opts :: opts()) ->
    {true | false, reliable:wf_result()}
    | {error, Reason :: any()}
    | no_return().

update_indices(Actions, IdxNames, Collection, Opts0) when is_list(Actions) ->
    Opts = validate_opts(Opts0),

    Fun = fun() ->
        CollectionId = babel_index_collection:id(Collection),

        %% We fail if the collection is being deleted as part of a
        %% parent workflow
        ok = ensure_not_deleted(CollectionId),

        ok = lists:foreach(
            fun(Name) ->
                Index = babel_index_collection:index(Name, Collection),
                Partitions = babel_index:update(Actions, Index, Opts),

                %% Tradeoff between memory intensive (lazy) or CPU
                %% intensive (eager) evaluation.
                %% We use eager here as we assume the
                %% user is smart enough to aggregate all operations for a
                %% collection and perform a single call to this function within
                %% a workflow.
                Items = partition_update_items(
                    Collection, Index, Partitions, eager
                ),

                %% We use the nop just to setup the precedence digraph
                CollectionItem = {CollectionId, undefined},
                ok = reliable:add_workflow_items([CollectionItem | Items]),

                %% If there is an update on the collection we want it to occur
                %% before the partition updates
                reliable:add_workflow_precedence(
                    CollectionId, [Id || {Id, _} <- Items]
                )
            end,
            IdxNames
        ),

        %% We return the index names that have been updated.
        IdxNames
    end,
    workflow(Fun, Opts).


%% -----------------------------------------------------------------------------
%% @doc Updates all the indices in the collection that are affected by he
%% provided Actions and schedules the update of the relevant index partitions
%% in the database i.e. persisting the index changes.
%%
%% An index in collection `Collection' will always be affectd in case the
%% action is either `{insert, Data}' or
%% `{delete, Data}' or when the action is `{udpate, Old, New}' and the option
%% `force' was set to `true' or when `New' is not a babel map.
%%
%% In case option object `New' is a babel map, and the option `force' is missing
%% or set to `false', an index will be affected by an update action only if the
%% index's distinguished key paths have been updated or removed in the object
%% `New' (See {@link babel_index:distinguished_key_paths/1})
%%
%% ?> This function uses a workflow, see {@link workflow/2} for an explanation
%% of the possible return values.
%% @end
%% -----------------------------------------------------------------------------
-spec update_all_indices(
    Actions :: [babel_index:update_action()],
    Collection :: babel_index_collection:t(),
    RiakOpts :: opts()) ->
   {true | false, reliable:wf_result()}
    | {error, Reason :: any()}
    | no_return().

update_all_indices(Actions, Collection, Opts) ->
    IdxNames = babel_index_collection:index_names(Collection),
    update_indices(Actions, IdxNames, Collection, Opts).


%% -----------------------------------------------------------------------------
%% @doc
%% @end
%% -----------------------------------------------------------------------------
-spec drop_index(
    Index :: binary(), Collection0 :: babel_index_collection:t()) ->
   {true | false, reliable:wf_result()}
    | {error, Reason :: any()}
    | no_return().

drop_index(IndexName, Collection) ->
    drop_index(IndexName, Collection, ?DEFAULT_OPTS).


%% -----------------------------------------------------------------------------
%% @doc Schedules the removal of the index with name `IndexName' from
%% collection `Collection' and all its index partitions from Riak KV.
%% In case the collection is itself being dropped by a parent workflow, the
%% collection will not be updated in Riak.
%%
%% ?> This function uses a workflow, see {@link workflow/2} for an explanation
%% of the possible return values.
%% @end
%% -----------------------------------------------------------------------------
-spec drop_index(
    Index :: binary(),
    Collection :: babel_index_collection:t(),
    Opts :: opts()) ->
    {true | false, reliable:wf_result()}
    | {error, Reason :: any()}
    | no_return().

drop_index(IndexName, Collection0, Opts0) when is_binary(IndexName) ->
    Opts = validate_opts(Opts0),

    Fun = fun() ->
        try
            CollectionId = babel_index_collection:id(Collection0),

            %% We validate the collection has this index, this will throw a
            %% badindex exception if it doesn't.
            Index = babel_index_collection:index(IndexName, Collection0),

            %% We scheduled then delete of all its partitions
            PartIds = babel_index:partition_identifiers(Index),
            Items = [
                begin
                    PItemId = {CollectionId, IndexName, Id},
                    Task = fun() -> babel_index:to_delete_task(Index, Id) end,
                    {PItemId, {delete, Task}}
                end || Id <- PartIds
            ],
            ok = reliable:add_workflow_items(Items),

            Collection1 = babel_index_collection:delete_index(
                Index, Collection0
            ),
            Task = fun() ->
                babel_index_collection:to_update_task(Collection1)
            end,
            CollectionItem = {CollectionId, {update, Task}},
            reliable:add_workflow_items([CollectionItem]),

            %% In case we are updating the collection we need to do it before
            %% dropping the index partitions so that thery are no longer
            %% available to users.
            _ = [
                reliable:add_workflow_precedence([CollectionId], X)
                || {X, _} <- Items
            ],
            CollectionId
        catch
            error:badindex ->
                {error, badindex}
        end
    end,
    workflow(Fun, Opts).


%% -----------------------------------------------------------------------------
%% @doc Calls {@link drop_indices/3}
%% @end
%% -----------------------------------------------------------------------------
-spec drop_indices(
    IdxNames :: [binary()],
    Collection :: babel_index_collection:t()) ->
    {true | false, reliable:wf_result()}
    | {error, Reason :: any()}
    | no_return().

drop_indices(IdxNames, Collection) ->
    drop_indices(IdxNames, Collection, ?DEFAULT_OPTS).


%% -----------------------------------------------------------------------------
%% @doc Schedules the removal from Riak KV of indices with names `IdxNames'
%% from collection `Collection' and their respective partitions.
%%
%% ?> This function uses a workflow, see {@link workflow/2} for an explanation
%% of the possible return values.
%% @end
%% -----------------------------------------------------------------------------
-spec drop_indices(
    IdxNames :: [binary()],
    Collection :: babel_index_collection:t(),
    Opts :: opts()) ->
    {true | false, reliable:wf_result()}
    | {error, Reason :: any()}
    | no_return().

drop_indices(IdxNames, Collection, Opts0) ->
    Opts = validate_opts(Opts0),
    Fun = fun() ->
        %% We delete all indices.
        %% drop_index also removes then index definition from the collection.
        _ = lists:foreach(
            fun(IdxName) -> drop_index(IdxName, Collection, Opts) end,
            IdxNames
        ),
        ok
    end,
    workflow(Fun, Opts).


%% -----------------------------------------------------------------------------
%% @doc Calls {@link drop_all_indices/3}
%% @end
%% -----------------------------------------------------------------------------
-spec drop_all_indices(Collection :: babel_index_collection:t()) ->
    {true | false, reliable:wf_result()}
    | {error, Reason :: any()}
    | no_return().

drop_all_indices(Collection) ->
    drop_all_indices(Collection, ?DEFAULT_OPTS).



%% -----------------------------------------------------------------------------
%% @doc Drops all indices in collection by calling {@link drop_indices/3}.
%% @end
%% -----------------------------------------------------------------------------
-spec drop_all_indices(
    Collection :: babel_index_collection:t(), Opts :: opts()) ->
    {true | false, reliable:wf_result()}
    | {error, Reason :: any()}
    | no_return().

drop_all_indices(Collection, Opts) ->
    IdxNames = babel_index_collection:index_names(Collection),
    drop_indices(IdxNames, Collection, Opts).



%% =============================================================================
%% PRIVATE
%% =============================================================================



%% @private
do_put(TypedBucket, Key, Datatype, Spec, Opts0) ->
    Opts = validate_opts(Opts0),
    Conn = get_connection(Opts),
    RiakOpts = babel:opts_to_riak_opts(Opts),
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
    Opts = validate_opts(Opts0),
    Conn = get_connection(Opts),
    RiakOpts = babel:opts_to_riak_opts(Opts),

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

    %% We add the index to the collection and schedule the update of the
    %% collection in the database
    NewCollection = babel_index_collection:add_index(Index, Collection),
    CollTask = fun() ->
        babel_index_collection:to_update_task(NewCollection)
    end,
    CollWorkflowItem = {CollectionId, {update, CollTask}},
    ok = reliable:add_workflow_items([CollWorkflowItem | PartitionItems]),

    %% We want the workflow to write partitions in the database prior to the
    %% collection so that if the index is present in a subsequent read of
    %% the collection, it means its partitions have been already
    %% written to Riak and it is usable.
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
    true = not is_deleted(Id) orelse throw({scheduled_for_delete, Id}),
    ok.


%% -----------------------------------------------------------------------------
%% @private
%% @doc
%% @end
%% -----------------------------------------------------------------------------
is_deleted(Id) ->
    case reliable:find_workflow_item(Id) of
        {ok, {Id, {delete, _}}} ->
            true;
        _ ->
            false
    end.


%% @private
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

datatype_to_op(counter, Datatype, Spec) ->
    babel_counter:to_riak_op(Datatype, Spec).


%% @private
to_babel_datatype(map, RiakDatatype, Spec) ->
    babel_map:from_riak_map(RiakDatatype, Spec);

to_babel_datatype(set, Datatype, Spec) ->
    babel_set:from_riak_set(Datatype, Spec);

to_babel_datatype(counter, Datatype, Spec) ->
    babel_counter:from_riak_counter(Datatype, Spec).


%% @private
to_update_task(map, TypedBucket, Key, Datatype, Spec) ->
    Op = babel_map:to_riak_op(Datatype, Spec),
    to_update_task(TypedBucket, Key, Op);

to_update_task(set, TypedBucket, Key, Datatype, Spec) ->
    Op = babel_set:to_riak_op(Datatype, Spec),
    to_update_task(TypedBucket, Key, Op);

to_update_task(counter, TypedBucket, Key, Datatype, Spec) ->
    Op = babel_set:to_riak_op(Datatype, Spec),
    to_update_task(TypedBucket, Key, Op).


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