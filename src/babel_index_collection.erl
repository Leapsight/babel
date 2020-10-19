%% =============================================================================
%%  babel_index_collection.erl -
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
    id      ::  binary(),
    bucket  ::  binary(),
    object  ::  riak_object()
}).

-type t()           ::  #babel_index_collection{}.
-type riak_object() ::  riakc_map:crdt_map().
-type data()        ::  riakc_map:crdt_map().

-export_type([t/0]).
-export_type([riak_object/0]).
-export_type([data/0]).
-export_type([riak_opts/0]).


%% API
-export([add_index/2]).
-export([bucket/1]).
-export([data/1]).
-export([delete/3]).
-export([delete_index/2]).
-export([fetch/3]).
-export([from_riak_object/1]).
-export([id/1]).
-export([index/2]).
-export([index_names/1]).
-export([indices/1]).
-export([lookup/3]).
-export([new/2]).
-export([size/1]).
-export([store/2]).
-export([to_delete_item/1]).
-export([to_riak_object/1]).
-export([to_update_item/1]).


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
    Object = riakc_map:update(
        {<<"data">>, map}, fun(Data) -> Data end, riakc_map:new()
    ),

    #babel_index_collection{
        id = Name,
        bucket = <<BucketPrefix/binary, ?PATH_SEPARATOR, ?BUCKET_SUFFIX>>,
        object = Object
    }.


%% -----------------------------------------------------------------------------
%% @doc
%% @end
%% -----------------------------------------------------------------------------
-spec from_riak_object(Object :: riak_object()) -> Collection :: t().

from_riak_object(Object) ->
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

to_riak_object(#babel_index_collection{} = Collection) ->
    #babel_index_collection{
        id = Id,
        bucket = Bucket,
        object = Object
    } = Collection,

    Values = [
        {{<<"id">>, register}, Id},
        {{<<"bucket">>, register}, Bucket}
    ],

    lists:foldl(
        fun({K, V}, Acc) -> babel_key_value:set(K, V, Acc) end,
        Object,
        Values
    ).


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
-spec data(Collection :: t()) -> data().

