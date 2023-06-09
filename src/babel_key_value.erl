%% =============================================================================
%%  babel_key_value.erl -
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
%% @doc A Key Value coding interface for property lists and maps.
%% @end
%% -----------------------------------------------------------------------------
-module(babel_key_value).

-define(BADKEY, '$error_badkey').

-type t()           ::  map()
                        | [proplists:property()]
                        | babel_map:t()
                        | riakc_map:crdt_map().
-type key()         ::  atom()
                        | binary()
                        | tuple()
                        | riakc_map:key()
                        | path().

-type path()        ::  [atom() | binary() | tuple() | riakc_map:key()].

-type fold_fun()    ::  fun(
                            (Key :: key(), Value :: any(), AccIn :: any()) ->
                                AccOut :: any()
                        ).

-export_type([t/0]).
-export_type([key/0]).
-export_type([path/0]).


-export([collect/2]).
-export([collect/3]).
-export([get/2]).
-export([get/3]).
-export([set/3]).
-export([put/3]).
-export([fold/3]).

-compile({no_auto_import, [get/1]}).

-eqwalizer({nowarn_function, fold/3}).


%% =============================================================================
%% API
%% =============================================================================



%% -----------------------------------------------------------------------------
%% @doc Returns value `Value' associated with `Key' if `KVTerm' contains `Key'.
%% `Key' can be an atom, a binary or a path represented as a list of atoms and/
%% or binaries.
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
    %% eqwalizer:ignore KVTerm
    case lists:keyfind(H, 1, KVTerm) of
        {H, Child} ->
            get(T, Child, Default);
        false ->
            maybe_badkey(Default)
    end;

get([H|T], KVTerm, Default) when is_map(KVTerm) ->
    %% eqwalizer:ignore KVTerm
    case maps:find(H, KVTerm) of
        {ok, Child} ->
            get(T, Child, Default);
        error ->
            maybe_badkey(Default)
    end;

get([{_, _} = H|T], KVTerm, Default) ->
    riakc_map:is_type(KVTerm) orelse error(badarg),

    %% eqwalizer:ignore KVTerm
    case riakc_map:find(H, KVTerm) of
        {ok, Child} ->
            %% eqwalizer:ignore Child
            get(T, Child, Default);
        error ->
            maybe_badkey(Default)
    end;

get(Path, KVTerm, Default) when is_list(Path) ->
    babel_map:is_type(KVTerm) orelse error(badarg),
    %% eqwalizer:ignore Path
    babel_map:get_value(Path, KVTerm, Default);

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

get(Key, KVTerm, Default) ->
    babel_map:is_type(KVTerm) orelse error(badarg),
    babel_map:get_value(Key, KVTerm, Default).


%% -----------------------------------------------------------------------------
%% @doc
%% @end
%% -----------------------------------------------------------------------------
-spec collect([key()], KVTerm :: t()) -> [any()].

collect(Keys, KVTerm) ->
    %% TODO this is not efficient as we traverse the tree from root for
    %% every key. We should implement collect_map/2 (which should be
    %% optimised) and then return the values for the Keys.
    collect(Keys, KVTerm, ?BADKEY).


%% -----------------------------------------------------------------------------
%% @doc
%% @end
%% -----------------------------------------------------------------------------
-spec collect([key()], KVTerm :: t(), Default :: any()) -> [any()].

collect([Key], KVTerm, Default) ->
    try
        [get(Key, KVTerm, Default)]
    catch
        error:badkey ->
            error({badkey, Key})
    end;

collect(Keys, KVTerm, Default) when is_list(Keys) ->
    collect(Keys, KVTerm, Default, []).


%% -----------------------------------------------------------------------------
%% @doc
%% @equiv set/3
%% @end
%% -----------------------------------------------------------------------------
-spec put(Key :: key(), Value :: any(), KVTerm :: t()) -> t().

put(Key, Value, KVTerm) ->
    set(Key, Value, KVTerm).


