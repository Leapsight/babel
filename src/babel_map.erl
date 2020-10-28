%% =============================================================================
%%  babel_map.erl -
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
%% @doc Provides an alternative to Riak map datatype.
%%
%% # Overview
%%
%% Babel maps (maps) differ from Riak's and Erlang's maps in several ways:
%%
%% * Maps are special key-value structures where the key is a binary name and
%% the value is either an Erlang term or another Babel data structure (each one
%% an alternative of the Riak's counterparts). In case the value is an Erlang
%% term, it is denoted as a Riak register but without the restriction of them
%% being binaries as in Riak. To be able to do this certain map operations
%% require a Specification object, a sort of schema that tells Babel map the
%% type of each value. This enables the map to use Erlang terms and only
%% convert them to the required Riak datatypes when storing the object in the
%% database.
%% * Maps maintain the same semantics as Riak Maps but with some key differences
%%     * As with Riak Map, removals, and modifications are captured for later
%% application by Riak but they are also applied to the local state. That is,
%% maps resolve the issue of not being able to read your object mutations in
%% memory that occurs when using Riak maps.
%%     * Removals are processed before updates in Riak.
%% Also, removals performed without a context may result in failure.
%%     * Updating an entry followed by removing that same entry will result in
%% no operation being recorded. Likewise, removing an entry followed by
%% updating that entry  will cancel the removal operation.
%%     * You may store or remove values in a map by using `set/3`, `remove/2',
%% and other functions targetting embedded babel containers e.g. `add_element/
%% 3', `add_elements/3', `del_element/3' to modify an embeded {@link babel_set}
%% . This is a complete departure from Riak's cumbersome `update/3' function.
%% As in Riak Maps, setting or adding a value to an embedded container that is
%% not present will create a new container before the set/add operation.
%%     * Certain function e.g. `set/3' allows you to set a value in a key or a
%% path (list of nested keys).
%%
%% # Map Specification
%%
%% A map specification is an Erlang map where the keys are Riak keys i.e. a
%% pair of a binary name and data type and value is another specification or a
%% `type()'. This can be seen as an encoding specification. For example the
%% specification `#{ {<<"friends">>, set} => list}', says the map contains a
%% single key name "friends" containing a set which individual elements we want
%% to convert to lists i.e. a set of lists. This will result in a map
%% containing the key `<<"friends">>' and a babel set contining the elements
%% converted from binaries to lists.
%%
%% The special '_' key name provides the capability to convert a Riak Map where
%% the keys are not known in advance, and their values are all of the same
%% type. These specs can only have a single entry as follows
%% `#{{'_', set}, binary}'.
%%
%% @end
%% -----------------------------------------------------------------------------
-module(babel_map).
-include("babel.hrl").

-define(BADKEY, '$error_badkey').

-record(babel_map, {
    values = #{}            ::  #{key() => value()},
    updates = []            ::  ordsets:ordset(key()),
    removes = []            ::  ordsets:ordset(key()),
    context                 ::  riakc_datatype:context() | undefined
}).

-opaque t()                 ::  #babel_map{}.
-type datatype()            ::  counter | flag | register | set | map.
-type type_spec()           ::  #{key() | '_' => type_mapping()}.
-type type_mapping()        ::  {map, type_spec()}
                                | {set, erl_type()}
                                | {counter, erl_type()}
                                | {flag, erl_type()}
                                | {register, erl_type()}.
-type erl_type()            ::  atom
                                | existing_atom
                                | boolean
                                | integer
                                | float
                                | binary
                                | list
                                | fun((encode, any()) -> value())
                                | fun((decode, value()) -> any()).
-type key_path()            ::  binary() | [binary()].
-type value()               ::  any().

-export_type([t/0]).
-export_type([type_spec/0]).
-export_type([key_path/0]).

%% API
-export([add_element/3]).
-export([add_elements/3]).
-export([collect/2]).
-export([collect/3]).
-export([context/1]).
-export([decrement/2]).
-export([decrement/3]).
-export([del_element/3]).
-export([disable/2]).
-export([enable/2]).
-export([find/2]).
-export([from_riak_map/2]).
-export([get/2]).
-export([get/3]).
-export([get_type/1]).
-export([get_value/2]).
-export([get_value/3]).
-export([increment/2]).
-export([increment/3]).
-export([is_type/1]).
-export([keys/1]).
-export([merge/2]).
-export([new/0]).
-export([new/1]).
-export([new/2]).
-export([patch/3]).
-export([put/3]).
-export([remove/2]).
-export([set/3]).
-export([set_elements/3]).
-export([size/1]).
-export([to_riak_op/2]).
-export([type/0]).
-export([update/3]).
-export([updated_key_paths/1]).
-export([value/1]).



%% =============================================================================
%% API
%% =============================================================================



%% -----------------------------------------------------------------------------
%% @doc
%% @end
%% -----------------------------------------------------------------------------
-spec new() -> t().

new()->
    #babel_map{}.


%% -----------------------------------------------------------------------------
%% @doc
%% @end
%% -----------------------------------------------------------------------------
-spec new(Data :: map()) -> t().

new(Data) when is_map(Data) ->
    #babel_map{
        values = Data,
        updates = ordsets:from_list(maps:keys(Data))
    }.


%% -----------------------------------------------------------------------------
%% @doc
%% @end
%% -----------------------------------------------------------------------------
-spec new(Data :: map(), Spec :: type_spec()) -> t().

new(Data, Spec) ->
    new(Data, Spec, undefined).


%% -----------------------------------------------------------------------------
%% @doc
%% @end
%% -----------------------------------------------------------------------------
-spec new(
    Data :: map(),
    Spec :: type_spec(),
    Ctxt :: riakc_datatype:context()) -> t().

new(Data, Spec, Ctxt) ->
    from_map(Data, Spec, Ctxt).

%% new(Data, Spec) when is_map(Data) andalso is_map(Spec) ->
%%     MissingKeys = lists:subtract(maps:keys(Spec), maps:keys(Data)),
%%     Values = init_values(maps:with(MissingKeys, Spec), Data),
%%     #babel_map{
%%         values = Values,
%%         updates = ordsets:from_list(maps:keys(Values))
%%     };


%% -----------------------------------------------------------------------------
%% @doc Returns a new map by applying the type specification `Spec' to the Riak
%% Map `RMap'.
%% @end
%% -----------------------------------------------------------------------------
-spec from_riak_map(
    RMap :: riakc_map:crdt_map() | list(), Spec :: type_spec()) -> t().

from_riak_map(RMap, #{'_':= Spec}) ->
    from_riak_map(RMap, expand_spec(orddict:fetch_keys(RMap), Spec));

from_riak_map({map, Values, _, _, Context}, Spec) when is_map(Spec) ->
    from_riak_map(Values, Context, Spec);

from_riak_map(RMap, Spec) when is_list(RMap) ->
    from_riak_map(RMap, undefined, Spec).


%% -----------------------------------------------------------------------------
%% @doc Extracts a Riak Operation from the map to be used with a Riak Client
%% update request.
%% The call fails with a `{badmap, T}' exception if `T' is not a map.
%% @end
%% -----------------------------------------------------------------------------
-spec to_riak_op(T :: t(), Spec :: type_spec()) ->
    riakc_datatype:update(riakc_map:map_op()) | no_return().

to_riak_op(T, #{'_' := TypeOrSpec}) ->
    to_riak_op(T, expand_spec(modified_keys(T), TypeOrSpec));

to_riak_op(#babel_map{} = T, Spec) when is_map(Spec) ->
    Updates = prepare_update_ops(T, Spec),
    Removes = prepare_remove_ops(T, Spec),

    case lists:append(Removes, Updates) of
        [] ->
            undefined;
        Ops ->
            {riakc_map:type(), {update, Ops}, T#babel_map.context}
    end;

to_riak_op(Term, _) ->
    badtype(map, Term).



%% -----------------------------------------------------------------------------
%% @doc Returns the symbolic name of this container.
%% @end
%% -----------------------------------------------------------------------------
-spec type() -> map.

type() -> map.


%% -----------------------------------------------------------------------------
%% @doc Returns the size of the values of the map `T'.
%% The call fails with a `{badmap, T}' exception if `T' is not a map.
%% @end
%% -----------------------------------------------------------------------------
-spec size(T :: t()) -> non_neg_integer() | no_return().

size(#babel_map{values = Values}) ->
    maps:size(Values);

size(Term) ->
    badtype(map, Term).


%% -----------------------------------------------------------------------------
%% @doc Returns a complete list of keys, in any order, which resides within map
%% `T'.
%% The call fails with a `{badmap, T}' exception if `T' is not a map.
%% @end
%% -----------------------------------------------------------------------------
-spec keys(T :: t()) -> [binary()] | no_return().

keys(#babel_map{values = Values}) ->
    maps:keys(Values);

keys(Term) ->
    badtype(map, Term).


%% -----------------------------------------------------------------------------
%% @doc Returns a list of the key paths that have been modified in map `T'.
%% The call fails with a `{badmap, T}' exception if `T' is not a map.
%% @end
%% -----------------------------------------------------------------------------
-spec updated_key_paths(T :: t()) -> [key_path()] | no_return().

updated_key_paths(#babel_map{} = T) ->
    updated_key_paths(T, [], []);

updated_key_paths(Term) ->
    badtype(map, Term).


%% -----------------------------------------------------------------------------
%% @doc Returns true if term `Term' is a babel map.
%% The call fails with a `{badmap, Term}' exception if `Term' is not a map.
%% @end
%% -----------------------------------------------------------------------------
-spec is_type(Term :: any()) -> boolean().

is_type(Term) ->
    is_record(Term, babel_map).


%% -----------------------------------------------------------------------------
%% @doc Returns the Riak KV context associated with map `T'.
%% The call fails with a `{badmap, T}' exception if `T' is not a map.
%% @end
%% -----------------------------------------------------------------------------
-spec context(T :: t()) -> riakc_datatype:context() | no_return().

context(#babel_map{context = Value}) ->
    Value;

context(Term) ->
    badtype(map, Term).


%% -----------------------------------------------------------------------------
%% @doc Returns an external representation of the map `Map' as an Erlang
%% map(). This is build recursively by calling the value/1 function on any
%% embedded datatype.
%% The call fails with a `{badmap, T}' exception if `T' is not a map.
%% @end
%% -----------------------------------------------------------------------------
-spec value(Map :: t()) -> map() | no_return().

value(#babel_map{values = V}) ->
    Fun = fun
        (_, Term) ->
            type_value(Term)
    end,
    maps:map(Fun, V);

value(Term) ->
    badtype(map, Term).



%% -----------------------------------------------------------------------------
%% @doc Returns the tuple `{ok, Value :: any()}' if the key 'Key' is associated
%% with value `Value' in map `T'. Otherwise returns the atom `error'.
%% The call fails with a `{badmap, T}' exception if `T' is not a map and
%% `{badkey, Key}' exception if `Key' is not a binary term.
%% @end
%% -----------------------------------------------------------------------------
-spec find(Key :: key_path(), T :: t()) -> {ok, any()} | error.

find(Key, #babel_map{} = T) when is_binary(Key) ->
    case get(Key, T, error) of
        error ->
            error;
        Value ->
            {ok, Value}
    end;

find(Key, _) when not is_binary(Key) ->
    error({badkey, Key});

find(_, Term) ->
    badtype(map, Term).


%% -----------------------------------------------------------------------------
%% @doc An util function equivalent to calling `DatatypeMod:value(get(Key, T))`.
%% @end
%% -----------------------------------------------------------------------------
-spec get_value(Key :: key_path(), T :: t()) -> any().

get_value(Key, T) ->
    type_value(get(Key, T, ?BADKEY)).


%% -----------------------------------------------------------------------------
%% @doc An util function equivalent to calling
%% `DatatypeMod:value(get(Key, T, Default))`.
%% @end
%% -----------------------------------------------------------------------------
-spec get_value(Key :: key_path(), T :: t(), Default :: any()) ->
    any() | no_return().

get_value(Key, T, Default) ->
    type_value(get(Key, T, Default)).


%% -----------------------------------------------------------------------------
%% @doc Returns value `Value' associated with `Key' if `T' contains `Key'.
%% `Key' can be a binary or a path represented as a list of binaries.
%%
%% The call fails with a {badarg, `T'} exception if `T' is not a Babel Map.
%% It also fails with a {badkey, `Key'} exception if no value is associated
%% with `Key' or if `Key' is not a binary term.
%% @end
%% -----------------------------------------------------------------------------
-spec get(Key :: key_path(), T :: t()) -> any() | no_return().

get(Key, T) ->
    get(Key, T, ?BADKEY).


%% -----------------------------------------------------------------------------
%% @doc Returns value `Value' associated with `Key' if `T' contains `Key', or
%% the default value `Default' in case `T' does not contain `Key'.
%%
%% `Key' can be a binary or a path represented as a list of binaries.
%%
%% The call fails with a `{badarg, T}` exception if `T' is not a Babel Map.
%% It also fails with a `{badkey, Key}` exception if no value is associated
%% with `Key' or if `Key' is not a binary term.
%% @end
%% -----------------------------------------------------------------------------
-spec get(Key :: key_path(), Map :: t(), Default :: any()) -> Value :: value().

get(_, #babel_map{values = V}, Default) when map_size(V) == 0 ->
    maybe_badkey(Default);

get([H|[]], #babel_map{} = Map, Default) when is_binary(H) ->
    get(H, Map, Default);

get([H|T], #babel_map{values = V}, Default) when is_binary(H) ->
    case maps:find(H, V) of
        {ok, Child} ->
            get(T, Child, Default);
        error ->
            maybe_badkey(Default)
    end;

get(K, #babel_map{values = V}, Default) when is_binary(K) ->
    case maps:find(K, V) of
        {ok, Value} ->
            Value;
        error ->
            maybe_badkey(Default)
    end;

get(Key, #babel_map{}, _) when not is_binary(Key) ->
    error({badkey, Key});

get(_, Term, _) ->
    badtype(map, Term).


%% -----------------------------------------------------------------------------
%% @doc Returns a list of values associated with the keys `Keys'.
%% Fails with a `{badkey, K}` exeception if any key `K' in `Keys' is not
%% present in the map.
%% @end
%% -----------------------------------------------------------------------------
-spec collect([key_path()], Map :: t()) -> [any()].

collect(Keys, Map) ->
    collect(Keys, Map, ?BADKEY).


%% -----------------------------------------------------------------------------
%% @doc Returns a list of values associated with the keys `Keys'. If any key
%% `K' in `Keys' is not present in the map the value `Default' is returned.
%% @end
%% -----------------------------------------------------------------------------
-spec collect(Keys :: [key_path()], Map :: t(), Default :: any()) -> [any()].

collect([Key], Map, Default) ->
    try
        [get(Key, Map, Default)]
    catch
        error:badkey ->
            error({badkey, Key})
    end;

collect(Keys, Map, Default) when is_list(Keys) ->
    collect(Keys, Map, Default, []).


%% -----------------------------------------------------------------------------
%% @doc Associates `Key' with value `Value' and inserts the association into
%% map `NewMap'. If key `Key' already exists in map `Map', the old associated
%% value is replaced by value `Value'. The function returns a new map `NewMap'
%% containing the new association and the old associations in `Map'.
%%
%% Passing a `Value' of `undefined` is equivalent to calling `remove(Key, Map)'
%% with the difference that an exception will not be raised in case the map had
%% no context assigned.
%%
%% The call fails with a `{badmap, Term}' exception if `Map' or any value of a
%% partial key path is not a babel map.
%% @end
%% -----------------------------------------------------------------------------
-spec set(Key :: key_path(), Value :: value(), Map :: t()) ->
    NewMap :: maybe_no_return(t()).

set(Key, Value, Map) ->
    mutate(Key, Value, Map).


%% -----------------------------------------------------------------------------
%% @doc Same as {@set/3}.
%% @end
%% -----------------------------------------------------------------------------
-spec put(Key :: key_path(), Value :: value(), Map :: t()) ->
    NewMap :: maybe_no_return(t()).

put(Key, Value, Map) ->
    mutate(Key, Value, Map).


%% -----------------------------------------------------------------------------
%% @doc Adds element `Value' to a babel set associated with key or path
%% `Key' in map `Map' and inserts the association into map `NewMap'.
%%
%% If the key `Key' does not exist in map `Map', this function creates a new
%% babel set containining `Value'.
%%
%% The call might fail with the following exception reasons:
%%
%% * `{badset, Set}' - if the initial value associated with `Key' in map `Map0'
%% is not a babel set;
%% * `{badmap, Map}' exception if `Map' is not a babel map.
%% * `{badkey, Key}' - exception if no value is associated with `Key' or `Key'
%% is not of type binary.
%% @end
%% -----------------------------------------------------------------------------
-spec add_element(Key :: key_path(), Value :: value(), Map :: t()) ->
    NewMap :: maybe_no_return(t()).

add_element(Key, Value, Map) ->
    add_elements(Key, [Value], Map).


%% -----------------------------------------------------------------------------
%% @doc Adds a list of values `Values' to a babel set associated with key or
%% path `Key' in map `Map' and inserts the association into map `NewMap'.
%%
%% If the key `Key' does not exist in map `Map', this function creates a new
%% babel set containining `Values'.
%%
%% The call might fail with the following exception reasons:
%%
%% * `{badset, Set}' - if the initial value associated with `Key' in map `Map0'
%% is not a babel set;
%% * `{badmap, Map}' exception if `Map' is not a babel map.
%% * `{badkey, Key}' - exception if no value is associated with `Key' or `Key'
%% is not of type binary.
%% @end
%% -----------------------------------------------------------------------------
-spec add_elements(Key :: key_path(), Values :: [value()], Map :: t()) ->
    NewMap :: maybe_no_return(t()).

add_elements(Key, Values, Map) ->
    Fun = fun
        ({ok, Term}) ->
            case babel_set:is_type(Term) of
                true ->
                    babel_set:add_elements(Values, Term);
                false ->
                    badtype(set, Term)
            end;
        (error) ->
            babel_set:new(Values, Map#babel_map.context)
    end,
    mutate(Key, Fun, Map).


%% -----------------------------------------------------------------------------
%% @doc Returns a new map `NewMap' were the value `Value' has been removed from
%% a babel set associated with key or path `Key' in
%% map `Map'.
%%
%% If the key `Key' does not exist in map `Map', this function creates a new
%% babel set recording the removal of `Value'.
%%
%% The call might fail with the following exception reasons:
%%
%% * `{badset, Set}' - if the initial value associated with `Key' in map `Map0'
%% is not a babel set;
%% * `{badmap, Map}' exception if `Map' is not a babel map.
%% * `{badkey, Key}' - exception if no value is associated with `Key' or `Key'
%% is not of type binary.
%% @end
%% -----------------------------------------------------------------------------
-spec del_element(Key :: key_path(), Value :: value(), Map :: t()) ->
    NewMap :: maybe_no_return(t()).

del_element(Key, Value, Map) ->
    Fun = fun
        ({ok, Term}) ->
            case babel_set:is_type(Term) of
                true ->
                    babel_set:del_element(Value, Term);
                false ->
                    badtype(set, Term)
            end;
        (error) ->
            babel_set:new(Value, Map#babel_map.context)
    end,
    mutate(Key, Fun, Map).


%% -----------------------------------------------------------------------------
%% @doc Sets a list of values `Values' to a babel set associated with key or
%% path `Key' in map `Map' and inserts the association into map `NewMap'.
%% See {@link babel_set:set_elements/2}.
%%
%% If the key `Key' does not exist in map `Map', this function creates a new
%% babel set containining `Values'.
%%
%% The call might fail with the following exception reasons:
%%
%% * `{badset, Set}' - if the initial value associated with `Key' in map `Map0'
%% is not a babel set;
%% * `{badmap, Map}' exception if `Map' is not a babel map.
%% * `{badkey, Key}' - exception if no value is associated with `Key' or `Key'
%% is not of type binary.
%% @end
%% -----------------------------------------------------------------------------
-spec set_elements(Key :: key_path(), Values :: [value()], Map :: t()) ->
    NewMap :: maybe_no_return(t()).

set_elements(Key, Values, Map) ->
    Fun = fun
        ({ok, Term}) ->
            case babel_set:is_type(Term) of
                true ->
                    babel_set:set_elements(Values, Term);
                false ->
                    badtype(set, Term)
            end;
        (error) ->
            babel_set:new(Values, Map#babel_map.context)
    end,
    mutate(Key, Fun, Map).



%% -spec update(Key :: key_path(), Fun :: update_fun(), T :: t()) -> NewT :: t().

%% update(Key, Fun, #babel_map{values = V, updates = U} = Map)
%% when is_function(Fun, 1) ->
%%     Map#babel_map{
%%         values = maps:put(Key, Fun(maps:get(Key, V)), V),
%%         updates = ordsets:add_element(Key, U)
%%     }.



%% -----------------------------------------------------------------------------
%% @doc Updated a map with the provide key-value pairs.
%% If the value associated with a key `Key' in `Values' is equal to `undefined`
%% this equivalent to calling `remove(Key, Map)' with the difference that an
%% exception will not be raised in case the map had no context assigned.
%% @end
%% -----------------------------------------------------------------------------
-spec update(Values :: babel_key_value:t(), T :: t(), Spec :: type_spec()) ->
    NewT :: t().

update(Values, T, Spec) when is_map(Values)->
    Fun = fun
        Fold({Key, _}, Value, Acc) ->
            %% A Riak Map key
            Fold(Key, Value, Acc);
        Fold(Key, Value, Acc) ->
            case maps:find(Key, Spec) of
                {ok, TypeSpec} ->
                    do_update(Key, Value, Acc, TypeSpec);
                error ->
                    error({missing_spec, Key})
            end

    end,
    maps:fold(Fun, T, Values);

update(Values, T, Spec) ->
    Map = babel_key_value:fold(
        fun(K, V, Acc) -> maps:put(K, V, Acc) end, Values
    ),
    update(Map, T, Spec).


%% -----------------------------------------------------------------------------
%% @doc Removes a key and its value from the map. Removing a key that
%% does not exist simply records a remove operation.
%% @throws context_required
%% @end
%% -----------------------------------------------------------------------------
-spec remove(Key :: key_path(), T :: t()) -> NewT :: maybe_no_return(t()).

remove(_, #babel_map{context = undefined}) ->
    error(context_required);

remove(Key, T) ->
    do_remove(Key, T).


%% -----------------------------------------------------------------------------
%% @doc
%% @end
%% -----------------------------------------------------------------------------
-spec enable(Key :: key_path(), T :: t()) -> NewT :: t().

enable(Key, Map) ->
    Fun = fun
        ({ok, Term}) ->
            case babel_flag:is_type(Term) of
                true ->
                    babel_flag:enable(Term);
                false ->
                    badtype(flag, Term)
            end;
        (error) ->
            babel_flag:new(true, Map#babel_map.context)
    end,
    mutate(Key, Fun, Map).


%% -----------------------------------------------------------------------------
%% @doc
%% @end
%% -----------------------------------------------------------------------------
-spec disable(Key :: key_path(), T :: t()) -> NewT :: t().

disable(Key, Map) ->
    Fun = fun
        ({ok, Term}) ->
            case babel_flag:is_type(Term) of
                true ->
                    babel_flag:disable(Term);
                false ->
                    badtype(flag, Term)
            end;
        (error) ->
            babel_flag:new(false, Map#babel_map.context)
    end,
    mutate(Key, Fun, Map).


%% -----------------------------------------------------------------------------
%% @doc
%% @end
%% -----------------------------------------------------------------------------
-spec increment(Key :: key_path(), T :: t()) -> NewT :: t().

increment(Key, Map) ->
    increment(Key, 1, Map).


%% -----------------------------------------------------------------------------
%% @doc
%% @end
%% -----------------------------------------------------------------------------
-spec increment(Key :: key_path(), Value :: integer(), T :: t()) -> NewT :: t().

increment(Key, Value, Map) ->
    Fun = fun
        ({ok, Term}) ->
            case babel_counter:is_type(Term) of
                true ->
                    babel_counter:increment(Value, Term);
                false ->
                    badtype(counter, Term)
            end;
        (error) ->
            babel_counter:increment(Value, babel_counter:new())
    end,
    mutate(Key, Fun, Map).


%% -----------------------------------------------------------------------------
%% @doc
%% @end
%% -----------------------------------------------------------------------------
-spec decrement(Key :: key_path(), T :: t()) -> NewT :: t().

decrement(Key, Map) ->
    decrement(Key, 1, Map).


%% -----------------------------------------------------------------------------
%% @doc
%% @end
%% -----------------------------------------------------------------------------
-spec decrement(Key :: key_path(), Value :: integer(), T :: t()) -> NewT :: t().

decrement(Key, Value, Map) ->
    Fun = fun
        ({ok, Term}) ->
            case babel_counter:is_type(Term) of
                true ->
                    babel_counter:decrement(Value, Term);
                false ->
                    badtype(counter, Term)
            end;
        (error) ->
            babel_counter:decrement(Value, babel_counter:new())
    end,
    mutate(Key, Fun, Map).



%% -----------------------------------------------------------------------------
%% @doc Merges two maps into a single map `Map3'.
%% The function implements a deep merge.
%% This function implements minimal type checking so merging two maps that use
%% different type specs can potentially result in an exception being thrown or
%% in an invalid map at time of storing.
%%
%% The call fails with a {badmap,Map} exception if `T1' or `T2' is not a map.
%% @end
%% -----------------------------------------------------------------------------
-spec merge(T1 :: t(), T2 :: t() | map()) -> Map3 :: t().

merge(#babel_map{} = T1, #babel_map{values = V2}) ->
    Fun = fun
        (Key, #babel_map{} = T2i, #babel_map{values = AccValues} = Acc) ->
            case maps:find(Key, AccValues) of
                {ok, #babel_map{} = T1i} ->
                    Acc#babel_map{
                        values = maps:put(Key, merge(T1i, T2i), AccValues),
                        updates = ordsets:add_element(
                            Key, Acc#babel_map.updates
                        )
                    };
                {ok, Term} ->
                    %% Not a babel map
                    badtype(map, Term);
                error ->
                    Acc#babel_map{
                        values = maps:put(Key, set(Key, T2i, Acc), AccValues),
                        updates = ordsets:add_element(
                            Key, Acc#babel_map.updates
                        )
                    }
            end;

        (Key, Term, Acc) ->
            maybe_merge(Key, Term, Acc)
    end,
    maps:fold(Fun, T1, V2).



%% =============================================================================
%% PRIVATE
%% =============================================================================



%% @private
from_map(Map, #{'_' := TypeOrSpec}, Ctxt) ->
    from_map(Map, expand_spec(maps:keys(Map), TypeOrSpec), Ctxt);

from_map(Map, Spec, Ctxt) when is_map(Spec) ->
    ConvertType = fun(Key, Value) ->
        case maps:find(Key, Spec) of
            {ok, {Datatype, SpecOrType}} ->
                from_term(Value, Ctxt, Datatype, SpecOrType);
            error ->
                error({missing_spec, Key})
        end
    end,
    Values0 = maps:map(ConvertType, Map),

    %% Initialise values for Spec keys not present in Map
    %% Keys = maps:keys(Map),
    %% MissingKeys = lists:subtract(maps:keys(Spec), Keys),
    %% Values = init_values(maps:with(MissingKeys, Spec), Values0),
    #babel_map{
        values = Values0,
        updates = ordsets:from_list(maps:keys(Values0)),
        context = Ctxt
    }.


%% @private
from_term(Term, Ctxt, map, Spec) when is_map(Term) ->
    new(Term, Spec, Ctxt);

from_term(Term, Ctxt, set, _) when is_list(Term) ->
    babel_set:new(Term, Ctxt);

from_term(Term, _, counter, integer) when is_integer(Term) ->
    babel_counter:new(Term);

from_term(Term, Ctxt, flag, boolean) when is_boolean(Term) ->
    babel_flag:new(Term, Ctxt);

from_term(Term, _, register, atom) when is_atom(Term) ->
    Term;

from_term(Term, _, register, existing_atom) when is_atom(Term) ->
    Term;

from_term(Term, _, register, boolean) when is_boolean(Term) ->
    Term;

from_term(Term, _, register, integer) when is_integer(Term) ->
    Term;

from_term(Term, _, register, float) when is_float(Term) ->
    Term;

from_term(Term, _, register, binary) when is_binary(Term) ->
    Term;

from_term(Term, _, register, integer) when is_integer(Term) ->
    Term;

from_term(Term, _, register, Fun) when is_function(Fun, 2) ->
    Term;

from_term(Term, _, register, Type) ->
    error({badkeytype, Term, Type}).


%% @private
-spec from_riak_map(orddict:orddict(), riakc_datatype:context(), type_spec()) ->
    maybe_no_return(t()).

from_riak_map(RMap, Context, Spec) when is_map(Spec) ->
    %% Convert values in RMap
    Convert = fun({Key, Datatype} = RKey, RValue, Acc) ->
        case maps:find(Key, Spec) of
            {ok, {X, SpecOrType}} when X == Datatype ->
                Value = from_datatype(RKey, RValue, Context, SpecOrType),
                maps:put(Key, Value, Acc);
            {ok, {X, _SpecOrType}} ->
                error({datatype_mismatch, X, Datatype});
            error ->
                error({missing_spec, RKey})
        end
    end,
    Values0 = orddict:fold(Convert, maps:new(), RMap),

    %% Initialise values for Spec keys not present in RMap
    %% Keys = [Key || {Key, _} <- orddict:fetch_keys(RMap)],
    %% MissingKeys = lists:subtract(maps:keys(Spec), Keys),
    %% Values1 = init_values(maps:with(MissingKeys, Spec), Values0),

    #babel_map{values = Values0, context = Context}.


%% @private
modified_keys(#babel_map{updates = U, removes = R}) ->
    ordsets:union(U, R).

%% @private
%% init_values(Spec, Acc0) ->
%%     %% We only set the missing container values
%%     Fun = fun
%%         (Key, {map, KeySpec}, Acc) when is_map(KeySpec) ->
%%             maps:put(Key, babel_map:new(), Acc);

%%         (Key, {set, _}, Acc) ->
%%             maps:put(Key, babel_set:new(), Acc);

%%         (_, {register, _}, Acc) ->
%%             Acc;

%%         (Key, {flag, _}, Acc) ->
%%             maps:put(Key, babel_flag:new(), Acc);

%%         (_, {counter, _KeySpec}, _) ->
%%             error(not_implemented)
%%     end,
%%     maps:fold(Fun, Acc0, Spec).


%% @private
from_datatype({_, register}, Value, Ctxt, Fun) when is_function(Fun, 2) ->
    Fun(decode, Value);

from_datatype({_, register}, Value, _, Type) ->
    babel_utils:from_binary(Value, Type);

from_datatype({_, set}, Value, Ctxt, Type) ->
    babel_set:from_riak_set(Value, Ctxt, Type);

from_datatype({_, map}, Value, Ctxt, Spec) ->
    from_riak_map(Value, Spec);

from_datatype({_, counter}, Value, _, Type) ->
    babel_counter:from_riak_counter(Value, Type);

from_datatype({_, flag}, Value, Ctxt, Type) ->
    babel_flag:from_riak_flag(Value, Ctxt, Type);

from_datatype(_, _, _, _) ->
    error(not_implemented).


%% @private
to_binary(Value, Fun) when is_function(Fun, 2) ->
    Fun(encode, Value);

to_binary(Value, Type) ->
    babel_utils:to_binary(Value, Type).


%% @private
maybe_badkey(?BADKEY) ->
    error(badkey);

maybe_badkey(Term) ->
    Term.


%% @private
type_value(#babel_map{} = Map) ->
    value(Map);

type_value(Term) ->
    case get_type(Term) of
        register ->
            %% Registers are implicit in babel
            Term;
        set ->
            babel_set:value(Term);
        flag ->
            babel_flag:value(Term);
        counter ->
            babel_counter:value(Term);
        Datatype ->
            error({not_implemented, Datatype})
    end.


%% -----------------------------------------------------------------------------
%% @private
%% @doc
%% @end
%% -----------------------------------------------------------------------------
-spec get_type(Term :: any()) -> datatype().

get_type(#babel_map{}) ->
    map;

get_type(Term) when is_tuple(Term) ->
    Mods = [babel_set, babel_map, babel_counter, babel_flag],
    Fun = fun(Mod, Acc) ->
        case (catch Mod:is_type(Term)) of
            true ->
                throw({type, Mod:type()});
            _ ->
                Acc
        end
    end,

    try
        lists:foldl(Fun, register, Mods)
    catch
        throw:{type, Mod} -> Mod
    end;

get_type(_) ->
    register.


%% @private
badtype(register, Key) ->
    error({badregister, Key});

badtype(map, Key) ->
    error({badmap, Key});

badtype(set, Key) ->
    error({badset, Key});

badtype(flag, Key) ->
    error({badflag, Key});

badtype(counter, Key) ->
    error({badcounter, Key}).


%% @private
expand_spec(Keys, Spec) when is_map(Spec) ->
    case maps:to_list(Spec) of
        [{'_', {_, _} = TypeMapping}] ->
            expand_spec(Keys, TypeMapping);
        _ ->
            %% If the spec uses the key wildcard there cannot be more keys in it
            error({badspec, Spec})
    end;

expand_spec(Keys, {Datatype, _} = TypeMapping) ->
    Fun = fun
        ({Key, X}, Acc) when X == Datatype ->
            %% All Keys in the Riak Map should be of the same datatype when
            %% using the key wildcard
            maps:put(Key, TypeMapping, Acc);
        ({_, _} = RKey, _) ->
            error({badarg, RKey});
        (Key, Acc) when is_binary(Key) ->
            maps:put(Key, TypeMapping, Acc)
    end,
    lists:foldl(Fun, maps:new(), Keys).


%% @private
prepare_update_ops(T, Spec) ->
    %% Spec :: #{Key => {{_, _} = RKey, Spec}}
    FoldFun = fun
        ToOp({{_, map} = RKey, MapSpec}, Map, Acc) ->
            case to_riak_op(Map, MapSpec) of
                undefined -> Acc;
                {_, Op, _} -> [{update, RKey, Op} | Acc]
            end;

        ToOp({{_, set} = RKey, Type}, Set, Acc) ->
            case babel_set:to_riak_op(Set, Type) of
                undefined -> Acc;
                {_, Op, _} -> [{update, RKey, Op} | Acc]
            end;

        ToOp({{_, register} = RKey, Type}, Value, Acc) ->
            Bin = to_binary(Value, Type),
            [{update, RKey, {assign, Bin}} | Acc];

        ToOp({_, register}, undefined, Acc) ->
            Acc;

        ToOp({{_, flag} = RKey, Type}, Flag, Acc) ->
            case babel_flag:to_riak_op(Flag, Type) of
                undefined -> Acc;
                {_, Op, _} -> [{update, RKey, Op} | Acc]
            end;

        ToOp({{_, counter} = RKey, Type}, Counter, Acc) ->
            case babel_counter:to_riak_op(Counter, Type) of
                undefined -> Acc;
                {_, Op, _} -> [{update, RKey, Op} | Acc]
            end;

        ToOp(Key, Value, Acc) ->
            {Datatype, SpecOrType} = maps:get(Key, Spec),
            ToOp({{Key, Datatype}, SpecOrType}, Value, Acc)

    end,

    Updates = maps:with(T#babel_map.updates, T#babel_map.values),
    maps:fold(FoldFun, [], Updates).


%% @private
prepare_remove_ops(T, Spec) ->
    [
        {remove, {Key, element(1, maps:get(Key, Spec))}}
        || Key <- T#babel_map.removes
    ].



%% -----------------------------------------------------------------------------
%% @private
%% @doc Util function used by the following type specific functions
%% (map) set/3,
%% (set) add_elements/3,
%% (set) del_elements/3,
%% (flag) enable/2
%% (flag) disable/2
%%
%% Passing a `Value' of `undefined` is equivalent to calling `remove(Key, Map)'
%% with the difference that an exception will not be raised in case the map had
%% no context assigned.
%% @end
%% -----------------------------------------------------------------------------
-spec mutate(Key :: key_path(), Value :: value() | function(), Map :: t()) ->
    NewMap :: maybe_no_return(t()).

mutate(_, undefined, #babel_map{context = undefined} = Map) ->
    %% We do nothing
    Map;

mutate(Key, undefined, Map) ->
    remove(Key, Map);

mutate([H|[]], Value, Map) ->
    mutate(H, Value, Map);

mutate([H|T], Value, #babel_map{values = V, context = C} = Map) ->
    case maps:find(H, V) of
        {ok, #babel_map{} = HMap} ->
            Map#babel_map{
                values = maps:put(H, mutate(T, Value, HMap), V),
                updates = ordsets:add_element(H, Map#babel_map.updates)
            };
        {ok, Term} ->
            badtype(map, Term);
        error ->
            Map#babel_map{
                values = maps:put(H, mutate(T, Value, new(#{}, #{}, C)), V),
                updates = ordsets:add_element(H, Map#babel_map.updates)
            }
    end;

mutate(Key, Term, #babel_map{} = Map) when is_binary(Key) ->
    Value = mutate_eval(Key, Term, Map),
    Map#babel_map{
        values = maps:put(Key, Value, Map#babel_map.values),
        updates = ordsets:add_element(Key, Map#babel_map.updates)
    };

mutate(Key, _, #babel_map{}) when not is_binary(Key) ->
    error({badkey, Key});

mutate(_, _, Map) ->
    badtype(map, Map).


%% @private
mutate_eval(_, Fun, _) when is_function(Fun, 0) ->
    Fun();

mutate_eval(Key, Fun, #babel_map{values = V}) when is_function(Fun, 1) ->
    Fun(maps:find(Key, V));

mutate_eval(_, Value, _) when not is_function(Value) ->
    Value.


%% @private
collect([H|T], Map, Default, Acc) ->
    try
        collect(T, Map, Default, [get(H, Map, Default)|Acc])
    catch
        error:badkey ->
            error({badkey, H})
    end;

collect([], _, _, Acc) ->
    lists:reverse(Acc).



%% @private
do_remove([H|[]], Map) ->
    do_remove(H, Map);

do_remove([H|T], #babel_map{values = V} = Map) ->
    case maps:get(H, V, undefined) of
        #babel_map{} = HMap ->
            Map#babel_map{
                values = maps:put(H, do_remove(T, HMap), V),
                updates = ordsets:add_element(H, Map#babel_map.updates)
            };
        undefined ->
            error({badkey, H});
        Term ->
            badtype(map, Term)
    end;

do_remove(Key, #babel_map{} = Map) when is_binary(Key) ->
    Map#babel_map{
        values = maps:remove(Key, Map#babel_map.values),
        removes = ordsets:add_element(Key, Map#babel_map.removes)
    };

do_remove(Key, #babel_map{}) when not is_binary(Key) ->
    error({badkey, Key});

do_remove(_, Term) ->
    badtype(map, Term).

%% @private
maybe_merge(Key, Term2, Acc) ->
    Type = get_type(Term2),

    case find(Key, Acc) of
        {ok, Term1} ->
            Type == get_type(Term1) orelse badtype(Type, Key),
            merge(Key, Term2, Acc, Type);
        error ->
            merge(Key, Term2, Acc, Type)
    end.


%% @private
merge(Key, Value, Acc, register) ->
    set(Key, Value, Acc);

merge(Key, Set, Acc, set) ->
    add_elements(Key, babel_set:value(Set), Acc);

merge(Key, Set, Acc, flag) ->
    case babel_flag:value(Set) of
        true ->
            enable(Key, Acc);
        false ->
            disable(Key, Acc)
    end;

merge(Key, Counter, Acc, counter) ->
    Value = babel_counter:value(Counter),
    increment(Key, Value, Acc).


%% @private
do_update(_, undefined, #babel_map{context = undefined} = Acc, _) ->
    Acc;

do_update(Key, undefined, Acc, _) ->
    remove(Key, Acc);

do_update(Key, Value, Acc, {register, _}) ->
    %% We simply replace the existing register
    set(Key, Value, Acc);

do_update(Key, Value, #babel_map{values = V} = Acc, {map, Spec}) ->
    case maps:find(Key, V) of
        {ok, #babel_map{} = Inner} ->
            %% We update the inner map recursively and replace
            set(Key, update(Value, Inner, Spec), Acc);
        _ ->
            %% The existing value was not found or is not a map, but it should
            %% be according to spec, so we replace by a new map
            set(Key, babel_map:new(Value, Spec), Acc)
    end;

do_update(Key, Value, Acc, {set, _}) when is_list(Value) ->
    try
        set_elements(Key, Value, Acc)
    catch
        throw:context_required ->
            %% We have a brand new set (not in Riak yet) so we just replace it
            set(Key, babel_set:new(Value, Acc#babel_map.context), Acc)
    end;

do_update(Key, Value, #babel_map{values = V} = Acc, {counter, integer}) ->
    case maps:find(Key, V) of
        {ok, Term} ->
            case babel_counter:is_type(Term) of
                true ->
                    %% We update the counter
                    set(Key, babel_counter:set(Value, Term), Acc);
                false ->
                    %% The existing value is not a counter, but it should be
                    %% according to spec, so we replace by a new one
                    set(Key, babel_counter:new(Value), Acc)
            end;
        _ ->
            %% The existing value was not found so create a new one
            set(Key, babel_counter:new(Value), Acc)
    end;

do_update(Key, Value, #babel_map{values = V} = Acc, {flag, boolean}) ->
    Ctxt = Acc#babel_map.context,

    case maps:find(Key, V) of
        {ok, Term} ->
            case babel_flag:is_type(Term) of
                true ->
                    Flag = try
                        babel_flag:set(Value, Term)
                    catch
                        throw:context_required ->
                            %% We have a brand new flag (not in Riak yet) so we
                            %% just replace it
                            babel_flag:new(Value, Ctxt)
                    end,
                    set(Key, Flag, Acc);
                false ->
                    %% The existing value is not a counter, but it should be
                    %% according to spec, so we replace by a new one
                    set(Key, babel_flag:new(Value, Ctxt), Acc)
            end;
        _ ->
            %% The existing value was not found so create a new one
            set(Key, babel_flag:new(Value, Ctxt), Acc)
    end.


%% @private
updated_key_paths(#babel_map{updates = U}, Acc, Path0) ->
    lists:foldl(
        fun(Key, InnerAcc0) ->
            Path1 = Path0 ++ [Key],
            case get(Key, InnerAcc0, undefined) of
                #babel_map{} = Map ->
                    updated_key_paths(Map, InnerAcc0, Path1);
                _ ->
                    [Path1 | InnerAcc0]
            end
        end,
        Acc,
        U
    ).