%% =============================================================================
%%  babel.erl -
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
%% @doc A server that takes care of initialising Babel configuration
%% with a set of statically define (and thus private) configuration options.
%% All the logic is handled by the {@link babel_config} helper module.
%% @end
%% -----------------------------------------------------------------------------
-module(babel_config_manager).
-behaviour(gen_server).
-include_lib("kernel/include/logger.hrl").


-define(CONFIG, [
    {riakc, [
        {allow_listing, true}
    ]}
]).


%% API
-export([start_link/0]).

%% GEN_SERVER CALLBACKS
-export([init/1]).
-export([handle_info/2]).
-export([terminate/2]).
-export([code_change/3]).
-export([handle_call/3]).
-export([handle_cast/2]).



%% =============================================================================
%% API
%% =============================================================================



%% -----------------------------------------------------------------------------
%% @doc Starts the config manager process
%% @end
%% -----------------------------------------------------------------------------
start_link() ->
    gen_server:start_link({local, ?MODULE}, ?MODULE, [], []).



%% =============================================================================
%% GEN_SERVER CALLBACKS
%% =============================================================================



init([]) ->
    %% We do this here so that other processes in the supervision tree
    %% are not started before we finished with the configuration
    %% This should be fast anyway so no harm is done.
    do_init().


handle_call(Event, From, State) ->
    ?LOG_ERROR(#{
        message => "Error handling call",
        reason => unsupported_event,
        event => Event,
        sender => From
    }),
    {reply, {error, {unsupported_call, Event}}, State}.


handle_cast(Event, State) ->
    ?LOG_ERROR(#{
        message => "Error handling cast",
        reason => unsupported_event,
        event => Event
    }),
    {noreply, State}.


handle_info(Info, State) ->
    ?LOG_DEBUG(#{
        message => "Unexpected message",
        state => State,
        message => Info
    }),
    {noreply, State}.


terminate(_Reason, _State) ->
    ok.


code_change(_OldVsn, State, _Extra) ->
    {ok, State}.



%% =============================================================================
%% PRIVATE
%% =============================================================================



%% @private
do_init() ->

    logger:set_application_level(babel, info),
    logger:set_application_level(reliable, error),
    %% We initialised the Babel app config
    ok = babel_config:init(),

    State = undefined,
    ok = apply_reliable_config(State),

    apply_private_config(State).


apply_reliable_config(_State) ->
    case babel_config:get(reliable_instances, undefined) of
        undefined ->
            exit({missing_configuration, reliable_instances});
        Instances ->
            application:set_env(reliable, instances, Instances)
    end.


%% @private
apply_private_config(State) ->
    % ?LOG_DEBUG("Babel private configuration started"),
    try
        _ = [
            ok = application:set_env(App, Param, Val)
            || {App, Params} <- ?CONFIG, {Param, Val} <- Params
        ],
        % _ = lager:info("Babel private configuration initialised"),
        {ok, State}
    catch
        error:Reason:Stacktrace ->
            ?LOG_ERROR(#{
                message => "Error while applying private configuration options",
                reason => Reason,
                stacktrace => Stacktrace
            }),
            {stop, Reason}
    end.

