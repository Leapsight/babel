%% =============================================================================
%%  key_value.erl -
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
%% @doc A Key Value coding interface for property lists and maps.
%% @end
%% -----------------------------------------------------------------------------
-module(babel_key_value).

-define(BADKEY, '$error_badkey').

-type t()           ::  map() | [proplists:property()] | riakc_map:crdt_map().
-type key()         ::  atom()
                        | binary()
                        | tuple()
                        | riakc_map:key()
                        | [atom() | binary() | tuple() | riakc_map:key()].



-export_type([t/0]).
-export_type([key/0]).


-export([collect/2]).
-export([collect/3]).
-export([get/2]).
-export([get/3]).
-export([set/3]).

-compile({no_auto_import, [get/1]}).



%% =============================================================================
%% API
%% =============================================================================



%% -----------------------------------------------------------------------------
%% @doc Returns value `Value' associated with `Key' if `KVTerm' contains `Key'.
%% `Key' can be an atom, a binary or a path represented as a list of atoms and/
%% or binaries, or as a tuple of atoms and/or binaries.
%%
%% The call fails with a {badarg, `KVTerm'} exception if `KVTerm' is not a
%% property list, map or Riak CRDT Map.
%% It also fails with a {badkey, `Key'} exception if no
%% value is associated with `Key'.
%%
%% > In the case of Riak CRDT Maps a key MUST be a `riakc_map:key()'.
%% @end
%% -----------------------------------------------------------------------------
-spec get(Key :: key(), KVTerm :: t()) -> Value :: term().

get(Key, KVTerm) ->
    get(Key, KVTerm, ?BADKEY).


%% -----------------------------------------------------------------------------
%% @doc
%% @end
%% -----------------------------------------------------------------------------
-spec get(Key :: key(), KVTerm :: t(), Default :: term()) -> term().

get([], _, _) ->
    error(badkey);

get(_, [], Default) ->
    maybe_badkey(Default);

get(_, KVTerm, Default) when is_map(KVTerm) andalso map_size(KVTerm) == 0 ->
    maybe_badkey(Default);

get([H|[]], KVTerm, Default) ->
    get(H, KVTerm, Default);

get([H|T], KVTerm, Default) when is_list(KVTerm) ->
    case lists:keyfind(H, 1, KVTerm) of
        {H, Child} ->
            get(T, Child, Default);
        false ->
            maybe_badkey(Default)
    end;

get([H|T], KVTerm, Default) when is_map(KVTerm) ->
    case maps:find(H, KVTerm) of
        {ok, Child} ->
            get(T, Child, Default);
        error ->
            maybe_badkey(Default)
    end;

get([{_, _} = H|T], KVTerm, Default) ->

    riakc_map:is_type(KVTerm) orelse error(badarg),

    case riakc_map:find(H, KVTerm) of
        {ok, Child} ->
            get(T, Child, Default);
        error ->
            maybe_badkey(Default)
    end;

get(Key, KVTerm, Default) when is_map(KVTerm) ->
    maybe_badkey(maps:get(Key, KVTerm, Default));

get(Key, KVTerm, Default) when is_list(KVTerm) ->
    case lists:keyfind(Key, 1, KVTerm) of
        {Key, Value} ->
            Value;
        false ->
            maybe_badkey(Default)
    end;

get({_, _} = Key, KVTerm, Default) ->

    riakc_map:is_type(KVTerm) orelse error(badarg),

    case riakc_map:find(Key, KVTerm) of
        {ok, Value} ->
            Value;
        error ->
            maybe_badkey(Default)
    end;

get(_, _, _) ->
    error(badarg).


%% -----------------------------------------------------------------------------
%% @doc
%% @end
%% -----------------------------------------------------------------------------
-spec collect([key()], KVTerm :: t()) -> [any()].

collect(Keys, KVTerm) ->
    collect(Keys, KVTerm, ?BADKEY).


%% -----------------------------------------------------------------------------
%% @doc
%% @end
%% -----------------------------------------------------------------------------
-spec collect([key()], KVTerm :: t(), Default :: any()) -> [any()].

collect([Key], KVTerm, Default) ->
    try
        get(Key, KVTerm, Default)
    catch
        error:badkey ->
            error({badkey, Key})
    end;

collect(Keys, KVTerm, Default) when is_list(Keys) ->
    collect(Keys, KVTerm, Default, []).


%% -----------------------------------------------------------------------------
%% @doc
%% @end
%% -----------------------------------------------------------------------------
-spec set(Key :: key(), Value :: any(), KVTerm :: t()) -> t().

set([H|[]], Value, KVTerm) ->
    set(H, Value, KVTerm);

set([H|T], Value, KVTerm)
when (is_atom(H) orelse is_binary(H)) andalso is_list(KVTerm)->
    InnerTerm = set(T, Value, get(H, KVTerm, [])),
    lists:keystore(H, 1, KVTerm, {H, InnerTerm});

set([H|T], Value, KVTerm)
when (is_atom(H) orelse is_binary(H)) andalso is_map(KVTerm)->
    InnerTerm = set(T, Value, get(H, KVTerm, [])),
    maps:put(H, InnerTerm, KVTerm);

set([H|T], Value, KVTerm) ->
    InnerTerm = set(T, Value, get(H, KVTerm, [])),
    riakc_map:update(H, fun(_) -> InnerTerm end, KVTerm);

set([], _, _)  ->
    error(badkey);

set(Key, Value, KVTerm)
when (is_atom(Key) orelse is_binary(Key)) andalso is_list(KVTerm) ->
    lists:keystore(Key, 1, KVTerm, {Key, Value});

set(Key, Value, KVTerm)
when (is_atom(Key) orelse is_binary(Key)) andalso is_map(KVTerm) ->
    maps:put(Key, Value, KVTerm);

set({_, Type} = Key, Value, KVTerm) ->
    riakc_map:is_type(KVTerm) orelse error(badarg),
    riakc_map:update(Key, riak_update_fun(Type, Value), KVTerm);

set(_, _, _) ->
    error(badarg).



%% =============================================================================
%% PRIVATE
%% =============================================================================



%% @private
maybe_badkey(?BADKEY) ->
    error(badkey);

maybe_badkey(Term) ->
    Term.


%% @private
collect([H|T], KVTerm, Default, Acc) ->
    try
        collect(T, KVTerm, Default, [get(H, KVTerm, Default)|Acc])
    catch
        error:badkey ->
            error({badkey, H})
    end;

collect([], _, _, Acc) ->
    lists:reverse(Acc).



%% @private
riak_update_fun(map, Value) ->
    fun(_) -> Value end;

riak_update_fun(register, Value) ->
    fun(Object) -> riakc_register:set(Value, Object) end;

riak_update_fun(flag, true) ->
    fun(Object) -> riakc_flag:enable(Object) end;

riak_update_fun(flag, false) ->
    fun(Object) -> riakc_flag:disable(Object) end;

riak_update_fun(counter, N) ->
    fun(Object) ->
        case N - riakc_counter:value(Object) of
            0 ->
                Object;
            Diff when Diff > 0 ->
                riakc_counter:increment(Diff, Object);
            Diff when Diff < 0 ->
                riakc_counter:decrement(abs(Diff), Object)
        end
    end;

riak_update_fun(Type, _) ->
    error({unsupported_type, Type}).