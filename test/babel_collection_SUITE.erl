-module(babel_collection_SUITE).
-include_lib("common_test/include/ct.hrl").
-include_lib("stdlib/include/assert.hrl").

-export([all/0]).

-compile([nowarn_export_all, export_all]).



all() ->
    [
        collection_1_test
    ].


init_per_suite(Config) ->
    ok = babel_config:set(
        [bucket_types, index_collection], <<"index_collection">>),
    ok = babel_config:set(
        [bucket_types, index_data], <<"index_data">>),

    Config.

end_per_suite(Config) ->
    {save_config, Config}.



collection_1_test(_) ->
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

    C1 = babel_index_collection:new([]),
    C2 = babel_index_collection:add_index(<<"a">>, Index, C1),

    RiakMap = babel_index:to_crdt(Index),
    ?assertEqual(Index, babel_index:from_crdt(RiakMap)),
    ?assertEqual(RiakMap, babel_index_collection:index(<<"a">>, C2)),
    ?assertEqual(RiakMap, babel_crdt:dirty_fetch({<<"a">>, map}, C2)),
    ok.


