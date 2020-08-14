-module(babel_collection_SUITE).
-include_lib("eunit/include/eunit.hrl").
-compile(export_all).



collection_1_test() ->
    Sort = asc,
    N = 8,
    Algo = jch,
    PartBy = [{<<"email">>, register}],
    IndexBy = [{<<"email">>, register}],
    Covered = [{<<"user_id">>, register}],

    Conf = #{
        id => <<"users_by_email">>,
        bucket_type => <<"map">>,
        bucket => <<"lojack/johndoe/index_data">>,
        type => babel_hash_partitioned_index,
        config => #{
            sort_ordering => Sort,
            number_of_partitions => N,
            partition_algorithm => Algo,
            partition_by => PartBy,
            index_by => IndexBy,
            covered_fields => Covered
        }
    },
    {ok, Index} = babel_index:new(Conf),

    C1 = babel_collection:new([]),
    C2 = babel_collection:add_index(<<"a">>, Index, C1),

    RiakMap = babel_index:to_crdt(Index),
    ?assertEqual(Index, babel_index:from_crdt(RiakMap)),
    ?assertEqual(RiakMap, babel_collection:index(<<"a">>, C2)),
    ?assertEqual(RiakMap, babel_crdt:dirty_fetch({<<"a">>, map}, C2)).


