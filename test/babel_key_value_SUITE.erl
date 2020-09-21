-module(babel_key_value_SUITE).
-include_lib("eunit/include/eunit.hrl").
-compile(export_all).


all() ->
    [
        get_empty_key_test,
        set_empty_key_test,
        get_empty_test,
        set_empty_test,
        get_empty_default_test,
        set_empty_default_test,
        badarg_get_test,
        badarg_set_test,
        get_1_test,
        set_1_test,
        crdt_get_1_test,
        crdt_set_1_test,
        babel_map_1_test
    ].


get_empty_key_test(_) ->
    KVC = [{a, 1}],
    ?assertError(badkey, key_value:get([], KVC)).

set_empty_key_test(_) ->
    KVC = [{a, 1}],
    ?assertError(badkey, key_value:set([], 1, KVC)).

get_empty_test(_) ->
    ?assertError(badkey, key_value:get([], [])),
    ?assertError(badkey, key_value:get([], #{})).

set_empty_test(_) ->
    ?assertError(badkey, key_value:set([], 1, [])),
    ?assertError(badkey, key_value:set([], 1, #{})).

get_empty_default_test(_) ->
    ?assertEqual(1, key_value:get(a, [], 1)),
    ?assertEqual(1, key_value:get([a], [], 1)),
    ?assertEqual(1, key_value:get(a, #{}, 1)),
    ?assertEqual(1, key_value:get([a], #{}, 1)).

set_empty_default_test(_) ->
    ?assertEqual([{a, 1}], key_value:set(a, 1, [])),
    ?assertEqual([{a, 1}], key_value:set([a], 1, [])),
    ?assertEqual(#{a => 1}, key_value:set(a, 1, #{})),
    ?assertEqual(#{a => 1}, key_value:set([a], 1, #{})),
    ?assertError(badkey, key_value:set([], 1, [])),
    ?assertError(badkey, key_value:set([], 1, #{})).

badarg_get_test(_) ->
    ?assertError(badkey, key_value:get([], 1)),
    ?assertError(badkey, key_value:get([], 1, 2)),
    ?assertError(badarg, key_value:get(a, 1)),
    ?assertError(badarg, key_value:get(a, 1, 2)),
    ?assertError(badkey, key_value:get([b], [])),
    ?assertError(badkey, key_value:get([b], #{})),
    ?assertError(badkey, key_value:get([b], [{a, 1}])).


badarg_set_test(_) ->
    ?assertError(badkey, key_value:set([], 1, #{a => 1})),
    ?assertError(badarg, key_value:set(a, 1, true)),
    ?assertError(badarg, key_value:set([a, b], 1, [{a , 1}])),
    ?assertError(badarg, key_value:set([a, b], 1, #{a => 1})).


get_1_test(_) ->
    D = #{e => 1},
    C = [{d, D}],
    B = #{c => C},
    A = [{b, B}],
    KVC = [{a, A}],

    ?assertEqual(A, key_value:get(a, KVC)),
    ?assertEqual(A, key_value:get([a], KVC)),
    ?assertEqual(A, key_value:get({a}, KVC)),
    ?assertEqual(B, key_value:get(b, A)),
    ?assertEqual(B, key_value:get([b], A)),
    ?assertEqual(B, key_value:get({b}, A)),
    ?assertEqual(B, key_value:get([a, b], KVC)),
    ?assertEqual(B, key_value:get({a, b}, KVC)),
    ?assertEqual(C, key_value:get([a, b, c], KVC)),
    ?assertEqual(D, key_value:get([a, b, c, d], KVC)),
    ?assertEqual(1, key_value:get([a, b, c, d, e], KVC)).

set_1_test(_) ->
    D = #{e => 1},
    C = [{d, D}],
    B = #{c => C},
    A = [{b, B}],
    KVC = [{a, A}],

    ?assertEqual(D, key_value:set(e, 1, #{})),
    ?assertEqual(C, key_value:set(d, D, [])),
    ?assertEqual(B, key_value:set(c, C, #{})),
    ?assertEqual(A, key_value:set(b, B, [])),
    ?assertEqual(KVC, key_value:set(a, A, [])).


crdt_get_1_test(_) ->
    Bin = term_to_binary([
        [{<<"info">>, map}, {<<"x">>, register}],
        {<<"a">>, register}
    ]),

    L = [
        babel_crdt:map_entry(map, <<"info">>, [
            babel_crdt:map_entry(
                register, <<"x">>, <<"value_of_x">>)
        ]),
        babel_crdt:map_entry(
            register, <<"a">>, <<"value_of_a">>
        ),
        babel_crdt:map_entry(
            register, <<"index_by">>, Bin
        )
    ],
    CRDT = riakc_map:new(L, undefined),
    ?assertEqual(true, riakc_map:is_type(CRDT)),

    % dbg:tracer(), dbg:p(all,c), dbg:tpl(babel_key_value, '_', x),

    ?assertEqual(
        riakc_map:fetch({<<"index_by">>, register}, CRDT),
        babel_key_value:get({<<"index_by">>, register}, CRDT)
    ),

    ?assertEqual(
        <<"value_of_x">>,
        riakc_register:value(
            babel_key_value:get([{<<"info">>, map}, {<<"x">>, register}], CRDT)
        )
    ).


crdt_set_1_test(_) ->
    Values = [
        {{<<"r">>, register}, <<"1">>},
        {{<<"c">>, counter}, 100}
    ],

    lists:foldl(
        fun({K, V}, Acc) ->
            babel_key_value:set(K, V, Acc)
        end,
        riakc_map:new(),
        Values
    ).


babel_map_1_test(_) ->
    M0 = babel_map:new(#{<<"foo">> => babel_map:new(#{<<"bar">> => 1})}),
    1 = babel_key_value:get([<<"foo">>, <<"bar">>], M0).