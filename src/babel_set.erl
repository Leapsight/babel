%% =============================================================================
%%  babel_set.erl -
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
-module(babel_set).
-include("babel.hrl").

-record(babel_set, {
    values = []         ::  ordsets:ordset(any()),
    adds = []           ::  ordsets:ordset(any()),
    removes = []        ::  ordsets:ordset(any()),
    size = 0            ::  non_neg_integer(),
    context             ::  riakc_datatype:context() | undefined
}).

-opaque t()             ::  #babel_set{}.
-type type_spec()       ::  atom
                            | existing_atom
                            | boolean
                            | integer
                            | float
                            | binary
                            | list
                            | fun((encode, any()) -> binary())
                            | fun((decode, binary()) -> any()).

-export_type([t/0]).
-export_type([type_spec/0]).


%% API
-export([add_element/2]).
-export([add_elements/2]).
-export([context/1]).
-export([del_element/2]).
-export([del_elements/2]).
-export([fold/3]).
-export([from_riak_set/2]).
-export([is_element/2]).
-export([is_original_element/2]).
-export([is_type/1]).
-export([is_valid_type_spec/1]).
-export([new/0]).
-export([new/1]).
-export([new/2]).
-export([original_value/1]).
-export([set_context/2]).
-export([set_elements/2]).
-export([size/1]).
-export([to_riak_op/2]).
-export([type/0]).
-export([value/1]).




%% =============================================================================
%% API
%% =============================================================================




%% -----------------------------------------------------------------------------
%% @doc
%% @end
%% -----------------------------------------------------------------------------
-spec new() -> t().

new() ->
    #babel_set{}.


%% -----------------------------------------------------------------------------
%% @doc
%% !> **Important**. Notice that using this function might result in
%% incompatible types when later using a type specification e.g. {@link
%% to_riak_op/2}. We strongly suggest not using this function and using {@link
%% new/2} instead.
%% @end
%% -----------------------------------------------------------------------------
-spec new(Data :: ordsets:ordset(any())) -> t().

new(Data) when is_list(Data) ->
    #babel_set{adds = Data, size = ordsets:size(Data)}.


%% -----------------------------------------------------------------------------
%% @doc
%% @end
%% -----------------------------------------------------------------------------
-spec new(
    Data :: ordsets:ordset(any()),
    Type :: type_spec())  -> t().

new(Data, Type) when is_list(Data) ->
    Adds = ordsets:from_list([from_term(E, Type) || E <- Data]),
    #babel_set{adds = Adds, size = ordsets:size(Adds)}.


%% -----------------------------------------------------------------------------
%% @doc
%% @throws {badindex, term()}
%% @end
%% -----------------------------------------------------------------------------
-spec from_riak_set(
    RiakSet :: riakc_set:riakc_set() | ordsets:ordset(),
    Type :: type_spec()) ->
    maybe_no_return(t()).


from_riak_set(Ordset, Type) when is_list(Ordset) ->
    Values = ordsets:from_list([from_binary(E, Type) || E <- Ordset]),
    #babel_set{values = Values, size = ordsets:size(Values)};

from_riak_set(RiakSet, Type) ->
    Set = from_riak_set(riakc_set:value(RiakSet), Type),
    Ctxt = element(5, RiakSet),
    set_context(Ctxt, Set).


%% -----------------------------------------------------------------------------
%% @doc
%% @end
%% -----------------------------------------------------------------------------
-spec to_riak_op(T :: t(), Type :: type_spec()) ->
    riakc_datatype:update(riakc_set:set_op()).

