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
%% @doc Provides an alternative to Riak Map Datatype.
%%
%% # Overview
%%
%% Babel maps (maps) differ from Riak's and Erlang's maps in several ways:
%%
%% * Maps are special key-value structures where the key is a binary name and
%% the value is a Babel datatype, each one an alternative of the Riak's
%% counterparts, with the exception of the Riak Register type which can be
%% represented by any Erlang Term in Babel (and not just a binary) provided
%% there exists a valid type conversion specification (see <a href="#type-specifications">Type Specifications</a>).
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
%% # <a name="type-specifications"></a>Type Specifications
%%
%% A type specification is an Erlang map where the keys are the Babel map keys
%% and their value is another specification or a
%% `type_mapping()'.
%%
%% For example the specification `#{<<"friends">> => {set, list}}', says the
%% map contains a single key name "friends" containing a Babel Set (compatible
%% with Riak Set) where the individual
%% elements are represented in Erlang as lists i.e. a set of lists. This will
%% result in a map containing the key `<<"friends">>' and a babel set contining
%% the elements converted from binaries to lists.
%%
%% The special '\_' key name provides the capability to convert a Riak Map where
%% the keys are not known in advance, and their values are all of the same
%% type. These specs can only have a single entry as follows
%% `#{{'\_', set}, binary}'.
%%
%% @end
%% -----------------------------------------------------------------------------
-module(babel_map).
-include("babel.hrl").

-define(BADKEY, '$error_badkey').
-define(COLLECT_VALUES, '$collect_values').
-define(DEFAULT_COLLECT_OPTS, #{
    '$collect_values' => false,
    default => ?BADKEY,
    on_badkey => default,
    return => list
}).

-record(babel_map, {
    values = #{}            ::  #{key() => value()},
    updates = []            ::  ordsets:ordset(key()),
    removes = []            ::  ordsets:ordset(key()),
    context                 ::  babel_context(),
    type_spec_ref           ::  type_spec_ref() | undefined
}).

-opaque t()                 ::  #babel_map{}.

-type datatype()            ::  counter | flag | register | set | map.
-type type_spec()           ::  #{
                                    '$validated' => true,
                                    key() | '_'  => type_mapping()
                                }.
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
-type action()              ::  map().
-type collect_opts()        ::  #{
                                    default => any(),
                                    on_badkey => skip | error,
                                    return => map | list
                                }.
-type type_spec_ref()       ::  {type_spec_ref, any()}.


-export_type([t/0]).
-export_type([type_spec/0]).
-export_type([type_spec_ref/0]).
-export_type([key_path/0]).
-export_type([action/0]).

%% API
-export([add_element/3]).
-export([add_elements/3]).
-export([change_status/2]).
-export([change_status/3]).
-export([changed_key_paths/1]).
-export([collect/2]).
-export([collect/3]).
-export([collect_values/2]).
-export([collect_values/3]).
-export([context/1]).
-export([decrement/2]).
-export([decrement/3]).
-export([del_element/3]).
-export([disable/2]).
-export([enable/2]).
-export([find/2]).
-export([from_riak_map/2]).
-export([from_riak_map/3]).
-export([get/2]).
-export([get/3]).
-export([get_value/2]).
-export([get_value/3]).
-export([increment/2]).
-export([increment/3]).
-export([is_type/1]).
-export([keys/1]).
-export([new/0]).
-export([new/1]).
-export([new/2]).
-export([new/3]).
-export([patch/3]).
-export([put/3]).
-export([remove/2]).
-export([set/3]).
-export([set_context/2]).
-export([set_elements/3]).
-export([size/1]).
-export([to_riak_op/1]).
-export([to_riak_op/2]).
-export([type/0]).
-export([update/3]).
-export([update/2]).
-export([validate_type_spec/1]).
-export([value/1]).
-export([type_spec_ref/1]).


-export([register_type_spec/1]).
-export([register_type_spec/2]).
-export([unregister_type_spec/1]).
-export([get_registered_type_spec/1]).


%% =============================================================================
%% API
%% =============================================================================



%% -----------------------------------------------------------------------------
%% @doc Creates a new empty map.
%% @end
%% -----------------------------------------------------------------------------
-spec new() -> t().

new()->
    #babel_map{}.


%% -----------------------------------------------------------------------------
%% @doc Creates a new map from the erlang map `Data', previously
%% filtering out all keys assigned to the `undefined'.
%% This function converts the erlang types `map()', `list()' and `boolean()' to
%% their corresponding Babel Datatypes `babel_map:t()', `babel_map:set()' and
%% `babel_map:flag()'. Any other value will be assumed to be a register. Also,
%% there is not type validation or coersion when creating a `babel_set:t()' out
%% of a list.
%%
%% !> **Important**. Notice that using this function might result in
%% incompatible types when later using a type specification e.g. {@link
%% to_riak_op/2}. We strongly suggest not using this function and using {@link
%% new/2} instead.
%%
%% @end
%% -----------------------------------------------------------------------------
-spec new(Data :: map()) -> t().

new(Data) when is_map(Data) ->
    Valid = maps:fold(
        fun
            (K, undefined, Acc) when is_binary(K) ->
                maps:remove(K, Acc);
            (K, V, Acc) when is_binary(K) andalso is_map(V) ->
                maps:update(K, new(V), Acc);
            (K, V, Acc) when is_binary(K) andalso is_list(V) ->
                maps:update(K, babel_set:new(V), Acc);
            (K, V, Acc) when is_binary(K) andalso is_boolean(V) ->
                maps:update(K, babel_flag:new(V), Acc);
            (K, V, Acc) when is_binary(K) andalso is_integer(V) ->
                maps:update(K, babel_counter:new(V), Acc);
            (K, _, Acc) when is_binary(K) ->
                Acc;
            (K, _, _) ->
                error({badkey, K})
        end,
        Data,
        Data
    ),
    #babel_map{
        values = Valid,
        updates = ordsets:from_list(maps:keys(Valid))
    }.


