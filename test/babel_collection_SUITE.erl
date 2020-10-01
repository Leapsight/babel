-module(babel_collection_SUITE).
-include_lib("common_test/include/ct.hrl").
-include_lib("stdlib/include/assert.hrl").

-compile(export_all).
-compile([nowarn_export_all, export_all]).



all() ->
    [
        collection_1_test
    ].


init_per_suite(Config) ->
    ok = common:setup(),
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
        name => <<"users_by_email">>,
        bucket_type => <<"index_data">>,
        bucket_prefix => <<"babel_collection_SUITE/johndoe">>,
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
    Index = babel_index:new(Conf),

    C1 = babel_index_collection:new(<<"foo">>, <<"bar">>),
    _C2 = babel_index_collection:add_index(Index, C1),

    _RiakMap = babel_index:to_riak_object(Index),
    %% ?assertEqual(Index, babel_index:from_riak_object(RiakMap)),
    %% ?assertEqual(
    %%     RiakMap, babel_index_collection:index(<<"users_by_email">>, C2)
    %% ),
    %% ?assertEqual(
    %%     [Index],
    %%     babel_index_collection:indices(C2)
    %% ),
    %% CRDT = babel_index_collection:data(C2),
    %% ?assertEqual(
    %%     RiakMap, babel_crdt:dirty_fetch({<<"users_by_email">>, map}, CRDT)
    %% ),
    ok.


