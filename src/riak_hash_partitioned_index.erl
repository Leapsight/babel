-module(riak_hash_partitioned_index).
-behaviour(riak_index).

-define(SPEC, #{
    sort_ordering => #{
        required => false,
        allow_null => false,
        allow_undefined => false,
        default => <<"asc">>,
        datatype => [atom, binary],
        validator => fun
            (X) when is_atom(X) -> atom_to_binary(X, utf8);
            (X) when is_binary(X) -> true;
            (_) -> false
        end
    },
    number_of_partitions => #{
        description => <<
            "The number of partitions for this index. "
            "It should be a power of 2."
        >>,
        required => true,
        allow_null => false,
        allow_undefined => false,
        datatype => pos_integer,
        validator => fun
            (N) when N =< 0 ->
                false;
            (N) ->
                %% It should be a power of 2
                N band (N - 1) == 0
        end
    },
    partition_algorithm => #{
        required => true,
        default => fnv32a,
        datatype => {in, [
            random, hash, fnv32, fnv32a, fnv32m,
            fnv64, fnv64a, fnv128, fnv128a
        ]}
    },
    partition_by => #{
        required => true,
        allow_null => false,
        allow_undefined => false,
        datatype => {list, binary}
    },
    index_by => #{
        required => true,
        allow_null => false,
        allow_undefined => false,
        datatype => {list, binary},
        validator => fun
            ([]) -> false;
            (_) -> true
        end
    },
    aggregate_by => #{
        required => false,
        allow_null => false,
        allow_undefined => false,
        datatype => {list, binary}
    },
    covered_fields => #{
        required => true,
        allow_null => false,
        allow_undefined => false,
        datatype => {list, binary}
    }
}).


-type action()      ::  {riak_kv_index:action(), riak_kv_index:data()}.

%% BEHAVIOUR CALLBACKS
-export([init/2]).
-export([number_of_partitions/1]).
-export([partition_identifier/2]).
-export([partition_identifiers/2]).
-export([update_partition/3]).

%% API
-export([aggregate_by/1]).
-export([covered_fields/1]).
-export([index_by/1]).
-export([partition_algorithm/1]).
-export([partition_by/1]).
-export([partition_identifier_prefix/1]).
-export([sort_ordering/1]).



%% =============================================================================
%% BEHAVIOUR CALLBACKS
%% =============================================================================



%% -----------------------------------------------------------------------------
%% @doc
%% @end
%% -----------------------------------------------------------------------------
-spec init(Index :: riak_index:t(), Spec :: map()) ->
    {ok, riak_index:config(), [riak_index:partition()]}
    | {error, any()}.

init(Index, Spec0) ->
    #{
        sort_ordering := Sort,
        number_of_partitions := N,
        partition_algorithm := Algo,
        partition_by := PKeyFields,
        index_by := LKeyFields,
        covered_fields := PayloadFields
    } = maps_utils:validate(Spec0, ?SPEC),
    IndexId = riak_index:id(Index),
    Prefix = <<IndexId/binary, "_partition_">>,
    {Identifiers, Partitions} = init_partitions(Prefix, N),

    Values = [
        wrap(register, <<"sort_ordering">>, Sort),
        wrap(register, <<"number_of_partitions">>, integer_to_binary(N)),
        wrap(register, <<"partition_algorithm">>, atom_to_binary(Algo, utf8)),
        wrap(register, <<"partition_identifier_prefix">>, Prefix),
        wrap(set, <<"partition_by">>, PKeyFields),
        wrap(set, <<"index_by">>, LKeyFields),
        wrap(set, <<"covered_fields">>, PayloadFields),
        wrap(set, <<"partition_identifiers">>, Identifiers)
    ],
    {ok, riakc_map:new(Values, undefined), Partitions}.


%% -----------------------------------------------------------------------------
%% @doc
%% @end
%% -----------------------------------------------------------------------------
-spec number_of_partitions(riak_kv_index:config()) -> pos_integer().

number_of_partitions(Config) ->
    binary_to_integer(
        riakc_map:fetch({<<"number_of_partitions">>, register}, Config)
    ).


%% -----------------------------------------------------------------------------
%% @doc
%% @end
%% -----------------------------------------------------------------------------
-spec partition_identifier(riak_kv_index:config(), riak_kv_index:data()) ->
    riak_kv_index:partition_id().

partition_identifier(Config, Data) ->
    N = number_of_partitions(Config),
    Algo = partition_algorithm(Config),
    Prefix = partition_identifier_prefix(Config),

    PKey = collect(Config, Data, partition_by(Config)),
    Hash = hash:Algo(PKey),
    gen_identifier(Prefix, Hash rem N).



