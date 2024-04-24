%% =============================================================================
%%  babel_index_utils.erl -
%%
%%  Copyright (c) 2022 Leapsight Technologies Limited. All rights reserved.
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
%% @doc A collection of utility functions used by the different index type
%% implementations.
%%
%% @end
%% -----------------------------------------------------------------------------
-module(babel_index_utils).


-export([gen_key/3]).
-export([safe_gen_key/3]).
-export([build_output/2]).
-export([build_output/3]).


-eqwalizer({nowarn_function, build_output/3}).



%% =============================================================================
%% API
%% =============================================================================



%% -----------------------------------------------------------------------------
%% @doc Collects keys `Keys' from key value data `Data' and joins them using a
%% separator.
%% We do this as Riak does not support list and sets are ordered.
%% The values for `Keys' in `Data' must be binary strings.
%% @end
%% -----------------------------------------------------------------------------
-spec gen_key([babel_key_value:key()], babel_key_value:t(), map()) -> binary().

gen_key(Keys, Data, #{case_sensitive := true}) ->
    binary_utils:join(collect(Keys, Data));

gen_key(Keys, Data, #{case_sensitive := false}) ->
    L = [string:lowercase(X) ||  X <- collect(Keys, Data)],
    binary_utils:join(L).


%% -----------------------------------------------------------------------------
%% @doc Collects keys `Keys' from key value data `Data' and joins them using a
%% separator.
%% We do this as Riak does not support list and sets are ordered.
%% The diff between this function and gen_key/2 is that this one catches
%% exceptions and returns a value.
%% @end
%% -----------------------------------------------------------------------------
-spec safe_gen_key([babel_key_value:key()], babel_key_value:t(), map()) ->
    binary() | undefined | error.

safe_gen_key([], _, _) ->
    undefined;

safe_gen_key(Keys, Data, Config) ->
    try
        gen_key(Keys, Data, Config)
    catch
        error:{badkey, _} ->
            error
    end.


%% -----------------------------------------------------------------------------
%% @doc
%% @end
%% -----------------------------------------------------------------------------
-spec build_output([babel_key_value:key()], binary() | undefined) -> map().

build_output([], undefined) ->
    #{};

build_output(Keys, Bin) when is_binary(Bin) ->
    build_output(Keys, Bin, #{}).


%% -----------------------------------------------------------------------------
%% @doc
%% @end
%% -----------------------------------------------------------------------------
-spec build_output(
    [babel_key_value:key()],
    [binary()] | binary() | undefined,
    map()
    ) -> map().

build_output([], undefined, Acc) ->
    Acc;

build_output(Keys, Bin, Acc) when is_binary(Bin) ->
    build_output(Keys, binary:split(Bin, <<$\31>>, [global]), Acc);

build_output([X | Xs], [Y | Ys], Acc) ->
    build_output(Xs, Ys, maps:put(X, Y, Acc));

build_output([], [], Acc) ->
    Acc.




%% =============================================================================
%% PRIVATE
%% =============================================================================



%% @private
-spec collect([babel_key_value:key()], babel_key_value:t()) -> [binary()].

collect(Keys, Data) ->
    [X || X <- babel_key_value:collect(Keys, Data), is_binary(X)].



