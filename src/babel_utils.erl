%% =============================================================================
%%  babel_utils.erl -
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
-module(babel_utils).

-type type()            ::  atom
                            | existing_atom
                            | boolean
                            | integer
                            | float
                            | binary
                            | list.

-export_type([type/0]).

-export([from_binary/2]).
-export([to_binary/2]).



%% =============================================================================
%% API
%% =============================================================================



%% -----------------------------------------------------------------------------
%% @doc
%% @end
%% -----------------------------------------------------------------------------
-spec from_binary(binary(), type()) -> any().

from_binary(Value, binary) ->
    Value;

from_binary(<<>>, _) ->
    undefined;

from_binary(Value, atom) ->
    binary_to_atom(Value, utf8);

from_binary(Value, existing_atom) ->
    binary_to_existing_atom(Value, utf8);

from_binary(<<"true">>, boolean) ->
    true;

from_binary(<<"false">>, boolean) ->
    false;

from_binary(Value, integer) ->
    binary_to_integer(Value);

from_binary(Value, float) ->
    binary_to_float(Value);

from_binary(Value, list) ->
    binary_to_list(Value);

from_binary(_, Type) ->
    error({badtype, Type}).


%% -----------------------------------------------------------------------------
%% @doc
%% @end
%% -----------------------------------------------------------------------------
-spec to_binary(any(), type()) -> binary().

to_binary(Value, binary) when is_binary(Value) ->
    Value;

to_binary(Value, atom) when is_atom(Value) ->
    atom_to_binary(Value, utf8);

to_binary(Value, existing_atom) ->
    atom_to_binary(Value, utf8);

to_binary(true, boolean) ->
    <<"true">>;

to_binary(false, boolean) ->
    <<"false">>;

to_binary(Value, integer) when is_integer(Value) ->
    integer_to_binary(Value);

to_binary(Value, float) when is_float(Value) ->
    float_to_binary(Value);

to_binary(Value, list) when is_list(Value) ->
    list_to_binary(Value);

to_binary(Value, Fun) when is_function(Fun, 2) ->
    Fun(encode, Value);

to_binary(Term, Type) ->
    error({badtype, {Term, Type}}).