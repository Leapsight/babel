%% =============================================================================
%%  babel_consisten_hashing.erl -
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
%% It uses Jump Consistent Hash algorithm described in
%% [A Fast, Minimal Memory, Consistent Hash Algorithm](https://arxiv.org/ftp/
%% arxiv/papers/1406/1406.2294.pdf).
%% @end
%% -----------------------------------------------------------------------------
-module(babel_consistent_hashing).

-define(MAGIC, 16#27BB2EE687B0B0FD).
-define(MASK, 16#FFFFFFFFFFFFFFFF).

-export([bucket/2]).
-export([bucket/3]).



%% =============================================================================
%% API
%% =============================================================================



%% -----------------------------------------------------------------------------
%% @doc
%% @end
%% -----------------------------------------------------------------------------
-spec bucket(Key :: term(), Buckets :: pos_integer()) -> Bucket :: integer().

bucket(Key, Buckets) ->
    bucket(Key, Buckets, jch).


%% -----------------------------------------------------------------------------
%% @doc
%% @end
%% -----------------------------------------------------------------------------
-spec bucket(Key :: term(), Buckets :: pos_integer(), Algo :: atom()) ->
    Bucket :: integer().

bucket(_, 1, _) ->
    0;

bucket(Key, Buckets, jch)
when is_integer(Key) andalso is_integer(Buckets) andalso Buckets > 1 ->
    State = rand:seed_s(exs1024s, {Key, Key, Key}),
    jch(-1, 0, Buckets, State);

bucket(Key, Buckets, Algo) ->
    bucket(erlang:phash2(Key), Buckets, Algo).



%% =============================================================================
%% PRIVATE
%% =============================================================================



%% @private
jch(Bucket, Jump, Buckets, _) when Jump >= Buckets ->
    Bucket;

jch(_, Jump, Buckets, State0) ->
    {Random, State1} = rand:uniform_s(State0),
    NewJump = trunc((Jump + 1) / Random),
    jch(Jump, NewJump, Buckets, State1).