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