%% -----------------------------------------------------------------------------
%% @doc
%% @end
%% -----------------------------------------------------------------------------
-spec set(Key :: key(), Value :: any(), KVTerm :: t()) -> t().

set([H|[]], Value, KVTerm) ->
    set(H, Value, KVTerm);

set([H|T], Value, KVTerm)
when (is_atom(H) orelse is_binary(H)) andalso is_list(KVTerm)->
    InnerTerm0 = get(H, KVTerm, []),
    %% eqwalizer:ignore InnerTerm0
    InnerTerm = set(T, Value, InnerTerm0),
    %% eqwalizer:ignore KVTerm
    lists:keystore(H, 1, KVTerm, {H, InnerTerm});

set([H|T], Value, KVTerm)
when (is_atom(H) orelse is_binary(H)) andalso is_map(KVTerm)->
    InnerTerm0 = get(H, KVTerm, #{}),
    %% eqwalizer:ignore InnerTerm0
    InnerTerm = set(T, Value, InnerTerm0),
    %% eqwalizer:ignore KVTerm
    maps:put(H, InnerTerm, KVTerm);

set([H|T] = L, Value, KVTerm) ->
    case babel_map:is_type(KVTerm) of
        true ->
            %% eqwalizer:ignore L
            babel_map:set(L, Value, KVTerm);
        false ->
            case riakc_map:is_type(KVTerm) of
                true ->
                    InnerTerm = set(T, Value, get(H, KVTerm, riakc_map:new())),
                    riakc_map:update(H, fun(_) -> InnerTerm end, KVTerm);
                false ->
                    error(badarg)
            end
    end;

set([], _, _)  ->
    error(badkey);

set(Key, Value, KVTerm)
when (is_atom(Key) orelse is_binary(Key)) andalso is_list(KVTerm) ->
    lists:keystore(Key, 1, KVTerm, {Key, Value});

set(Key, Value, KVTerm)
when (is_atom(Key) orelse is_binary(Key)) andalso is_map(KVTerm) ->
    maps:put(Key, Value, KVTerm);

set({_, Type} = Key, Value, KVTerm) ->
    riakc_map:is_type(KVTerm) orelse error({badarg, [Key, Value, KVTerm]}),
    riakc_map:update(Key, riak_update_fun(Type, Value), KVTerm);

set(Key, Value, KVTerm) ->
    babel_map:is_type(KVTerm) orelse error(badarg),
    babel_map:set(Key, Value, KVTerm).


%% -----------------------------------------------------------------------------
%% @doc
%% @end
%% -----------------------------------------------------------------------------
-spec fold(Fun :: fold_fun(), Acc :: any(), KVTerm :: t()) -> NewAcc :: any().

fold(Fun, Acc, KVTerm) when is_list(KVTerm) ->
    lists:foldl(fun({K, V}, In) -> Fun(K, V, In) end, Acc, KVTerm);

fold(Fun, Acc, KVTerm) when is_map(KVTerm) ->
    maps:fold(Fun, Acc, KVTerm);

fold(Fun, Acc, KVTerm) ->
    case babel_map:is_type(KVTerm) of
        true ->
            maps:fold(Fun, Acc, babel_map:value(KVTerm));

        false ->
            case riakc_map:is_type(KVTerm) of
                true ->
                    riakc_map:fold(Fun, Acc, KVTerm);
                false ->
                    error(badarg)
            end
    end.


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

riak_update_fun(set, Value) ->
    fun(_) -> Value end;

riak_update_fun(register, Value) ->
    fun(Object) -> riakc_register:set(Value, Object) end;

riak_update_fun(flag, true) ->
    fun(Object) -> riakc_flag:enable(Object) end;

riak_update_fun(flag, false) ->
    fun(Object) ->
        try
            riakc_flag:disable(Object)
        catch
            throw:context_required ->
                case riakc_flag:value(Object) of
                    true -> throw(context_required);
                    false -> Object
                end
        end
    end;

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