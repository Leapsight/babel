%% =============================================================================
%%  babel_hash_partitioned_index.erl -
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
%% @doc A hash-partitioned index is an index whose contents (index entries)
%% have been partitioned amongst a fixed number of parts (called partitions)
%% using a hashing algorithm to determine in which partition and entry should be
%% located.
%%
%% By partitioning an index into multiple physical parts, you are accessing much
%% smaller objects which makes it faster and more reliable.
%%
%% With hash partitioning, an index entry is placed into a partition based
%% on the result of passing the partitioning key into a hashing algorithm.
%%
%% @end
%% -----------------------------------------------------------------------------
-module(babel_hash_partitioned_index).
-behaviour(babel_index).
-include("babel.hrl").


-define(SPEC, #{
    sort_ordering => #{
        required => false,
        allow_null => false,
        allow_undefined => false,
        default => asc,
        datatype => {in, [asc, desc]}
    },
    number_of_partitions => #{
        description => <<"The number of partitions for this index.">>,
        required => true,
        allow_null => false,
        allow_undefined => false,
        datatype => pos_integer
    },
    partition_algorithm => #{
        required => true,
        default => jch,
        datatype => {in, [jch]}
    },
    partition_by => #{
        required => true,
        allow_null => false,
        allow_undefined => false,
        datatype => {list, [binary, tuple]}
    },
    index_by => #{
        required => true,
        allow_null => false,
        allow_undefined => false,
        datatype => {list, [binary, tuple]},
        validator => fun
            ([]) -> false;
            (_) -> true
        end
    },
    aggregate_by => #{
        required => true,
        description => <<"A list of keys that will be use to compute the aggregate. It has to be a subset of the index_by value.">>,
        default => [],
        allow_null => false,
        allow_undefined => false,
        datatype => {list, [binary, tuple]}
    },
    covered_fields => #{
        required => true,
        allow_null => false,
        allow_undefined => false,
        datatype => {list, [binary, tuple]}
    }
}).

-type t()           ::  #{
    sort_ordering := asc | desc,
    number_of_partitions := integer(),
    partition_algorithm := atom(),
    partition_identifier_prefix := binary(),
    partition_identifiers := [binary()],
    partition_by := fields(),
    index_by := fields(),
    aggregate_by := fields(),
    covered_fields := fields()
}.


-record(babel_hash_partitioned_index_iter, {
    partition                   ::  babel_index_partition:t() | undefined,
    sort_ordering               ::  asc | desc,
    key                         ::  binary() | undefined,
    values                      ::  map() | undefined,
    typed_bucket                ::  {binary(), binary()},
    first                       ::  binary() | undefined,
    keys = []                   ::  [binary()],
    partition_identifiers = []  ::  [babel_index:partition_id()],
    riak_opts                   ::  babel_index:riak_opts(),
    done = false                ::  boolean()
}).

-type action()      ::  {babel_index:action(), babel_index:key_value()}.
-type fields()      ::  [babel_key_value:key()].
-type iterator()    ::  #babel_hash_partitioned_index_iter{}.

-export_type([action/0]).
-export_type([fields/0]).


%% API
-export([aggregate_by/1]).
-export([covered_fields/1]).
-export([index_by/1]).
-export([partition_algorithm/1]).
-export([partition_by/1]).
-export([partition_identifier_prefix/1]).
-export([sort_ordering/1]).


%% BEHAVIOUR CALLBACKS
-export([from_riak_dict/1]).
-export([init/2]).
-export([init_partitions/1]).
-export([iterator/3]).
-export([iterator_done/1]).
-export([iterator_key/1]).
-export([iterator_move/3]).
-export([iterator_values/1]).
-export([match/3]).
-export([number_of_partitions/1]).
-export([partition_identifier/2]).
-export([partition_identifiers/2]).
-export([to_riak_object/1]).
-export([update_partition/3]).


%% =============================================================================
%% API
%% =============================================================================



%% -----------------------------------------------------------------------------
%% @doc Returns the sort ordering configured for this index. The result can be
%% the atoms `asc' or `desc'.
%% @end
%% -----------------------------------------------------------------------------
-spec sort_ordering(t()) -> asc | desc.

