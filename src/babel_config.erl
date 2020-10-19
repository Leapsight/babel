%% =============================================================================
%%  babel_config.erl -
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
-module(babel_config).
-behaviour(app_config).
-include_lib("kernel/include/logger.hrl").

-define(APP, babel).

-define(CONFIG, [
    {riakc, [
        {allow_listing, true}
    ]}
]).


-export([init/0]).
-export([get/1]).
-export([get/2]).
-export([set/2]).



%% =============================================================================
%% API
%% =============================================================================



%% -----------------------------------------------------------------------------
%% @doc
%% @end
%% -----------------------------------------------------------------------------
init() ->
    %% _ = logger:set_application_level(babel, info),
    %% _ = logger:set_application_level(reliable, error),
    ok = app_config:init(?APP, #{callback_mod => ?MODULE}),
    ok = apply_reliable_config(),
    apply_private_config().




%% -----------------------------------------------------------------------------
%% @doc
%% @end
%% -----------------------------------------------------------------------------
-spec get(Key :: list() | atom() | tuple()) -> term().

get(Key) ->
    app_config:get(?APP, Key).


%% -----------------------------------------------------------------------------
%% @doc
%% @end
%% -----------------------------------------------------------------------------
-spec get(Key :: list() | atom() | tuple(), Default :: term()) -> term().

get(Key, Default) ->
    app_config:get(?APP, Key, Default).


%% -----------------------------------------------------------------------------
%% @doc
%% @end
%% -----------------------------------------------------------------------------
-spec set(Key :: key_value:key() | tuple(), Value :: term()) -> ok.

set(Key, Value) ->
    app_config:set(?APP, Key, Value).




%% =============================================================================
%% PRIVATE
%% =============================================================================



%% @private
apply_reliable_config() ->
    case babel_config:get(reliable, undefined) of
        undefined ->
            %% Use Reliable defaults
            ok;
        Config when is_list(Config) ->
            application:set_env([{reliable, Config}])
    end.


%% @private
apply_private_config() ->
    % ?LOG_DEBUG("Babel private configuration started"),
    try
        _ = [
            ok = application:set_env(App, Param, Val)
            || {App, Params} <- ?CONFIG, {Param, Val} <- Params
        ],
        ok
    catch
        error:Reason:Stacktrace ->
            ?LOG_ERROR(#{
                message => "Error while applying private configuration options",
                reason => Reason,
                stacktrace => Stacktrace
            }),
            {stop, Reason}
    end.
