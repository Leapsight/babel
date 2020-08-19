-module(babel_SUITE).
-include_lib("common_test/include/ct.hrl").
-include_lib("stdlib/include/assert.hrl").

-export([all/0]).

-compile([nowarn_export_all, export_all]).



all() ->
    [
        nothing_test,
        error_test
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