%% -----------------------------------------------------------------------------
%% @doc
%% @end
%% -----------------------------------------------------------------------------
-module(babel_index_partition).
-include("babel.hrl").
-include_lib("riakc/include/riakc.hrl").

-define(BUCKET_SUFFIX, "index_data").

-record(babel_index_partition, {
    id                      ::  binary(),
    created_ts              ::  non_neg_integer(),
    last_updated_ts         ::  non_neg_integer(),
    object                  ::  riak_object()
}).

-type t()                   ::  #babel_index_partition{}.
-type riak_object()         ::  riakc_map:crdt_map().
-type data()                ::  riakc_map:crdt_map().

-export_type([t/0]).
-export_type([riak_object/0]).

-export([created_ts/1]).
-export([data/1]).
-export([delete/4]).
-export([fetch/3]).
-export([fetch/4]).
-export([from_riak_object/1]).
-export([id/1]).
-export([last_updated_ts/1]).
-export([lookup/3]).
-export([lookup/4]).
-export([new/1]).
-export([size/1]).
-export([store/5]).
-export([to_riak_object/1]).
-export([update_data/2]).



%% =============================================================================
%% API
%% =============================================================================



%% -----------------------------------------------------------------------------
%% @doc
%% @end
%% -----------------------------------------------------------------------------
-spec new(Id :: binary()) -> t().

new(Id) ->
    Ts = erlang:system_time(millisecond),
    Object = riakc_map:update(
        {<<"data">>, map}, fun(Data) -> Data end, riakc_map:new()
    ),

    #babel_index_partition{
        id = Id,
        created_ts = Ts,
        last_updated_ts = Ts,
        object = Object
    }.



%% -----------------------------------------------------------------------------
%% @doc
%% @end
%% -----------------------------------------------------------------------------
-spec from_riak_object(Object :: riak_object()) -> Partition :: t().

from_riak_object(Object) ->
    Id = babel_crdt:register_to_binary(
        riakc_map:fetch({<<"id">>, register}, Object)
    ),
    Created = babel_crdt:register_to_integer(
        riakc_map:fetch({<<"created_ts">>, register}, Object)
    ),
    LastUpdated = babel_crdt:register_to_integer(
        riakc_map:fetch({<<"last_updated_ts">>, register}, Object)
    ),

    #babel_index_partition{
        id = Id,
        created_ts = Created,
        last_updated_ts = LastUpdated,
        object = Object
    }.


%% -----------------------------------------------------------------------------
%% @doc
%% @end
%% -----------------------------------------------------------------------------
-spec to_riak_object(Index :: t()) -> IndexCRDT :: riak_object().

to_riak_object(#babel_index_partition{} = Partition) ->
    #babel_index_partition{
        id = Id,
        created_ts = Created,
        last_updated_ts = LastUpdated,
        object = Object
    } = Partition,

    Values = [
        {{<<"id">>, register}, Id},
        {{<<"created_ts">>, register}, integer_to_binary(Created)},
        {{<<"last_updated_ts">>, register}, integer_to_binary(LastUpdated)}
    ],


    lists:foldl(
        fun({K, V}, Acc) -> babel_key_value:set(K, V, Acc) end,
        Object,
        Values
    ).



%% -----------------------------------------------------------------------------
%% @doc
%% @end
%% -----------------------------------------------------------------------------
-spec id(Partition :: t()) -> binary() | no_return().

