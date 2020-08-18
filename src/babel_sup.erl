%%%-------------------------------------------------------------------
%% @doc riak_utils top level supervisor.
%% @end
%%%-------------------------------------------------------------------

-module(babel_sup).
-behaviour(supervisor).

-define(SUPERVISOR(Id, Args, Restart, Timeout), #{
    id => Id,
    start => {Id, start_link, Args},
    restart => Restart,
    shutdown => Timeout,
    type => supervisor,
    modules => [Id]
}).

-define(WORKER(Id, Args, Restart, Timeout), #{
    id => Id,
    start => {Id, start_link, Args},
    restart => Restart,
    shutdown => Timeout,
    type => worker,
    modules => [Id]
}).

-define(EVENT_MANAGER(Id, Restart, Timeout), #{
    id => Id,
    start => {gen_event, start_link, [{local, Id}]},
    restart => Restart,
    shutdown => Timeout,
    type => worker,
    modules => [dynamic]
}).

%% API
-export([start_link/0]).

%% SUPERVISOR CALLBACKS
-export([init/1]).



%% =============================================================================
%% API
%% =============================================================================



start_link() ->
    supervisor:start_link({local, ?MODULE}, ?MODULE, []).



%% =============================================================================
%% SUPERVISOR CALLBACKS
%% =============================================================================



init([]) ->
    Children = [
        %% babel_config_manager should be first process to be started
        ?WORKER(babel_config_manager, [], permanent, 30000),
        cache()
    ],
    {ok, {{one_for_one, 1, 5}, Children}}.


cache() ->
    TTL = babel_config:get(cache_ttl_secs, 60),
    Args = [babel_index_collection, [{n, 10}, {ttl, TTL}]],

    ?WORKER(cache, Args, permanent, 5000).