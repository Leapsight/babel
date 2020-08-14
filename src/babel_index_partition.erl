%% -----------------------------------------------------------------------------
%% @doc
%% @end
%% -----------------------------------------------------------------------------
-module(babel_index_partition).
-include("babel.hrl").
-include_lib("riakc/include/riakc.hrl").

-type t()   ::  riakc_map:crdt_map().

-export_type([t/0]).

-export([created_ts/1]).
-export([data/1]).
-export([delete/4]).
-export([fetch/3]).
-export([fetch/4]).
-export([id/1]).
-export([last_updated_ts/1]).
-export([lookup/4]).
-export([new/1]).
-export([new/2]).
-export([size/1]).
-export([update_data/2]).
-export([store/4]).
-export([to_work_item/3]).



%% =============================================================================
%% API
%% =============================================================================



%% -----------------------------------------------------------------------------
%% @doc
%% @end
%% -----------------------------------------------------------------------------
-spec new(Id :: binary()) -> t().

new(Id) ->
    new(Id, []).


%% -----------------------------------------------------------------------------
%% @doc
%% @end
%% -----------------------------------------------------------------------------
-spec new(Id :: binary(), Data :: list()) -> t().

new(Id, Data) ->
    Ts = integer_to_binary(erlang:system_time(millisecond)),
    Values = [
        babel_crdt:map_entry(register, <<"id">>, Id),
        babel_crdt:map_entry(register, <<"created_ts">>, Ts),
        babel_crdt:map_entry(register, <<"last_updated_ts">>, Ts),
        babel_crdt:map_entry(map, <<"data">>, Data)
    ],
    riakc_map:new(Values, undefined).


%% -----------------------------------------------------------------------------
%% @doc
%% @end
%% -----------------------------------------------------------------------------
-spec id(Partition :: t()) -> binary() | no_return().

id(Partition) ->
    riakc_register:value(riakc_map:fetch({<<"id">>, register}, Partition)).


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
%% @doc Returns
%% @end
%% -----------------------------------------------------------------------------
-spec to_work_item(TypeBucket :: tuple(), Key :: binary(), Partition :: t()) ->
    reliable_storage_backend:work_item().

to_work_item(TypeBucket, Key, Partition) ->
    Args = [TypeBucket,  Key,  riakc_map:to_op(Partition)],
    {node(), riakc_pb_socket, update_type, [{symbolic, riakc} | Args]}.


%% -----------------------------------------------------------------------------
%% @doc
%% @end
%% -----------------------------------------------------------------------------
-spec store(
    Conn :: pid(),
    TypeBucket :: type_bucket(),
    Key :: binary(),
    Partition :: t()) ->
    ok | {error, any()}.

store(Conn, TypeBucket, Key, Partition) ->
    Opts = #{
        r => quorum,
        pr => quorum,
        notfound_ok => false,
        basic_quorum => true
    },
    Op = riakc_map:to_op(Partition),

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
    TypeBucket :: type_bucket(),
    Key :: binary()) ->
    {ok, t()} | no_return().

fetch(Conn, TypeBucket, Key) ->
    Opts = #{
        r => quorum,
        pr => quorum,
        notfound_ok => false,
        basic_quorum => true
    },
    fetch(Conn, TypeBucket, Key, Opts).


%% -----------------------------------------------------------------------------
%% @doc
%% @end
%% -----------------------------------------------------------------------------
-spec fetch(
    Conn :: pid(),
    TypeBucket :: type_bucket(),
    Key :: binary(),
    Opts :: req_opts()) ->
    {ok, t()} | no_return().

fetch(Conn, TypeBucket, Key, ReqOpts) ->
    Opts = validate_req_opts(ReqOpts),
    case lookup(Conn, TypeBucket, Key, Opts) of
        {ok, Value} -> Value;
        {error, Reason} -> error(Reason)
    end.


%% -----------------------------------------------------------------------------
%% @doc
%% @end
%% -----------------------------------------------------------------------------
-spec lookup(
    Conn :: pid(),
    TypeBucket :: type_bucket(),
    Key :: binary(),
    Opts :: req_opts()) ->
    {ok, t()} | {error, not_found | term()}.

lookup(Conn, TypeBucket, Key, ReqOpts) ->
    Opts = validate_req_opts(ReqOpts),
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
    TypeBucket :: type_bucket(),
    Key :: binary(),
    Opts :: req_opts()) ->
    ok | {error, not_found | term()}.

delete(Conn, TypeBucket, Key, ReqOpts) ->
    Opts = validate_req_opts(ReqOpts),
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
    maps:to_list(maps:validate(Opts, ?REQ_OPTS_SPEC)).