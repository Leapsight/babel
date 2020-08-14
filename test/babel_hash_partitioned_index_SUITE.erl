-module(babel_hash_partitioned_index_SUITE).
-include_lib("eunit/include/eunit.hrl").
-compile(export_all).



hash_partitioned_index_1_test() ->
    Conf = #{
        id => <<"users_by_email">>,
        bucket_type => <<"map">>,
        bucket => <<"lojack/johndoe/index_data">>,
        type => babel_hash_partitioned_index,
        config => #{
            sort_ordering => asc,
            number_of_partitions => 8,
            partition_algorithm => jch,
            partition_by => [{<<"email">>, register}],
            index_by => [{<<"email">>, register}],
            covered_fields => [{<<"user_id">>, register}]
        }
    },
    {ok, Index} = babel_index:new(Conf),

    CRDT = babel_index:to_crdt(Index),
    ?assertEqual(Index, babel_index:from_crdt(CRDT)),

    {ok, Partitions} = babel_index:create_partitions(Index),
    ?assertEqual(8, length(Partitions)).


hash_partitioned_index_2_test() ->
    Conf = #{
        id => <<"users_by_email">>,
        bucket_type => <<"map">>,
        bucket => <<"lojack/johndoe/index_data">>,
        type => babel_hash_partitioned_index,
        config => #{
            sort_ordering => asc,
            number_of_partitions => 8,
            partition_algorithm => jch,
            partition_by => [{<<"email">>, register}],
            index_by => [{<<"email">>, register}],
            covered_fields => [
                {<<"user_id">>, register},
                {<<"account_id">>, register}
            ]
        }
    },
    {ok, Index} = babel_index:new(Conf),
    {ok, Partitions} = babel_index:create_partitions(Index),
    ?assertEqual(8, length(Partitions)).

hash_partitioned_index_3_test() ->
    Conf = #{
        id => <<"users_by_email">>,
        bucket_type => <<"map">>,
        bucket => <<"lojack/johndoe/index_data">>,
        type => babel_hash_partitioned_index,
        config => #{
            sort_ordering => asc,
            number_of_partitions => 8,
            partition_algorithm => jch,
            partition_by => [{<<"email">>, register}],
            aggregate_by => [{<<"email">>, register}],
            index_by => [{<<"email">>, register}],
            covered_fields => [{<<"user_id">>, register}]
        }
    },
    {ok, Index} = babel_index:new(Conf),
    {ok, Partitions} = babel_index:create_partitions(Index),
    ?assertEqual(8, length(Partitions)).


hash_partitioned_index_4_test() ->
    Conf = #{
        id => <<"users_by_email">>,
        bucket_type => <<"map">>,
        bucket => <<"lojack/johndoe/index_data">>,
        type => babel_hash_partitioned_index,
        config => #{
            sort_ordering => asc,
            number_of_partitions => 8,
            partition_algorithm => jch,
            partition_by => [{<<"email">>, register}],
            aggregate_by => [{<<"email">>, register}],
            index_by => [
                {<<"post_code">>, register},
                {<<"email">>, register}
            ],
            covered_fields => [
                {<<"user_id">>, register},
                {<<"account_id">>, register}
            ]
        }
    },
    {ok, Index} = babel_index:new(Conf),
    {ok, Partitions} = babel_index:create_partitions(Index),
    ?assertEqual(8, length(Partitions)).