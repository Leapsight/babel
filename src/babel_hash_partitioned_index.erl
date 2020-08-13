-module(babel_hash_partitioned_index).
-behaviour(babel_index).


-define(SPEC, #{
    sort_ordering => #{
        required => false,
        allow_null => false,
        allow_undefined => false,
        default => <<"asc">>,
        datatype => [atom, binary],
        validator => fun
            (X) when is_atom(X) -> {ok, atom_to_binary(X, utf8)};
            (X) when is_binary(X) -> true;
            (_) -> false
        end
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
        datatype => {list, [binary, tuple, list]}
    },
    index_by => #{
        required => true,
        allow_null => false,
        allow_undefined => false,
        datatype => {list, [binary, tuple, list]},
        validator => fun
            ([]) -> false;
            (_) -> true
        end
    },
    aggregate_by => #{
        required => false,
        allow_null => false,
        allow_undefined => false,
        datatype => {list, [binary, tuple, list]}
    },
    covered_fields => #{
        required => true,
        allow_null => false,
        allow_undefined => false,
        datatype => {list, [binary, tuple, list]}
    }
}).


-type action()      ::  {riak_kv_index:action(), riak_kv_index:data()}.

-export_type([action/0]).


%% API
-export([aggregate_by/1]).
-export([covered_fields/1]).
-export([index_by/1]).
-export([partition_algorithm/1]).
-export([partition_by/1]).
-export([partition_identifier_prefix/1]).
-export([sort_ordering/1]).


%% BEHAVIOUR CALLBACKS
-export([init/2]).
-export([init_partitions/1]).
-export([number_of_partitions/1]).
-export([partition_size/2]).
-export([partition_identifier/2]).
-export([partition_identifiers/2]).
-export([update_partition/3]).



%% =============================================================================
%% API
%% =============================================================================



%% -----------------------------------------------------------------------------
%% @doc Returns the sort ordering configured for this index. The result can be
%% the atoms `asc' or `desc'.
%% @end
%% -----------------------------------------------------------------------------
-spec sort_ordering(babel_index:config()) -> asc | desc.

sort_ordering(Config) ->
    binary_to_existing_atom(
        riakc_register:value(
            riakc_map:fetch({<<"sort_ordering">>, register}, Config)
        ),
        utf8
    ).


%% -----------------------------------------------------------------------------
%% @doc Returns the partition algorithm name configured for this index.
%% @end
%% -----------------------------------------------------------------------------
-spec partition_algorithm(babel_index:config()) -> atom().

partition_algorithm(Config) ->
    binary_to_atom(
        riakc_register:value(
            riakc_map:fetch({<<"algorithm">>, register}, Config)
        ),
        utf8
    ).


%% -----------------------------------------------------------------------------
%% @doc
%% @end
%% -----------------------------------------------------------------------------
-spec partition_by(babel_index:config()) -> [binary()].

partition_by(Config) ->
    binary_to_term(
        riakc_register:value(
            riakc_map:fetch({<<"partition_by">>, register}, Config)
        )
    ).


%% -----------------------------------------------------------------------------
%% @doc
%% @end
%% -----------------------------------------------------------------------------
-spec index_by(babel_index:config()) -> [binary()].

index_by(Config) ->
    binary_to_term(
        riakc_register:value(
            riakc_map:fetch({<<"index_by">>, register}, Config)
        )
    ).


%% -----------------------------------------------------------------------------
%% @doc
%% @end
%% -----------------------------------------------------------------------------
-spec aggregate_by(babel_index:config()) -> [binary()].

aggregate_by(Config) ->
    case riakc_map:find({<<"aggregate_by">>, register}, Config) of
        {ok, Value} ->
            binary_to_term(riakc_register:value(Value));
        error ->
            []
    end.


%% -----------------------------------------------------------------------------
%% @doc
%% @end
%% -----------------------------------------------------------------------------
-spec covered_fields(babel_index:config()) -> [binary()].

covered_fields(Config) ->
    binary_to_term(
        riakc_register:value(
            riakc_map:fetch({<<"covered_fields">>, register}, Config)
        )
    ).


%% -----------------------------------------------------------------------------
%% @doc
%% @end
%% -----------------------------------------------------------------------------
-spec partition_identifier_prefix(babel_index:config()) -> binary().

partition_identifier_prefix(Config) ->
    riakc_map:fetch({<<"partition_identifier_prefix">>, register}, Config).


%% -----------------------------------------------------------------------------
%% @doc Returns the partition indentifiers of this index.
%% @end
%% -----------------------------------------------------------------------------
-spec partition_identifiers(babel_index:config()) -> [binary()].

