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
%% @doc
%% @end
%% -----------------------------------------------------------------------------
-module(babel).
-include("babel.hrl").
-include_lib("riakc/include/riakc.hrl").
-include_lib("kernel/include/logger.hrl").


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



%% =============================================================================
%% API
%% =============================================================================



%% -----------------------------------------------------------------------------
%% @doc Equivalent to calling {@link workflow/2} with and empty map passed as
%% the `Opts' argument.
%% @end
%% -----------------------------------------------------------------------------
-spec workflow(Fun :: fun(() -> any())) ->
    {ok, WorkId :: binary(), ResultOfFun :: any()}
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
%% ```
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
-spec workflow(Fun ::fun(() -> any()), Opts :: babel_workflow:opts()) ->
    {ok, WorkId :: binary(), ResultOfFun :: any()}
    | {error, Reason :: any()}
    | no_return().

workflow(Fun, Opts) ->
    babel_reliable:workflow(Fun, Opts).


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
    ok = babel_reliable:ensure_in_workflow(),

    Collection = babel_index_collection:new(BucketPrefix, Name),
    CollectionId = babel_index_collection:id(Collection),

    %% We need to avoid the situation were we create a collection we
    %% have previously initialised in the workflow graph
    ok = maybe_already_exists(CollectionId),

    WorkItem = fun() -> babel_index_collection:to_update_item(Collection) end,
    WorkflowItem = {CollectionId, {update, WorkItem}},
    ok = babel_reliable:add_workflow_items([WorkflowItem]),

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
    ok = babel_reliable:ensure_in_workflow(),

    CollectionId = babel_index_collection:id(Collection),
    WorkItem = fun() -> babel_index_collection:to_delete_item(Collection) end,
    WorkflowItem = {CollectionId, {delete, WorkItem}},

    babel_reliable:add_workflow_items([WorkflowItem]).


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
    babel_index_collection:t() | no_return().

create_index(Index, Collection) ->
    ok = babel_reliable:ensure_in_workflow(),

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
    ok = babel_reliable:ensure_in_workflow(),

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

            ok = babel_reliable:add_workflow_items(
                [CollWorkflowItem | PartitionItems]
            ),

            %% If there is an update on the collection we want it to occur
            %% before the partition updates
            babel_reliable:add_workflow_precedence(
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

        ok = babel_reliable:add_workflow_items(
            [CollectionItem | PartitionItems]
        ),

        %% We need to first remove the index from the collection so that no more
        %% entries are added to the partitions, then we need to remove the partition
        _ = [
            babel_reliable:add_workflow_precedence([CollectionId], X)
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
    CollWorkItem = fun() ->
        babel_index_collection:to_update_item(NewCollection)
    end,
    CollWorkflowItem = {CollectionId, {update, CollWorkItem}},
    ok = babel_reliable:add_workflow_items(
        [CollWorkflowItem | PartitionItems]
    ),

    %% Index partitions write will be scheduled prior to the collection
    %% write so that if the index is present in a subsequent read of
    %% the collection, it means its partitions have been already
    %% written to Riak.
    ok = babel_reliable:add_workflow_precedence(
        [Id || {Id, _} <- PartitionItems], CollectionId
    ),

    NewCollection.


%% -----------------------------------------------------------------------------
%% @private
%% @doc
%% @end
%% -----------------------------------------------------------------------------
maybe_already_exists(Id) ->
    case babel_reliable:find_workflow_item(Id) of
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
    case babel_reliable:find_workflow_item(Id) of
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
    [babel_reliable:workflow_item()].

partition_update_items(Collection, Index, Partitions, Mode) ->
    [
        begin
            CollectionId = babel_index_collection:id(Collection),
            IndexName = babel_index:name(Index),
            %% We ensure the name of the partition is unique within the
            %% workflow graph
            Id = {CollectionId, IndexName, babel_index_partition:id(P)},

            WorkItem = case Mode of
                eager ->
                    babel_index:to_update_item(Index, P);
                lazy ->
                    fun() -> babel_index:to_update_item(Index, P) end
            end,

            {Id, {update, WorkItem}}

        end || P <- Partitions
    ].