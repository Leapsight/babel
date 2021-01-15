%%%-------------------------------------------------------------------
%% @doc simple_vehicle_demo public API
%% @end
%%%-------------------------------------------------------------------

-module(simple_vehicle_demo_app).

-behaviour(application).

-export([start/2, stop/1]).

start(_StartType, _StartArgs) ->
    simple_vehicle_demo_sup:start_link().

stop(_State) ->
    ok.

%% internal functions
