%% =============================================================================
%%  babel_index.erl -
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
%% @doc An object that specifies the type and configuration of an application
%% maintained index in Riak KV and the location
%% `({bucket_type(), bucket()}, key()})' of its partitions
%% {@link babel_index_partition} in Riak KV.
%%
%% Every Index has one or more partition objects which are modelled as Riak KV
%% maps.
%%
%% An Index is persisted as a read-only CRDT Map as part of an Index Collection
%% {@link babel_index_collection}. An Index Collection aggregates all indices
%% for a domain entity or resource e.g. accounts.
%%
%% @end
%% -----------------------------------------------------------------------------
-module(babel_index).
-include("babel.hrl").
-include_lib("riakc/include/riakc.hrl").
-include_lib("kernel/include/logger.hrl").

-define(BUCKET_SUFFIX, "index_data").

%% Validator for maps_utils:validate/2,3
-define(BINARY_VALIDATOR, fun
    (Val) when is_atom(Val) ->
        {ok, atom_to_binary(Val, utf8)};
    (Val) when is_binary(Val) ->
        true;
    (_) ->
        false
end).

%% Spec for maps_utils:validate/2,3
-define(SPEC, #{
    name => #{
        required => true,
        datatype => binary
    },
    bucket_type => #{
        description => <<
            "The bucket type used to store the babel_index_partition:t() objects. "
            "This bucket type should have a datatype of `map`."
        >>,
        required => true,
        datatype => [binary, atom],
        allow_undefined => true,
        default => babel_config:get([bucket_types, index_data]),
        validator => ?BINARY_VALIDATOR
    },
    bucket_prefix => #{
        description => <<
            "The bucket name used to store the babel_index_partition:t() objects"
        >>,
        required => true,
        datatype => [binary, atom],
        validator => ?BINARY_VALIDATOR
    },
    type => #{
        description => <<
            "The index type (Erlang module) used by this index."
        >>,
        required => true,
        datatype => atom
    },
    config => #{
        description => <<
            "The configuration data for the index type used by this index."
        >>,
        required => false,
        default => #{},
        datatype => map
    }
}).


-type t()                       ::  #{
    bucket := binary(),
    bucket_type := binary(),
    config := _,
    name := binary(),
    type := atom()
}.
-type riak_object()             ::  riakc_map:crdt_map().
-type config()                  ::  map().
-type config_object()           ::  riakc_map:crdt_map().
-type partition_id()            ::  binary().
-type partition_key()           ::  binary().
-type local_key()               ::  binary().
-type action()                  ::  insert | delete.
-type key_value()               ::  babel_key_value:t().
-type index_key()               ::  binary().
-type index_values()            ::  map().
-type iterator_action()         ::  first | last | next | prev | binary().
-type fold_opts()               ::  #{
    first => binary(),
    sort_ordering => asc | desc
}.
-type fold_fun()                ::  fun(
                                        (index_key(), index_values(), any()) ->
                                        any()
                                    ).
-type foreach_fun()             ::  fun(
                                        (index_key(), index_values()) ->
                                        any()
                                    ).
-type query_opts()              ::  #{
    max_results => non_neg_integer() | all,
    continuation => any(),
    return_body => any(),
    timeout => timeout() ,
    pagination_sort => boolean(),
    stream => boolean()
}.

-export_type([t/0]).
-export_type([riak_object/0]).
-export_type([config/0]).
-export_type([config_object/0]).
-export_type([partition_id/0]).
-export_type([partition_key/0]).
-export_type([local_key/0]).
-export_type([action/0]).
-export_type([key_value/0]).
-export_type([index_key/0]).
-export_type([index_values/0]).
-export_type([riak_opts/0]).

%% API
%% -export([get/4]).
%% -export([list/4]).
-export([bucket/1]).
-export([bucket_type/1]).
-export([config/1]).
-export([create_partitions/1]).
%% -export([fold/3]).
%% -export([fold/4]).
-export([foreach/2]).
-export([from_riak_object/1]).
-export([match/3]).
-export([name/1]).
-export([new/1]).
-export([partition_identifier/2]).
-export([partition_identifiers/1]).
-export([partition_identifiers/2]).
-export([to_delete_item/2]).
-export([to_riak_object/1]).
-export([to_update_item/2]).
-export([type/1]).
-export([typed_bucket/1]).
-export([update/3]).



%% =============================================================================
%% CALLBACKS
%% =============================================================================



-callback init(Name :: binary(), ConfigData :: map()) ->
    {ok, Config :: config()}
    | {error, any()}.

-callback init_partitions(config()) ->
    {ok, [babel_index_partition:t()]}
    | {error, any()}.

-callback from_riak_object(Object :: config_object()) -> Config :: config().

-callback to_riak_object(Config :: config()) -> Object :: config_object().

-callback number_of_partitions(config()) -> pos_integer().

-callback partition_identifier(key_value(), config()) -> partition_id().

-callback partition_identifiers(asc | desc, config()) -> [partition_id()].

-callback update_partition(
    [{action(), key_value()}], babel_index_partition:t(), config()) ->
    babel_index_partition:t().

-callback match(Pattern :: key_value(), babel_index_partition:t(), config()) ->
    [{index_key(), index_values()}] | no_return().

-callback iterator(Index :: t(), Config :: config(), Opts :: map()) ->
    Iterator :: any().

-callback iterator_move(
    Action :: iterator_action(), Iterator :: any(), config()) ->
    any().

-callback iterator_done(Iterator :: any()) -> boolean().

-callback iterator_key(Iterator :: any()) -> Key :: index_key().

-callback iterator_values(Iterator :: any()) -> Key :: index_values().



%% =============================================================================
%% API
%% =============================================================================



%% -----------------------------------------------------------------------------
%% @doc Returns a new index based on the specification map. It fails in case
%% the specification in invalid.
%%
%% A specification is map with the following fields (required fields are in
%% bold):
%%
%% **name** :: binary() – a unique name for this index within a collection.
%% **bucket_type** :: binary() | atom() – the bucket type used to store the
%% babel_index_partition:t() objects. This bucket type should have a datatype
%% of `map`.
%% **bucket** :: binary() | atom() – the bucket name used to store the
%% babel_index_partition:t() objects of this index. Typically the name of an
%% entity in plural form e.g. 'accounts'.
%% **type** :: atom() – the index type (Erlang module) used by this index.
%% config :: map() – the configuration data for the index type used by this
%% index.
%%
%% @end
%% -----------------------------------------------------------------------------
-spec new(IndexData :: map()) -> Index :: t() | no_return().

new(IndexData) ->
    Index0 = maps_utils:validate(IndexData, ?SPEC),
    #{
        name := Name,
        type := Type,
        config := ConfigSpec,
        bucket_prefix := BucketPrefix
    } = Index0,

    Index1 = maps:without([bucket_prefix], Index0),
    Bucket = <<BucketPrefix/binary, ?PATH_SEPARATOR, ?BUCKET_SUFFIX>>,
    Index = Index1#{bucket => Bucket},

    case Type:init(Name, ConfigSpec) of
        {ok, Config} ->
            Index#{config => Config};
        {error, Reason} ->
            error(Reason)
    end.


%% -----------------------------------------------------------------------------
%% @doc
%% @end
%% -----------------------------------------------------------------------------
-spec from_riak_object(ConfigCRDT :: riak_object()) -> Index :: t().

from_riak_object(Object) ->
    Name = babel_crdt:register_to_binary(
        orddict:fetch({<<"name">>, register}, Object)
    ),
    BucketType = babel_crdt:register_to_binary(
        orddict:fetch({<<"bucket_type">>, register}, Object)
    ),
    Bucket = babel_crdt:register_to_binary(
        orddict:fetch({<<"bucket">>, register}, Object)
    ),
    Type = babel_crdt:register_to_existing_atom(
        orddict:fetch({<<"type">>, register}, Object),
        utf8
    ),
    Config = Type:from_riak_object(
        orddict:fetch({<<"config">>, map}, Object)
    ),

    #{
        name => Name,
        bucket_type => BucketType,
        bucket => Bucket,
        type => Type,
        config => Config
    }.


%% -----------------------------------------------------------------------------
%% @doc
%% @end
%% -----------------------------------------------------------------------------
-spec to_riak_object(Index :: t()) -> IndexCRDT :: riak_object().

to_riak_object(Index) ->
    #{
        name := Name,
        bucket_type := BucketType,
        bucket := Bucket,
        type := Type,
        config := Config
    } = Index,

    ConfigCRDT =  Type:to_riak_object(Config),

    Values = [
        {{<<"name">>, register}, Name},
        {{<<"bucket_type">>, register}, BucketType},
        {{<<"bucket">>, register}, Bucket},
        {{<<"type">>, register}, atom_to_binary(Type, utf8)},
        {{<<"config">>, map}, ConfigCRDT}
    ],

    lists:foldl(
        fun({K, V}, Acc) -> babel_key_value:set(K, V, Acc) end,
        riakc_map:new(),
        Values
    ).


%% -----------------------------------------------------------------------------
%% @doc
%% @end
%% -----------------------------------------------------------------------------
-spec create_partitions(t()) -> [babel_index_partition:t()] | no_return().

create_partitions(#{type := Type, config := Config}) ->
    case Type:init_partitions(Config) of
        {ok, Partitions} -> Partitions;
        {error, Reason} -> error(Reason)
    end.


%% -----------------------------------------------------------------------------
%% @doc Returns the representation of this object as a Reliable Update work
%% item.
%% @end
%% -----------------------------------------------------------------------------
-spec to_update_item(Index :: babel_index:t(), Partition :: t()) ->
    babel:work_item().

to_update_item(Index, Partition) ->
    PartitionId = babel_index_partition:id(Partition),
    TypedBucket = typed_bucket(Index),
    RiakOps = riakc_map:to_op(babel_index_partition:to_riak_object(Partition)),
    Args = [TypedBucket, PartitionId, RiakOps],
    {node(), riakc_pb_socket, update_type, [{symbolic, riakc} | Args]}.


%% -----------------------------------------------------------------------------
%% @doc Returns the representation of this object as a Reliable Delete work
%% item.
%% @end
%% -----------------------------------------------------------------------------
-spec to_delete_item(Index :: babel_index:t(), PartitionId :: binary()) ->
    babel:work_item().

to_delete_item(Index, PartitionId) ->
    TypedBucket = typed_bucket(Index),
    Args = [TypedBucket, PartitionId],
    {node(), riakc_pb_socket, delete, [{symbolic, riakc} | Args]}.




%% -----------------------------------------------------------------------------
%% @doc Returns name of this index
%% @end
%% -----------------------------------------------------------------------------
-spec name(t()) -> binary().

name(#{name := Value}) -> Value.


%% -----------------------------------------------------------------------------
%% @doc Returns the Riak KV bucket were this index partitions are stored.
%% @end
%% -----------------------------------------------------------------------------
-spec bucket(t()) -> maybe_no_return(binary()).

bucket(#{bucket := Value}) -> Value.


%% -----------------------------------------------------------------------------
%% @doc Returns the Riak KV bucket type associated with this index.
%% @end
%% -----------------------------------------------------------------------------
-spec bucket_type(t()) -> maybe_no_return(binary()).

bucket_type(#{bucket_type := Value}) -> Value.


%% -----------------------------------------------------------------------------
%% @doc Returns the Riak KV `typed_bucket()' associated with this index.
%% @end
%% -----------------------------------------------------------------------------
-spec typed_bucket(t()) -> maybe_no_return({binary(), binary()}).

