%% -----------------------------------------------------------------------------
%% @doc
%% @end
%% -----------------------------------------------------------------------------
-module(babel_index_partition).
-include("babel.hrl").
-include_lib("riakc/include/riakc.hrl").

-define(BUCKET_SUFFIX, "index_data").


-type t()   ::  riakc_map:crdt_map().

-export_type([t/0]).

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



%% =============================================================================
%% API
%% =============================================================================



%% -----------------------------------------------------------------------------
%% @doc
%% @end
%% -----------------------------------------------------------------------------
-spec new(Id :: binary()) -> t().

new(Id) ->
    Ts = integer_to_binary(erlang:system_time(millisecond)),

    Values = [
       {{<<"id">>, register}, Id},
       {{<<"created_ts">>, register}, Ts},
       {{<<"last_updated_ts">>, register}, Ts},
       {{<<"data">>, map}, riakc_map:new()}
    ],
    lists:foldl(
        fun({K, V}, Acc) ->
            babel_key_value:set(K, V, Acc)
        end,
        riakc_map:new(),
        Values
    ).


%% -----------------------------------------------------------------------------
%% @doc
%% @end
%% -----------------------------------------------------------------------------
-spec id(Partition :: t()) -> binary() | no_return().

id(Partition) ->
    riakc_register:value(
        babel_crdt:dirty_fetch({<<"id">>, register}, Partition)
    ).


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
-spec created_ts(Partition :: t()) -> non_neg_integer() | no_return().

created_ts(Partition) ->
    binary_to_integer(
        riakc_register:value(
            riakc_map:fetch({<<"created_ts">>, register}, Partition)
        )
    ).


%% -----------------------------------------------------------------------------
%% @doc
%% @end
%% -----------------------------------------------------------------------------
-spec last_updated_ts(Partition :: t()) -> non_neg_integer() | no_return().

last_updated_ts(Partition) ->
    binary_to_integer(
        riakc_register:value(
            riakc_map:fetch({<<"last_updated_ts">>, register}, Partition)
        )
    ).


%% -----------------------------------------------------------------------------
%% @doc
%% @end
%% -----------------------------------------------------------------------------
-spec data(Partition :: t()) -> riakc_map:crdt_map() | no_return().

data(Partition) ->
    riakc_map:fetch({<<"data">>, map}, Partition).


%% -----------------------------------------------------------------------------
%% @doc
%% @end
%% -----------------------------------------------------------------------------
-spec update_data(riakc_map:update_fun(), t()) -> t().

update_data(Fun, Partition0) ->
    Ts = integer_to_binary(erlang:system_time(millisecond)),
    Partition1 = riakc_map:update({<<"data">>, map}, Fun, Partition0),

    riakc_map:update(
        {<<"last_updated_ts">>, register},
        fun(R) -> riakc_register:set(Ts, R) end,
        Partition1
    ).


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
    Op = riakc_map:to_op(Partition),

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