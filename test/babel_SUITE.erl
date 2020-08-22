-module(babel_SUITE).
-include_lib("common_test/include/ct.hrl").
-include_lib("stdlib/include/assert.hrl").

-export([all/0]).

-compile([nowarn_export_all, export_all]).



all() ->
    [
        nothing_test,
        error_test,
        index_creation_1_test,
        scheduled_for_delete_test
    ].


init_per_suite(Config) ->

    ok = babel_config:set(
        [bucket_types, index_collection], <<"index_collection">>),
    ok = babel_config:set(
        [bucket_types, index_data], <<"index_data">>),

    %% Start the application.
    application:ensure_all_started(reliable),
    application:ensure_all_started(babel),
    meck:unload(),

    Config.

end_per_suite(Config) ->
    meck:unload(),
    {save_config, Config}.



nothing_test(_) ->
    {ok, _, ok} = babel:workflow(fun() -> ok end, []).


error_test(_) ->
    ?assertEqual({error, foo}, babel:workflow(fun() -> throw(foo) end, [])),
    ?assertError(foo, babel:workflow(fun() -> error(foo) end, [])),
    ?assertError(foo, babel:workflow(fun() -> exit(foo) end, [])).


index_creation_1_test(_) ->
    meck:new(reliable, [passthrough]),
    meck:expect(reliable, enqueue, fun
        (_, Work) ->
            ct:pal("Work being scheduled is ~p", [Work]),
            %% 8 partitions + 1 collection
            ?assertEqual(9, length(Work)),
            ok
    end),

    Conf = index_conf(),

    Fun = fun() ->
        Index = babel_index:new(Conf),
        Collection = babel_index_collection:new(<<"mytenant">>, <<"users">>),
        ok = babel:create_index(Index, Collection),
        ok
    end,

    {ok, _, _} =  babel:workflow(Fun),
    ok.



scheduled_for_delete_test(_) ->
    Conf = index_conf(),
    Fun = fun() ->
        Index = babel_index:new(Conf),
        Collection = babel_index_collection:new(<<"mytenant">>, <<"users">>),
        ok = babel:delete_collection(Collection),
        ok = babel:create_index(Index, Collection),
        ok
    end,

    {error, {scheduled_for_delete, _Id}} = babel:workflow(Fun),
    ok.


index_conf() ->
    Sort = asc,
    N = 8,
    Algo = jch,
    PartBy = [{<<"email">>, register}],
    IndexBy = [{<<"email">>, register}],
    Covered = [{<<"user_id">>, register}],

    #{
        name => <<"users_by_email">>,
        bucket_type => <<"index_data">>,
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
    }.