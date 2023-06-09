%% =============================================================================
%%  babel_index_collection.erl -
%%
%%  Copyright (c) 2022 Leapsight Technologies Limited. All rights reserved.
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
%% @doc A babel_index_collection is a Riak Map representing a mapping from
%% binary keys to {@link babel_index} objects, where keys are the value of the
%% {@link babel_index:name/1} property.
%%
%% An Index Collection has a name that typically represents the name of a
%% resource (or entity) name in your domain model e.g. accounts, users.
%%
%% A babel collection object is stored in Riak KV under a bucket_type that
%% should be defined through configuration using the
%% `index_collection_bucket_type' configuration option; and a bucket name which
%% results from concatenating a prefix provided as argument in this module
%% functions and the suffix "/index_collection".
%%
%% ## Configuring the bucket type
%%
%% The bucket type needs to be configured and activated
%% in Riak KV before using this module. The `datatype' property of the bucket
%% type should be configured to `map'.
%%
%% The following example shows how to configure and activate the
%% bucket type with the recommeded default replication
%% properties, for the example we asume the application property
%% `index_collection_bucket_type' maps to "index_collection"
%% bucket type name.
%%
%% ```shell
%% riak-admin bucket-type create index_collection '{"props":
%% {"datatype":"map",
%% "n_val":3, "pw":"quorum", "pr":"quorum", "notfound_ok":false,
%% "basic_quorum":true}}'
%% riak-admin bucket-type activate index_collection
%% '''
%%
%% ## Default replication properties
%%
%% All functions in this module resulting in reading or writing to Riak KV
%% allow an optional map with Riak KV's replication properties, but we
%% recommend to use of the functions which provide the default replication
%% properties.
%%
%% @end
%% -----------------------------------------------------------------------------
-module(babel_index_collection).
-include("babel.hrl").

-define(BUCKET_SUFFIX, "index_collection").

%% TODO Map <-> CRDT
%% we need to store objects with local update capability that will apply
%% changes to the CRDT on to_riak_object.
%% This is to be able to operate with them before they are store in RIAK as we
%% are delyaing storage via Reliable
-record(babel_index_collection, {
    id              ::  binary(),
    bucket          ::  binary(),
    object          ::  riak_object()
}).

-type t()           ::  #babel_index_collection{}.
-type riak_object() ::  riakc_map:crdt_map().
-type fold_fun()    ::  fun(
                            (Key :: key(), Value :: any(), AccIn :: any()) ->
                                AccOut :: any()
                        ).

-export_type([t/0]).
-export_type([riak_object/0]).
-export_type([fold_fun/0]).


%% API
-export([add_index/2]).
-export([bucket/1]).
-export([data/1]).
-export([delete/3]).
-export([delete_index/2]).
-export([fetch/3]).
-export([fold/3]).
-export([from_riak_object/1]).
-export([id/1]).
-export([index/2]).
-export([index_names/1]).
-export([indices/1]).
-export([is_index/2]).
-export([lookup/3]).
-export([new/2]).
-export([size/1]).
-export([store/2]).
-export([to_delete_task/1]).
-export([to_riak_object/1]).
-export([to_update_task/1]).



%% =============================================================================
%% API
%% =============================================================================



%% -----------------------------------------------------------------------------
%% @doc Creates a new index collection object.
%% The value for `bucket' is computed by concatenating `BucketPrefix' with the
%% suffix `/index_collection'.
%% @end
%% -----------------------------------------------------------------------------
-spec new(BucketPrefix :: binary(), Name :: binary()) -> t().

new(BucketPrefix, Name) ->
    Bucket = <<BucketPrefix/binary, ?PATH_SEPARATOR, ?BUCKET_SUFFIX>>,

    Object0 = riakc_map:update(
        {<<"id">>, register},
        fun(R) -> riakc_register:set(Name, R) end,
        riakc_map:new()
    ),
    Object1 = riakc_map:update(
        {<<"bucket">>, register},
        fun(R) -> riakc_register:set(Bucket, R) end,
        Object0
    ),
    Object2 = riakc_map:update(
        {<<"data">>, map},
        fun(Data) -> Data end,
        Object1
    ),

    #babel_index_collection{
        id = Name,
        bucket = <<BucketPrefix/binary, ?PATH_SEPARATOR, ?BUCKET_SUFFIX>>,
        object = Object2
    }.


%% -----------------------------------------------------------------------------
%% @doc
%% @end
%% -----------------------------------------------------------------------------
-spec from_riak_object(Object :: riak_object()) -> Collection :: t().

from_riak_object(Object) ->
    %% We extract id and bucket values from Object for convenience
    Id = babel_crdt:register_to_binary(
        riakc_map:fetch({<<"id">>, register}, Object)
    ),
    Bucket = babel_crdt:register_to_binary(
        riakc_map:fetch({<<"bucket">>, register}, Object)
    ),

    #babel_index_collection{
        id = Id,
        bucket = Bucket,
        object = Object
    }.


%% -----------------------------------------------------------------------------
%% @doc
%% @end
%% -----------------------------------------------------------------------------
-spec to_riak_object(Collection :: t()) -> Object :: riak_object().

to_riak_object(#babel_index_collection{object = Object}) ->
    %% id and bucket record fields are readonly and alredy present in the
    %% Riak object.
    Object.


%% -----------------------------------------------------------------------------
%% @doc Returns the number of elements in the collection `Collection'.
%% @end
%% -----------------------------------------------------------------------------
-spec size(Collection :: t()) -> non_neg_integer().

