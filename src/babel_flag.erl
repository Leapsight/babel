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

-module(babel_flag).
-include("babel.hrl").

-record(babel_flag, {
    value = false       ::  boolean(),
    op                  ::  enable | disable | undefined,
    context             ::  riakc_datatype:context() | undefined
}).

-opaque t()             ::  #babel_flag{}.
-type type_spec()       ::  boolean.

-export_type([t/0]).
-export_type([type_spec/0]).

-export([context/1]).
-export([disable/1]).
-export([enable/1]).
-export([set/2]).
-export([from_riak_flag/2]).
-export([is_type/1]).
-export([new/0]).
-export([new/1]).
-export([to_riak_op/2]).
-export([type/0]).
-export([original_value/1]).
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

new(Value) ->
    new(Value, undefined).


%% -----------------------------------------------------------------------------
%% @doc
%% @end
%% -----------------------------------------------------------------------------
-spec new(Value :: boolean(), Ctxt :: riakc_datatype:context()) -> t().

new(true, Ctxt) ->
    enable(#babel_flag{context = Ctxt});

new(false, Ctxt) ->
    #babel_flag{context = Ctxt}.


%% -----------------------------------------------------------------------------
%% @doc
%% @end
%% -----------------------------------------------------------------------------
-spec from_riak_flag(
    RiakFlag :: riakc_flag:riakc_t() | boolean, Type :: type_spec()) ->
    maybe_no_return(t()).

from_riak_flag(Value, boolean) when is_boolean(Value) ->
    #babel_flag{value = Value};

from_riak_flag(RiakFlag, boolean) ->
    Flag = from_riak_flag(riakc_flag:value(RiakFlag), boolean),
    Flag#babel_flag{context = element(4, RiakFlag)}.


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
%% @doc Returns the Riak KV context
%% @end
%% -----------------------------------------------------------------------------
-spec context(T :: t()) -> riakc_datatype:context().

context(#babel_flag{context = Value}) -> Value.


%% -----------------------------------------------------------------------------
%% @doc Returns the original value of the flag.
%% @end
%% -----------------------------------------------------------------------------
-spec original_value(T :: t()) -> integer().

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