data(#babel_index_collection{object = Object}) ->
    riakc_map:fetch({<<"data">>, map}, Object).


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
        _:_ ->
            error(badindex)
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
        Data ->
            Fun = fun({K, map}, _, Acc) -> [K | Acc] end,
            lists:reverse(orddict:fold(Fun, [], Data))
    catch
        error:function_clause ->
            []
    end.



%% -----------------------------------------------------------------------------
%% @doc
%% @end
%% -----------------------------------------------------------------------------
-spec add_index(Index :: babel_index:t(), Collection :: t()) ->
    t() | no_return().

add_index(Index, #babel_index_collection{} = Collection) ->
    IndexId = babel_index:name(Index),
    IndexObject = babel_index:to_riak_object(Index),
    Object = riakc_map:update(
        {<<"data">>, map},
        fun(Data) ->
            riakc_map:update({IndexId, map}, fun(_) -> IndexObject end, Data)
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
        fun(Data) -> riakc_map:erase({IndexId, map}, Data) end,
        Collection#babel_index_collection.object
    ),

    Collection#babel_index_collection{object = Object};

delete_index(Index, Collection) ->
    delete_index(babel_index:name(Index), Collection).



%% -----------------------------------------------------------------------------
%% @doc
%% @end
%% -----------------------------------------------------------------------------
-spec to_update_item(Collection :: t()) ->
    babel:work_item().

to_update_item(#babel_index_collection{} = Collection) ->
    Key = Collection#babel_index_collection.id,
    Object = to_riak_object(Collection),
    TypedBucket = typed_bucket(Collection),
    Args = [TypedBucket, Key, riakc_map:to_op(Object)],
    {node(), riakc_pb_socket, update_type, [{symbolic, riakc} | Args]}.


%% -----------------------------------------------------------------------------
%% @doc
%% @end
%% -----------------------------------------------------------------------------
-spec to_delete_item(Collection :: t()) ->
    babel:work_item().

to_delete_item(#babel_index_collection{} = Collection) ->
    Key = Collection#babel_index_collection.id,
    TypedBucket = typed_bucket(Collection),
    Args = [TypedBucket, Key],
    {node(), riakc_pb_socket, delete, [{symbolic, riakc} | Args]}.





%% -----------------------------------------------------------------------------
%% @doc Stores an index collection in Riak KV.
%% The collection will be stored under the bucket type configured
%% for the application option `index_collection_bucket_type', bucket name
%% will be the value returned by {@link bucket/1}, and the key will be the
%% value returned by {@link id/1}.
%% @end
%% -----------------------------------------------------------------------------
-spec store(Collection :: t(), RiakOpts :: riak_opts()) ->
    {ok, Index :: t()} | {error, Reason :: any()}.


store(Collection, RiakOpts) ->
    Opts = babel:validate_riak_opts(RiakOpts),
    Conn = babel:get_connection(Opts),
    ReqOpts = babel_utils:opts_to_riak_opts(Opts),

    Key = Collection#babel_index_collection.id,
    Object = Collection#babel_index_collection.object,
    TypeBucket = typed_bucket(Collection),
    Op = riakc_map:to_op(Object),


    case riakc_pb_socket:update_type(Conn, TypeBucket, Key, Op, ReqOpts) of
        {error, _} = Error ->
            Error;
        _ ->
            ok
    end.


%% -----------------------------------------------------------------------------
%% @doc
%% @end
%% -----------------------------------------------------------------------------
-spec fetch(
    BucketPrefix :: binary(),
    Key :: binary(),
    RiakOpts :: riak_opts()) ->
    t() | no_return().

fetch(BucketPrefix, Key, RiakOpts) ->
    Opts = RiakOpts#{
        r => quorum,
        pr => quorum
    },
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
    Opts :: riak_opts()) ->
    {ok, t()} | {error, not_found | term()}.

lookup(BucketPrefix, Key, RiakOpts)
when is_binary(BucketPrefix) andalso is_binary(Key) ->

    Opts0 = babel:validate_riak_opts(RiakOpts),
    Conn = babel:get_connection(Opts0),

    Opts1 = Opts0#{
        r => quorum,
        pr => quorum
    },
    ReqOpts = babel_utils:opts_to_riak_opts(Opts1),
    TypeBucket = typed_bucket(BucketPrefix),

    case riakc_pb_socket:fetch_type(Conn, TypeBucket, Key, ReqOpts) of
        {ok, Object} -> {ok, from_riak_object(Object)};
        {error, {notfound, _}} -> {error, not_found};
        {error, _} = Error -> Error
    end.


%% -----------------------------------------------------------------------------
%% @doc
%% @end
%% -----------------------------------------------------------------------------
-spec delete(
    BucketPrefix :: binary(),
    Key :: binary(),
    Opts :: riak_opts()) ->
    ok | {error, not_found | term()}.

delete(BucketPrefix, Key, ReqOpts)
when is_binary(BucketPrefix) andalso is_binary(Key) ->
    Opts0 = babel:validate_riak_opts(ReqOpts),
    Conn = babel:get_connection(Opts0),
    Opts1 = Opts0#{
        r => quorum,
        w => quorum,
        pr => quorum,
        pw => quorum
    },
    RiakOpts = babel_utils:opts_to_riak_opts(Opts1),
    TypeBucket = typed_bucket(BucketPrefix),

    case riakc_pb_socket:delete(Conn, TypeBucket, Key, RiakOpts) of
        ok -> ok;
        {error, {notfound, _}} -> {error, not_found};
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


%% @private
on_delete(TypedBucket, Key) ->
    %% TODO WAMP Publication
    _URI = <<"org.babel.index_collection.deleted">>,
    _Args = [TypedBucket, Key],
    ok.


%% @private
on_update(TypedBucket, Key) ->
    %% TODO WAMP Publication
    _URI = <<"org.babel.index_collection.updated">>,
    _Args = [TypedBucket, Key],
    ok.