typed_bucket(#{bucket_type := Type, bucket := Bucket}) ->
    {Type, Bucket}.


%% -----------------------------------------------------------------------------
%% @doc Returns the type of this index. A type is a module name implementing
%% the babel_index behaviour i.e. a type of index.
%% @end
%% -----------------------------------------------------------------------------
-spec type(t()) -> maybe_no_return(module()).

type(#{type := Value}) -> Value.


%% -----------------------------------------------------------------------------
%% @doc Returns the configuration associated with this index.
%% The configuration depends on the index type {@link babel:type/1}.
%% @end
%% -----------------------------------------------------------------------------
-spec config(t()) -> maybe_no_return(riakc_map:crdt_map()).

config(#{config := Value}) -> Value.


%% -----------------------------------------------------------------------------
%% @doc
%% @end
%% -----------------------------------------------------------------------------
-spec partition_identifier(KeyValue :: key_value(), Index :: t()) -> binary().

partition_identifier(KeyValue, Index) ->
    Mod = type(Index),
    Config = config(Index),
    Mod:partition_identifier(KeyValue, Config).


%% -----------------------------------------------------------------------------
%% @doc
%% @end
%% -----------------------------------------------------------------------------
-spec update(
    Actions :: [{action(), key_value()}],
    Index :: t(),
    RiakOpts :: riak_opts()) ->
    maybe_no_return([babel_index_partition:t()]).

update(Actions, Index, RiakOpts) when is_list(Actions) ->
    Mod = type(Index),
    Config = config(Index),
    TypeBucket = typed_bucket(Index),

    Update = fun({PartitionId, PActions}, Acc) ->
        Part0 = babel_index_partition:fetch(TypeBucket, PartitionId, RiakOpts),
        Part1 = Mod:update_partition(PActions, Part0, Config),
        [Part1 | Acc]
    end,
    lists:foldl(
        Update,
        [],
        objects_by_partition_id(Mod, Config, Actions)
    ).






%% -----------------------------------------------------------------------------
%% @doc Returns the list of Riak KV keys under which the partitions are stored,
%% in ascending order.
%% This is equivalent to the call `partition_identifiers(Index, asc)'.
%% @end
%% -----------------------------------------------------------------------------
-spec partition_identifiers(t()) -> maybe_no_return([binary()]).

partition_identifiers(Index) ->
    partition_identifiers(Index, asc).


%% -----------------------------------------------------------------------------
%% @doc Returns the list of Riak KV keys under which the partitions are stored
%% in a defined order i.e. `asc' or `desc'.
%% @end
%% -----------------------------------------------------------------------------
-spec partition_identifiers(t(), asc | desc) -> maybe_no_return([binary()]).

partition_identifiers(Index, Order) ->
    Mod = type(Index),
    Config = config(Index),
    Mod:partition_identifiers(Order, Config).



%% -spec fold(fold_fun(), any(), Index :: t()) -> any().

%% fold(Fun, Acc, Index) ->
%%     fold(Fun, Acc, Index, #{}).



%% -spec fold(fold_fun(), any(), Index :: t(), Opts :: fold_opts()) -> any().

%% fold(Fun, Acc, Index, Opts) ->
%%     Mod = type(Index),
%%     Config = config(Index),
%%     Iter = Mod:iterator(Config, Opts),
%%     do_fold(Fun, Acc, {Mod, Iter}).


%% -----------------------------------------------------------------------------
%% @doc
%% @end
%% -----------------------------------------------------------------------------
-spec foreach(foreach_fun(), Index :: t()) -> any().

foreach(_Fun, _Index) ->
    ok.



%% -----------------------------------------------------------------------------
%% @doc Returns a list of matching index entries
%% @end
%% -----------------------------------------------------------------------------
-spec match(
    Index :: t(),
    Pattern :: babel_index:key_value(),
    RiakOpts :: riak_opts()) -> [{index_key(), index_values()}] | no_return().

match(Pattern, Index, RiakOpts) ->
    Mod = type(Index),
    Config = config(Index),
    PartitionId = Mod:partition_identifier(Pattern, Config),
    TypeBucket = typed_bucket(Index),
    Partition = babel_index_partition:fetch(TypeBucket, PartitionId, RiakOpts),
    Mod:match(Pattern, Partition, Config).



%% =============================================================================
%% PRIVATE
%% =============================================================================



%% @private
objects_by_partition_id(Mod, Config, List) ->
    Tuples = [
        %% We generate the tuple {partition_id(), {action(), key_value()}}.
        {Mod:partition_identifier(Data, Config), X}
        || {_, Data} = X <- List
    ],

    %% We generate the list [ {partition_id(), [{action(), key_value()}]} ]
    %% by grouping by the 1st element and collecting the 2nd element
    Proj = {1, {function, collect, [2]}},
    leap_tuples:summarize(Tuples, Proj, #{}).


%% %% @private
%% iterator(Index, Opts) ->
%%     Mod = type(Index),
%%     Config = config(Index),
%%     Mod:iterator(Config, Opts).


%% do_fold(Fun, Acc, {Mod, Iter}) ->
%%     case Mod:iterator_done(Iter) of
%%         true ->
%%             Acc;
%%         false ->
%%             Acc1 = Fun(Mod:iterator_key(Iter), Mod:iterator_values(Iter), Acc),
%%             do_fold(Fun, Acc1, iterator(Iter))
%%     end.



