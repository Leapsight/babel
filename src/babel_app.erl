%%%-------------------------------------------------------------------
%% @doc riak_utils public API
%% @end
%%%-------------------------------------------------------------------

-module(babel_app).

-behaviour(application).

-export([start/2, stop/1]).


start(_StartType, _StartArgs) ->
    ok = babel_config:init(),

    case babel_sup:start_link() of
        {ok, _} = OK ->
            OK;
        Error ->
            Error
    end.

stop(_State) ->
    ok.