sort_ordering(#{sort_ordering := Value}) -> Value.


%% -----------------------------------------------------------------------------
%% @doc Returns the partition algorithm name configured for this index.
%% @end
%% -----------------------------------------------------------------------------
-spec partition_algorithm(t()) -> atom().

partition_algorithm(#{partition_algorithm := Value}) -> Value.


%% -----------------------------------------------------------------------------
%% @doc
%% @end
%% -----------------------------------------------------------------------------
-spec partition_by(t()) -> [binary()].

partition_by(#{partition_by := Value}) -> Value.


%% -----------------------------------------------------------------------------
%% @doc
%% @end
%% -----------------------------------------------------------------------------
-spec index_by(t()) -> [binary()].

index_by(#{index_by := Value}) -> Value.


%% -----------------------------------------------------------------------------
%% @doc
%% @end
%% -----------------------------------------------------------------------------
-spec aggregate_by(t()) -> [binary()].

aggregate_by(#{aggregate_by := Value}) -> Value.


%% -----------------------------------------------------------------------------
%% @doc
%% @end
%% -----------------------------------------------------------------------------
-spec covered_fields(t()) -> [binary()].

covered_fields(#{covered_fields := Value}) -> Value.


%% -----------------------------------------------------------------------------
%% @doc
%% @end
%% -----------------------------------------------------------------------------
-spec partition_identifier_prefix(t()) -> binary().

partition_identifier_prefix(#{partition_identifier_prefix := Value}) -> Value.


%% -----------------------------------------------------------------------------
%% @doc Returns the partition indentifiers of this index.
%% @end
%% -----------------------------------------------------------------------------
-spec partition_identifiers(t()) -> [binary()].

partition_identifiers(#{partition_identifiers := Value}) -> Value.



%% =============================================================================
%% BEHAVIOUR CALLBACKS
%% =============================================================================



%% -----------------------------------------------------------------------------
%% @doc
%% @end
%% -----------------------------------------------------------------------------
-spec init(IndexId :: binary(), ConfigData :: map()) ->
    {ok, t()} | {error, any()}.

init(IndexId, ConfigData0) ->
    Config0 = validate(ConfigData0),
    N = maps:get(number_of_partitions, Config0),
    Prefix = <<IndexId/binary, "_partition">>,
    Identifiers = gen_partition_identifiers(Prefix, N),
    Config1 = maps:put(partition_identifier_prefix, Prefix, Config0),
    Config2 = maps:put(partition_identifiers, Identifiers, Config1),
    {ok, Config2}.


%% -----------------------------------------------------------------------------
%% @doc
%% @end
%% -----------------------------------------------------------------------------
-spec from_riak_dict(Dict :: orddict:orddict()) -> Config :: t().

from_riak_dict(Dict) ->
    Sort = babel_crdt:register_to_existing_atom(
        orddict:fetch({<<"sort_ordering">>, register}, Dict),
        utf8
    ),
    N = babel_crdt:register_to_integer(
        orddict:fetch({<<"number_of_partitions">>, register}, Dict)
    ),

    Algo = babel_crdt:register_to_existing_atom(
        orddict:fetch({<<"partition_algorithm">>, register}, Dict),
        utf8
    ),

    Prefix = babel_crdt:register_to_binary(
        orddict:fetch({<<"partition_identifier_prefix">>, register}, Dict)
    ),

    PartitionBy = decode_fields(
        babel_crdt:register_to_binary(
            orddict:fetch({<<"partition_by">>, register}, Dict)
        )
    ),

    Identifiers = decode_list(
        babel_crdt:register_to_binary(
            orddict:fetch({<<"partition_identifiers">>, register}, Dict)
        )
    ),

    IndexBy = decode_fields(
        babel_crdt:register_to_binary(
            orddict:fetch({<<"index_by">>, register}, Dict)
        )
    ),

    AggregateBy = decode_fields(
        babel_crdt:register_to_binary(
            orddict:fetch({<<"aggregate_by">>, register}, Dict)
        )
    ),

    CoveredFields = decode_fields(
        babel_crdt:register_to_binary(
            orddict:fetch({<<"covered_fields">>, register}, Dict)
        )
    ),

    %% As this object is read-only and embeded in an Index Collection we turn it
    %% into an Erlang map as soon as we read it from the collection for enhanced
    %% performance. So loosing its CRDT context it not an issue.
    #{
        sort_ordering => Sort,
        number_of_partitions => N,
        partition_algorithm => Algo,
        partition_by => PartitionBy,
        partition_identifier_prefix => Prefix,
        partition_identifiers => Identifiers,
        index_by => IndexBy,
        aggregate_by => AggregateBy,
        covered_fields => CoveredFields
    }.


%% -----------------------------------------------------------------------------
%% @doc
%% @end
%% -----------------------------------------------------------------------------
-spec to_riak_object(Config :: t()) ->
    ConfigCRDT :: babel_index:riak_object().

to_riak_object(Config) ->
    #{
        sort_ordering := Sort,
        number_of_partitions := N,
        partition_algorithm := Algo,
        partition_by := PartitionBy,
        partition_identifier_prefix := Prefix,
        partition_identifiers := Identifiers,
        index_by := IndexBy,
        aggregate_by := AggregateBy,
        covered_fields := CoveredFields
    } = Config,


    Values = [
        {{<<"sort_ordering">>, register}, atom_to_binary(Sort, utf8)},
        {{<<"number_of_partitions">>, register}, integer_to_binary(N)},
        {{<<"partition_algorithm">>, register}, atom_to_binary(Algo, utf8)},
        {{<<"partition_identifier_prefix">>, register}, Prefix},
        {{<<"partition_identifiers">>, register}, encode_list(Identifiers)},
        {{<<"partition_by">>, register}, encode_fields(PartitionBy)},
        {{<<"index_by">>, register}, encode_fields(IndexBy)},
        {{<<"aggregate_by">>, register}, encode_fields(AggregateBy)},
        {{<<"covered_fields">>, register}, encode_fields(CoveredFields)}
    ],

    lists:foldl(
        fun({K, V}, Acc) ->
            babel_key_value:set(K, V, Acc)
        end,
        riakc_map:new(),
        Values
    ).


%% -----------------------------------------------------------------------------
%% @doc
%% @end
%% -----------------------------------------------------------------------------
-spec init_partitions(t()) ->
    {ok, [babel_index_partition:t()]}
    | {error, any()}.

init_partitions(#{partition_identifiers := Identifiers}) ->
    Partitions = [babel_index_partition:new(Id) || Id <- Identifiers],
    {ok, Partitions}.


%% -----------------------------------------------------------------------------
%% @doc
%% @end
%% -----------------------------------------------------------------------------
-spec number_of_partitions(t()) -> pos_integer().

number_of_partitions(#{number_of_partitions := Value}) -> Value.


%% -----------------------------------------------------------------------------
%% @doc
%% @end
%% -----------------------------------------------------------------------------
-spec partition_identifier(babel_index:key_value(), t()) ->
    babel_index:partition_id().

partition_identifier(KeyValue, Config) ->
    N = number_of_partitions(Config),
    Algo = partition_algorithm(Config),

    PKey = gen_index_key(partition_by(Config), KeyValue),

    Bucket = babel_consistent_hashing:bucket(PKey, N, Algo),

    %% Prefix = partition_identifier_prefix(Config),
    %% gen_identifier(Prefix, Bucket).

    %% Bucket is zero-based
    lists:nth(Bucket + 1, partition_identifiers(Config)).



%% -----------------------------------------------------------------------------
%% @doc
%% @end
%% -----------------------------------------------------------------------------
-spec partition_identifiers(asc | desc, t()) ->
    [babel_index:partition_id()].

partition_identifiers(Order, Config) ->
    Default = sort_ordering(Config),
    maybe_reverse(Default, Order, partition_identifiers(Config)).



%% -----------------------------------------------------------------------------
%% @doc
%% @end
%% -----------------------------------------------------------------------------
-spec update_partition(
    ActionData :: action() | [action()],
    Partition :: babel_index_partition:t(),
    Config :: t()
    ) -> babel_index_partition:t() | no_return().

update_partition({update, Data}, Partition, Config) ->
    AggregateBy = aggregate_by(Config),
    IndexBy = index_by(Config),
    IndexKey = gen_index_key(IndexBy, Data),
    Value = gen_index_key(covered_fields(Config), Data),

    case AggregateBy of
        [] ->
            update_data(IndexKey, Value, Partition);
        IndexBy ->
            update_data({IndexKey, IndexKey}, Value, Partition);
        AggregateBy ->
            AggregateKey = gen_index_key(AggregateBy, Data),
            update_data({AggregateKey, IndexKey}, Value, Partition)
    end;

update_partition({delete, Data}, Partition, Config) ->
    IndexKey = gen_index_key(index_by(Config), Data),

    case aggregate_by(Config) of
        [] ->
            delete_data(IndexKey, Partition);
        Fields ->
            AggregateKey = gen_index_key(Fields, Data),
            delete_data({AggregateKey, IndexKey}, Partition)
    end;

update_partition([H|T], Partition0, Config) ->
    Partition1 = update_partition(H, Partition0, Config),
    update_partition(T, Partition1, Config);

update_partition([], Partition, _) ->
    Partition.



%% -----------------------------------------------------------------------------
%% @doc
%% @end
%% -----------------------------------------------------------------------------
match(Pattern, Partition, Config) ->
    IndexBy = index_by(Config),
    IndexKey = safe_gen_index_key(IndexBy, Pattern),
    AggregateKey = safe_gen_index_key(aggregate_by(Config), Pattern),

    Result = case {AggregateKey, IndexKey} of
        {error, error} ->
            %% At least an aggregate key is required to match
            error(badpattern);
        {_, undefined} ->
            %% This should be imposible, we could not have created an index
            %% with IndexKey = []
            error(badarg);
        {undefined, error} ->
            %% At least an aggregate key is required to match
            error(badpattern);
        {undefined, IndexKey} ->
            Data = babel_index_partition:data(Partition),
            babel_key_value:get({IndexKey, register}, Data, nomatch);
        {AggregateKey, error} ->
            %% The user only provided values for the AggregateBy part
            %% in Pattern, so we return the whole aggregate object
            Data = babel_index_partition:data(Partition),
            babel_key_value:get({AggregateKey, map}, Data, nomatch);
        {AggregateKey, IndexKey} ->
            Data = babel_index_partition:data(Partition),
            babel_key_value:get(
                [{AggregateKey, map}, {IndexKey, register}], Data, nomatch
            )
    end,

    match_output(IndexBy, covered_fields(Config), Result).



%% -----------------------------------------------------------------------------
%% @doc
%% @end
%% -----------------------------------------------------------------------------
-spec iterator(babel_index:t(), babel_index:config(), Opts :: riak_opts()) ->
    Iterator :: iterator().

iterator(Index, Config, Opts) ->
    First = maps:get(first, Opts, undefined),
    Sort = iterator_sort_ordering(Config, Opts),

    #babel_hash_partitioned_index_iter{
        sort_ordering = Sort,
        partition_identifiers = partition_identifiers(Sort, Config),
        first = First,
        typed_bucket = babel_index:typed_bucket(Index),
        riak_opts = Opts
    }.


%% -----------------------------------------------------------------------------
%% @doc
%% @end
%% -----------------------------------------------------------------------------
-spec iterator_move(
     Action :: babel_index:iterator_action(), Iterator :: iterator(), t()) ->
    iterator().

iterator_move(_Action, _Iterator, _Config) ->
    %% TODO
    error(not_implemented).


%% -----------------------------------------------------------------------------
%% @doc
%% @end
%% -----------------------------------------------------------------------------
-spec iterator_done(Iterator :: any()) -> boolean().

iterator_done(#babel_hash_partitioned_index_iter{done = Value}) ->
    Value.


%% -----------------------------------------------------------------------------
%% @doc
%% @end
%% -----------------------------------------------------------------------------
-spec iterator_key(Iterator :: any()) -> Key :: babel_index:index_key().

iterator_key(#babel_hash_partitioned_index_iter{key = Value}) ->
    Value.


%% -----------------------------------------------------------------------------
%% @doc
%% @end
%% -----------------------------------------------------------------------------
-spec iterator_values(Iterator :: any()) -> Key :: babel_index:index_values().

iterator_values(#babel_hash_partitioned_index_iter{values = Values}) ->
    Values.



%% =============================================================================
%% PRIVATE
%% =============================================================================


%% @private
-dialyzer({nowarn_function, validate/1}).

validate(Config0) ->
    Config = maps_utils:validate(Config0, ?SPEC),
    AggregateBy = aggregate_by(Config),
    IndexBy = index_by(Config),

    case lists:sublist(IndexBy, length(AggregateBy)) of
        AggregateBy ->
            Rest = lists:subtract(IndexBy, AggregateBy),
            Config#{index_by => Rest};
        _ ->
            error({validation_error, #{key => <<"aggregate_by">>}})
    end.


%% @private
gen_partition_identifiers(Prefix, N) ->
    [gen_identifier(Prefix, X) || X <- lists:seq(0, N - 1)].


%% @private
gen_identifier(Prefix, N) ->
    <<Prefix/binary, $_, (integer_to_binary(N))/binary>>.


%% @private
gen_index_key(Keys, Data) ->
    binary_utils:join(babel_key_value:collect(Keys, Data)).


%% @private
safe_gen_index_key([], _) ->
    undefined;

safe_gen_index_key(Keys, Data) ->
    try
        binary_utils:join(babel_key_value:collect(Keys, Data))
    catch
        error:{badkey, _} ->
            error
    end.



%% @private
update_data({AggregateKey, IndexKey}, Value, Partition) ->
    babel_index_partition:update_data(
        fun(Data) ->
            riakc_map:update(
                {AggregateKey, map},
                fun(AggregateMap) ->
                    riakc_map:update(
                        {IndexKey, register},
                        fun(R) -> riakc_register:set(Value, R) end,
                        AggregateMap
                    )
                end,
                Data
            )
        end,
        Partition
    );

update_data(IndexKey, Value, Partition) ->
    babel_index_partition:update_data(
        fun(Data) ->
            riakc_map:update(
                {IndexKey, register},
                fun(R) -> riakc_register:set(Value, R) end,
                Data
            )
        end,
        Partition
    ).


%% @private
delete_data({AggregateKey, IndexKey}, Partition) ->
    babel_index_partition:update_data(
        fun(Data) ->
            riakc_map:update(
                {AggregateKey, map},
                fun(AMap) -> riakc_map:erase({IndexKey, map}, AMap) end,
                Data
            )
        end,
        Partition
    );

delete_data(IndexKey, Partition) ->
    babel_index_partition:update_data(
        fun(Data) -> riakc_map:erase({IndexKey, map}, Data) end,
        Partition
    ).


%% @private
maybe_reverse(Order, Order, L) ->
    L;

maybe_reverse(_, _, L) ->
    lists:reverse(L).


%% -----------------------------------------------------------------------------
%% @private
%% @doc We encode the term in JSON for interoperability with clients in other
%% programming languages.
%% @end
%% -----------------------------------------------------------------------------
encode_list(List) ->
    jsone:encode(List).


%% -----------------------------------------------------------------------------
%% @private
%% @doc We encode the term in JSON for interoperability with clients in other
%% programming languages.
%% @end
%% -----------------------------------------------------------------------------
decode_list(Data) ->
    jsone:decode(Data).


%% -----------------------------------------------------------------------------
%% @private
%% @doc We encode the term in JSON for interoperability with clients in other
%% programming languages.
%% @end
%% -----------------------------------------------------------------------------
encode_fields(List) ->
    jsone:encode(List).


%% -----------------------------------------------------------------------------
%% @private
%% @doc We encode the term in JSON for interoperability with clients in other
%% programming languages.
%% @end
%% -----------------------------------------------------------------------------
decode_fields(Data) ->
    [
        case X of
            {Key, Type} ->
                {Key, binary_to_existing_atom(Type,  utf8)};
            Key ->
                Key
        end
        || X <- jsone:decode(Data, [{object_format, proplist}])
    ].


%% @private
iterator_sort_ordering(_, #{sort_ordering := Value}) ->
    Value;

iterator_sort_ordering(#{sort_ordering := Value}, _) ->
    Value.


%% @private
match_output(_, _, nomatch) ->
    [];

match_output(_, CoveredFields, Bin) when is_binary(Bin) ->
    Values = binary:split(Bin, <<$\31>>),
    [maps:from_list(lists:zip(CoveredFields, Values))];

match_output(IndexBy, CoveredFields, AggregateMap) when is_list(AggregateMap) ->
    Fun = fun({Key, register}, Values, Acc) ->
        Map1 = maps:from_list(
            lists:zip(IndexBy, binary:split(Key, <<$\31>>))
        ),
        Map2 = maps:from_list(
            lists:zip(CoveredFields, binary:split(Values, <<$\31>>))
        ),
        [maps:merge(Map1, Map2) | Acc]
    end,
    orddict:fold(Fun, [], AggregateMap).
