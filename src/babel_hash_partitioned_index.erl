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
%% This object is immutable.
%%
%% @end
%% -----------------------------------------------------------------------------
-module(babel_hash_partitioned_index).
-behaviour(babel_index).
-include("babel.hrl").

%% TODO Leaf nodes in the index should be either SET or REGISTER depending on the new option 'cardinality' :: one | many.

-define(KEYPATH_LIST_SPEC, {list, [binary, tuple, {list, [binary, tuple]}]}).

-define(SPEC, #{
    case_sensitive => #{
        required => true,
        allow_null => false,
        allow_undefined => false,
        default => false,
        datatype => boolean
    },
    sort_ordering => #{
        required => true,
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
        datatype => ?KEYPATH_LIST_SPEC
    },
    index_by => #{
        required => true,
        allow_null => false,
        allow_undefined => false,
        datatype => ?KEYPATH_LIST_SPEC,
        validator => fun
            ([]) -> false;
            (_) -> true
        end
    },
    aggregate_by => #{
        required => true,
        description => <<"A list of keys that will be use to compute the aggregate. It has to be a prefix of the index_by list.">>,
        default => [],
        allow_null => false,
        allow_undefined => false,
        datatype => ?KEYPATH_LIST_SPEC
    },
    covered_fields => #{
        required => true,
        allow_null => false,
        allow_undefined => false,
        datatype => ?KEYPATH_LIST_SPEC
    },
    cardinality => #{
        required => true,
        allow_null => false,
        allow_undefined => false,
        datatype => {in, [one, many]},
        default => one
    }
}).

-type t()           ::  #{
    case_sensitive := boolean(),
    sort_ordering := asc | desc,
    number_of_partitions := integer(),
    partition_algorithm := atom(),
    partition_identifier_prefix := binary(),
    partition_identifiers := [binary()],
    partition_by := fields(),
    index_by := fields(),
    aggregate_by := fields(),
    covered_fields := fields(),
    cardinality := one | many
}.

-record(babel_hash_partitioned_index_iter, {
    partition                   ::  babel_index_partition:t() | undefined,
    case_sensitive              ::  boolean(),
    sort_ordering               ::  asc | desc,
    key                         ::  binary() | undefined,
    values                      ::  map() | undefined,
    typed_bucket                ::  {binary(), binary()},
    first                       ::  binary() | undefined,
    keys = []                   ::  [binary()],
    partition_identifiers = []  ::  [babel_index:partition_id()],
    opts                        ::  babel:opts(),
    done = false                ::  boolean()
}).

-type fields()      ::  [babel_key_value:key()].
-type iterator()    ::  #babel_hash_partitioned_index_iter{}.

-export_type([fields/0]).


%% API
-export([aggregate_by/1]).
-export([covered_fields/1]).
-export([index_by/1]).
-export([partition_algorithm/1]).
-export([partition_by/1]).
-export([partition_identifier_prefix/1]).
-export([sort_ordering/1]).
-export([case_sensitive/1]).


%% BEHAVIOUR CALLBACKS
-export([from_riak_dict/1]).
-export([init/2]).
-export([init_partitions/1]).
-export([init_partition/2]).
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
-export([distinguished_key_paths/1]).


%% =============================================================================
%% API
%% =============================================================================



%% -----------------------------------------------------------------------------
%% @doc Returns true if the index is case sensitivity.
%% @end
%% -----------------------------------------------------------------------------
-spec case_sensitive(t()) -> boolean().

