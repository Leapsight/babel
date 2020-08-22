%% -----------------------------------------------------------------------------
%% @doc
%% @end
%% -----------------------------------------------------------------------------
-module(babel).
-include_lib("kernel/include/logger.hrl").



%% -export([add_index/2]).
%% -export([remove_index/2]).
-export([create_collection/2]).
-export([create_index/2]).
-export([delete_collection/1]).
-export([delete_index/2]).
-export([rebuild_index/4]).
-export([update_indices/3]).



%% =============================================================================
%% API
%% =============================================================================




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

    Collection = babel_index_collection:new(BucketPrefix, Name, []),
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
%% > babel_reliable:workflow(
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
    ok = babel_reliable:ensure_in_workflow(),

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
            ok = babel_reliable:add_workflow_items(
                [CollWorkflowItem | PartitionItems]
            ),

            %% Index partitions write will be scheduled prior to the collection
            %% write so that if the index is present in a subsequent read of
            %% the collection, it means its partitions have been already
            %% written to Riak.
            babel_reliable:add_workflow_precedence(
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
    ok = babel_reliable:ensure_in_workflow(),
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

    ok = babel_reliable:add_workflow_items([CollectionItem | PartitionItems]),

    %% We need to first remove the index from the collection so that no more
    %% entries are added to the partitions, then we need to remove the partition
    _ = [
        babel_reliable:add_workflow_precedence([CollectionId], X)
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