to_riak_op(#babel_set{adds = [], removes = []}, _) ->
    undefined;

to_riak_op(#babel_set{adds = A, removes = [], context = C}, Type) ->
    {riakc_set:type(), {add_all, [to_binary(E, Type) || E <- A]}, C};

to_riak_op(#babel_set{adds = [], removes = R, context = C}, Type) ->
    {riakc_set:type(), {remove_all, [to_binary(E, Type) || E <- R]}, C};

to_riak_op(#babel_set{adds = A, removes = R, context = C}, Type) ->
    {
        riakc_set:type(),
        {update, [
            {remove_all, [to_binary(E, Type) || E <- R]},
            {add_all, [to_binary(E, Type) || E <- A]}
        ]},
        C
    }.


%% -----------------------------------------------------------------------------
%% @doc Returns the symbolic name of this container.
%% @end
%% -----------------------------------------------------------------------------
-spec type() -> set.

type() -> set.



%% -----------------------------------------------------------------------------
%% @doc
%% @end
%% -----------------------------------------------------------------------------
-spec is_type(Term :: any()) -> boolean().

is_type(Term) ->
    is_record(Term, babel_set).


%% -----------------------------------------------------------------------------
%% @doc
%% @end
%% -----------------------------------------------------------------------------
-spec is_valid_type_spec(term()) -> boolean().

is_valid_type_spec(atom) -> true;
is_valid_type_spec(existing_atom) -> true;
is_valid_type_spec(boolean) -> true;
is_valid_type_spec(integer) -> true;
is_valid_type_spec(float) -> true;
is_valid_type_spec(binary) -> true;
is_valid_type_spec(list) -> true;
is_valid_type_spec(Fun) when is_function(Fun, 1) -> true;
is_valid_type_spec(Fun) when is_function(Fun, 2) -> true;
is_valid_type_spec(_) -> false.


%% -----------------------------------------------------------------------------
%% @doc Returns the Riak KV context
%% @end
%% -----------------------------------------------------------------------------
-spec context(T :: t()) -> riakc_datatype:context().

context(#babel_set{context = Value}) -> Value.


%% -----------------------------------------------------------------------------
%% @doc Sets the context `Ctxt'.
%% @end
%% -----------------------------------------------------------------------------
-spec set_context(Ctxt :: riakc_datatype:set_context(), T :: t()) ->
    NewT :: t().

set_context(Ctxt, #babel_set{} = T)
when is_binary(Ctxt) orelse Ctxt == undefined ->
    T#babel_set{context = Ctxt};

set_context(Ctxt, #babel_set{}) ->
    error({badarg, Ctxt});

set_context(_, Term) ->
    error({badset, Term}).


%% -----------------------------------------------------------------------------
%% @doc Returns the original value of the set as an ordset.
%% This is equivalent to riakc_set:value/1 but where the elements are binaries
%% but of the type defined by the conversion `spec()' used to create the set.
%% @end
%% -----------------------------------------------------------------------------
-spec original_value(t()) -> ordsets:ordset(any()).

original_value(#babel_set{values = V}) -> V.


%% -----------------------------------------------------------------------------
%% @doc Returns the current value of the set.
%% @end
%% -----------------------------------------------------------------------------
-spec value(T :: t()) -> ordsets:ordset(any()).

value(#babel_set{values = V, adds = A, removes = R}) ->
    ordsets:subtract(ordsets:union(V, A), R).


%% -----------------------------------------------------------------------------
%% @doc Returns the cardinality (size) of the set.
%% @end
%% -----------------------------------------------------------------------------
-spec size(T :: t()) -> pos_integer().

size(#babel_set{size = Size}) -> Size.


%% -----------------------------------------------------------------------------
%% @doc Adds an element to the set.
%% You may add an element that already exists in the original set
%% value, but it does not count for the object's size calculation. Adding an
%% element that already exists is non-intuitive, but acts as a safety feature: a
%% client code path that requires an element to be present in the set
%% (or removed) can ensure that intended state by applying an
%% operation.
%% @end
%% -----------------------------------------------------------------------------
-spec add_element(Element :: any(), T :: t()) -> t().

add_element(Element, T) ->
    add_elements([Element], T).


%% -----------------------------------------------------------------------------
%% @doc
%% @end
%% -----------------------------------------------------------------------------
-spec add_elements(Elements :: [any()], T :: t()) -> t().

add_elements(Elements, #babel_set{adds = A0, size = S0} = T) ->
    A1 = lists:foldl(fun ordsets:add_element/2, A0, Elements),
    S1 = S0 + ordsets:size(A1) - ordsets:size(A0),

    T#babel_set{
        adds = A1,
        size = S1
    }.


%% -----------------------------------------------------------------------------
%% @doc Removes an element from the set.
%% You may remove an element that does not appear in the original
%% set value. This is non-intuitive, but acts as a safety feature: a
%% client code path that requires an element to be present in the set
%% (or removed) can ensure that intended state by applying an
%% operation.
%% @throws context_required
%% @end
%% -----------------------------------------------------------------------------
-spec del_element(Element :: any(), T :: t()) -> t() | no_return().

del_element(Element, T) ->
    del_elements([Element], T).


%% -----------------------------------------------------------------------------
%% @doc Removes an element from the set.
%% You may remove an element that does not appear in the original
%% set value. This is non-intuitive, but acts as a safety feature: a
%% client code path that requires an element to be present in the set
%% (or removed) can ensure that intended state by applying an
%% operation.
%% @throws context_required
%% @end
%% -----------------------------------------------------------------------------
-spec del_elements(Elements :: [any()], T :: t()) -> t() | no_return().

del_elements(_, #babel_set{context = undefined}) ->
    throw(context_required);

del_elements(Elements, #babel_set{removes = R0, size = S0} = T) ->
    R1 = lists:foldl(fun ordsets:add_element/2, R0, Elements),
    S1 = S0 + ordsets:size(R1) - ordsets:size(R0),

    T#babel_set{
        removes = R1,
        size = S1
    }.


%% -----------------------------------------------------------------------------
%% @doc
%% @end
%% -----------------------------------------------------------------------------
-spec set_elements(Elements :: [any()], T :: t()) -> NewT :: t().

set_elements(Elements, #babel_set{values = Value} = T) ->
    %% We add all elements not already in Value
    NewValue = ordsets:from_list(Elements),
    Adds = ordsets:subtract(NewValue, Value),
    Removes = ordsets:subtract(Value, NewValue),

    S1 = ordsets:size(Value) + ordsets:size(Adds) - ordsets:size(Removes),

    T#babel_set{
        adds = Adds,
        removes = Removes,
        size = S1
    }.


%% -----------------------------------------------------------------------------
%% @doc Folds over the members of the set.
%% @end
%% -----------------------------------------------------------------------------
-spec fold(Fun :: fun((term(), term()) -> term()), Acc :: term(), T :: t()) ->
    Acc :: term().

fold(Fun, Acc0, T) ->
    ordsets:fold(Fun, Acc0, value(T)).


%% -----------------------------------------------------------------------------
%% @doc Test whether an element is a member of the set.
%% @end
%% -----------------------------------------------------------------------------
-spec is_element(binary(), t()) -> boolean().

is_element(Element, #babel_set{values = V, adds = A, removes = R}) ->
    not ordsets:is_element(Element, R) andalso
    (ordsets:is_element(Element, V) orelse ordsets:is_element(Element, A)).


%% -----------------------------------------------------------------------------
%% @doc Test whether an element is a member of the original set i,e. the one
%% retrieved from Riak.
%% @end
%% -----------------------------------------------------------------------------
-spec is_original_element(binary(), t()) -> boolean().

is_original_element(Element, #babel_set{values = V}) ->
    ordsets:is_element(Element, V).



%% =============================================================================
%% PRIVATE
%% =============================================================================



%% @private
from_binary(Value, Fun) when is_function(Fun, 2) ->
    Fun(decode, Value);

from_binary(Value, Type) ->
    babel_utils:from_binary(Value, Type).


%% @private
from_term(Term, atom) ->
    is_atom(Term) orelse error({badarg, Term}),
    Term;

from_term(Term, existing_atom) ->
    is_atom(Term) orelse error({badarg, Term}),
    Term;

from_term(Term, boolean) ->
    is_boolean(Term) orelse error({badarg, Term}),
    Term;

from_term(Term, integer) ->
    is_integer(Term) orelse error({badarg, Term}),
    Term;

from_term(Term, float) ->
    is_float(Term) orelse error({badarg, Term}),
    Term;

from_term(Term, binary) ->
    is_binary(Term) orelse error({badarg, Term}),
    Term;

from_term(Term, list) ->
    is_list(Term) orelse error({badarg, Term}),
    Term;

from_term(Term, Fun) when is_function(Fun) ->
    is_function(Fun, 1) orelse is_function(Fun, 2) orelse error({badarg, Term}),
    Term;

from_term(_, Type) ->
    error({badtype, Type}).


%% @private
to_binary(Value, Fun) when is_function(Fun, 2) ->
    Fun(encode, Value);

to_binary(Value, Type) ->
    babel_utils:to_binary(Value, Type).