partition_identifiers(Config) ->
    binary_to_term(
        riakc_map:fetch({<<"partition_identifiers">>, register}, Config)
    ).



%% =============================================================================
%% BEHAVIOUR CALLBACKS
%% =============================================================================



%% -----------------------------------------------------------------------------
%% @doc
%% @end
%% -----------------------------------------------------------------------------
-spec init(IndexId :: binary(), ConfigData :: map()) ->
    {ok, babel_index:config()} | {error, any()}.

init(IndexId, ConfigData0) ->
    #{
        sort_ordering := Sort,
        number_of_partitions := N,
        partition_algorithm := Algo,
        partition_by := PKeyFields,
        index_by := LKeyFields,
        covered_fields := PayloadFields
    } = maps_utils:validate(ConfigData0, ?SPEC),

    Prefix = <<IndexId/binary, "_partition">>,
    Identifiers = gen_partition_identifiers(Prefix, N),

    Values = [
        babel_crdt_utils:map_entry(
            register, <<"sort_ordering">>, Sort),
        babel_crdt_utils:map_entry(
            register, <<"number_of_partitions">>, integer_to_binary(N)),
        babel_crdt_utils:map_entry(
            register, <<"partition_algorithm">>, atom_to_binary(Algo, utf8)),
        babel_crdt_utils:map_entry(
            register, <<"partition_identifier_prefix">>, Prefix),
        babel_crdt_utils:map_entry(
            register, <<"partition_by">>, term_to_binary(PKeyFields)),
        babel_crdt_utils:map_entry(
            register, <<"index_by">>, term_to_binary(LKeyFields)),
        babel_crdt_utils:map_entry(
            register, <<"covered_fields">>, term_to_binary(PayloadFields)),
        babel_crdt_utils:map_entry(
            register, <<"partition_identifiers">>, term_to_binary(Identifiers))
    ],

    Config = riakc_map:new(Values, undefined),

    {ok, Config}.


%% -----------------------------------------------------------------------------
%% @doc
%% @end
%% -----------------------------------------------------------------------------
-spec init_partitions(babel_index:config()) ->
    {ok, [babel_index_partition:t()]}
    | {error, any()}.

init_partitions(Config) ->
    Identifiers = binary_to_term(
        riakc_register:value(
            babel_crdt_utils:dirty_fetch(
                {<<"partition_identifiers">>, register},
                Config
            )
        )
    ),
    Partitions = [
        {Id, babel_index_partition:new(Id)} || Id <- Identifiers
    ],
    {ok, Partitions}.


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

    Bucket = babel_consistent_hashing:bucket(PKey, N, Algo),
    gen_identifier(Prefix, Bucket).



%% -----------------------------------------------------------------------------
%% @doc
%% @end
%% -----------------------------------------------------------------------------
-spec partition_identifiers(riak_kv_index:config(), asc | desc) ->
    [babel_index:partition_id()].

partition_identifiers(Config, Order) ->
    Default = sort_ordering(Config),
    maybe_reverse(Default, Order, partition_identifiers(Config)).




%% -----------------------------------------------------------------------------
%% @doc
%% @end
%% -----------------------------------------------------------------------------
-spec partition_size(
    Config :: riak_kvindex:config(),
    Partition :: babel_index_partition:t()
    ) -> non_neg_integer().

partition_size(_, Partition) ->
    Data = riakc_map:fetch({<<"data">>, map}, Partition),
    riakc_map:size(Data).


%% -----------------------------------------------------------------------------
%% @doc
%% @end
%% -----------------------------------------------------------------------------
-spec update_partition(
    Config :: riak_kv_index:config(),
    Partition :: babel_index_partition:t(),
    ActionData :: action() | [action()]
    ) -> babel_index_partition:t() | no_return().

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
%% PRIVATE
%% =============================================================================



%% @private
gen_partition_identifiers(Prefix, N) ->
    [gen_identifier(Prefix, X) || X <- lists:seq(0, N - 1)].


%% @private
gen_identifier(Prefix, N) ->
    <<Prefix/binary, $_, (integer_to_binary(N))/binary>>.



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

insert_data(Partition, IndexKey, Value) ->
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
delete_data(Partition, {AggregateKey, IndexKey}) ->
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

delete_data(Partition, IndexKey) ->
    babel_index_partition:update_data(
        fun(Data) -> riakc_map:erase({IndexKey, map}, Data) end,
        Partition
    ).


%% @private
maybe_reverse(Order, Order, L) ->
    L;

maybe_reverse(_, _, L) ->
    lists:reverse(L).

