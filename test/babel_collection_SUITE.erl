-module(babel_collection_SUITE).
-include_lib("eunit/include/eunit.hrl").
-compile(export_all).



collection_1_test() ->
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
    C1 = babel_collection:new([]),
    C2 = babel_collection:add_index(<<"a">>, Index, C1),
    ?assertEqual(Index, babel_crdt_utils:dirty_fetch({<<"a">>, map}, C2)).

