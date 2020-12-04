-module(babel_flag_SUITE).
-include_lib("common_test/include/ct.hrl").
-include_lib("stdlib/include/assert.hrl").

-compile(export_all).
-compile([nowarn_export_all, export_all]).


all() ->
    [
        new,
        from_riak_flag,
        enable,
        disable,
        set
    ].



init_per_suite(Config) ->
    ok = common:setup(),
    meck:unload(),
    Config.

end_per_suite(Config) ->
    meck:unload(),
    {save_config, Config}.


new(_) ->
    ?assertEqual({babel_flag, false, undefined, undefined}, babel_flag:new()),
    ?assertEqual({babel_flag, false, enable, undefined}, babel_flag:new(true)).


from_riak_flag(_) ->
    Ctxt = <<>>,
    ?assertEqual(
        {babel_flag, true, undefined, <<>>},
        babel_flag:from_riak_flag(
            riakc_flag:new(true, Ctxt),
            Ctxt,
            boolean
        )
    ).


enable(_) ->
    Ctxt = <<>>,
    C0 = babel_flag:from_riak_flag(
        riakc_flag:new(true, Ctxt),
        Ctxt,
        boolean
    ),
    ?assertEqual(true, babel_flag:value(C0)),

    C1 = babel_flag:enable(C0),
    ?assertEqual({babel_flag, true, enable, <<>>}, C1),
    ?assertEqual(true, babel_flag:value(C1)),
    ?assertEqual(true, babel_flag:original_value(C1)).


disable(_) ->
    Ctxt = <<>>,
    C0 = babel_flag:from_riak_flag(
        riakc_flag:new(true, Ctxt),
        Ctxt,
        boolean
    ),
    ?assertEqual(true, babel_flag:value(C0)),

    C1 = babel_flag:disable(C0),
    ?assertEqual({babel_flag, true, disable, <<>>}, C1),
    ?assertEqual(false, babel_flag:value(C1)),
    ?assertEqual(true, babel_flag:original_value(C1)).


set(_) ->
    Ctxt = <<>>,
    C0 = babel_flag:from_riak_flag(
        riakc_flag:new(true, Ctxt),
        Ctxt,
        boolean
    ),
    ?assertEqual(true, babel_flag:value(C0)),

    C1 = babel_flag:set(true, C0),
    ?assertEqual({babel_flag, true, enable, <<>>}, C1),
    ?assertEqual(true, babel_flag:value(C1)),
    ?assertEqual(true, babel_flag:original_value(C1)),

    C2 = babel_flag:set(false, C1),
    ?assertEqual({babel_flag, true, disable, <<>>}, C2),
    ?assertEqual(false, babel_flag:value(C2)),
    ?assertEqual(true, babel_flag:original_value(C2)).


