%% -----------------------------------------------------------------------------
%% @doc
%% @end
%% -----------------------------------------------------------------------------
-module(riak_index_partition).
-include("riak_index.hrl").
-include_lib("riakc/include/riakc.hrl").

-type t()   ::  riakc_map:crdt_map().

-export_type([t/0]).

-export([new/0]).
-export([new/2]).
-export([new/3]).
%% -export([meta/1]).
%% -export([data/1]).
%% -export([size/1]).
-export([update/4]).
-export([fetch/3]).
-export([fetch/4]).
-export([lookup/4]).
-export([delete/4]).



%% =============================================================================
%% API
%% =============================================================================



%% -----------------------------------------------------------------------------
%% @doc
%% @end
%% -----------------------------------------------------------------------------
-spec new() -> t().

new() ->
    Ctxt = undefined,
    Meta = riakc_map:new([{{<<"size">>, counter}, riakc_counter:new()}], Ctxt),
    Data = riakc_map:new(Ctxt),
    new(Meta, Data, Ctxt).


%% -----------------------------------------------------------------------------
%% @doc
%% @end
%% -----------------------------------------------------------------------------
-spec new(Meta :: riakc_map:crdt_map(), Data :: riakc_map:crdt_map()) -> t().

new(Meta, Data) ->
    new(Meta, Data, undefined).


%% -----------------------------------------------------------------------------
%% @doc
%% @end
%% -----------------------------------------------------------------------------
-spec new(
    Meta :: riakc_map:crdt_map(),
    Data :: riakc_map:crdt_map(),
    Ctxt :: riakc_datatype:context()) -> t().

new(Meta, Data, Ctxt) ->
    Values = [
        {{<<"meta">>, map}, Meta},
        {{<<"data">>, map}, Data}
    ],
    riakc_map:new(Values, Ctxt).


%% -----------------------------------------------------------------------------
%% @doc
%% @end
%% -----------------------------------------------------------------------------
-spec update(
    Conn :: pid(),
    TypeBucket :: type_bucket(),
    Key :: binary(),
    Partition :: t()) ->
    ok | {error, any()}.

update(Conn, TypeBucket, Key, Partition) ->
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



%% -----------------------------------------------------------------------------
%% @private
%% @doc Validates and returns the options in proplist format as expected by
%% Riak KV.
%% @end
%% -----------------------------------------------------------------------------
validate_req_opts(Opts) ->
    maps:to_list(maps:validate(Opts, ?REQ_OPTS_SPEC)).