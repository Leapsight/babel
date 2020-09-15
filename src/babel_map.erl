-module(babel_map).
-include("babel.hrl").

-define(BADKEY, '$error_badkey').

-record(babel_map, {
    values = #{}        ::  #{key() => value()},
    updates = []        ::  ordsets:ordset(key()),
    removes = []        ::  ordsets:ordset(key()),
    context = undefined ::  riakc_datatype:context()
}).

-opaque t()             ::  #babel_map{}.
-type spec()            ::  #{riak_key() => babel_key() | type()}
                            | {register, type()}
                            | fun((encode, binary(), any()) -> value())
                            | fun((decode, binary(), value()) -> any()).
-type babel_key()       ::  {binary(), type()}.
-type riak_key()        ::  {binary(), datatype()}.
-type key_path()        ::  binary() | [binary()].
-type value()           ::  any().
-type datatype()        ::  counter | flag | register | set | map.
-type type()            ::  atom
                            | existing_atom
                            | boolean
                            | integer
                            | float
                            | binary
                            | list
                            | spec()
                            | babel_set:spec()
                            | fun((encode, any()) -> value())
                            | fun((decode, value()) -> any()).
-type update_fun()      ::  fun((babel_datatype() | term()) ->
                                babel_datatype() | term()
                            ).

-export_type([t/0]).
-export_type([spec/0]).
-export_type([key_path/0]).

%% API
-export([add_element/3]).
-export([add_elements/3]).
-export([context/1]).
-export([del_element/3]).
-export([from_riak_map/2]).
-export([get/2]).
-export([get/3]).
-export([get_type/1]).
-export([is_type/1]).
-export([new/0]).
-export([new/1]).
-export([new/2]).
-export([remove/2]).
-export([set/3]).
-export([to_riak_op/2]).
-export([type/0]).
-export([update/3]).
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
        updates = ordsets:add_elements(maps:keys(Data))
    }.


%% -----------------------------------------------------------------------------
%% @doc
%% @end
%% -----------------------------------------------------------------------------
-spec new(Data :: map(), Ctxt :: riakc_datatype:context()) -> t().

new(Data, Spec) when is_map(Data) ->
    MissingKeys = lists:subtract(maps:keys(Spec), maps:keys(Data)),
    Values = init_values(maps:with(MissingKeys, Spec), Data),
    #babel_map{
        values = Values,
        updates = ordsets:add_elements(maps:keys(Values))
    }.


%% -----------------------------------------------------------------------------
%% @doc
%% @end
%% -----------------------------------------------------------------------------
-spec from_riak_map(
    RMap :: riakc_map:crdt_map() | list(), Spec :: spec()) -> t().

from_riak_map({map, Values, _, _, Context}, Spec) ->
    from_riak_map(Values, Context, Spec).


%% -----------------------------------------------------------------------------
%% @doc
%% @end
%% -----------------------------------------------------------------------------
-spec to_riak_op(T :: t(), Spec :: spec()) ->
    riakc_datatype:update(riakc_map:map_op()).

