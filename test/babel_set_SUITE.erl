-module(babel_set_SUITE).
-include_lib("common_test/include/ct.hrl").
-include_lib("stdlib/include/assert.hrl").

-compile(export_all).
-compile([nowarn_export_all, export_all]).


all() ->
    [
        set_elements,
        add_element,
        add_elements,
        del_element,
        del_elements
    ].



init_per_suite(Config) ->
    ok = common:setup(),
    meck:unload(),
    Config.

end_per_suite(Config) ->
    meck:unload(),
    {save_config, Config}.

set_elements(_) ->
    S0 = babel_set:new([1, 2, 3], integer),
    ?assertEqual([1, 2, 3], babel_set:value(S0)),
    S1 = babel_set:set_elements([2], S0),
    ?assertEqual([2], babel_set:value(S1)).

add_element(_) ->
    S0 = babel_set:new([1, 3], integer),
    ?assertEqual(
        [1, 2, 3],
        babel_set:value(babel_set:add_element(2, S0))
    ).

add_elements(_) ->
    S0 = babel_set:new([3], integer),
    ?assertEqual(
        [1, 2, 3],
        babel_set:value(babel_set:add_elements([2, 1], S0))
    ).

del_element(_) ->
    S0 = babel_set:new([1, 2, 3], integer),
    ?assertException(throw, context_required, babel_set:del_element(2, S0)),
    S1 = babel_set:set_context(<<>>, S0),
    ?assertEqual([1, 3], babel_set:value(babel_set:del_element(2, S1))).

del_elements(_) ->
    S0 = babel_set:new([1, 2, 3], integer),
    ?assertException(throw, context_required, babel_set:del_elements([2], S0)),
    S1 = babel_set:set_context(<<>>, S0),
    ?assertEqual([2], babel_set:value(babel_set:del_elements([1, 3], S1))).