size(Collection) ->
    orddict:size(data(Collection)).


%% -----------------------------------------------------------------------------
%% @doc
%% @end
%% -----------------------------------------------------------------------------
-spec id(Collection :: t()) -> binary().

id(#babel_index_collection{id = Value}) -> Value.


%% -----------------------------------------------------------------------------
%% @doc
%% @end
%% -----------------------------------------------------------------------------
-spec bucket(Collection :: t()) -> binary().

bucket(#babel_index_collection{bucket = Value}) -> Value.


%% -----------------------------------------------------------------------------
%% @doc
%% @end
%% -----------------------------------------------------------------------------
-spec data(Collection :: t()) -> orddict:orddict().

data(#babel_index_collection{object = Object}) ->
    riakc_map:fetch({<<"data">>, map}, Object).


-spec is_index(IndexName :: binary(), Collection :: t()) ->
    babel_index:t() | no_return().

is_index(IndexName, #babel_index_collection{} = Collection)
when is_binary(IndexName) ->

    Data = data(Collection),
    orddict:is_key({IndexName, map}, Data).


%% -----------------------------------------------------------------------------
%% @doc Returns the babel index associated with name `IndexName' in collection
%% `Collection'. This function assumes that the name is present in the
%% collection. An exception is generated if it is not.
%% @end
%% -----------------------------------------------------------------------------
-spec index(IndexName :: binary(), Collection :: t()) ->
    babel_index:t() | no_return().

index(IndexName, #babel_index_collection{} = Collection)
when is_binary(IndexName) ->

    try
        Data = data(Collection),
        Object = orddict:fetch({IndexName, map}, Data),
        babel_index:from_riak_object(Object)
    catch
        _:_:Stacktrace ->
            error(badindex, Stacktrace)
    end.


%% -----------------------------------------------------------------------------
%% @doc Returns all the indices in the collection.
%% @end
%% -----------------------------------------------------------------------------
-spec indices(Collection :: t()) -> [babel_index:t()].

indices(#babel_index_collection{} = Collection) ->
    try data(Collection) of
        Data ->
            Fun = fun(_, V, Acc) ->
                E = babel_index:from_riak_object(V),
                [E | Acc]
            end,
            lists:reverse(orddict:fold(Fun, [], Data))
    catch
        error:function_clause ->
            []
    end.


%% -----------------------------------------------------------------------------
%% @doc
%% @end
%% -----------------------------------------------------------------------------
-spec index_names(Collection :: t()) -> [binary()].

index_names(Collection) ->
    try data(Collection) of
        RMap ->
            Fun = fun({K, map}, _, Acc) -> [K | Acc] end,
            lists:reverse(orddict:fold(Fun, [], RMap))
    catch
        error:function_clause ->
            []
    end.


%% -----------------------------------------------------------------------------
%% @doc Returns a copy of collection `Collection' where the index `Index' has
%% been added.
%% If the an index with the same name existed in the collection, it will be
%% replaced by `Index'.
%%
%% !> **Important**. This is a private API. If you want to add an index to the
%% collection and create the index in Riak KV use {@link babel:create_index/3}
%% instead.
%%
%% @end
%% -----------------------------------------------------------------------------
-spec add_index(Index :: babel_index:t(), Collection :: t()) ->
    t() | no_return().

add_index(Index, #babel_index_collection{} = Collection) ->
    IndexId = babel_index:name(Index),
    IndexObject = babel_index:to_riak_object(Index),
    Object = riakc_map:update(
        {<<"data">>, map},
        fun(RMap) ->
            riakc_map:update({IndexId, map}, fun(_) -> IndexObject end, RMap)
        end,
        Collection#babel_index_collection.object
    ),

    Collection#babel_index_collection{object = Object}.


%% -----------------------------------------------------------------------------
%% @doc
%% @end
%% -----------------------------------------------------------------------------
-spec delete_index(Id :: binary() | babel_index:t(), Collection :: t()) ->
    t() | no_return().

delete_index(IndexId, #babel_index_collection{} = Collection)
when is_binary(IndexId) ->
    Object = riakc_map:update(
        {<<"data">>, map},
        fun(RMap) -> riakc_map:erase({IndexId, map}, RMap) end,
        Collection#babel_index_collection.object
    ),

    Collection#babel_index_collection{object = Object};

delete_index(Index, Collection) ->
    delete_index(babel_index:name(Index), Collection).


%% -----------------------------------------------------------------------------
%% @doc
%% @end
%% -----------------------------------------------------------------------------
-spec to_update_task(Collection :: t()) -> reliable:action().

to_update_task(#babel_index_collection{} = Collection) ->
    Key = Collection#babel_index_collection.id,
    Object = to_riak_object(Collection),
    TypedBucket = typed_bucket(Collection),
    Args = [TypedBucket, Key, riakc_map:to_op(Object)],
    reliable_task:new(
        node(), riakc_pb_socket, update_type, [{symbolic, riakc} | Args]
    ).


%% -----------------------------------------------------------------------------
%% @doc
%% @end
%% -----------------------------------------------------------------------------
-spec to_delete_task(Collection :: t()) -> reliable:action().

to_delete_task(#babel_index_collection{} = Collection) ->
    Key = Collection#babel_index_collection.id,
    TypedBucket = typed_bucket(Collection),
    Args = [TypedBucket, Key],
    reliable_task:new(
        node(), riakc_pb_socket, delete, [{symbolic, riakc} | Args]
    ).


%% -----------------------------------------------------------------------------
%% @doc
%% @end
%% -----------------------------------------------------------------------------
-spec fold(Fun :: fold_fun(), Acc :: any(), Collection :: t()) -> any().

fold(Fun, Acc, Collection) ->
    try data(Collection) of
        Data ->
            Fun = fun(_, V, IAcc) ->
                E = babel_index:from_riak_object(V),
                Fun(E, IAcc)
            end,
            lists:reverse(orddict:fold(Fun, Acc, Data))
    catch
        error:function_clause ->
            []
    end.


%% -----------------------------------------------------------------------------
%% @doc Stores an index collection in Riak KV.
%% The collection will be stored under the bucket type configured
%% for the application option `index_collection_bucket_type', bucket name
%% will be the value returned by {@link bucket/1}, and the key will be the
%% value returned by {@link id/1}.
%% @end
%% -----------------------------------------------------------------------------
-spec store(Collection :: t(), Opts :: babel:put_opts()) ->
    {ok, Index :: t()} | {error, Reason :: any()}.


store(Collection, Opts0) ->
    Opts = babel:validate_opts(put, Opts0),
    Poolname = maps:get(connection_pool, Opts, undefined),

    Fun = fun(Pid) ->
        ROpts = babel:opts_to_riak_opts(Opts),
        Key = Collection#babel_index_collection.id,
        Object = Collection#babel_index_collection.object,
        TypeBucket = typed_bucket(Collection),
        Op = riakc_map:to_op(Object),

        case riakc_pb_socket:update_type(Pid, TypeBucket, Key, Op, ROpts) of
            {error, _} = Error ->
                Error;
            _ ->
                ok
        end
    end,
    case babel:execute(Poolname, Fun, Opts) of
        {ok, Result} -> Result;
        {error, _} = Error -> Error
    end.


%% -----------------------------------------------------------------------------
%% @doc
%% @end
%% -----------------------------------------------------------------------------
-spec fetch(
    BucketPrefix :: binary(),
    Key :: binary(),
    Opts :: babel:get_opts()) ->
    t() | no_return().

fetch(BucketPrefix, Key, Opts) ->
    case lookup(BucketPrefix, Key, Opts) of
        {ok, Value} -> Value;
        {error, Reason} -> error(Reason)
    end.


%% -----------------------------------------------------------------------------
%% @doc
%% @end
%% -----------------------------------------------------------------------------
-spec lookup(
    BucketPrefix :: binary(),
    Key :: binary(),
    Opts :: babel:get_opts()) ->
    {ok, t()} | {error, not_found | term()}.

lookup(BucketPrefix, Key, Opts0)
when is_binary(BucketPrefix) andalso is_binary(Key) ->
    Opts = babel:validate_opts(get, Opts0),
    Poolname = maps:get(connection_pool, Opts, undefined),

    Fun = fun(Pid) ->
        TypeBucket = typed_bucket(BucketPrefix),
        ROpts = babel:opts_to_riak_opts(Opts),

        case riakc_pb_socket:fetch_type(Pid, TypeBucket, Key, ROpts) of
            {ok, Object} -> {ok, from_riak_object(Object)};
            {error, {notfound, _}} -> {error, not_found};
            {error, _} = Error -> Error
        end

    end,
    case babel:execute(Poolname, Fun, Opts) of
        {ok, Result} -> Result;
        {error, _} = Error -> Error
    end.





%% -----------------------------------------------------------------------------
%% @doc
%% @end
%% -----------------------------------------------------------------------------
-spec delete(
    BucketPrefix :: binary(),
    Key :: binary(),
    Opts :: babel:delete_opts()) ->
    ok | {error, not_found | term()}.

delete(BucketPrefix, Key, Opts0)
when is_binary(BucketPrefix) andalso is_binary(Key) ->
    Opts = babel:validate_opts(delete, Opts0),
    Poolname = maps:get(connection_pool, Opts, undefined),

    Fun = fun(Pid) ->
        TypeBucket = typed_bucket(BucketPrefix),
        ROpts = babel:opts_to_riak_opts(Opts),

        case riakc_pb_socket:delete(Pid, TypeBucket, Key, ROpts) of
            ok -> ok;
            {error, {notfound, _}} -> {error, not_found};
            {error, _} = Error -> Error
        end
    end,

    case babel:execute(Poolname, Fun, Opts) of
        {ok, Result} -> Result;
        {error, _} = Error -> Error
    end.







%% =============================================================================
%% PRIVATE
%% =============================================================================



%% @private
typed_bucket(#babel_index_collection{bucket = Bucket}) ->
    Type = babel_config:get([bucket_types, index_collection]),
    {Type, Bucket};

typed_bucket(Prefix) ->
    Type = babel_config:get([bucket_types, index_collection]),
    Bucket = <<Prefix/binary, ?PATH_SEPARATOR, ?BUCKET_SUFFIX>>,
    {Type, Bucket}.


%% %% @private
%% on_delete(TypedBucket, Key) ->
%%     %% TODO WAMP Publication
%%     _URI = <<"org.babel.index_collection.deleted">>,
%%     _Args = [TypedBucket, Key],
%%     ok.


%% %% @private
%% on_update(TypedBucket, Key) ->
%%     %% TODO WAMP Publication
%%     _URI = <<"org.babel.index_collection.updated">>,
%%     _Args = [TypedBucket, Key],
%%     ok.
