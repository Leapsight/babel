%% -----------------------------------------------------------------------------
%% @doc A babel_index_collection is a Riak Map, that maps
%% binary keys to {@link babel_index} objects (also a Riak Map).
%%
%% Keys typically represent a resource (or entity) name in your domain model
%% e.g. accounts, users.
%%
%% A babel collection object is stored in Riak KV under a bucket_type that
%% should be defined through configuration using the
%% `index_collection_bucket_type' configuration option; and a bucket name which
%% results from concatenating a prefix provided as argument in this module
%% functions a key separator and the suffix "_index_collection".
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
%% `index_collection_bucket_type' maps to "my_index_collection" bucket type
%% name.
%%
%% ```shell
%% riak-admin bucket-type create my_index_collection '{"props":
%% {"datatype":"map",
%% "n_val":3, "pw":"quorum", "pr":"quorum", "notfound_ok":false,
%% "basic_quorum":true}}'
%% riak-admin bucket-type activate my_index_collection
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
-include_lib("riakc/include/riakc.hrl").

-define(BUCKET_SUFFIX, "index_collection").

%% TODO Map <-> CRDT
%% we need to store objects with local update capability that will apply
%% changes to the CRDT on to_riak_object.
%% This is to be able to operate with them before they are store in RIAK as we
%% are delyaing storage via Reliable
-record(babel_index_collection, {
    id      ::  binary(),
    bucket  ::  binary(),
    data    ::  data()
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
-export([indices/1]).
-export([lookup/3]).
-export([new/2]).
-export([new/3]).
-export([size/1]).
-export([store/2]).
-export([to_delete_item/1]).
-export([to_riak_object/1]).
-export([to_update_item/1]).


%% =============================================================================
%% API
%% =============================================================================



%% -----------------------------------------------------------------------------
%% @doc
%% @end
%% -----------------------------------------------------------------------------
-spec new(BucketPrefix :: binary(), Name :: binary()) -> t().

new(BucketPrefix, Name) ->
    new(BucketPrefix, Name, []).


%% -----------------------------------------------------------------------------
%% @doc
%% @end
%% -----------------------------------------------------------------------------
-spec new(
    BucketPrefix :: binary(),
    Name :: binary(),
    Indices :: [{binary(), babel_index:t()}]) -> t().

new(BucketPrefix, Name, Indices) when is_list(Indices) ->
    Values = [babel_crdt:map_entry(map, K, V) || {K, V} <- Indices],
    #babel_index_collection{
        id = Name,
        bucket = BucketPrefix,
        data = riakc_map:new(Values, undefined)
    };

new(BucketPrefix, Name, Indices) when is_map(Indices) ->
    new(BucketPrefix, Name, maps:to_list(Indices)).



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
    Data = riakc_map:fetch({<<"data">>, map}, Object),

    #babel_index_collection{
        id = Id,
        bucket = Bucket,
        data = Data
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
        data = Data
    } = Collection,

    Values = [
        {{<<"id">>, register}, Id},
        {{<<"bucket">>, register}, Bucket},
        {{<<"data">>, map}, Data}
    ],

    lists:foldl(
        fun({K, V}, Acc) -> babel_key_value:set(K, V, Acc) end,
        riakc_map:new(),
        Values
    ).


%% -----------------------------------------------------------------------------
%% @doc Returns the number of elements in the collection `Collection'.
%% @end
%% -----------------------------------------------------------------------------
-spec size(Collection :: t()) -> non_neg_integer().

size(Collection) ->
    riakc_map:size(data(Collection)).


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

data(#babel_index_collection{data = Value}) -> Value.


%% -----------------------------------------------------------------------------
%% @doc Returns the babel index associated with name `IndexName' in collection
%% `Collection'. This function assumes that the name is present in the
%% collection. An exception is generated if it is not.
%% @end
%% -----------------------------------------------------------------------------
-spec index(IndexName :: binary(), Collection :: t()) ->
    babel_index:t() | error.

index(IndexName, #babel_index_collection{} = Collection)
when is_binary(IndexName) ->
    Data = Collection#babel_index_collection.data,
    try babel_crdt:dirty_fetch({IndexName, map}, Data) of
        Object ->
            babel_index:from_riak_object(Object)
    catch
        _:_ ->
            error
    end.



%% -----------------------------------------------------------------------------
%% @doc Returns all the indices in the collection.
%% @end
%% -----------------------------------------------------------------------------
-spec indices(Collection :: t()) -> [babel_index:t()].

indices(#babel_index_collection{} = Collection) ->
    Data = Collection#babel_index_collection.data,
    Keys = babel_crdt:dirty_fetch_keys(Data),
    [
        babel_index:from_riak_object(babel_crdt:dirty_fetch(Key, Data))
        || Key <- Keys
    ].


%% -----------------------------------------------------------------------------
%% @doc
%% @end
%% -----------------------------------------------------------------------------
-spec add_index(Index :: babel_index:t(), Collection :: t()) ->
    t() | no_return().

add_index(Index, #babel_index_collection{} = Collection) ->
    IndexId = babel_index:name(Index),
    Object = babel_index:to_riak_object(Index),
    Data0 = Collection#babel_index_collection.data,
    Data = riakc_map:update({IndexId, map}, fun(_) -> Object end, Data0),

    Collection#babel_index_collection{data = Data}.


%% -----------------------------------------------------------------------------
%% @doc
%% @end
%% -----------------------------------------------------------------------------
-spec delete_index(Id :: binary(), Collection :: t()) ->
    t() | no_return().

delete_index(Id, #babel_index_collection{} = Collection) ->
    Data = Collection#babel_index_collection.data,
    Collection#babel_index_collection{data = riakc_map:erase({Id, map}, Data)}.



%% -----------------------------------------------------------------------------
%% @doc
%% @end
%% -----------------------------------------------------------------------------
-spec to_update_item(Collection :: t()) ->
    babel:work_item().

to_update_item(#babel_index_collection{} = Collection) ->
    Key = Collection#babel_index_collection.id,
    Data = Collection#babel_index_collection.data,
    TypedBucket = typed_bucket(Collection),
    Args = [TypedBucket, Key, riakc_map:to_op(Data)],
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
%% @doc Stores an index collection in Riak KV under a bucket name which results
%% from contenating the prefix `BucketPrefix' to suffix "/index_collection" and
%% key `Key'.
%% @end
%% -----------------------------------------------------------------------------
-spec store(Collection :: t(), RiakOpts :: riak_opts()) ->
    {ok, Index :: t()} | {error, Reason :: any()}.


store(Collection, RiakOpts) ->
    Opts = babel:validate_riak_opts(RiakOpts),
    Conn = babel:get_connection(Opts),

    Key = Collection#babel_index_collection.id,
    Data = Collection#babel_index_collection.data,
    TypeBucket = typed_bucket(Collection),
    Op = riakc_map:to_op(Data),

    case riakc_pb_socket:update_type(Conn, TypeBucket, Key, Op, Opts) of
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
    TypeBucket = typed_bucket(BucketPrefix),

    case riakc_pb_socket:fetch_type(Conn, TypeBucket, Key, Opts1) of
        {ok, _} = OK -> from_riak_object(OK);
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
    TypeBucket = typed_bucket(BucketPrefix),

    case riakc_pb_socket:delete(Conn, TypeBucket, Key, Opts1) of
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