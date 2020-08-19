-module(babel_hash_partitioned_index).
-behaviour(babel_index).
-include("babel.hrl").
-include_lib("riakc/include/riakc.hrl").


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
        datatype => {list, tuple}
    },
    index_by => #{
        required => true,
        allow_null => false,
        allow_undefined => false,
        datatype => {list, tuple},
        validator => fun
            ([]) -> false;
            (_) -> true
        end
    },
    aggregate_by => #{
        required => true,
        default => [],
        allow_null => false,
        allow_undefined => false,
        datatype => {list, tuple}
    },
    covered_fields => #{
        required => true,
        allow_null => false,
        allow_undefined => false,
        datatype => {list, tuple}
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

-type action()      ::  {babel_index:action(), babel_index:data()}.
-type fields()      ::  [babel_key_value:key() | [babel_key_value:key()]].

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
-export([from_crdt/1]).
-export([init/2]).
-export([init_partitions/1]).
-export([number_of_partitions/1]).
-export([partition_identifier/2]).
-export([partition_identifiers/2]).
-export([partition_size/2]).
-export([to_crdt/1]).
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
    Config0 = maps_utils:validate(ConfigData0, ?SPEC),
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
-spec from_crdt(Object :: babel_index:config_crdt()) ->
    Config :: t().

from_crdt(Object) ->
    Sort = babel_crdt:register_to_existing_atom(
        riakc_map:fetch({<<"sort_ordering">>, register}, Object),
        utf8
    ),
    N = babel_crdt:register_to_integer(
        riakc_map:fetch({<<"number_of_partitions">>, register}, Object)
    ),

    Algo = babel_crdt:register_to_existing_atom(
        riakc_map:fetch({<<"partition_algorithm">>, register}, Object),
        utf8
    ),

    Prefix = babel_crdt:register_to_binary(
        riakc_map:fetch({<<"partition_identifier_prefix">>, register}, Object)
    ),

    PartitionBy = decode_proplist(
        babel_crdt:register_to_binary(
            riakc_map:fetch({<<"partition_by">>, register}, Object)
        )
    ),

    Identifiers = decode_list(
        babel_crdt:register_to_binary(
            riakc_map:fetch({<<"partition_identifiers">>, register}, Object)
        )
    ),

    IndexBy = decode_proplist(
        babel_crdt:register_to_binary(
            riakc_map:fetch({<<"index_by">>, register}, Object)
        )
    ),

    AggregateBy = decode_proplist(
        babel_crdt:register_to_binary(
            riakc_map:fetch({<<"aggregate_by">>, register}, Object)
        )
    ),

    CoveredFields = decode_proplist(
        babel_crdt:register_to_binary(
            riakc_map:fetch({<<"covered_fields">>, register}, Object)
        )
    ),

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
-spec to_crdt(Config :: t()) ->
    ConfigCRDT :: babel_index:config_crdt().

to_crdt(Config) ->
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
        {{<<"partition_by">>, register}, encode_proplist(PartitionBy)},
        {{<<"index_by">>, register}, encode_proplist(IndexBy)},
        {{<<"aggregate_by">>, register}, encode_proplist(AggregateBy)},
        {{<<"covered_fields">>, register}, encode_proplist(CoveredFields)}
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
-spec init_partitions(t()) -> [babel_index_partition:t()].

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
-spec partition_identifier(babel_index:data(), t()) ->
    babel_index:partition_id().

partition_identifier(Data, Config) ->
    N = number_of_partitions(Config),
    Algo = partition_algorithm(Config),

    PKey = gen_index_key(partition_by(Config), Data),

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
-spec partition_size(Partition :: babel_index_partition:t(), Config :: t()) ->
    non_neg_integer().

partition_size(_, Partition) ->
    Data = riakc_map:fetch({<<"data">>, map}, Partition),
    riakc_map:size(Data).


%% -----------------------------------------------------------------------------
%% @doc
%% @end
%% -----------------------------------------------------------------------------
-spec update_partition(
    ActionData :: action() | [action()],
    Partition :: babel_index_partition:t(),
    Config :: t()
    ) -> babel_index_partition:t() | no_return().

update_partition({insert, Data}, Partition, Config) ->
    IndexKey = gen_index_key(index_by(Config), Data),
    Value = gen_index_key(covered_fields(Config), Data),

    case aggregate_by(Config) of
        [] ->
            insert_data(IndexKey, Value, Partition);
        Fields ->
            AggregateKey = gen_index_key(Fields, Data),
            insert_data({AggregateKey, IndexKey}, Value, Partition)
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

update_partition(_, Partition, []) ->
    Partition.



%% =============================================================================
%% PRIVATE
%% =============================================================================



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
insert_data({AggregateKey, IndexKey}, Value, Partition) ->
    babel_index_partition:update_data(
        fun(Data) ->
            riakc_map:update(
                {AggregateKey, map},
                fun(AMap) ->
                    riakc_map:update(
                        {IndexKey, register},
                        fun(R) -> riakc_register:set(Value, R) end,
                        AMap
                    )
                end,
                Data
            )
        end,
        Partition
    );

insert_data(IndexKey, Value, Partition) ->
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


%% @private
encode_list(List) ->
    jsx:encode(List).


%% @private
decode_list(Data) ->
    jsx:decode(Data).


%% @private
encode_proplist(List) ->
    jsx:encode(List).


%% @private
decode_proplist(Data) ->
    [
        {Key, binary_to_existing_atom(Type,  utf8)}
        || {Key, Type} <- jsx:decode(Data)
    ].