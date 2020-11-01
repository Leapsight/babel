%% =============================================================================
%%  babel_counter.erl -
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

-module(babel_counter).
-include("babel.hrl").

-record(babel_counter, {
    value = 0           :: integer(),
    increment           :: undefined | integer()
}).

-opaque t()             ::  #babel_counter{}.
-type type_spec()       ::  integer.

-export_type([t/0]).
-export_type([type_spec/0]).

-export([context/1]).
-export([decrement/1]).
-export([decrement/2]).
-export([from_riak_counter/2]).
-export([increment/1]).
-export([increment/2]).
-export([is_type/1]).
-export([new/0]).
-export([new/1]).
-export([original_value/1]).
-export([set/2]).
-export([set_context/2]).
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
    #babel_counter{}.


%% -----------------------------------------------------------------------------
%% @doc
%% @end
%% -----------------------------------------------------------------------------
-spec new(Value :: integer()) -> t().

new(Value) when is_integer(Value) ->
    #babel_counter{increment = Value}.


%% -----------------------------------------------------------------------------
%% @doc
%% @end
%% -----------------------------------------------------------------------------
-spec from_riak_counter(
    RiakCounter :: riakc_counter:counter() | integer, Type :: integer) ->
    maybe_no_return(t()).

from_riak_counter(Value, integer) when is_integer(Value) ->
    #babel_counter{value = Value};

from_riak_counter(RiakCounter, integer) ->
    #babel_counter{value = riakc_counter:value(RiakCounter)}.


%% -----------------------------------------------------------------------------
%% @doc
%% @end
%% -----------------------------------------------------------------------------
-spec to_riak_op(t(), type_spec()) ->
    riakc_datatype:update(riak_counter:coutner_op()).

to_riak_op(#babel_counter{increment = undefined}, _) ->
    undefined;

to_riak_op(#babel_counter{increment = Incr}, _) ->
    {riakc_counter:type(), {increment, Incr}, undefined}.


%% -----------------------------------------------------------------------------
%% @doc Returns the symbolic name of this container.
%% @end
%% -----------------------------------------------------------------------------
-spec type() -> counter.

type() -> counter.


%% -----------------------------------------------------------------------------
%% @doc
%% @end
%% -----------------------------------------------------------------------------
-spec is_type(Term :: any()) -> boolean().

is_type(Term) ->
    is_record(Term, babel_counter).


%% -----------------------------------------------------------------------------
%% @doc Returns the Riak KV context
%% @end
%% -----------------------------------------------------------------------------
-spec context(T :: t()) -> riakc_datatype:context().

context(#babel_counter{}) -> undefined.

%% -----------------------------------------------------------------------------
%% @doc
%% This has call has no effect and it is provided for compliance withe the
%% datatype interface.
%% @end
%% -----------------------------------------------------------------------------
-spec set_context(Ctxt :: riakc_datatype:set_context(), T :: t()) ->
    NewT :: t().

set_context(_, #babel_counter{} = T) ->
    T;

set_context(_, Term) ->
    error({badcounter, Term}).


%% -----------------------------------------------------------------------------
%% @doc Returns the original value of the counter.
%% @end
%% -----------------------------------------------------------------------------
-spec original_value(T :: t()) -> integer().

original_value(#babel_counter{value = Value}) ->
    Value.


%% -----------------------------------------------------------------------------
%% @doc Returns the current value of the counter.
%% @end
%% -----------------------------------------------------------------------------
-spec value(T :: t()) -> integer().

value(#babel_counter{value = Value, increment = undefined}) ->
    Value;

value(#babel_counter{value = Value, increment = Incr}) ->
    Value + Incr.


%% -----------------------------------------------------------------------------
%% @doc Increments the counter by 1.
%% @end
%% -----------------------------------------------------------------------------
-spec increment(t()) -> t().

increment(#babel_counter{} = T) ->
    increment(1, T).


%% -----------------------------------------------------------------------------
%% @doc Increments the counter by amount `Amount'.
%% @end
%% -----------------------------------------------------------------------------
-spec increment(Amount :: integer(), t()) -> t().

increment(Amount, #babel_counter{increment = undefined} = T)
when is_integer(Amount) ->
  T#babel_counter{increment = Amount};

increment(Amount, #babel_counter{increment = Incr} = T)
when is_integer(Amount) ->
  T#babel_counter{increment = Incr + Amount}.


%% -----------------------------------------------------------------------------
%% @doc Decrements the counter by 1.
%% @end
%% -----------------------------------------------------------------------------
-spec decrement(t()) -> t().

decrement(#babel_counter{} = T) ->
    increment(-1, T).


%% -----------------------------------------------------------------------------
%% @doc Decrements the counter by amount `Amount'.
%% @end
%% -----------------------------------------------------------------------------
-spec decrement(Amount :: integer(), t()) -> t().

decrement(Amount, #babel_counter{} = T) ->
    increment(-Amount, T).


%% -----------------------------------------------------------------------------
%% @doc Increments or decrements the counter so that its resulting value would
%% be equal to `Amount'.
%% @end
%% -----------------------------------------------------------------------------
-spec set(integer(), t()) -> t().

set(Amount, #babel_counter{value = Value} = T) when Value == Amount ->
    T#babel_counter{increment = undefined};

set(Amount, #babel_counter{value = Value} = T) when Value < Amount ->
    T#babel_counter{increment = Amount - Value};

set(Amount, #babel_counter{value = Value} = T) when Value > Amount ->
    T#babel_counter{increment = - abs(Amount - Value)}.



