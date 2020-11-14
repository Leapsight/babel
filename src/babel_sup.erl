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
-include_lib("kernel/include/logger.hrl").


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
    try
        ok = babel_config:init(),
        ok = maybe_add_pool(),
        supervisor:start_link({local, ?MODULE}, ?MODULE, [])
    catch
        _:Reason ->
            {error, Reason}
    end.




%% =============================================================================
%% SUPERVISOR CALLBACKS
%% =============================================================================



init([]) ->
    %% We first initialise the config
    TTL = babel_config:get(cache_ttl_secs, 60),

    Children = [
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
        ?SUPERVISOR(
            reliable_sup,
            reliable_sup,
            [],
            permanent,
            5000
        )
    ],
    {ok, {{one_for_one, 1, 5}, Children}}.



%% =============================================================================
%% PRIVATE
%% =============================================================================




maybe_add_pool() ->
    case babel_config:get(riak_pools, undefined) of
        undefined ->
            ?LOG_INFO(#{
                message => "No Riak KV connection pool configured"
            }),
            ok;
        Pools when is_list(Pools) ->
            ok = lists:foreach(
                fun
                    (#{name := Name} = Pool) ->
                        Config = maps:without([name], Pool),
                        case riak_pool:add_pool(default, Config) of
                            ok ->
                                ?LOG_INFO(#{
                                    message => "Riak KV connection pool configured",
                                    poolname => Name,
                                    config => Pool
                                }),
                                ok;
                            {error, Reason} ->
                                throw(Reason)
                        end;
                    (Pool) ->
                        throw({missing_poolname, Pool})
                end,
                Pools
            )
    end.