id(#babel_index_partition{id = Value}) -> Value.


%% -----------------------------------------------------------------------------
%% @doc
%% @end
%% -----------------------------------------------------------------------------
-spec size(Partition :: t()) -> non_neg_integer().

size(Partition) ->
    riakc_map:size(data(Partition)).


%% -----------------------------------------------------------------------------
%% @doc
%% @end
%% -----------------------------------------------------------------------------
-spec created_ts(Partition :: t()) -> non_neg_integer().

created_ts(#babel_index_partition{created_ts = Value}) -> Value.


%% -----------------------------------------------------------------------------
%% @doc
%% @end
%% -----------------------------------------------------------------------------
-spec last_updated_ts(Partition :: t()) -> non_neg_integer().

last_updated_ts(#babel_index_partition{last_updated_ts = Value}) -> Value.


%% -----------------------------------------------------------------------------
%% @doc
%% @end
%% -----------------------------------------------------------------------------
-spec data(Partition :: t()) -> data().

data(#babel_index_partition{object = Object}) ->
    babel_crdt:dirty_fetch({<<"data">>, map}, Object).


%% -----------------------------------------------------------------------------
%% @doc
%% @end
%% -----------------------------------------------------------------------------
-spec update_data(riakc_map:update_fun(), t()) -> t().

update_data(Fun, #babel_index_partition{} = Partition) ->
    Ts = erlang:system_time(millisecond),
    Object = riakc_map:update(
        {<<"data">>, map}, Fun, Partition#babel_index_partition.object
    ),

    Partition#babel_index_partition{
        last_updated_ts = Ts,
        object = Object
    }.


%% -----------------------------------------------------------------------------
%% @doc
%% @end
%% -----------------------------------------------------------------------------
-spec store(
    BucketType :: binary(),
    BucketPrefix :: binary(),
    Key :: binary(),
    Partition :: t(),
    RiakOpts :: riak_opts()) ->
    ok | {error, any()}.

store(BucketType, BucketPrefix, Key, Partition, RiakOpts) ->
    Opts0 = RiakOpts#{
        r => quorum,
        pr => quorum,
        notfound_ok => false,
        basic_quorum => true
    },

    Opts1 = babel:validate_riak_opts(Opts0),
    ReqOpts = maps:to_list(maps:without([connection], Opts1)),
    Conn = babel:get_connection(Opts1),
    TypeBucket = type_bucket(BucketType, BucketPrefix),
    Op = riakc_map:to_op(to_riak_object(Partition)),

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
    TypedBucket :: {binary(), binary()},
    Key :: binary(),
    RiakOpts :: riak_opts()) ->
    t() | no_return().

fetch(TypedBucket, Key, RiakOpts) ->
    Opts = RiakOpts#{
        r => quorum,
        pr => quorum,
        notfound_ok => false,
        basic_quorum => true
    },
    case lookup(TypedBucket, Key, Opts) of
        {ok, Value} -> Value;
        {error, Reason} -> error(Reason)
    end.


%% -----------------------------------------------------------------------------
%% @doc
%% @end
%% -----------------------------------------------------------------------------
-spec fetch(
    BucketType :: binary(),
    BucketPrefix :: binary(),
    Key :: binary(),
    RiakOpts :: riak_opts()) ->
    t() | no_return().

fetch(BucketType, BucketPrefix, Key, RiakOpts) ->
    Opts = RiakOpts#{
        r => quorum,
        pr => quorum,
        notfound_ok => false,
        basic_quorum => true
    },
    case lookup(BucketType, BucketPrefix, Key, Opts) of
        {ok, Value} -> Value;
        {error, Reason} -> error(Reason)
    end.





%% -----------------------------------------------------------------------------
%% @doc
%% @end
%% -----------------------------------------------------------------------------
-spec lookup(
    TypedBucket :: {binary(), binary()},
    Key :: binary(),
    Opts :: riak_opts()) ->
    {ok, t()} | {error, not_found | term()}.

lookup(TypedBucket, Key, RiakOpts) ->
    Opts = babel:validate_riak_opts(RiakOpts),
    ReqOpts = maps:to_list(maps:without([connection], Opts)),
    Conn = babel:get_connection(Opts),

    case riakc_pb_socket:fetch_type(Conn, TypedBucket, Key, ReqOpts) of
        {ok, Object} ->
            {ok, from_riak_object(Object)};
        {error, {notfound, _}} ->
            {error, not_found};
        {error, _} = Error ->
            Error
    end.

%% -----------------------------------------------------------------------------
%% @doc
%% @end
%% -----------------------------------------------------------------------------
-spec lookup(
    BucketType :: binary(),
    BucketPrefix :: binary(),
    Key :: binary(),
    Opts :: riak_opts()) ->
    {ok, t()} | {error, not_found | term()}.

lookup(BucketType, BucketPrefix, Key, RiakOpts) ->
    TypedBucket = type_bucket(BucketType, BucketPrefix),
    lookup(TypedBucket, Key, RiakOpts).


%% -----------------------------------------------------------------------------
%% @doc
%% @end
%% -----------------------------------------------------------------------------
-spec delete(
    BucketType :: binary(),
    BucketPrefix :: binary(),
    Key :: binary(),
    Opts :: riak_opts()) ->
    ok | {error, not_found | term()}.

delete(BucketType, BucketPrefix, Key, RiakOpts) ->
    Opts = babel:validate_riak_opts(RiakOpts),
    ReqOpts = maps:to_list(maps:without([connection], Opts)),
    Conn = babel:get_connection(Opts),
    TypeBucket = type_bucket(BucketType, BucketPrefix),

    case riakc_pb_socket:delete(Conn, TypeBucket, Key, ReqOpts) of
        ok -> ok;
        {error, {notfound, _}} -> {error, not_found};
        {error, _} = Error -> Error
    end.



%% =============================================================================
%% PRIVATE
%% =============================================================================


%% @private
type_bucket(Type, Prefix) ->
    Bucket = <<Prefix/binary, ?PATH_SEPARATOR, ?BUCKET_SUFFIX>>,
    {Type, Bucket}.