%% -----------------------------------------------------------------------------
%% @doc
%% @end
%% -----------------------------------------------------------------------------
-spec partition_identifiers(riak_kv_index:config(), asc | desc) ->
    [riak_index:partition_id()].

partition_identifiers(Config, Order) ->
    Default = sort_ordering(Config),
    maybe_reverse(Default, Order, partition_identifiers(Config)).


%% -----------------------------------------------------------------------------
%% @doc
%% @end
%% -----------------------------------------------------------------------------
-spec update_partition(
    Config :: riak_kv_index:config(),
    Partition :: riak_kv_index:partition(),
    ActionData :: action() | [action()]
    ) -> riak_kv_index:partition() | no_return().

update_partition(Config, Partition, {insert, Data}) ->
    IndexKey = collect(Config, Data, index_by(Config)),
    Value = collect(Config, Data, covered_fields(Config)),

    case aggregate_by(Config) of
        [] ->
            insert_data(Partition, IndexKey, Value);
        Fields ->
            AggregateKey = collect(Config, Data, Fields),
            insert_data(Partition, {AggregateKey, IndexKey}, Value)
    end;

update_partition(Config, Partition, {delete, Data}) ->
    IndexKey = collect(Config, Data, index_by(Config)),

    case aggregate_by(Config) of
        [] ->
            delete_data(Partition, IndexKey);
        Fields ->
            AggregateKey = collect(Config, Data, Fields),
            delete_data(Partition, {AggregateKey, IndexKey})
    end;

update_partition(Config, Partition0, [H|T]) ->
    Partition1 = update_partition(Config, Partition0, H),
    update_partition(Config, Partition1, T);

update_partition(_, Partition, []) ->
    Partition.



%% =============================================================================
%% API
%% =============================================================================



%% -----------------------------------------------------------------------------
%% @doc
%% @end
%% -----------------------------------------------------------------------------
-spec sort_ordering(riak_index:config()) -> asc | desc.

sort_ordering(Config) ->
    binary_to_existing_atom(
        riakc_map:fetch({<<"sort_ordering">>, set}, Config),
        utf8
    ).


%% -----------------------------------------------------------------------------
%% @doc
%% @end
%% -----------------------------------------------------------------------------
-spec partition_algorithm(riak_index:config()) -> atom().

partition_algorithm(Config) ->
    binary_to_atom(
        riakc_map:fetch({<<"algorithm">>, register}, Config), utf8
    ).


%% -----------------------------------------------------------------------------
%% @doc
%% @end
%% -----------------------------------------------------------------------------
-spec partition_identifiers(riak_index:config()) -> [binary()].

partition_identifiers(Config) ->
    ordsets:to_list(
        riakc_set:value(
            riakc_map:fetch({<<"partition_identifiers">>, set}, Config)
        )
    ).


%% -----------------------------------------------------------------------------
%% @doc
%% @end
%% -----------------------------------------------------------------------------
-spec partition_identifier_prefix(riak_index:config()) -> binary().

partition_identifier_prefix(Config) ->
    riakc_map:fetch({<<"partition_identifier_prefix">>, register}, Config).


%% -----------------------------------------------------------------------------
%% @doc
%% @end
%% -----------------------------------------------------------------------------
-spec partition_by(riak_index:config()) -> [binary()].

partition_by(Config) ->
    riakc_set:values(
        riakc_map:fetch({<<"partition_by">>, set}, Config)
    ).


%% -----------------------------------------------------------------------------
%% @doc
%% @end
%% -----------------------------------------------------------------------------
-spec index_by(riak_index:config()) -> [binary()].

index_by(Config) ->
    riakc_set:values(riakc_map:fetch({<<"index_by">>, set}, Config)).


%% -----------------------------------------------------------------------------
%% @doc
%% @end
%% -----------------------------------------------------------------------------
-spec aggregate_by(riak_index:config()) -> [binary()].

aggregate_by(Config) ->
    case riakc_map:find({<<"aggregate_by">>, set}, Config) of
        {ok, Set} -> riakc_set:values(Set);
        error -> []
    end.


%% -----------------------------------------------------------------------------
%% @doc
%% @end
%% -----------------------------------------------------------------------------
-spec covered_fields(riak_index:config()) -> [binary()].

covered_fields(Config) ->
    riakc_set:values(riakc_map:fetch({<<"covered_fields">>, set}, Config)).



