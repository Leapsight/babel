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
%% ```
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

-record(babel_index_collection, {
    id      ::  binary(),
    bucket  ::  binary(),
    data    ::  data()
}).

-type t()           ::  #babel_index_collection{}.
-type data()        ::  riakc_map:crdt_map().

-export_type([t/0]).
-export_type([data/0]).
-export_type([req_opts/0]).


%% API
-export([add_index/2]).
-export([delete_index/2]).
-export([store/2]).
-export([store/3]).
-export([delete/3]).
-export([delete/4]).
-export([fetch/3]).
-export([fetch/4]).
-export([new/2]).
-export([new/3]).
-export([index/2]).
-export([lookup/3]).
-export([lookup/4]).
-export([size/1]).
-export([id/1]).
-export([bucket/1]).
-export([data/1]).
-export([to_work_item/1]).




%% =============================================================================
%% API
%% =============================================================================



%% -----------------------------------------------------------------------------
%% @doc Takes a list of pairs (property list) or map of binary keys to values
%% of type `babel_index:t()' and returns an index collection.
%% @end
%% -----------------------------------------------------------------------------
-spec new(BucketPrefix :: binary(), Name :: binary()) -> t().

new(BucketPrefix, Name) ->
    new(BucketPrefix, Name, []).


%% -----------------------------------------------------------------------------
%% @doc Takes a list of pairs (property list) or map of binary keys to values
%% of type `babel_index:t()' and returns an index collection.
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
%% @doc Returns the number of elements in the collection `Collection'.
%% @end
%% -----------------------------------------------------------------------------
-spec size(Collection :: t()) -> non_neg_integer().

size(#babel_index_collection{} = Collection) ->
    Data = Collection#babel_index_collection.data,
    riakc_map:size(Data).


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
%% @doc Returns the babel index associated with key `Key' in collection
%% `Collection'. This function assumes that the key is present in the
%% collection. An exception is generated if the key is not in the collection.
%% @end
%% -----------------------------------------------------------------------------
-spec index(Key :: binary(), Collection :: t()) -> babel_index:t().

index(Key, #babel_index_collection{} = Collection) when is_binary(Key) ->
    Data = Collection#babel_index_collection.data,
    babel_crdt:dirty_fetch({Key, map}, Data).


%% -----------------------------------------------------------------------------
%% @doc
%% @end
%% -----------------------------------------------------------------------------
-spec add_index(Index :: babel_index:t(), Collection :: t()) ->
    t() | no_return().

add_index(Index, #babel_index_collection{} = Collection) ->
    IndexId = babel_index:id(Index),
    RiakMap = babel_index:to_crdt(Index),
    Data0 = Collection#babel_index_collection.data,
    Data = riakc_map:update({IndexId, map}, fun(_) -> RiakMap end, Data0),

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
%% @doc Returns
%% @end
%% -----------------------------------------------------------------------------
-spec to_work_item(Collection :: t()) ->
    babel:work_item().

to_work_item(#babel_index_collection{} = Collection) ->
    Key = Collection#babel_index_collection.id,
    Data = Collection#babel_index_collection.data,
    TypedBucket = typed_bucket(Collection),
    Args = [TypedBucket, Key, riakc_map:to_op(Data)],
    {node(), riakc_pb_socket, update_type, [{symbolic, riakc} | Args]}.



%% -----------------------------------------------------------------------------
%% @doc Stores an index collection in Riak KV under a bucket name which results
%% from contenating the prefix `BucketPrefix' to suffix "/index_collection" and
%% key `Key'.
%% @end
%% -----------------------------------------------------------------------------
-spec store(Conn :: pid(), Collection :: t()) ->
    {ok, Index :: t()} | {error, Reason :: any()}.


store(Conn, Collection) ->
    ReqOpts = #{
        w => quorum,
        pw => quorum
    },
    store(Conn, Collection, ReqOpts).


%% -----------------------------------------------------------------------------
%% @doc Stores an index collection in Riak KV under a bucket name which results
%% from contenating the prefix `BucketPrefix' to suffix "/index_collection" and
%% key `Key'.
%% @end
%% -----------------------------------------------------------------------------
-spec store(Conn :: pid(), Collection :: t(), ReqOpts :: req_opts()) ->
    {ok, Index :: t()} | {error, Reason :: any()}.


store(Conn, Collection, ReqOpts) when is_pid(Conn) ->
    Opts = validate_req_opts(ReqOpts),
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
    Conn :: pid(),
    BucketPrefix :: binary(),
    Key :: binary()) ->
    t() | no_return().

fetch(Conn, BucketPrefix, Key) ->
    ReqOpts = #{
        r => quorum,
        pr => quorum
    },
    fetch(Conn, BucketPrefix, Key, ReqOpts).


%% -----------------------------------------------------------------------------
%% @doc
%% @end
%% -----------------------------------------------------------------------------
-spec fetch(
    Conn :: pid(),
    BucketPrefix :: binary(),
    Key :: binary(),
    Opts :: req_opts()) ->
    t() | no_return().

fetch(Conn, BucketPrefix, Key, ReqOpts) ->
    case lookup(Conn, BucketPrefix, Key, ReqOpts) of
        {ok, Value} -> Value;
        {error, Reason} -> error(Reason)
    end.


%% -----------------------------------------------------------------------------
%% @doc
%% @end
%% -----------------------------------------------------------------------------
-spec lookup(
    Conn :: pid(),
    BucketPrefix :: binary(),
    Key :: binary()) ->
    {ok, t()} | {error, not_found | term()}.

lookup(Conn, BucketPrefix, Key) ->
    ReqOpts = #{
        r => quorum,
        pr => quorum
    },
    lookup(Conn, BucketPrefix, Key, ReqOpts).


