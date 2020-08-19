-module(babel_SUITE).
-include_lib("common_test/include/ct.hrl").
-include_lib("stdlib/include/assert.hrl").

-export([all/0]).

-compile([nowarn_export_all, export_all]).



all() ->
    [
        nothing_test,
        error_test,
        error_dangling_index
    ].


init_per_suite(Config) ->

    ok = babel_config:set(
        [bucket_types, index_collection], <<"index_collection">>),
    ok = babel_config:set(
        [bucket_types, index_data], <<"index_data">>),

    %% Start the application.
    application:ensure_all_started(reliable),
    application:ensure_all_started(babel),

    Config.

end_per_suite(Config) ->
    {save_config, Config}.



nothing_test(_) ->
    {ok, _, ok} = babel:workflow(fun() -> ok end, []).


error_test(_) ->
    ?assertEqual({error, foo}, babel:workflow(fun() -> throw(foo) end, [])),
    ?assertError(foo, babel:workflow(fun() -> error(foo) end, [])),
    ?assertError(foo, babel:workflow(fun() -> exit(foo) end, [])).


error_dangling_index(_) ->
    Sort = asc,
    N = 8,
    Algo = jch,
    PartBy = [{<<"email">>, register}],
    IndexBy = [{<<"email">>, register}],
    Covered = [{<<"user_id">>, register}],

    Conf = #{
        id => <<"users_by_email">>,
        bucket_type => <<"map">>,
        bucket_prefix => <<"lojack/johndoe">>,
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
    Fun = fun() ->
        babel:create_index(Conf)
    end,
    ?assertEqual({error, dangling_index}, babel:workflow(Fun)).
