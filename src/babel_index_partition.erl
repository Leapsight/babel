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
    data                    ::  riakc_map:crdt_map()
}).

-type t()                   ::  #babel_index_partition{}.
-type riak_object()         ::  riakc_map:crdt_map().

-export_type([t/0]).
-export_type([riak_object/0]).

-export([created_ts/1]).
-export([data/1]).
-export([delete/5]).
-export([fetch/4]).
-export([fetch/5]).
-export([id/1]).
-export([last_updated_ts/1]).
-export([lookup/5]).
-export([new/1]).
-export([size/1]).
-export([update_data/2]).
-export([store/5]).
-export([from_riak_object/1]).
-export([to_riak_object/1]).



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

    #babel_index_partition{
        id = Id,
        created_ts = Ts,
        last_updated_ts = Ts,
        data = riakc_map:new()
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
    Data = riakc_map:fetch({<<"data">>, map}, Object),

    #babel_index_partition{
        id = Id,
        created_ts = Created,
        last_updated_ts = LastUpdated,
        data = Data
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
        data = Data
    } = Partition,

    Values = [
        {{<<"id">>, register}, Id},
        {{<<"created_ts">>, register}, integer_to_binary(Created)},
        {{<<"last_updated_ts">>, register}, integer_to_binary(LastUpdated)},
        {{<<"config">>, map}, Data}
    ],

    lists:foldl(
        fun({K, V}, Acc) -> babel_key_value:set(K, V, Acc) end,
        riakc_map:new(),
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
-spec data(Partition :: t()) -> riakc_map:crdt_map().

data(#babel_index_partition{data = Value}) -> Value.


%% -----------------------------------------------------------------------------
%% @doc
%% @end
%% -----------------------------------------------------------------------------
-spec update_data(riakc_map:update_fun(), t()) -> t().

update_data(Fun, #babel_index_partition{} = Partition) ->
    Ts = erlang:system_time(millisecond),
    Data0 = Partition#babel_index_partition.data,
    Data1 = riakc_map:update({<<"data">>, map}, Fun, Data0),

    Partition#babel_index_partition{
        last_updated_ts = Ts,
        data = Data1
    }.


%% -----------------------------------------------------------------------------
%% @doc
%% @end
%% -----------------------------------------------------------------------------
-spec store(
    Conn :: pid(),
    BucketType :: binary(),
    BucketPrefix :: binary(),
    Key :: binary(),
    Partition :: t()) ->
    ok | {error, any()}.

store(Conn, BucketType, BucketPrefix, Key, Partition) ->
    Opts = #{
        r => quorum,
        pr => quorum,
        notfound_ok => false,
        basic_quorum => true
    },

    Op = riakc_map:to_op(to_riak_object(Partition)),

    TypeBucket = type_bucket(BucketType, BucketPrefix),

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
    BucketType :: binary(),
    BucketPrefix :: binary(),
    Key :: binary()) ->
    t() | no_return().

fetch(Conn, BucketType, BucketPrefix, Key) ->
    Opts = #{
        r => quorum,
        pr => quorum,
        notfound_ok => false,
        basic_quorum => true
    },
    fetch(Conn, BucketType, BucketPrefix, Key, Opts).


%% -----------------------------------------------------------------------------
%% @doc
%% @end
%% -----------------------------------------------------------------------------
-spec fetch(
    Conn :: pid(),
    BucketType :: binary(),
    BucketPrefix :: binary(),
    Key :: binary(),
    Opts :: req_opts()) ->
    t() | no_return().

fetch(Conn, BucketType, BucketPrefix, Key, ReqOpts) ->
    case lookup(Conn, BucketType, BucketPrefix, Key, ReqOpts) of
        {ok, Value} -> Value;
        {error, Reason} -> error(Reason)
    end.


%% -----------------------------------------------------------------------------
%% @doc
%% @end
%% -----------------------------------------------------------------------------
-spec lookup(
    Conn :: pid(),
    BucketType :: binary(),
    BucketPrefix :: binary(),
    Key :: binary(),
    Opts :: req_opts()) ->
    {ok, t()} | {error, not_found | term()}.

lookup(Conn, BucketType, BucketPrefix, Key, ReqOpts) ->
    Opts = validate_req_opts(ReqOpts),
    TypeBucket = type_bucket(BucketType, BucketPrefix),

    case riakc_pb_socket:fetch_type(Conn, TypeBucket, Key, Opts) of
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
-spec delete(
    Conn :: pid(),
    BucketType :: binary(),
    BucketPrefix :: binary(),
    Key :: binary(),
    Opts :: req_opts()) ->
    ok | {error, not_found | term()}.

delete(Conn, BucketType, BucketPrefix, Key, ReqOpts) ->
    Opts = validate_req_opts(ReqOpts),
    TypeBucket = type_bucket(BucketType, BucketPrefix),
    case riakc_pb_socket:delete(Conn, TypeBucket, Key, Opts) of
        ok -> ok;
        {error, {notfound, _}} -> {error, not_found};
        {error, _} = Error -> Error
    end.



%% =============================================================================
%% PRIVATE
%% =============================================================================



%%-----------------------------------------------------------------------------
%% @private
%% @doc Validates and returns the options in proplist format as expected by
%% Riak KV.
%% @end
%% -----------------------------------------------------------------------------
validate_req_opts(Opts) ->
    maps:to_list(maps_utils:validate(Opts, ?REQ_OPTS_SPEC)).


%% @private
type_bucket(Type, Prefix) ->
    Bucket = <<Prefix/binary, ?PATH_SEPARATOR, ?BUCKET_SUFFIX>>,
    {Type, Bucket}.