%% -----------------------------------------------------------------------------
%% @doc
%% @end
%% -----------------------------------------------------------------------------
-spec lookup(
    Conn :: pid(),
    BucketPrefix :: binary(),
    Key :: binary(),
    Opts :: req_opts()) ->
    {ok, t()} | {error, not_found | term()}.

lookup(Conn, BucketPrefix, Key, ReqOpts)
when is_pid(Conn) andalso is_binary(BucketPrefix) andalso is_binary(Key) ->
    Opts = validate_req_opts(ReqOpts),
    TypeBucket = typed_bucket(BucketPrefix),

    case riakc_pb_socket:fetch_type(Conn, TypeBucket, Key, Opts) of
        {ok, _} = OK -> OK;
        {error, {notfound, _}} -> {error, not_found};
        {error, _} = Error -> Error
    end.


%% -----------------------------------------------------------------------------
%% @doc
%% @end
%% -----------------------------------------------------------------------------
-spec delete(
    Conn :: pid(),
    BucketPrefix :: binary(),
    Key :: binary()) ->
    ok | {error, not_found | term()}.

delete(Conn, BucketPrefix, Key) ->
    ReqOpts = #{
        r => quorum,
        w => quorum,
        pr => quorum,
        pw => quorum
    },
    delete(Conn, BucketPrefix, Key, ReqOpts).


%% -----------------------------------------------------------------------------
%% @doc
%% @end
%% -----------------------------------------------------------------------------
-spec delete(
    Conn :: pid(),
    BucketPrefix :: binary(),
    Key :: binary(),
    Opts :: req_opts()) ->
    ok | {error, not_found | term()}.

delete(Conn, BucketPrefix, Key, ReqOpts)
when is_pid(Conn) andalso is_binary(BucketPrefix) andalso is_binary(Key) ->
    Opts = validate_req_opts(ReqOpts),
    TypeBucket = typed_bucket(BucketPrefix),

    case riakc_pb_socket:delete(Conn, TypeBucket, Key, Opts) of
        ok -> ok;
        {error, {notfound, _}} -> {error, not_found};
        {error, _} = Error -> Error
    end.



%% =============================================================================
%% PRIVATE
%% =============================================================================



%% -----------------------------------------------------------------------------
%% @private
%% @doc Validates and returns the options in proplist format as expected by
%% Riak KV.
%% @end
%% -----------------------------------------------------------------------------
validate_req_opts(Opts) ->
    maps:to_list(maps_utils:validate(Opts, ?REQ_OPTS_SPEC)).


%% @private
typed_bucket(#babel_index_collection{bucket = Bucket}) ->
    Type = babel_config:get([bucket_types, index_collection]),
    {Type, Bucket};

typed_bucket(Prefix) ->
    Type = babel_config:get([bucket_types, index_collection]),
    Bucket = <<Prefix/binary, ?PATH_SEPARATOR, ?BUCKET_SUFFIX>>,
    {Type, Bucket}.