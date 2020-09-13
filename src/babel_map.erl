-module(babel_map).

-record(babel_map, {
    values = #{}        ::  #{key() => value()},
    updates = []        ::  ordsets:ordset(key()),
    removes = []        ::  ordsets:ordset(key()),
    context = undefined ::  riakc_datatype:context()
}).

-opaque t()             ::  #babel_map{}.
-type spec()            ::  #{riak_key() => babel_key() | type()}
                            | {register, type()}
                            | fun((encode, key(), any()) -> value())
                            | fun((decode, key(), value()) -> any()).
-type babel_key()       ::  {key(), type()}.
-type riak_key()        ::  {key(), datatype()}.
-type key()             ::  binary().
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


-export_type([t/0]).
-export_type([spec/0]).


%% API
-export([new/1]).
-export([new/2]).
-export([from_riak_map/2]).
%% -export([to_riak_map/2]).
-export([to_riak_op/2]).
-export([type/0]).
-export([is_type/1]).
-export([get/2]).
-export([update/3]).
-export([remove/2]).



%% =============================================================================
%% API
%% =============================================================================



%% -----------------------------------------------------------------------------
%% @doc
%% @end
%% -----------------------------------------------------------------------------
-spec new(Data :: map()) -> t().

new(Data) when is_map(Data) ->
    #babel_map{values = Data}.


%% -----------------------------------------------------------------------------
%% @doc
%% @end
%% -----------------------------------------------------------------------------
-spec new(Data :: map(), Ctxt :: riakc_datatype:context()) -> t().

new(Data, Ctxt) when is_map(Data) ->
    #babel_map{values = Data, context = Ctxt}.


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

to_riak_op(T, Spec) when is_map(Spec) ->
    Updated = maps_utils:collect(T#babel_map.updates, T#babel_map.values),

    FoldFun = fun
        ToOp({_, counter}, V, Acc) ->
            error(not_implemented);

        ToOp({_, flag}, V, Acc) ->
            error(not_implemented);

        ToOp({_, register}, undefined, Acc) ->
            Acc;

        ToOp({_, register} = Key, Value, Acc) ->
            Bin = to_binary(Value, maps:get(Key, Spec)),
            ToOp(
                {riakc_register:type(), {assign, Bin}, undefined}, Key, Acc
            );

        ToOp({_, set} = Key, Set, Acc) ->
            ToOp(babel_set:to_riak_op(Set, maps:get(Key, Spec)), Key, Acc);

        ToOp({_, map} = Key, Map, Acc) ->
            ToOp(to_riak_op(Map, maps:get(Key, Spec)), Key, Acc);

        ToOp(undefined, Key, Acc) ->
            Acc;

        ToOp({_, Op, _}, Key, Acc) ->
            [{update, Key, Op} | Acc]

    end,
    Updates = maps:fold(FoldFun, [], Updated),

    Result = lists:append(
        [{remove, Key} || Key <- T#babel_map.removes],
        Updates
    ),

    case Result of
        [] ->
            undefined;
        _ ->
            {riakc_map:type(), {update, Result}, T#babel_map.context}
    end.


%% -----------------------------------------------------------------------------
%% @doc %% @doc Returns the symbolic name of this container.
%% @end
%% -----------------------------------------------------------------------------
-spec type() -> atom().

type() -> map.


%% -----------------------------------------------------------------------------
%% @doc
%% @end
%% -----------------------------------------------------------------------------
-spec is_type(Term :: any()) -> boolean().

is_type(Term) ->
    is_record(Term, babel_map).


%% -----------------------------------------------------------------------------
%% @doc
%% @end
%% -----------------------------------------------------------------------------
-spec get(Key :: key(), T :: t()) -> term().

get(Key, #babel_map{values = Values}) ->
    maps:get(Key, Values).


%% -----------------------------------------------------------------------------
%% @doc
%% @end
%% -----------------------------------------------------------------------------
-spec update(Key :: key(), UpdateFun :: term(), T :: t()) ->
    NewT :: t().

update(Key, UpdateFun, T) ->
    NewValue = UpdateFun(maps:find(Key, T#babel_map.values)),
    T#babel_map{
        values = maps:put(Key, NewValue, T#babel_map.values),
        updates = ordsets:add_element(Key, T#babel_map.updates)
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
    T#babel_map{
        values = maps:remove(Key, T#babel_map.values),
        removes = ordsets:add_element(Key, T#babel_map.removes)
    }.




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
init_values(Spec, Acc) ->
    Fun = fun
        ({_, counter}, {_Key, _TypeOrFun}, _) ->
            %% from_integer(<<>>, TypeOrFun)
            error(not_implemented);
        ({Key, counter}, TypeOrFun, _) ->
            error(not_implemented);
        ({_, flag}, {_Key, _TypeOrFun}, _) ->
            %% from_boolean(<<>>, TypeOrFun)
            error(not_implemented);
        ({Key, flag}, TypeOrFun, _) ->
            error(not_implemented);
        ({_, register}, {Key, TypeOrFun}, Acc) ->
            maps:put(Key, from_binary(<<>>, TypeOrFun), Acc);
        ({Key, register}, TypeOrFun, Acc) ->
            maps:put(Key, from_binary(<<>>, TypeOrFun), Acc);
        ({_, set}, {Key, TypeOrFun}, Acc) ->
            maps:put(Key, babel_set:new([]), Acc);
        ({Key, set}, TypeOrFun, Acc) ->
            maps:put(Key, babel_set:new([]), Acc);
        ({_, map}, {Key, TypeOrFun}, Acc) ->
            maps:put(Key, babel_map:new([]), Acc);
        ({Key, map}, TypeOrFun, Acc) ->
            maps:put(Key, babel_map:new([]), Acc)
    end,
    maps:fold(Fun, Acc, Spec).


%% @private
from_datatype({_, register} = Key, Value, Fun) when is_function(Fun, 2) ->
    Fun(decode, Value);

from_datatype({_, register} = Key, Value, Type) ->
    babel_utils:from_binary(Value, Type);

from_datatype({_, set} = Key, Value, #{binary := _} = Spec) ->
    babel_set:from_riak_set(Value, Spec);

from_datatype({_, map} = Key, Value, Spec) ->
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
