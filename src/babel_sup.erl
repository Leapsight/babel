%% =============================================================================
%%  babel_sup.erl -
%%
%%  Copyright (c) 2020 Leapsight Holdings Limited. All rights reserved.
%%
%%  Licensed under the Apache License, Version 2.0 (the "License");
%%  you may not use this file except in compliance with the License.
%%  You may obtain a copy of the License at
%%
%%     http://www.apache.org/licenses/LICENSE-2.0
%%
%%  Unless required by applicable law or agreed to in writing, software
%%  distributed under the License is distributed on an "AS IS" BASIS,
%%  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
%%  See the License for the specific language governing permissions and
%%  limitations under the License.
%% =============================================================================

%% -----------------------------------------------------------------------------
%% @doc
%% @end
%% -----------------------------------------------------------------------------

-module(babel_sup).
-behaviour(supervisor).

-define(SUPERVISOR(Id, Mod, Args, Restart, Timeout), #{
    id => Id,
    start => {Mod, start_link, Args},
    restart => Restart,
    shutdown => Timeout,
    type => supervisor,
    modules => [Mod]
}).

-define(WORKER(Id, Mod, Args, Restart, Timeout), #{
    id => Id,
    start => {Mod, start_link, Args},
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
    TTL = babel_config:get(cache_ttl_secs, 60),

    Children = [
        %% babel_config_manager should be first process to be started
        ?WORKER(
            babel_config_manager,
            babel_config_manager,
            [],
            permanent,
            30000
        ),
        ?WORKER(
            babel_index_collection,
            cache,
            [babel_index_collection, [{n, 10}, {ttl, TTL}]],
            permanent,
            5000
        ),
        ?WORKER(
            babel_index_partition,
            cache,
            [babel_index_partition, [{n, 10}, {ttl, TTL}]],
            permanent,
            5000
        ),
        %% ?SUPERVISOR(
        %%     babel_riak_connection_sup,
        %%     babel_riak_connection_sup,
        %%     [],
        %%     permanent,
        %%     5000
        %% ),
        %% ?WORKER(
        %%     babel_riak_connection_broker,
        %%     babel_riak_connection_broker,
        %%     [],
        %%     permanent,
        %%     5000
        %% ),
        %% ?WORKER(
        %%     babel_riak_pool,
        %%     babel_riak_pool,
        %%     [],
        %%     permanent,
        %%     5000
        %% ),
        ?SUPERVISOR(
            reliable_sup,
            reliable_sup,
            [],
            permanent,
            5000
        )
    ],
    {ok, {{one_for_one, 1, 5}, Children}}.