to_riak_op(T, Spec0) when is_map(Spec0) ->
    %% Spec :: #{Key => {{_, _} = RKey, Spec}}
    Spec = reverse_spec(Spec0),
    Updates = prepare_update_ops(T, Spec),
    Removes = prepare_remove_ops(T, Spec),

    case lists:append(Removes, Updates) of
        [] ->
            undefined;
        Ops ->
            {riakc_map:type(), {update, Ops}, T#babel_map.context}
    end.


%% -----------------------------------------------------------------------------
%% @doc Returns the symbolic name of this container.
%% @end
%% -----------------------------------------------------------------------------
-spec type() -> atom().

type() -> map.


%% -----------------------------------------------------------------------------
%% @doc Returns true if term `Term' is a babel map.
%% @end
%% -----------------------------------------------------------------------------
-spec is_type(Term :: any()) -> boolean().

is_type(Term) ->
    is_record(Term, babel_map).


%% -----------------------------------------------------------------------------
%% @doc Returns the Riak KV context
%% @end
%% -----------------------------------------------------------------------------
-spec context(T :: t()) -> riakc_datatype:context().

context(#babel_map{context = Value}) -> Value.


%% -----------------------------------------------------------------------------
%% @doc Returns an external representation of the babel map `Map' as an erlang
%% map. This is build recursively by calling the value/1 function on any
%% embedded babel datatype.
%% @end
%% -----------------------------------------------------------------------------
-spec value(Map :: t()) -> map().

value(#babel_map{values = V}) ->
    Fun = fun
        (_, #babel_map{} = Term) ->
            value(Term);
        (_, Term) ->
            case get_type(Term) of
                term ->
                    Term;
                set ->
                    babel_set:value(Term);
                counter ->
                    error(not_implemented);
                flag ->
                    error(not_implemented)
            end
    end,
    maps:map(Fun, V).


%% -----------------------------------------------------------------------------
%% @doc Returns value `Value' associated with `Key' if `T' contains `Key'.
%% `Key' can be a binary or a path represented as a list of binaries.
%%
%% The call fails with a {badarg, `T'} exception if `T' is not a Babel Map.
%% It also fails with a {badkey, `Key'} exception if no value is associated
%% with `Key'.
%% @end
%% -----------------------------------------------------------------------------
-spec get(Key :: key(), T :: t()) -> any().

get(Key, T) ->
    get(Key, T, ?BADKEY).


%% -----------------------------------------------------------------------------
%% @doc
%% @end
%% -----------------------------------------------------------------------------
-spec get(Key :: key_path(), Map :: t(), Default :: any()) -> value().

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
        {ok, #babel_map{} = Value} ->
            Value;
        {ok, Value} ->
            case babel_set:is_type(Value) of
                true ->
                    babel_set:value(Value);
                false ->
                    Value
            end;
        error ->
            maybe_badkey(Default)
    end;

get(Key, #babel_map{}, _) when not is_binary(Key) ->
    error({badkey, Key});

get(_, Map, _) ->
    error({badmap, Map}).


%% -----------------------------------------------------------------------------
%% @doc Associates `Key' with value `Value' and inserts the association into
%% map `NewMap'. If key `Key' already exists in map `Map', the old associated
%% value is replaced by value `Value'. The function returns a new map `NewMap'
%% containing the new association and the old associations in `Map'.
%%
%% The call fails with a {badmap, Map} exception if `Map' is not a babel map.
%% @end
%% -----------------------------------------------------------------------------
-spec set(Key :: key(), Value :: value(), Map :: t()) ->
    NewMap :: t() | no_return().

set([H|[]], Value, Map) ->
    set(H, Value, Map);

set([H|T], Value, #babel_map{values = V} = Map) ->
    case maps:find(H, V) of
        {ok, #babel_map{} = HMap} ->
            Map#babel_map{
                values = maps:put(H, set(T, Value, HMap), V),
                updates = ordsets:add_element(H, Map#babel_map.updates)
            };
        {ok, Term} ->
            error({badmap, Term});
        error ->
            Map#babel_map{
                values = maps:put(H, set(T, Value, new()), V),
                updates = ordsets:add_element(H, Map#babel_map.updates)
            }
    end;

set(Key, Value, #babel_map{} = Map) when is_binary(Key) ->
    Map#babel_map{
        values = maps:put(Key, Value, Map#babel_map.values),
        updates = ordsets:add_element(Key, Map#babel_map.updates)
    };

set(Key, _, #babel_map{}) when not is_binary(Key) ->
    error({badkey, Key});

set(_, _, Map) ->
    error({badmap, Map}).


%% -----------------------------------------------------------------------------
%% @doc
%% @end
%% -----------------------------------------------------------------------------
-spec add_element(Key :: key(), Value :: value(), Map :: t()) ->
    NewMap :: t() | no_return().

add_element(Key, Value, Map) ->
    add_elements(Key, [Value], Map).


%% -----------------------------------------------------------------------------
%% @doc Adds a a list of values to a babel set associated with key or path
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
-spec add_elements(Key :: key(), Value :: [value()], Map :: t()) ->
    NewMap :: t() | no_return().

add_elements([H|[]], Values, Map) ->
    add_elements(H, Values, Map);

add_elements([H|T], Values, #babel_map{values = V} = Map) ->
    case maps:find(H, V) of
        {ok, #babel_map{} = HMap} ->
            Map#babel_map{
                values = maps:put(H, add_elements(T, Values, HMap), V),
                updates = ordsets:add_element(H, Map#babel_map.updates)
            };
        {ok, Term} ->
            error({badmap, Term});
        error ->
            Map#babel_map{
                values = maps:put(H, add_elements(T, Values, new()), V),
                updates = ordsets:add_element(H, Map#babel_map.updates)
            }
    end;

add_elements(Key, Values, #babel_map{values = V} = Map)
when is_binary(Key) andalso is_list(Values) ->
    NewValue = case maps:find(Key, V) of
        {ok, Term} ->
            case babel_set:is_type(Term) of
                true ->
                    babel_set:add_elements(Values, Term);
                false ->
                    error({badset, Term})
            end;
        error ->
            babel_set:new(Values)
    end,
    Map#babel_map{
        values = maps:put(Key, NewValue, Map#babel_map.values),
        updates = ordsets:add_element(Key, Map#babel_map.updates)
    };

add_elements(Key, _, #babel_map{}) when not is_binary(Key) ->
    error({badkey, Key});

add_elements(_, _, Map) ->
    error({badmap, Map}).


%% -----------------------------------------------------------------------------
%% @doc Adds a value to a babel set associated with key or path `Key' in map
%% `Map' and inserts the association into map `NewMap'.
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
-spec del_element(Key :: key(), Value :: value(), Map :: t()) ->
    NewMap :: t() | no_return().

del_element([H|[]], Value, Map) ->
    del_element(H, Value, Map);

del_element([H|T], Value, #babel_map{values = V} = Map) ->
    case maps:find(H, V) of
        {ok, #babel_map{} = HMap} ->
            Map#babel_map{
                values = maps:put(H, del_element(T, Value, HMap), V),
                updates = ordsets:add_element(H, Map#babel_map.updates)
            };
        {ok, Term} ->
            error({badmap, Term});
        error ->
            %% We create the map as we need to record the removal even if it
            %% did not exist
            Map#babel_map{
                values = maps:put(H, del_element(T, Value, new()), V),
                updates = ordsets:add_element(H, Map#babel_map.updates)
            }
    end;


del_element(Key, Value, #babel_map{values = V} = Map) when is_binary(Key) ->
    NewValue = case maps:find(Key, V) of
        {ok, Term} ->
            case babel_set:is_type(Term) of
                true ->
                    babel_set:del_element(Value, Term);
                false ->
                    error({badset, Term})
            end;
        error ->
            babel_set:new([Value])
    end,
    Map#babel_map{
        values = maps:put(Key, NewValue, Map#babel_map.values),
        updates = ordsets:add_element(Key, Map#babel_map.updates)
    };

del_element(Key, _, _) when not is_binary(Key) ->
    error({badkey, Key});

del_element(_, _, Map) when not is_record(Map, babel_map) ->
    error({badmap, Map}).


%% -----------------------------------------------------------------------------
%% @doc
%% @end
%% -----------------------------------------------------------------------------
-spec update(Key :: key(), Fun :: update_fun(), T :: t()) -> NewT :: t().

update(Key, Fun, #babel_map{values = V, updates = U} = Map) ->
    Map#babel_map{
        values = maps:put(Key, Fun(maps:get(Key, V)), V),
        updates = ordsets:add_element(Key, U)
    }.



%% -----------------------------------------------------------------------------
%% @doc Removes a key and its value from the map. Removing a key that
%% does not exist simply records a remove operation.
%% @throws context_required
%% -----------------------------------------------------------------------------
-spec remove(Key :: key(), T :: t()) -> NewT :: t() | no_return().

remove(_, #babel_map{context = undefined}) ->
    throw(context_required);

remove(Key, T) ->
    do_remove(Key, T).




%% =============================================================================
%% PRIVATE
%% =============================================================================



%% @private
from_riak_map(RMap, Context, Spec) when is_map(Spec) ->
     %% Convert values in RMap
    Convert = fun({Key, _} = RKey, RValue, Acc) ->
        case maps:find(RKey, Spec) of
            {ok, {NewKey, TypeOrFun}} ->
                Value = from_datatype(RKey, RValue, TypeOrFun),
                maps:put(NewKey, Value, Acc);
            {ok, TypeOrFun} ->
                Value = from_datatype(RKey, RValue, TypeOrFun),
                maps:put(Key, Value, Acc);
            error ->
                error({missing_spec, RKey})
        end
    end,
    Values0 = orddict:fold(Convert, maps:new(), RMap),

    %% Initialise values for Spec kyes not present in RMap
    MissingKeys = lists:subtract(maps:keys(Spec), orddict:fetch_keys(RMap)),
    Values1 = init_values(maps:with(MissingKeys, Spec), Values0),

    #babel_map{values = Values1, context = Context};

from_riak_map(RMap, Context, Fun) when is_function(Fun, 3) ->
    %% This is equivalent to a map function.
    Values = riakc_map:fold(
        fun(K, V, Acc) ->
            maps:put(K, Fun(decode, K, V), Acc)
        end,
        maps:new(),
        RMap
    ),
    #babel_map{values = Values, context = Context};

from_riak_map(RMap, Context, Type) ->
    %% This is equivalent to a map function where we assume all keys in the map
    %% to be a register of the same type.
    Fun = fun(decode, _, V) -> babel_utils:from_binary(V, Type) end,
    from_riak_map(RMap, Context, Fun).


%% @private
init_values(Spec, Acc0) ->
    Fun = fun
        ({_, counter}, {_Key, _KeySpec}, _) ->
            %% from_integer(<<>>, KeySpec)
            error(not_implemented);
        ({_, counter}, _KeySpec, _) ->
            error(not_implemented);
        ({_, flag}, {_Key, _KeySpec}, _) ->
            %% from_boolean(<<>>, KeySpec)
            error(not_implemented);
        ({_, flag}, _, _) ->
            error(not_implemented);
        ({_, register}, {Key, KeySpec}, Acc) ->
            maps:put(Key, from_binary(<<>>, KeySpec), Acc);
        ({Key, register}, KeySpec, Acc) ->
            maps:put(Key, from_binary(<<>>, KeySpec), Acc);
        ({_, set}, {Key, _}, Acc) ->
            maps:put(Key, babel_set:new(), Acc);
        ({Key, set}, _, Acc) ->
            maps:put(Key, babel_set:new(), Acc);
        ({_, map}, {Key, KeySpec}, Acc) when is_map(KeySpec) ->
            maps:put(Key, babel_map:new(#{}, KeySpec), Acc);
        ({_, map}, {Key, KeySpec}, Acc) ->
            maps:put(Key, babel_map:new(#{}, KeySpec), Acc);
        ({Key, map}, KeySpec, Acc) when is_map(KeySpec) ->
            maps:put(Key, babel_map:new(#{}, KeySpec), Acc);
        ({Key, map}, KeySpec, Acc) ->
            maps:put(Key, babel_map:new(#{}, KeySpec), Acc)
    end,
    maps:fold(Fun, Acc0, Spec).


%% @private
from_datatype({_, register}, Value, Fun) when is_function(Fun, 2) ->
    Fun(decode, Value);

from_datatype({_, register}, Value, Type) ->
    babel_utils:from_binary(Value, Type);

from_datatype({_, set}, Value, #{binary := _} = Spec) ->
    babel_set:from_riak_set(Value, Spec);

from_datatype({_, map}, Value, Spec) ->
    from_riak_map(Value, undefined, Spec);

from_datatype(_Key, _RiakMap, _Type) ->
    error(not_implemented).



%% @private
from_binary(Value, Fun) when is_function(Fun, 2) ->
    Fun(decode, Value);

from_binary(Value, Type) ->
    babel_utils:from_binary(Value, Type).


%% @private
to_binary(Value, Fun) when is_function(Fun, 2) ->
    Fun(encode, Value);

to_binary(Value, Type) ->
    babel_utils:to_binary(Value, Type).


%% @private
reverse_spec(Spec) ->
    maps:fold(
        fun
            (RKey, {Key, KeySpec}, Acc) ->
                maps:put(Key, {RKey, KeySpec}, Acc);

            ({Key, _} = RKey, KeySpec, Acc) ->
                maps:put(Key, {RKey, KeySpec}, Acc)
        end,
        maps:new(),
        Spec
    ).


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
            error({badmap, Term})
    end;

do_remove(Key, #babel_map{} = Map) when is_binary(Key) ->
    Map#babel_map{
        values = maps:remove(Key, Map#babel_map.values),
        removes = ordsets:add_element(Key, Map#babel_map.removes)
    };

do_remove(Key, #babel_map{}) when not is_binary(Key) ->
    error({badkey, Key});

do_remove(_, Map) ->
    error({badmap, Map}).


%% @private
maybe_badkey(?BADKEY) ->
    error(badkey);

maybe_badkey(Term) ->
    Term.



%% -----------------------------------------------------------------------------
%% @private
%% @doc
%% @end
%% -----------------------------------------------------------------------------
-spec get_type(Term :: any()) -> counter | flag | set | map | term.

get_type(Term) ->
    Fun = fun(Mod, Acc) ->
        try Mod:is_type(Term) of
            true -> throw({type, Mod:type()});
            false -> Acc
        catch
            error:_ -> Acc
        end
    end,

    try
        lists:foldl(
            Fun,
            term,
            [babel_set, babel_map, babel_counter, babel_flag]
        )
    catch
        throw:{type, Mod} -> Mod
    end.


prepare_update_ops(T, Spec) ->
    %% Spec :: #{Key => {{_, _} = RKey, Spec}}
    FoldFun = fun
        ToOp({{_, counter}, _KeySpec}, _V, _Acc) ->
            error(not_implemented);

        ToOp({{_, flag}, _KeySpec}, _V, _Acc) ->
            error(not_implemented);

        ToOp({_, register}, undefined, Acc) ->
            Acc;

        ToOp({{_, register} = RKey, KeySpec}, Value, Acc) ->
            Bin = to_binary(Value, KeySpec),
            [{update, RKey, {assign, Bin}} | Acc];

        ToOp({{_, set} = RKey, KeySpec}, Set, Acc) ->
            case babel_set:to_riak_op(Set, KeySpec) of
                undefined -> Acc;
                {_, Op, _} -> [{update, RKey, Op} | Acc]
            end;

        ToOp({{_, map} = RKey, KeySpec}, Map, Acc) ->
            case to_riak_op(Map, KeySpec) of
                undefined -> Acc;
                {_, Op, _} -> [{update, RKey, Op} | Acc]
            end;

        ToOp(Key, Value, Acc) ->
            ToOp(maps:get(Key, Spec), Value, Acc)

    end,

    Updates = maps:with(T#babel_map.updates, T#babel_map.values),
    maps:fold(FoldFun, [], Updates).


prepare_remove_ops(T, Spec) ->
    %% Spec :: #{Key => {{_, _} = RKey, Spec}}
    [
        begin
            {RKey, _} = maps:get(Key, Spec),
            {remove, RKey}
        end || Key <- T#babel_map.removes
    ].