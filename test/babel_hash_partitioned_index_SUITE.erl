-module(babel_hash_partitioned_index_SUITE).
-include_lib("eunit/include/eunit.hrl").
-compile(export_all).



all() ->
    [
        index_1_test,
        index_2_test,
        index_3_test,
        index_4_test
    ].


init_per_suite(Config) ->
    ok = babel_config:set(
        [bucket_types, index_collection], <<"index_collection">>),
    ok = babel_config:set(
        [bucket_types, index_data], <<"index_data">>),

    Config.

end_per_suite(Config) ->
    {save_config, Config}.



index_1_test(_) ->
    Conf = #{
        name => <<"users_by_email">>,
        bucket_type => <<"map">>,
        bucket_prefix => <<"lojack/johndoe">>,
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
    Index = babel_index:new(Conf),

    CRDT = babel_index:to_riak_object(Index),
    ?assertEqual(true, riakc_map:is_type(CRDT)),

    Partitions = babel_index:create_partitions(Index),
    ?assertEqual(8, length(Partitions)),
    ok.


index_2_test(_) ->
    Conf = #{
        name => <<"users_by_email">>,
        bucket_type => <<"map">>,
        bucket_prefix => <<"lojack/johndoe">>,
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
    Index = babel_index:new(Conf),
    Partitions = babel_index:create_partitions(Index),
    ?assertEqual(8, length(Partitions)),
    ok.


index_3_test(_) ->
    Conf = #{
        name => <<"users_by_email">>,
        bucket_type => <<"map">>,
        bucket_prefix => <<"lojack/johndoe">>,
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
    Index = babel_index:new(Conf),
    Partitions = babel_index:create_partitions(Index),
    ?assertEqual(8, length(Partitions)),
    ok.


index_4_test(_) ->
    Conf = #{
        name => <<"users_by_email">>,
        bucket_type => <<"map">>,
        bucket_prefix => <<"lojack/johndoe">>,
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
    Index = babel_index:new(Conf),
    Partitions = babel_index:create_partitions(Index),
    ?assertEqual(8, length(Partitions)),
    ok.