%% -----------------------------------------------------------------------------
%% @doc
%% @equiv new(Data, Spec, undefined)
%% @end
%% -----------------------------------------------------------------------------
-spec new(Data :: map(), Spec :: type_spec()) -> t().

new(Data, Spec) ->
    new(Data, Spec, undefined).


%% -----------------------------------------------------------------------------
%% @doc Creates a new Babel Map from the erlang map `Data', previously
%% filtering out all keys assigned to the `undefined'.
%% @end
%% -----------------------------------------------------------------------------
-spec new(
    Data :: map(),
    Spec :: type_spec() | type_spec_ref(),
    Ctxt :: riakc_datatype:context()) -> t().

new(Data, Spec, Ctxt) ->
    from_map(Data, Spec, Ctxt).


%% -----------------------------------------------------------------------------
%% @doc Returns a new map by applying the type specification `Spec' to the Riak
%% Map `RMap'.
%% @end
%% -----------------------------------------------------------------------------
-spec from_riak_map(
    RMap :: riakc_map:crdt_map() | list(), Spec :: type_spec()) -> t().

from_riak_map(RMap, Spec) ->
    from_riak_map(RMap, Spec, #{missing_specs => error}).


%% -----------------------------------------------------------------------------
%% @doc Returns a new map by applying the type specification `Spec' to the Riak
%% Map `RMap'.
%%
%% `Options' is a map containing th following options:
%% * missing_spec -- the strategy to deal with a field found in the Riak Map
%% that does not have a mapping in the type specificiation `Spec'. It accepts
%% the values `error` or `ignore`. In the case of `error` a
%% `{missing_spec, Key}' exception will be raised; in the case or `ignore' it
%% will simply be ignored. The default is `error'.
%% @end
%% -----------------------------------------------------------------------------
-spec from_riak_map(
    RMap :: riakc_map:crdt_map() | list(),
    Spec :: type_spec() | type_spec_ref(),
    Opts :: map()) -> t().


from_riak_map(RMap, SpecOrRef, Opts) when is_tuple(RMap) ->
    Context = element(5, RMap),
    Values = riakc_map:value(RMap),
    from_orddict(Values, Context, SpecOrRef, Opts);

from_riak_map(Values, SpecOrRef, Opts) when is_list(Values) ->
    from_orddict(Values, undefined, SpecOrRef, Opts).


%% -----------------------------------------------------------------------------
%% @doc Extracts a Riak Operation from the map to be used with a Riak Client
%% update request.
%% The call fails with a `{badmap, T}' exception if `T' is not a map and
%% `missing_spec' if it does not have a type specification reference.
%% @end
%% -----------------------------------------------------------------------------
to_riak_op(#babel_map{type_spec_ref = {type_spec_ref, _} = Ref} = T) ->
    to_riak_op(T, Ref);

to_riak_op(_) ->
    error(missing_spec).


%% -----------------------------------------------------------------------------
%% @doc Extracts a Riak Operation from the map to be used with a Riak Client
%% update request.
%% The call fails with a `{badmap, T}' exception if `T' is not a map.
%% @end
%% -----------------------------------------------------------------------------
-spec to_riak_op(T :: t(), Spec :: type_spec()) ->
    riakc_datatype:update(riakc_map:map_op()) | no_return().

to_riak_op(T, {type_spec_ref, _} = Ref) ->
    to_riak_op(T, get_registered_type_spec(Ref));

to_riak_op(T, #{'_' := TypeOrSpec}) ->
    to_riak_op(T, expand_spec(modified_keys(T), TypeOrSpec));

to_riak_op(#babel_map{} = T, Spec0) when is_map(Spec0) ->
    Spec = validate_type_spec(Spec0),
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
%% @doc
%% @end
%% -----------------------------------------------------------------------------
-spec validate_type_spec(Spec :: type_spec()) -> type_spec() | no_return().

validate_type_spec(#{'$validated' := true} = Spec) ->
    Spec;

validate_type_spec(Spec0) ->
    _ = validate_type_spec(Spec0, []),
    maps:put('$validated', true, Spec0).


%% @private
validate_type_spec(Spec0, Acc) ->
    Validate = fun
        (K, {map, MapSpec}, FAcc) when is_binary(K) orelse K == '_' ->
            validate_type_spec(MapSpec, FAcc);

        (K, {Type, TypeSpec} = V, FAcc) when is_binary(K) orelse K == '_' ->
            case type_to_mod(Type) of
                undefined ->
                    %% register
                    FAcc;
                error ->
                    [{K, V} | FAcc];
                Mod ->
                    case Mod:is_valid_type_spec(TypeSpec) of
                        true -> FAcc;
                        false -> [{K, V} | FAcc]
                    end
            end;

        (K, V, FAcc) ->
            [{K, V} | FAcc]
    end,

    case maps:fold(Validate, Acc, Spec0) of
        [] ->
            Acc;
        Errors ->
            error({invalid_spec, Errors})
    end.


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
%% @doc Returns a tuple where the first element is the list of the key paths
%% that have been updated and the second one those which have been removed
%% in map `T'.
%% Notice that a key path might be both removed and updated, in which case it
%% will be a mamber of both result elements.
%% The call fails with a `{badmap, T}' exception if `T' is not a map.
%% @end
%% -----------------------------------------------------------------------------
-spec changed_key_paths(T :: t()) ->
    {Updated :: [key_path()], Removed :: [key_path()]} | no_return().

changed_key_paths(#babel_map{} = T) ->
    changed_key_paths(T, {[], []}, []);

changed_key_paths(Term) ->
    badtype(map, Term).


%% -----------------------------------------------------------------------------
%% @doc Returns the status of a key path `KeyPath' in map `Map', where status
%% can be one of `updated', `removed', `both' or `none'.
%% @end
%% -----------------------------------------------------------------------------
-spec change_status(KeyOrPath :: key_path(), Map :: t()) ->
    none | both | removed | updated | any().

change_status(KeyOrPath, Map) ->
    change_status(KeyOrPath, Map, ?BADKEY).


%% -----------------------------------------------------------------------------
%% @doc Returns the status of a key path `KeyPath' in map `Map', where status
%% can be one of `updated', `removed', `both' or `none'.
%% @end
%% -----------------------------------------------------------------------------
-spec change_status(KeyOrPath :: key_path(), Map :: t(), Default :: any()) ->
    none | removed | updated | any() | no_return().

change_status([Key|[]], Map, Default) ->
    change_status(Key, Map, Default);

change_status([H|T], #babel_map{values = V}, Default) ->
    case maps:find(H, V) of
        {ok, #babel_map{} = Child} ->
            change_status(T, Child, Default);
        {ok, _} ->
            error({badkey, T});
        error when Default == ?BADKEY ->
            error({badkey, H});
        error ->
            Default
    end;

change_status(Key, #babel_map{values = V, updates = U, removes = R}, Default) ->
    case maps:is_key(Key, V) of
        true ->
            IsU = ordsets:is_element(Key, U),
            IsR = ordsets:is_element(Key, R),
            case {IsU, IsR} of
                {false, false} -> none;
                _ -> updated
            end;
        false when length(R) > 0 ->
            IsU = ordsets:is_element(Key, U),
            IsR = ordsets:is_element(Key, R),
            case {IsU, IsR} of
                {_, true} -> removed;
                {true, false} -> updated;
                _ ->
                    Default == ?BADKEY andalso error({badkey, Key}),
                    Default
            end;
         false when Default == ?BADKEY ->
            error({badkey, Key});
        false ->
            Default
    end.



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
-spec context(T :: t()) -> babel_context() | no_return().

context(#babel_map{context = Value}) ->
    Value;

context(Term) ->
    badtype(map, Term).


%% -----------------------------------------------------------------------------
%% @doc Sets the context `Ctxt'.
%% @end
%% -----------------------------------------------------------------------------
-spec set_context(Ctxt :: riakc_datatype:context(), T :: t()) ->
    NewT :: t().

set_context(Ctxt, #babel_map{} = T)
when is_binary(Ctxt) orelse Ctxt == undefined orelse Ctxt == inherited ->
    T#babel_map{context = Ctxt};

set_context(Ctxt, #babel_map{}) ->
    error({badarg, Ctxt});

set_context(_, Term) ->
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
%% @doc An util function equivalent to calling `DatatypeMod:value(get(Key, T))'.
%% @end
%% -----------------------------------------------------------------------------
-spec get_value(Key :: key_path(), T :: t()) -> any().

get_value(Key, T) ->
    type_value(get(Key, T, ?BADKEY)).


%% -----------------------------------------------------------------------------
%% @doc An util function equivalent to calling
%% `DatatypeMod:value(get(Key, T, Default))'.
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
%% @doc Calls {@link collect/3} with the default options.
%% @end
%% -----------------------------------------------------------------------------
-spec collect([key_path()], Map :: t()) -> [any()].

collect(Keys, Map) ->
    collect(Keys, Map, ?DEFAULT_COLLECT_OPTS).


%% -----------------------------------------------------------------------------
%% @doc Returns a list of values associated with the keys `Keys'.
%%
%% ?> The value returned by this function are not raw values, but Babel
%% datatype values. If you want to get the raw values use
%% {@link collect_values/3} instead.
%%
%% The return depends on the following options:
%%
%% * `default' - the value to use as default when a key in `Keys' is not
%% present in the map `Map'. The presence of a default value disables the
%% option `on_badkey'.
%% * `on_badkey' - what happens when a key is not present in the map and there
%% was no default value provided. Valid values are `skip', or `error'. When
%% using `skip' the function simply ignores the missing key and returns all
%% found keys. Using `error' will fail with a `badkey' exception.
%% * `return` - the Erlang return type of the function. Valid values are `list'
%% and `map'. Notice that naturally Erlang maps will deduplicate keys whereas
%% lists would not. Default value: `list'.
%%
%% **Examples**:
%%
%% <pre lang="erlang"><![CDATA[
%% Map = babel_map:new(
%%     #{
%%         <<"x">> => #{
%%             <<"a">> => 1,
%%             <<"b">> => 2
%%         }
%%     },
%%     #{
%%         <<"x">> => {map, #{
%%             <<"a">> => {counter, integer},
%%             <<"b">> => {counter, integer}
%%         }}
%%     }
%% ).
%% ]]></pre>
%%
%% <pre lang="erlang"><![CDATA[
%% babel_map:collect([<<"x">>], Map).
%% [{babel_map,#{<<"a">> => {babel_counter,0,1},
%%               <<"b">> => {babel_counter,0,2}},
%%             [<<"a">>,<<"b">>],
%%             [],undefined}]
%% ]]></pre>
%%
%% <pre lang="erlang"><![CDATA[
%% babel_map:collect([<<"y">>], Map).
%% ** exception error: badkey
%% ]]></pre>
%%
%% <pre lang="erlang"><![CDATA[
%% babel_map:collect([<<"y">>], Map, #{on_badkey => skip}).
%% []
%% ]]></pre>
%%
%% <pre lang="erlang"><![CDATA[
%% babel_map:collect([<<"y">>], Map, #{default => undefined}).
%% [undefined]
%% ]]></pre>
%%
%% <pre lang="erlang"><![CDATA[
%% babel_map:collect([<<"x">>], Map, #{return => map}).
%% #{<<"x">> =>
%%       {babel_map,#{<<"a">> => {babel_counter,0,1},
%%                    <<"b">> => {babel_counter,0,2}},
%%                  [<<"a">>,<<"b">>],
%%                  [],undefined}}
%% ]]></pre>
%%
%% <pre lang="erlang"><![CDATA[
%% babel_map:collect(
%%     [ [<<"x">>, <<"a">>], [<<"x">>, <<"b">>]  ],
%%     Map,
%%     #{return => list}
%% ).
%% [{babel_counter, 0, 1},{babel_counter, 0, 2}]
%% ]]></pre>
%%
%% <pre lang="erlang"><![CDATA[
%% babel_map:collect(
%%     [ [<<"x">>, <<"a">>], [<<"x">>, <<"b">>]  ],
%%     Map,
%%     #{return => map}
%% ).
%% #{<<"x">> =>
%%       #{<<"a">> => {babel_counter,0,1},
%%         <<"b">> => {babel_counter,0,2}}}
%% ]]></pre>
%%
%% !> The function is not clever in terms of optimisations, so judgment is
%% required when used. For example if
%% `Keys = [ [A, B, X], [A, B, Y], [A, B, Z] ]', it will iterate 3 times
%% traversing the whole path from A to X, Y and Z i.e. reading A then B three
%% times. In the future we might want to change this so that [A, B] is read
%% once.
%%
%% @throws badkey
%% @end
%% -----------------------------------------------------------------------------
-spec collect(Keys :: [key_path()], Map :: t(), Opts :: collect_opts()) ->
    [any()] | #{binary() => any()}.

collect(Keys, Map, Opts0) when is_list(Keys) andalso is_map(Opts0) ->
    Opts1 = maps:merge(?DEFAULT_COLLECT_OPTS, Opts0),
    Opts = maps:put(?COLLECT_VALUES, false, Opts1),
    Acc = case maps:get(return, Opts) of
        list -> [];
        map -> maps:new()
    end,
    do_collect(Keys, Map, Opts, Acc).


%% -----------------------------------------------------------------------------
%% @doc Returns a list of values associated with the keys `Keys'.
%% Fails with a `{badkey, K}` exeception if any key `K' in `Keys' is not
%% present in the map.
%% @end
%% -----------------------------------------------------------------------------
-spec collect_values([key_path()], Map :: t()) -> [any()].

collect_values(Keys, Map) ->
    collect_values(Keys, Map, ?DEFAULT_COLLECT_OPTS).


%% -----------------------------------------------------------------------------
%% @doc Returns a list of values associated with the keys `Keys'.
%%
%% ?> The value returned by this function are the raw values e.g. equivalent to
%% calling {@link get_value/2} on a Babel datatype. If you want to get the
%% container datatype values use {@link collect/3} instead.
%%
%% The return depends on the following options:
%%
%% * `default' - the value to use as default when a key in `Keys' is not
%% present in the map `Map'. The presence of a default value disables the
%% option `on_badkey'.
%% * `on_badkey' - what happens when a key is not present in the map and there
%% was no default value provided. Valid values are `skip', or `error'. When
%% using `skip' the function simply ignores the missing key and returns all
%% found keys. Using `error' will fail with a `badkey' exception.
%% * `return` - the Erlang return type of the function. Valid values are `list'
%% and `map'. Notice that naturally Erlang maps will deduplicate keys whereas
%% lists would not. Default value: `list'.
%%
%% **Examples**:
%%
%% <pre lang="erlang"><![CDATA[
%% Map = babel_map:new(
%%     #{
%%         <<"x">> => #{
%%             <<"a">> => 1,
%%             <<"b">> => 2
%%         }
%%     },
%%     #{
%%         <<"x">> => {map, #{
%%             <<"a">> => {counter, integer},
%%             <<"b">> => {counter, integer}
%%         }}
%%     }
%% ).
%% ]]></pre>
%%
%% <pre lang="erlang"><![CDATA[
%% babel_map:collect_values([<<"x">>], Map).
%% [#{<<"a">> => 1, <<"b">> => 2}]
%% ]]></pre>
%%
%% <pre lang="erlang"><![CDATA[
%% babel_map:collect_values([<<"y">>], Map).
%% ** exception error: badkey
%% ]]></pre>
%%
%% <pre lang="erlang"><![CDATA[
%% babel_map:collect_values([<<"y">>], Map, #{on_badkey => skip}).
%% []
%% ]]></pre>
%%
%% <pre lang="erlang"><![CDATA[
%% babel_map:collect_values([<<"y">>], Map, #{default => undefined}).
%% [undefined]
%% ]]></pre>
%%
%% <pre lang="erlang"><![CDATA[
%% babel_map:collect_values([<<"x">>], Map, #{return => map}).
%% #{<<"x">> => #{<<"a">> => 1, <<"b">> => 2}}.
%% ]]></pre>
%%
%% <pre lang="erlang"><![CDATA[
%% babel_map:collect_values(
%%     [ [<<"x">>, <<"a">>], [<<"x">>, <<"b">>]  ],
%%     Map,
%%     #{return => list}
%% ).
%% [1,2]
%% ]]></pre>
%% <pre lang="erlang"><![CDATA[
%% babel_map:collect_values(
%%     [ [<<"x">>, <<"a">>], [<<"x">>, <<"b">>]  ],
%%     Map,
%%     #{return => map}
%% ).
%% #{<<"x">> => #{<<"a">> => 1, <<"b">> => 2}}
%% ]]></pre>
%%
%% !> The function is not clever in terms of optimisations, so judgment is
%% required when used. For example if
%% `Keys = [ [A, B, X], [A, B, Y], [A, B, Z] ]', it will iterate 3 times
%% traversing the whole path from A to X, Y and Z i.e. reading A then B three
%% times. In the future we might want to change this so that [A, B] is read
%% once.
%%
%% @throws badkey
%% @end
%% -----------------------------------------------------------------------------
-spec collect_values([key_path()], Map :: t(), Opts :: collect_opts()) ->
    [any()] | #{binary() => any()}.

collect_values(Keys, Map, Opts0) ->
    %% We remove the posibility of a user forcinf this function to behave like
    %% collect_values/3 to maintain the semantics of the API.
    Opts1 = maps:merge(?DEFAULT_COLLECT_OPTS, Opts0),
    Opts = maps:put(?COLLECT_VALUES, true, Opts1),
    Acc = case maps:get(return, Opts) of
        list -> [];
        map -> maps:new()
    end,
    do_collect(Keys, Map, Opts, Acc).


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
%% @doc Same as {@link set/3}.
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
            babel_set:set_context(Map#babel_map.context, babel_set:new(Values))
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
            babel_set:set_context(Map#babel_map.context, babel_set:new(Value))
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
            babel_set:set_context(Map#babel_map.context, babel_set:new(Values))
    end,
    mutate(Key, Fun, Map).


%% -----------------------------------------------------------------------------
%% @doc Updates a map `T' with the provide key-value pairs `Values'.
%% If the value associated with a key `Key' in `Values' is equal to `undefined`
%% this equivalent to calling `remove(Key, Map)' with the difference that an
%% exception will not be raised in case the map had no context assigned.
%%
%% This function fails with `missing_spec' if it does not have a type
%% specification reference. See {@link update/3} to pass a type specification.
%% @end
%% -----------------------------------------------------------------------------
-spec update(Values :: babel_key_value:t(), T :: t()) ->
    NewT :: t().

update(Values, #babel_map{type_spec_ref = {type_spec_ref, _} = Ref} = T) ->
    update(Values, T, get_registered_type_spec(Ref));

update(_, _) ->
    error(missing_spec).


%% -----------------------------------------------------------------------------
%% @doc Updates a map `T' with the provide key-value pairs `Values'.
%% If the value associated with a key `Key' in `Values' is equal to `undefined`
%% this equivalent to calling `remove(Key, Map)' with the difference that an
%% exception will not be raised in case the map had no context assigned.
%% @end
%% -----------------------------------------------------------------------------
-spec update(Values :: babel_key_value:t(), T :: t(), Spec :: type_spec()) ->
    NewT :: t().

update(Values, #babel_map{} = T, #{'_' := TypeSpec}) ->
    Fun = fun(Key0, Value, Acc) ->
        Key = to_key(Key0),
        do_update(Key, Value, Acc, TypeSpec)
    end,
    babel_key_value:fold(Fun, T, Values);

update(Values, #babel_map{} = T, MapSpec0) when is_map(MapSpec0) ->
    MapSpec = validate_type_spec(MapSpec0),
    Fun = fun(Key0, Value, Acc) ->
            Key = to_key(Key0),
            case maps:find(Key, MapSpec) of
                {ok, TypeSpec} ->
                    do_update(Key, Value, Acc, TypeSpec);
                error ->
                    error({missing_spec, Key})
            end

    end,
    babel_key_value:fold(Fun, T, Values).


%% -----------------------------------------------------------------------------
%% @doc Updates a map `T' with the provide key-value action list `ActionList'.
%% If the value associated with a key `Key' in `Values' is equal to `undefined`
%% this equivalent to calling `remove(Key, Map)' with the difference that an
%% exception will not be raised in case the map had no context assigned.
%%
%% This function fails with `missing_spec' if it does not have a type
%% specification reference. See {@link update/3} to pass a type specification.
%% @end
%% -----------------------------------------------------------------------------
-spec patch(ActionList :: [action()], T :: t()) ->
    NewT :: t().

patch(ActionList, #babel_map{type_spec_ref = {type_spec_ref, _} = Ref} = T) ->
    patch(ActionList, T, get_registered_type_spec(Ref));

patch(_, _) ->
    error(missing_spec).


%% -----------------------------------------------------------------------------
%% @doc Updates a map `T' with the provide key-value action list `ActionList'.
%% If the value associated with a key `Key' in `Values' is equal to `undefined`
%% this equivalent to calling `remove(Key, Map)' with the difference that an
%% exception will not be raised in case the map had no context assigned.
%%
%% Example:
%% @end
%% -----------------------------------------------------------------------------
-spec patch(ActionList :: [action()], T :: t(), Spec :: type_spec()) ->
    NewT :: t().

patch(ActionList, #babel_map{} = T, Spec0) ->
    Spec = validate_type_spec(Spec0),
    Fun = fun(Action, Acc) ->
        patch_eval(Action, Acc, Spec)
    end,
    lists:foldl(Fun, T, ActionList);

patch(_, T, _) ->
    badtype(map, T).


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
%% @doc Registers a type specification `Spec' and returns a `type_spec_ref()'
%% that can be use with any other map instance of the same kind. A registered
%% type spec is validated during registration and the registration fails if it
%% does not pass the validation. All functions that take a type specification
%% as argument also accept a type specification reference, which is more
%% efficient as there is no need to have the type specification in the local
%% process memery and there is no need for further validation.
%%
%% This call fails with exception `{invalid_spec, Errors :: map()}' if the type
%% specification `Spec' is invalid.
%%
%% The storage for specifications is implemented using {@link persistent_term}.
%% So refer to that  module's documentation to understand best practices. In
%% particular, it is ideal to register the type specifications as soon as your
%% aplication starts in order to minimize the number of processes on the node
%% before performing a registration. It would also be wise to avoid registering
%% type specifications when the system is at peak load.
%%
%% @equiv register_type_spec(undefined, Spec)
%% @end
%% -----------------------------------------------------------------------------
-spec register_type_spec(type_spec()) -> type_spec_ref().

register_type_spec(Spec) ->
    register_type_spec(undefined, Spec).


%% -----------------------------------------------------------------------------
%% @doc Registers a type specification `Spec' under a reference using unique
%% identifier `Id'. Returns a `type_spec_ref()'.
%% If `Id' equals `undefined', then id is computed by computing a hash of value
%% of `Spec'.
%% The returned reference can be use with any other map instance of the same
%% kind. A registered type spec is validated during registration and the
%% registration fails if it does not pass the validation.
%% All functions that take a type specification
%% as argument also accept a type specification reference, which is more
%% efficient as there is no need to have the type specification in the local
%% process memery and there is no need for further validation.
%%
%% This call fails with exception `{invalid_spec, Errors :: map()}' if the type
%% specification `Spec' is invalid.
%%
%% The storage for specifications is implemented using {@link persistent_term}.
%% So refer to that  module's documentation to understand best practices. In
%% particular, it is ideal to register the type specifications as soon as your
%% aplication starts in order to minimize the number of processes on the node
%% before performing a registration. It would also be wise to avoid registering
%% type specifications when the system is at peak load.
%% @end
%% -----------------------------------------------------------------------------
-spec register_type_spec(Id :: any() | undefined, type_spec()) ->
    type_spec_ref().

register_type_spec(Id, Spec0) ->
    Spec = validate_type_spec(Spec0),
    do_register_type_spec(Id, Spec).


%% -----------------------------------------------------------------------------
%% @doc
%% @end
%% -----------------------------------------------------------------------------
-spec unregister_type_spec(Ref :: any()) -> boolean().

unregister_type_spec({type_spec_ref, _} = Ref) ->
    persistent_term:erase(Ref).


%% -----------------------------------------------------------------------------
%% @doc
%% @end
%% -----------------------------------------------------------------------------
-spec get_registered_type_spec(Ref :: any()) -> type_spec_ref() | undefined.

get_registered_type_spec({type_spec_ref, _} = Ref) ->
    persistent_term:get(Ref, undefined).


%% -----------------------------------------------------------------------------
%% @doc Returns the type specification reference associated with map `T' or
%% `undefined' is there is none.
%% @end
%% -----------------------------------------------------------------------------
-spec type_spec_ref(T :: t()) -> type_spec_ref() | undefined.

type_spec_ref(#babel_map{type_spec_ref = Value}) -> Value.



%% =============================================================================
%% PRIVATE
%% =============================================================================



%% @private
do_register_type_spec(undefined, Spec) ->
    do_register_type_spec(erlang:phash2(Spec), Spec);

do_register_type_spec(Id, Spec) ->
    Key = {type_spec_ref, Id},
    ok = persistent_term:put(Key, Spec),
    Key.


%% @private
from_map(Map, {type_spec_ref, _} = Ref, Ctxt) ->
    from_map(Map, {Ref, get_registered_type_spec(Ref)}, Ctxt);

from_map(Map, Spec0, Ctxt) when is_map(Spec0) ->
    Spec = validate_type_spec(Spec0),
    Ref = register_type_spec(Spec),
    from_map(Map, {Ref, Spec}, Ctxt);

from_map(Map, {Ref, #{'_' := TypeOrSpec}}, Ctxt) ->
    Expanded = expand_spec(maps:keys(Map), TypeOrSpec),
    from_map(Map, {Ref, Expanded}, Ctxt);

from_map(Map, {{type_spec_ref, _} = Ref, Spec}, Ctxt) when is_map(Spec) ->
    ConvertType = fun
        (_, undefined, Acc) ->
            %% We filter out entries with undefined value
            Acc;
        (Key, Value, Acc) ->
            case maps:find(Key, Spec) of
                {ok, {Datatype, SpecOrType}} ->
                    NewValue = from_term(Value, Ctxt, Datatype, SpecOrType),
                    maps:put(Key, NewValue, Acc);
                error ->
                    error({missing_spec, Key})
            end
    end,
    Values = maps:fold(ConvertType, maps:new(), Map),

    %% Initialise values for Spec keys not present in Map
    %% Keys = maps:keys(Map),
    %% MissingKeys = lists:subtract(maps:keys(Spec), Keys),
    %% Values = init_values(maps:with(MissingKeys, Spec), Values0),

    #babel_map{
        values = Values,
        updates = ordsets:from_list(maps:keys(Values)),
        context = Ctxt,
        type_spec_ref = Ref
    }.


%% @private
from_term(Term, Ctxt, map, Spec) when is_map(Term) ->
    new(Term, Spec, Ctxt);

from_term(Term, Ctxt, set, _) when is_list(Term) ->
    babel_set:set_context(Ctxt, babel_set:new(Term));

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

from_term(Term, _, Datatype, Type) ->
    error({badkeytype, Term, {Datatype, Type}}).


%% @private
-spec from_orddict(
    orddict:orddict(), riakc_datatype:context(), type_spec(), Opts :: map()) ->
    maybe_no_return(t()).


from_orddict(RMap, Context, Spec0, Opts) when is_map(Spec0) ->
    Spec = validate_type_spec(Spec0),
    Ref = register_type_spec(Spec),
    from_orddict(RMap, Context, {Ref, Spec}, Opts);

from_orddict(RMap, Context, {type_spec_ref, _} = Ref, Opts) ->
    from_orddict(RMap, Context, {Ref, get_registered_type_spec(Ref)}, Opts);

from_orddict(RMap, Context, {Ref, #{'_' := Spec}}, Opts) ->
    Expanded = expand_spec(orddict:fetch_keys(RMap), Spec),
    from_orddict(RMap, Context, {Ref, Expanded}, Opts);

from_orddict(RMap, Context, {{type_spec_ref, _} = Ref, Spec}, Opts)
when is_map(Spec) ->
    Strategy = maps:get(missing_spec, Opts, error),

    %% Convert values in RMap
    Convert = fun({Key, Datatype} = RKey, RValue, Acc) ->
        case maps:find(Key, Spec) of
            {ok, {X, SpecOrType}} when X == Datatype ->
                Value = from_datatype(RKey, RValue, Context, SpecOrType),
                maps:put(Key, Value, Acc);
            {ok, {X, _SpecOrType}} ->
                error({datatype_mismatch, X, Datatype});
            error when Strategy == ignore ->
                Acc;
            error when Strategy == error ->
                %% TODO we should take a 4th arg with options to deal with this
                %% situation
                error({missing_spec, RKey})
        end
    end,
    Values = orddict:fold(Convert, maps:new(), RMap),

    %% Initialise values for Spec keys not present in RMap
    %% Keys = [Key || {Key, _} <- orddict:fetch_keys(RMap)],
    %% MissingKeys = lists:subtract(maps:keys(Spec), Keys),
    %% Values = init_values(maps:with(MissingKeys, Spec), Values0),

    #babel_map{
        values = Values,
        context = Context,
        type_spec_ref = Ref
    }.



%% init_values(Spec, Acc0) ->
%%     %% We only set the missing container values
%%     Fun = fun
%%         ('$validated', _, Acc) ->
%%             Acc;

%%         (_, {register, _}, Acc) ->
%%             Acc;

%%         (Key, {map, KeySpec}, Acc) when is_map(KeySpec) ->
%%             maps:put(Key, new(#{}, KeySpec), Acc);

%%         (Key, {Type, _}, Acc) ->
%%             Mod = type_to_mod(Type),
%%             Mod /= undefined andalso Mod /= error orelse error({badtype, Type}),
%%             maps:put(Key, Mod:new(), Acc)
%%     end,
%%     maps:fold(Fun, Acc0, Spec).


%% @private
modified_keys(#babel_map{updates = U, removes = R}) ->
    ordsets:union(U, R).


%% @private
to_key({Key, _}) when is_binary(Key) ->
    Key;

to_key(Key) when is_binary(Key) ->
    Key;

to_key(Term) ->
    error({badkey, Term}).


%% @private
from_datatype({_, register}, Value, _Ctxt, Fun) when is_function(Fun, 2) ->
    Fun(decode, Value);

from_datatype({_, register}, Value, _, Type) ->
    babel_utils:from_binary(Value, Type);

from_datatype({_, set}, Value, Ctxt, Type) ->
    Set = babel_set:from_riak_set(Value, Type),
    babel_set:set_context(Ctxt, Set);

from_datatype({_, map}, Value, _Ctxt, Spec) ->
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
    case babel:type(Term) of
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


%% @private
type_to_mod(register) -> undefined;
type_to_mod(set) -> babel_set;
type_to_mod(counter) -> babel_counter;
type_to_mod(flag) -> babel_flag;
type_to_mod(map) -> ?MODULE;
type_to_mod(_) -> error.


%% @private
-spec badtype(datatype(), binary()) -> no_return().

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
path_type([_], {Type, _}) ->
    Type;

path_type([_], #{'_' := {Type, _}}) ->
    Type;

path_type([Key], Spec) ->
    case maps:find(Key, Spec) of
        {ok, {Type, _}} ->
            Type;
        error ->
            error({missing_spec, Key})
    end;

path_type([_|T], {_, _}) ->
    %% We should have received {map, Spec}
    error({badkey, T});

path_type([_|T], #{'_' := {map, InnerSpec}}) ->
    path_type(T, InnerSpec);

path_type([_|T], #{'_' := InnerSpec}) ->
    path_type(T, InnerSpec);

path_type([H|T], Spec) ->
    case maps:find(H, Spec) of
        {ok, {map, InnerSpec}} ->
            path_type(T, InnerSpec);
        {ok, {_, _}} ->
            error({badkey, T});
        error ->
            error({missing_spec, H})
    end.


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

        ToOp({_, register}, undefined, Acc) ->
            Acc;

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
mutate_eval(_, #babel_map{} = Value, #babel_map{context = Ctxt}) ->
    Value#babel_map{context = Ctxt};

mutate_eval(_, Fun, _) when is_function(Fun, 0) ->
    Fun();

mutate_eval(Key, Fun, #babel_map{values = V}) when is_function(Fun, 1) ->
    Fun(maps:find(Key, V));

mutate_eval(_, Value, #babel_map{context = Ctxt}) when not is_function(Value) ->
    maybe_set_context(Ctxt, Value).


%% @private
maybe_set_context(Ctxt, Term) ->
    case babel:module(Term) of
        undefined ->
            Term;
        Mod ->
            Mod:set_context(Ctxt, Term)
    end.


%% @private
do_collect([H|T], Map, Opts, Acc0) ->
    Strategy = maps:get(on_badkey, Opts),

    try
        Default = maps:get(default, Opts),
        %% We get the value for key or path H
        Value = get(H, Map, Default),
        Acc1 = collect_acc(H, Value, Opts, Acc0),
        do_collect(T, Map, Opts, Acc1)
    catch
        error:badkey when Strategy == skip ->
            do_collect(T, Map, Opts, Acc0);
        error:badkey when Strategy == error ->
            error({badkey, H})
    end;

do_collect([], _, _, Acc) when is_map(Acc) ->
    Acc;

do_collect([], _, _, Acc) when is_list(Acc) ->
    lists:reverse(Acc).


%% @private
collect_acc(Key, Value, #{?COLLECT_VALUES := true}, Acc) ->
    collect_acc(Key, type_value(Value), Acc);

collect_acc(Key, Value, _, Acc) ->
    collect_acc(Key, Value, Acc).


%% @private
collect_acc(Key, Value, Acc) when is_map(Acc) ->
    babel_key_value:put(Key, Value, Acc);

collect_acc(_, Value, Acc) when is_list(Acc) ->
    [Value | Acc].


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
%% TODO this clause is wrong or we need to have copied the root context to the
%% internal maps to avoid being here
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
            case is_type(Value) of
                true ->
                    set(Key, set_context(Acc#babel_map.context, Value), Acc);
                false ->
                    %% The existing value was not found or is not a map, but it
                    %% should be according to spec, so we replace by a new map
                    New = babel_map:new(Value, Spec, Acc#babel_map.context),
                    set(Key, New, Acc)
            end
    end;

do_update(Key, Value, Acc, {set, _}) when is_list(Value) ->
    try
        set_elements(Key, Value, Acc)
    catch
        throw:context_required ->
            %% We have a brand new set (not in Riak yet) so we just replace it
            Set = babel_set:set_context(
                Acc#babel_map.context, babel_set:new(Value)
            ),
            set(Key, Set, Acc)
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
            case babel_counter:is_type(Value) of
                true ->
                    set(Key, Value, Acc);
                false ->
                    set(Key, babel_counter:new(Value), Acc)
            end
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
            case babel_flag:is_type(Value) of
                true ->
                    set(Key, babel_flag:set_context(Ctxt, Value), Acc);
                false ->
                    set(Key, babel_flag:new(Value, Ctxt), Acc)
            end
    end.


%% @private
-spec changed_key_paths(
    t(),
    AccIn :: {Updated :: [key_path()], Removed :: [key_path()]},
    Path :: list()) ->
    AccOut :: {Updated :: [key_path()], Removed :: [key_path()]}.

changed_key_paths(
    #babel_map{updates = U, removes = R} = Parent, Acc, Path0) ->
    lists:foldl(
        fun({Op, Key}, {UAcc0, RAcc0} = IAcc) ->
            Path1 = Path0 ++ [Key],
            case get(Key, Parent, undefined) of
                #babel_map{} = Child ->
                    changed_key_paths(Child, IAcc, Path1);
                _ when Op == update ->
                    {[Path1 | UAcc0], RAcc0};
                _ when Op == remove ->
                    {UAcc0, [Path1 | RAcc0]}
            end
        end,
        Acc,
        lists:append(
            [{update, X} || X <- ordsets:to_list(U)],
            [{remove, X} || X <- ordsets:to_list(R)]
        )
    ).


%% @private
patch_eval(A, Map, Spec) when is_map(Spec) ->
    Path = patch_path(A),
    patch_eval(A, Map, path_type(Path, Spec), Path).


%% @private
patch_eval(
    #{<<"value">> := V, <<"action">> := <<"update">>}, Map, _, Path) ->
    set(Path, V, Map);

patch_eval(#{<<"value">> := V, <<"action">> := <<"set">>}, Map, _, Path) ->
    set(Path, V, Map);

patch_eval(
    #{<<"value">> := V, <<"action">> := <<"remove">>}, Map, set, Path) ->
    del_element(Path, V, Map);

patch_eval(
    #{<<"value">> := V, <<"action">> := <<"append">>}, Map, set, Path) ->
    add_element(Path, V, Map);

patch_eval(
    #{<<"value">> := V, <<"action">> := <<"add_element">>}, Map, set, Path) ->
    add_element(Path, V, Map);

patch_eval(
    #{<<"value">> := V, <<"action">> := <<"del_element">>}, Map, set, Path) ->
    del_element(Path, V, Map);

patch_eval(#{<<"action">> := <<"remove">>}, Map, _, Path) ->
    remove(Path, Map);

patch_eval(#{<<"action">> := <<"enable">>}, Map, flag, Path) ->
    enable(Path, Map);

patch_eval(#{<<"action">> := <<"disable">>}, Map, flag, Path) ->
    disable(Path, Map);

patch_eval(#{<<"action">> := <<"increment">>}, Map, counter, Path) ->
    increment(Path, Map);

patch_eval(#{<<"action">> := <<"decrement">>}, Map, counter, Path) ->
    decrement(Path, Map);

patch_eval(Action, _, _, _) ->
    error({badaction, Action}).


%% @private
patch_path(#{<<"path">> := BinPath}) ->
    [<<>> | Path] = binary:split(BinPath, [<<"/">>], [global, trim]),
    Path.