%% =============================================================================
%% PRIVATE
%% =============================================================================



%% @private
init_partitions(Prefix, N) ->
    Identifiers = [gen_identifier(Prefix, X) || X <- lists:seq(0, N - 1)],
    Partitions = [{Id, riak_index_partition:new()}  || Id <- Identifiers],
    {Identifiers, Partitions}.


%% @private
gen_identifier(Prefix, N) ->
    <<Prefix/binary, (integer_to_binary(N))>>.


%% @private
wrap(register, Field, Value) ->
    {{Field, register}, riakc_register:new(Value, undefined)};

wrap(counter, Field, Value) ->
    {{Field, counter}, riakc_counter:new(Value, undefined)};

wrap(set, Field, Values) ->
    {{Field, set}, riakc_set:new(Values, undefined)};

wrap(map, Field, Values) ->
    {{Field, map}, riakc_map:new(Values, undefined)}.


%% @private
collect(_, Data, [Field]) ->
    get_value(Data, Field);

collect(Config, Data, Fields) ->
    collect(Config, Data, Fields, []).


%% @private
collect(Config, Data, [H|T], Acc) ->
    Value = get_value(Data, H),
    collect(Config, Data, T, [Value|Acc]);

collect(_, _, [], Acc) ->
    string:join(lists:reverse(Acc), $\31).


%% -----------------------------------------------------------------------------
%% @private
%% @doc Gets the value for the field from a struct (riakc_map, map or property
%% list)
%% @end
%% -----------------------------------------------------------------------------
get_value(Field, Object) when is_map(Object) ->
    maybe_get_error(Field, maps:find(Field, Object));

get_value(Field, Object) when is_list(Object) ->
    maybe_get_error(Field, lists:keyfind(Field, 1, Object));

get_value(Field, Object) ->
    case riakc_map:is_type(Object) of
        true ->
            maybe_get_error(Field, riakc_map:find({Field, register}, Object));
        false ->
            error({badobject, Object})
    end.


%% @private
maybe_get_error(_, {ok, Value}) when is_binary(Value) ->
    Value;

maybe_get_error(Field, {Field, Value}) when is_binary(Value) ->
    Value;

maybe_get_error(Field, {_, Value}) ->
    error({badvalue, {Field, Value}});

maybe_get_error(Field, error) ->
    error({badfield, Field}).


%% @private
insert_data(Partition, {AggregateKey, IndexKey}, Value) ->
    riakc_map:update(
        {<<"data">>, map},
        fun(Data) ->
            riakc_map:update(
                {AggregateKey, map},
                fun(AMap) ->
                    riakc_map:update(
                        {IndexKey, map},
                        fun(R) -> riakc_register:set(Value, R) end,
                        AMap
                    )
                end,
                Data
            )
        end,
        Partition
    );

insert_data(Partition, IndexKey, Value) ->
    riakc_map:update(
        {<<"data">>, map},
        fun(Data) ->
            riakc_map:update(
                {IndexKey, map},
                fun(R) -> riakc_register:set(Value, R) end,
                Data
            )
        end,
        Partition
    ).


%% @private
delete_data(Partition, {AggregateKey, IndexKey}) ->
    riakc_map:update(
        {<<"data">>, map},
        fun(Data) ->
            riakc_map:update(
                {AggregateKey, map},
                fun(AMap) -> riakc_map:erase({IndexKey, map}, AMap) end,
                Data
            )
        end,
        Partition
    );

delete_data(Partition, IndexKey) ->
    riakc_map:update(
        {<<"data">>, map},
        fun(Data) -> riakc_map:erase({IndexKey, map}, Data) end,
        Partition
    ).


%% @private
maybe_reverse(Order, Order, L) ->
    L;
maybe_reverse(_, _, L) ->
    lists:reverse(L).


%% %% @private
%% increment_size(Partition, N) ->
%%     riakc_map:update(
%%         {<<"meta">>, map},
%%         fun(M) ->
%%             riakc_map:update(
%%                 {<<"size">>, counter},
%%                 fun(C) -> riakc_counter:increment(N, C) end,
%%                 M
%%             )
%%         end,
%%         Partition
%%     ).


%% %% @private
%% decrement_size(Partition, N) ->
%%     riakc_map:update(
%%         {<<"meta">>, map},
%%         fun(M) ->
%%             riakc_map:update(
%%                 {<<"size">>, counter},
%%                 fun(C) -> riakc_counter:decrement(N, C) end,
%%                 M
%%             )
%%         end,
%%         Partition
%%     ).

