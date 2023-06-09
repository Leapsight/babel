-module(babel_counter_SUITE).
-include_lib("common_test/include/ct.hrl").
-include_lib("stdlib/include/assert.hrl").

-compile(export_all).
-compile([nowarn_export_all, export_all]).


all() ->
    [
        new,
        from_riak_counter,
        incr,
        decr,
        set_1,
        set_2
    ].



init_per_suite(Config) ->
    ok = common:setup(),
    meck:unload(),
    Config.

end_per_suite(Config) ->
    meck:unload(),
    {save_config, Config}.


new(_) ->
    C0 = babel_counter:new(),
    ?assertEqual( {babel_counter, 0, undefined}, C0),
    ?assertEqual(0, babel_counter:value(C0)),
    ?assertEqual(undefined, babel_counter:to_riak_op(C0, integer)),

    C1 = babel_counter:new(1),
    ?assertEqual( {babel_counter, 0, 1}, C1),
    ?assertEqual(1, babel_counter:value(C1)),
    ?assertEqual(
        {counter, {increment, 1}, undefined},
        babel_counter:to_riak_op(C1, integer)
    ),

    C2 = babel_counter:new(-5),
    ?assertEqual( {babel_counter, 0, -5}, C2),
    ?assertEqual(-5, babel_counter:value(C2)),
    ?assertEqual(
        {counter, {increment, -5}, undefined},
        babel_counter:to_riak_op(C2, integer)
    ).


from_riak_counter(_) ->
    ?assertEqual(
        {babel_counter, 1, undefined},
        babel_counter:from_riak_counter(
            riakc_counter:new(1, undefined),
            integer
        )
    ).


incr(_) ->
    C0 = babel_counter:from_riak_counter(
        riakc_counter:new(1, undefined),
        integer
    ),
    ?assertEqual(1, babel_counter:value(C0)),

    C1 = babel_counter:increment(C0),
    ?assertEqual({babel_counter, 1, 1}, C1),
    ?assertEqual(2, babel_counter:value(C1)),

    C2 = babel_counter:increment(100, C1),
    ?assertEqual({babel_counter, 1, 101}, C2),
    ?assertEqual(102, babel_counter:value(C2)),

    C3 = babel_counter:increment(-50, C2),
    ?assertEqual({babel_counter, 1, 51}, C3),
    ?assertEqual(52, babel_counter:value(C3)).


decr(_) ->
    C0 = babel_counter:from_riak_counter(
        riakc_counter:new(100, undefined),
        integer
    ),
    C1 = babel_counter:decrement(C0),
    ?assertEqual({babel_counter, 100, -1}, C1),
    ?assertEqual(99, babel_counter:value(C1)),

    C2 = babel_counter:decrement(50, C1),
    ?assertEqual({babel_counter, 100, -51}, C2),
    ?assertEqual(49, babel_counter:value(C2)),

    C3 = babel_counter:decrement(-50, C2),
    ?assertEqual({babel_counter, 100, -1}, C3),
    ?assertEqual(99, babel_counter:value(C3)).


set_1(_) ->

    C0 = babel_counter:from_riak_counter(
        riakc_counter:new(100, undefined),
        integer
    ),
    ?assertEqual({babel_counter, 100, undefined}, C0),

    C1 = babel_counter:set(50, C0),
    ?assertEqual({babel_counter, 100, -50}, C1),
    ?assertEqual(50, babel_counter:value(C1)),

    C2 = babel_counter:set(200, C1),
    ?assertEqual({babel_counter, 100, 100}, C2),
    ?assertEqual(200, babel_counter:value(C2)),

    C3 = babel_counter:set(-50, C2),
    ?assertEqual({babel_counter, 100, -150}, C3),
    ?assertEqual(-50, babel_counter:value(C3)).

set_2(_) ->
    ?assertEqual(
        {babel_counter, 0, 100},
        babel_counter:set(100, {babel_counter, 0, undefined})
    ),
    ?assertEqual(
        {babel_counter, 0, 100},
        babel_counter:set(100, {babel_counter, 0, 100})
    ),
    ?assertEqual(
        {babel_counter, 0, 200},
        babel_counter:set(200, {babel_counter, 0, 100})
    ),
    ?assertEqual(
        {babel_counter, 0, -100},
        babel_counter:set(-100, {babel_counter, 0, 100})
    ),
    ?assertEqual(
        {babel_counter, 100, undefined},
        babel_counter:set(100, {babel_counter, 100, undefined})
    ),
    ?assertEqual(
        {babel_counter, 100, 100},
        babel_counter:set(200, {babel_counter, 100, undefined})
    ),
    ?assertEqual(
        {babel_counter, 100, -200},
        babel_counter:set(-100, {babel_counter, 100, undefined})
    ),
    ?assertEqual(
        {babel_counter, -100, 200},
        babel_counter:set(100, {babel_counter, -100, undefined})
    ),
    ?assertEqual(
        {babel_counter, -100, 200},
        babel_counter:set(100, {babel_counter, -100, undefined})
    ),
    ?assertEqual(
        {babel_counter, -100, -100},
        babel_counter:set(-200, {babel_counter, -100, undefined})
    ).



