-module(riakc_pool).

-define(GET_CONN_TIMEOUT, 10000).

-type connection() :: riakc_pb_socket:riakc_pb_socket().

-export([start/1]).
-export([stop/0]).
-export([get_connection/1]).
-export([get_connection/2]).
-export([get_connection/3]).




%% =============================================================================
%% API
%% =============================================================================


start(_Opts) ->
    ok.


stop() ->
    ok.


%% -----------------------------------------------------------------------------
%% @doc
%% @end
%% -----------------------------------------------------------------------------
-spec get_connection(atom()) -> connection() | {error, timeout}.

get_connection(Pool) ->
    get_connection(Pool, ?GET_CONN_TIMEOUT).


%% -----------------------------------------------------------------------------
%% @doc
%% @end
%% -----------------------------------------------------------------------------
-spec get_connection(atom(), Timeout :: timeout()) ->
    connection() | {error, timeout}.

get_connection(Pool, Timeout) ->
    get_connection(Pool, Timeout, 1).


%% -----------------------------------------------------------------------------
%% @doc
%% @end
%% -----------------------------------------------------------------------------
get_connection(_PoolName, _Timeout, _Retries) ->
    error(not_implemented).