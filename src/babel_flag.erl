%% =============================================================================
%%  babel_flag.erl -
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
%% @doc Flags behave much like Boolean values, except that instead of true or
%% false flags have the values enable or disable.
%%
%% Flags cannot be used on their own, i.e. a flag cannot be stored in a bucket/
%% key by itself. Instead, flags can only be stored within maps.
%% To disable an existing flag, you have to read it or provide a context.
%% @end
%% -----------------------------------------------------------------------------
-module(babel_flag).
-include("babel.hrl").

-record(babel_flag, {
    value = false       ::  boolean(),
    %% RiakC uses undefined but this causes Riak to never record a flag
    %% initilised with 'false'.
    op = disable        ::  enable | disable | undefined,
    context             ::  babel_context()
}).

-opaque t()             ::  #babel_flag{}.
-type type_spec()       ::  boolean.

-export_type([t/0]).
-export_type([type_spec/0]).

-export([context/1]).
-export([disable/1]).
-export([enable/1]).
-export([from_riak_flag/3]).
-export([is_type/1]).
-export([is_valid_type_spec/1]).
-export([new/0]).
-export([new/1]).
-export([new/2]).
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
    #babel_flag{}.


%% -----------------------------------------------------------------------------
%% @doc
%% @end
%% -----------------------------------------------------------------------------
-spec new(Value :: boolean()) -> t().

new(true) ->
    enable(new());

new(false) ->
    new().


%% -----------------------------------------------------------------------------
%% @doc
%% @end
%% -----------------------------------------------------------------------------
-spec new(Value :: boolean(), Ctxt :: babel_context()) -> t().

new(Value, undefined) when is_boolean(Value) ->
    new(Value);

new(Value, Ctxt) when is_boolean(Value) ->
    #babel_flag{value = Value, op = undefined, context = Ctxt}.


%% -----------------------------------------------------------------------------
%% @doc
%% @end
%% -----------------------------------------------------------------------------
-spec from_riak_flag(
    RiakFlag :: riakc_flag:riakc_t() | boolean,
    Ctxt :: babel_context(),
    Type :: type_spec()) ->
    maybe_no_return(t()).

from_riak_flag(Value, Ctxt, boolean) when is_boolean(Value) ->
    new(Value, Ctxt);

from_riak_flag(RiakFlag, Ctxt, boolean) ->
    from_riak_flag(riakc_flag:value(RiakFlag), Ctxt, boolean).


%% -----------------------------------------------------------------------------
%% @doc
%% @end
%% -----------------------------------------------------------------------------
-spec to_riak_op(t(), type_spec()) ->
    riakc_datatype:update(riak_flag:flag_op()).

to_riak_op(#babel_flag{op = undefined}, _) ->
    undefined;

to_riak_op(#babel_flag{op = O}, _) ->
    {riakc_flag:type(), O, undefined}.


%% -----------------------------------------------------------------------------
%% @doc Returns the symbolic name of this container.
%% @end
%% -----------------------------------------------------------------------------
-spec type() -> flag.

type() -> flag.



%% -----------------------------------------------------------------------------
%% @doc
%% @end
%% -----------------------------------------------------------------------------
-spec is_type(Term :: any()) -> boolean().

is_type(Term) ->
    is_record(Term, babel_flag).



%% -----------------------------------------------------------------------------
%% @doc
%% @end
%% -----------------------------------------------------------------------------
-spec is_valid_type_spec(term()) -> boolean().

is_valid_type_spec(boolean) -> true;
is_valid_type_spec(_) -> false.


%% -----------------------------------------------------------------------------
%% @doc Returns the Riak KV context
%% @end
%% -----------------------------------------------------------------------------
-spec context(T :: t()) -> babel_context().

context(#babel_flag{context = Value}) -> Value.


%% -----------------------------------------------------------------------------
%% @doc Sets the context `Ctxt'.
%% @end
%% -----------------------------------------------------------------------------
-spec set_context(Ctxt :: babel_context(), T :: t()) ->
    NewT :: t().

set_context(Ctxt, #babel_flag{} = T)
when is_binary(Ctxt) orelse Ctxt == undefined orelse Ctxt == inherited ->
    T#babel_flag{context = Ctxt};

set_context(Ctxt, #babel_flag{}) ->
    error({badarg, Ctxt});

set_context(_, Term) ->
    error({badflag, Term}).


%% -----------------------------------------------------------------------------
%% @doc Returns the original value of the flag.
%% @end
%% -----------------------------------------------------------------------------
-spec original_value(T :: t()) -> boolean().

original_value(#babel_flag{value = Value}) ->
    Value.


%% -----------------------------------------------------------------------------
%% @doc Returns the current value of the flag.
%% @end
%% -----------------------------------------------------------------------------
-spec value(T :: t()) -> boolean().

value(#babel_flag{op = undefined, value = Value}) ->
    Value;

value(#babel_flag{op = enable}) ->
    true;

value(#babel_flag{op = disable}) ->
    false.


%% -----------------------------------------------------------------------------
%% @doc Enables the flag, setting its value to true.
%% @end
%% -----------------------------------------------------------------------------
-spec enable(t()) -> t().

enable(#babel_flag{} = T) ->
    T#babel_flag{op = enable}.


%% -----------------------------------------------------------------------------
%% @doc Disables the flag, setting its value to false.
%% @throws context_required
%% @end
%% -----------------------------------------------------------------------------
-spec disable(t()) -> t().

disable(#babel_flag{context = undefined}) ->
    throw(context_required);

disable(#babel_flag{} = T) ->
    T#babel_flag{op = disable}.


%% -----------------------------------------------------------------------------
%% @doc
%% @end
%% -----------------------------------------------------------------------------
-spec set(boolean(), t()) -> t().

set(true, T) ->
    enable(T);

set(false, T) ->
    disable(T).



%% =============================================================================
%% PRIVATE
%% =============================================================================

