%%%-------------------------------------------------------------------
%% @doc riak_utils public API
%% @end
%%%-------------------------------------------------------------------

-module(riak_utils_app).

-behaviour(application).

-export([start/2, stop/1]).


start(_StartType, _StartArgs) ->
    ok = riak_utils_config:init(),

    case riak_utils_sup:start_link() of
        {ok, _} = OK ->
            OK;
        Error ->
            Error
    end.

stop(_State) ->
    ok.