case_sensitive(#{case_sensitive := Value}) -> Value.


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
-spec cardinality(t()) -> one | many.

cardinality(#{cardinality := Value}) -> Value.


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

    Cardinality = case orddict:find({<<"cardinality">>, register}, Dict) of
        {ok, Bin} -> binary_to_existing_atom(Bin, utf8);
        error -> one
    end,

    CaseSensitive = case orddict:find({<<"case_sensitive">>, flag}, Dict) of
        {ok, Value} -> Value;
        error -> false
    end,

    %% As this object is read-only and embeded in an Index Collection we turn it
    %% into an Erlang map as soon as we read it from the collection for enhanced
    %% performance. So loosing its CRDT context it not an issue.
    #{
        case_sensitive => CaseSensitive,
        sort_ordering => Sort,
        number_of_partitions => N,
        partition_algorithm => Algo,
        partition_by => PartitionBy,
        partition_identifier_prefix => Prefix,
        partition_identifiers => Identifiers,
        index_by => IndexBy,
        aggregate_by => AggregateBy,
        covered_fields => CoveredFields,
        cardinality => Cardinality
    }.


%% -----------------------------------------------------------------------------
%% @doc
%% @end
%% -----------------------------------------------------------------------------
-spec to_riak_object(Config :: t()) ->
    ConfigCRDT :: babel_index:riak_object().

to_riak_object(Config) ->
    #{
        case_sensitive := CaseSensitive,
        sort_ordering := Sort,
        number_of_partitions := N,
        partition_algorithm := Algo,
        partition_by := PartitionBy,
        partition_identifier_prefix := Prefix,
        partition_identifiers := Identifiers,
        index_by := IndexBy,
        aggregate_by := AggregateBy,
        covered_fields := CoveredFields,
        cardinality := Cardinality
    } = Config,


    Values = [
        {{<<"case_sensitive">>, flag}, CaseSensitive},
        {{<<"sort_ordering">>, register}, atom_to_binary(Sort, utf8)},
        {{<<"number_of_partitions">>, register}, integer_to_binary(N)},
        {{<<"partition_algorithm">>, register}, atom_to_binary(Algo, utf8)},
        {{<<"partition_identifier_prefix">>, register}, Prefix},
        {{<<"partition_identifiers">>, register}, encode_list(Identifiers)},
        {{<<"partition_by">>, register}, encode_fields(PartitionBy)},
        {{<<"index_by">>, register}, encode_fields(IndexBy)},
        {{<<"aggregate_by">>, register}, encode_fields(AggregateBy)},
        {{<<"covered_fields">>, register}, encode_fields(CoveredFields)},
        {{<<"cardinality">>, register}, atom_to_binary(Cardinality, utf8)}
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
    {ok, [babel_index_partition:t()]} | {error, any()}.

init_partitions(#{partition_identifiers := Identifiers}) ->
    Partitions = [babel_index_partition:new(Id) || Id <- Identifiers],
    {ok, Partitions}.


%% -----------------------------------------------------------------------------
%% @doc
%% @end
%% -----------------------------------------------------------------------------
-spec init_partition(PartitionId :: binary(), ConfigData :: t()) ->
    {ok, babel_index_partition:t()}
    | {error, any()}.

init_partition(PartitionId, _) ->
    Partition = babel_index_partition:new(PartitionId),
    {ok, Partition}.


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
    babel_index:partition_id() | no_return().

partition_identifier(KeyValue, Config) ->
    N = number_of_partitions(Config),
    Algo = partition_algorithm(Config),
    Keys = partition_by(Config),

    %% We collect the partition keys from the key value object and build a
    %% binary key that we then use to hash to the partition.
    try babel_index_utils:gen_key(Keys, KeyValue, Config) of
        PKey ->
            Bucket = babel_consistent_hashing:bucket(PKey, N, Algo),
            %% Bucket is zero-based
            lists:nth(Bucket + 1, partition_identifiers(Config))
    catch
        error:{badkey, Key} ->
            error({missing_pattern_key, Key})
    end.



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
-spec distinguished_key_paths(Config :: t()) -> [babel_key_value:key()].

distinguished_key_paths(Config) ->
    ordsets:to_list(
        ordsets:union([
            ordsets:from_list(partition_by(Config)),
            ordsets:from_list(aggregate_by(Config)),
            ordsets:from_list(index_by(Config)),
            ordsets:from_list(covered_fields(Config))
        ])
    ).


%% -----------------------------------------------------------------------------
%% @doc
%% @end
%% -----------------------------------------------------------------------------
-spec update_partition(
    ActionData :: babel_index:update_action() | [babel_index:update_action()],
    Partition :: babel_index_partition:t(),
    Config :: t()) -> babel_index_partition:t() | no_return().

update_partition([H|T], Partition0, Config) ->
    Partition1 = update_partition(H, Partition0, Config),
    update_partition(T, Partition1, Config);

update_partition([], Partition, _) ->
    Partition;

update_partition({delete, Data}, Partition, Config) ->
    Cardinality = cardinality(Config),
    IndexKey = babel_index_utils:gen_key(index_by(Config), Data, Config),
    Value = babel_index_utils:gen_key(covered_fields(Config), Data, Config),

    case aggregate_by(Config) of
        [] ->
            delete_data(IndexKey, Value, Cardinality, Partition);
        Fields ->
            AggregateKey = babel_index_utils:gen_key(Fields, Data, Config),
            delete_data({AggregateKey, IndexKey}, Value, Cardinality, Partition)
    end;

update_partition({insert, Data}, Partition, Config) ->
    Cardinality = cardinality(Config),
    AggregateBy = aggregate_by(Config),
    IndexBy = index_by(Config),

    IndexKey = babel_index_utils:gen_key(IndexBy, Data, Config),
    Value = babel_index_utils:gen_key(covered_fields(Config), Data, Config),

    case AggregateBy of
        [] ->
            update_data(IndexKey, Value, Cardinality, Partition);
        IndexBy ->
            update_data({IndexKey, IndexKey}, Value, Cardinality, Partition);
        AggregateBy ->
            AggregateKey = babel_index_utils:gen_key(AggregateBy, Data, Config),
            update_data({AggregateKey, IndexKey}, Value, Cardinality, Partition)
    end.


%% -----------------------------------------------------------------------------
%% @doc
%% @end
%% -----------------------------------------------------------------------------
match(Pattern, Partition, Config) ->
    Cardinality = cardinality(Config),
    IndexBy = index_by(Config),
    IndexKey = babel_index_utils:safe_gen_key(IndexBy, Pattern, Config),
    AggregateBy = aggregate_by(Config),
    AggregateKey = babel_index_utils:safe_gen_key(AggregateBy, Pattern, Config),

    Result = case {AggregateKey, IndexKey} of
        {error, error} ->
            %% At least an aggregate key is required to match
            error(badpattern);

        {_, undefined} ->
            %% This should be imposible, we could not have created an index
            %% with IndexKey = []
            error(invalid_metadata);

        {undefined, error} ->
            %% At least an aggregate key is required to match
            error(badpattern);

        {undefined, IndexKey} when Cardinality =:= one ->
            Data = babel_index_partition:data(Partition),
            babel_key_value:get({IndexKey, register}, Data, nomatch);

        {undefined, IndexKey} when Cardinality =:= many ->
            Data = babel_index_partition:data(Partition),
            babel_key_value:get({IndexKey, set}, Data, nomatch);

        {AggregateKey, error} ->
            %% The user only provided values for the AggregateBy part
            %% in Pattern, so we return the whole aggregate object
            Data = babel_index_partition:data(Partition),
            babel_key_value:get({AggregateKey, map}, Data, nomatch);

        {AggregateKey, IndexKey} when Cardinality =:= one ->
            Data = babel_index_partition:data(Partition),
            babel_key_value:get(
                [{AggregateKey, map}, {IndexKey, register}], Data, nomatch
            );

        {AggregateKey, IndexKey} when Cardinality =:= many ->
            Data = babel_index_partition:data(Partition),
            babel_key_value:get(
                [{AggregateKey, map}, {IndexKey, set}], Data, nomatch
            )
    end,
    Covered = covered_fields(Config),
    Acc = babel_index_utils:build_output(AggregateBy, AggregateKey),
    IsAggregate = AggregateKey /= undefined,
    match_output(IsAggregate, IndexBy, Covered, Cardinality, Result, Acc).


%% -----------------------------------------------------------------------------
%% @doc
%% @end
%% -----------------------------------------------------------------------------
-spec iterator(
    babel_index:t(), babel_index:config(), Opts :: babel:opts()) ->
    Iterator :: iterator().

iterator(Index, Config, Opts) ->
    First = maps:get(first, Opts, undefined),
    Sort = iterator_sort_ordering(Config, Opts),

    #babel_hash_partitioned_index_iter{
        sort_ordering = Sort,
        partition_identifiers = partition_identifiers(Sort, Config),
        first = First,
        typed_bucket = babel_index:typed_bucket(Index),
        opts = Opts
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
            case lists:subtract(IndexBy, AggregateBy) of
                [] ->
                    error({validation_error, #{key => <<"index_by">>}});
                Rest ->
                    Config#{index_by => Rest}
            end;
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
update_data({AggregateKey, IndexKey}, Value, one, Partition) ->
    %% {data, map} ->
    %%      {AggregateKey, map} ->
    %%          {IndexKey, register} ->
    %%              Value
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

update_data({AggregateKey, IndexKey}, Value, many, Partition) ->
    %% {data, map} ->
    %%      {AggregateKey, map} ->
    %%          {IndexKey, set} ->
    %%              Values
    babel_index_partition:update_data(
        fun(Data) ->
            riakc_map:update(
                {AggregateKey, map},
                fun(AggregateMap) ->
                    riakc_map:update(
                        {IndexKey, set},
                        fun(Set) -> riakc_set:add_element(Value, Set) end,
                        AggregateMap
                    )
                end,
                Data
            )
        end,
        Partition
    );

update_data(IndexKey, Value, one, Partition) ->
    %% {data, map} ->
    %%      {IndexKey, register} ->
    %%          Value
    babel_index_partition:update_data(
        fun(Data) ->
            riakc_map:update(
                {IndexKey, register},
                fun(R) -> riakc_register:set(Value, R) end,
                Data
            )
        end,
        Partition
    );

update_data(IndexKey, Value, many, Partition) ->
    %% {data, map} ->
    %%      {IndexKey, set} ->
    %%          Values
    babel_index_partition:update_data(
        fun(Data) ->
            riakc_map:update(
                {IndexKey, set},
                fun(Set) -> riakc_set:add_element(Value, Set) end,
                Data
            )
        end,
        Partition
    ).


%% @private
delete_data({AggregateKey, IndexKey}, _, one, Partition) ->
    %% {data, map} ->
    %%      {AggregateKey, map} ->
    %%          {IndexKey, register} ->
    %%              Value
    babel_index_partition:update_data(
        fun(Data) ->
            riakc_map:update(
                {AggregateKey, map},
                fun(AMap) -> riakc_map:erase({IndexKey, register}, AMap) end,
                Data
            )
        end,
        Partition
    );

delete_data({AggregateKey, IndexKey}, Value, many, Partition) ->
    %% {data, map} ->
    %%      {AggregateKey, map} ->
    %%          {IndexKey, set} ->
    %%              Values
    AKey = {AggregateKey, map},
    IKey = {IndexKey, set},
    babel_index_partition:update_data(
        fun(Data) ->
            try
                riakc_map:update(
                    AKey,
                    fun(Map) ->
                        try
                            riakc_map:update(
                                IKey,
                                fun(Set) ->
                                    ok = erase_check(Value, Set, IKey, Map),
                                    riakc_set:del_element(Value, Set)
                                end,
                                Map
                            )
                        catch
                            throw:erase_index_key ->
                                %% We need to remove the whole key as we would
                                %% otherwise leave the key with an empty set
                                %% This is safe to do even in the case of
                                %% concurrent updates as we are using an ORSWOT
                                %% in which adds win
                                riakc_map:erase(IKey, Map)
                        end
                    end,
                    Data
                )
            catch
                throw:erase_aggregate_key ->
                    %% We need to remove the whole aggregate map as it would
                    %% otherwise leave an agreggate key with an empty set value
                    riakc_map:erase(AKey, Data)
            end
        end,
        Partition
    );

delete_data(IndexKey, _, one, Partition) ->
    %% {data, map} ->
    %%      {IndexKey, register} ->
    %%          Value
    IKey = {IndexKey, register},
    babel_index_partition:update_data(
        fun(Map) -> riakc_map:erase(IKey, Map) end,
        Partition
    );

delete_data(IndexKey, Value, many, Partition) ->
    %% {data, map} ->
    %%      {IndexKey, set} ->
    %%          Values
    IKey = {IndexKey, set},
    babel_index_partition:update_data(
        fun(Map) ->
            try
                riakc_map:update(
                    IKey,
                    fun(Set) ->
                        ok = erase_check(Value, Set),
                        riakc_set:del_element(Value, Set)
                    end,
                    Map
                )
            catch
                throw:erase_index_key ->
                    %% We need to remove the whole key as we would
                    %% otherwise leave the key with an empty set
                    %% This is safe to do even in the case of
                    %% concurrent updates as we are using an ORSWOT
                    %% in which adds win
                    riakc_map:erase(IKey, Map)
            end
        end,
        Partition
    ).


%% @private
maybe_reverse(Order, Order, L) ->
    L;

maybe_reverse(_, _, L) ->
    lists:reverse(L).


%% @private
erase_check(Value, Set, {_, set} = Key, Map) ->
    try
        erase_check(Value, Set)
    catch
        throw:erase_index_key ->

            case riakc_map:is_key(Key, Map) andalso riakc_map:size(Map) == 1 of
                true ->
                    %% A del_element would result in an empty set and since
                    %% this is the only key in the map we would be wasting
                    %% space, so we remove the AggregateKey from the Data map
                    %% instead
                    throw(erase_aggregate_key);
                false ->
                    throw(erase_index_key)
            end
    end.


%% @private
erase_check(Value, Set) ->
    case riakc_set:is_element(Value, Set) andalso riakc_set:size(Set) == 1 of
        true ->
            %% A del_element would result in an empty set which wastes
            %% space, so we remove the set from the Aggregate map
            %% instead
            throw(erase_index_key);
        false ->
            ok
    end.


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
match_output(_, _, _, _, nomatch, _) ->
    [];

match_output(false, _, CoveredFields, one, Bin, Map0) when is_binary(Bin) ->
    [babel_index_utils:build_output(CoveredFields, Bin, Map0)];

match_output(false, _IndexBy, CoveredFields, many, Result, Map0)
when is_list(Result) ->
    Fun = fun
        (Bin, Acc)  ->
            Map = babel_index_utils:build_output(CoveredFields, Bin, Map0),
            [Map| Acc]
    end,
    lists:foldl(Fun, [], Result);

match_output(true, IndexBy, CoveredFields, Cardinality, Result, Map0)
when is_list(Result) ->
    Fun = fun
        ({Key, register}, Bin, Acc) when Cardinality == one ->
            Map1 = babel_index_utils:build_output(IndexBy, Key, Map0),
            Map2 = babel_index_utils:build_output(CoveredFields, Bin, Map1),
            [Map2 | Acc];

        ({Key, set}, Set, Acc) when Cardinality == many ->
            Map1 = babel_index_utils:build_output(IndexBy, Key, Map0),
            ordsets:fold(
                fun(Bin, IAcc) ->
                    Map2 = babel_index_utils:build_output(CoveredFields, Bin, Map1),
                    [Map2 | IAcc]
                end,
                Acc,
                Set
            )
    end,
    orddict:fold(Fun, [], Result).

