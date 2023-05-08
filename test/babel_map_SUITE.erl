-module(babel_map_SUITE).
-include_lib("common_test/include/ct.hrl").
-include_lib("stdlib/include/assert.hrl").

-compile(export_all).
-compile([nowarn_export_all, export_all]).


all() ->
    [
        huge_nested_update,
        create_test,
        create_test_2,
        put_1_test,
        put_2_test,
        to_riak_op_test,
        babel_put_test,
        babel_get_test,
        % update_1_test,
        update_2_test,
        update_3_test,
        update_4_test,
        update_5_test,
        update_6_test,
        update_7_test,
        patch_1_test,
        patch_2_test,
        patch_3_test,
        undefined_test_1,
        set_test_1,
        set_undefined_test_1,
        set_undefined_test_2,
        update_counter_value_roundtrip,
        update_set_value_roundtrip,
        concurrent_set_update,
        nested_update,
        nested_update_1,
        update_type_check,
        nested_flags
    ].



init_per_suite(Config) ->
    ok = common:setup(),
    meck:unload(),
    Config.

end_per_suite(Config) ->
    meck:unload(),
    {save_config, Config}.


create_test(_) ->
    M = babel_map:new(data(), spec()),
    ?assertEqual(true, babel_map:is_type(M)).

create_test_2(_) ->
    M = babel_map:new(data1(), spec()),
    ?assertEqual(true, babel_map:is_type(M)).


to_riak_op_test(_) ->
    M = babel_map:new(data(), spec()),
    Op = babel_map:to_riak_op(M, spec()),
    ?assertEqual(true, is_tuple(Op)).


put_1_test(_) ->
    M0 = babel_map:new(),
    M1 = babel_map:put(<<"a">>, 1, M0),
    ?assertEqual(1, babel_map:get_value(<<"a">>, M1)).


put_2_test(_) ->
    M0 = babel_map:new(),
    M1 = babel_map:put(<<"a">>, babel_map:new(), M0),
    M2 = babel_map:put([<<"a">>, <<"aa">>], 1, M1),
    ?assertEqual(1, babel_map:get_value([<<"a">>, <<"aa">>], M2)),
    ?assertEqual(1, maps:get(<<"aa">>, babel_map:get_value(<<"a">>, M2))),

    M3 = babel_map:put([<<"a">>, <<"ab">>, <<"aba">>], 1, M2),
    ?assertEqual(
        1,
        babel_map:get_value([<<"a">>, <<"ab">>, <<"aba">>], M3)
    ),
    ?assertEqual(
        1,
        maps:get(
            <<"aba">>,
            maps:get(<<"ab">>, babel_map:get_value(<<"a">>, M3))
        )
    ).


babel_put_test(_) ->
    M0 = babel_map:new(data(), spec()),
    {ok, Conn} = riakc_pb_socket:start_link("127.0.0.1", 8087),
    pong = riakc_pb_socket:ping(Conn),

    Opts = #{
        connection => Conn,
        return_body => true
    },

    ?assertEqual(false, reliable:is_in_workflow()),

    {ok, M1} = babel:put(
        {<<"index_data">>, <<"test">>},<<"to_riak_op_test">>, M0, spec(), Opts
    ),
    ?assertEqual(babel_map:value(M0), babel_map:value(M1)).


babel_get_test(_) ->
    {ok, Conn} = riakc_pb_socket:start_link("127.0.0.1", 8087),
    pong = riakc_pb_socket:ping(Conn),
    {ok, M} = babel:get(
        {<<"index_data">>, <<"test">>},
        <<"to_riak_op_test">>,
        spec(),
        #{connection => Conn}
    ),
    ?assertEqual(true, babel_map:is_type(M)).

modify_test(_) ->
    Spec = #{<<"foo">> => {map, #{'_' => {register, integer}}}},
    M0 = babel_map:new(#{<<"foo">> => #{<<"bar">> => 1}}, Spec, <<>>),
    M1 = babel_map:set(<<"foo">>, babel_map:new(#{}), M0),
    ?assertNotEqual(
        undefined,
        babel_map:to_riak_op(M1, Spec)
    ).



babel_test(_) ->
    T1 = babel_map:new(data1(), spec()),
    T2 = babel_map:update(data2(), T1, spec()),
    ?assertEqual(
        <<"11111111">>, babel_map:get_value(<<"identification_number">>, T2)
    ),
    ?assertEqual(
        <<"11111111">>, babel_map:get_value(<<"identification_number">>, T2)
    ),
    ?assertEqual(
        [a, b, c],
        babel_map:get_value(<<"set_prop">>, T2)
    ),
    ?assertEqual(
        100,
        babel_map:get_value(<<"counter_prop">>, T2)
    ),
    ?assertEqual(
        true,
        babel_map:get_value(<<"flag_prop">>, T2)
    ).

update_2_test(_) ->
    Data = data1(),
    Number = maps:get(<<"identification_number">>, Data),

    T1 = babel_map:new(Data, spec()),

    T2 = babel_map:update(
        #{<<"identification_number">> => undefined}, T1,  spec()
    ),

    ?assertError(
        badkey,
        babel_map:get_value(<<"identification_number">>, T2),
        "Key must have been removed even without context because we added the field in data1()"
    ),

    %% We remove the field to produce an error
    T3 = babel_map:new(
        maps:without([<<"identification_number">>], data1()), spec()
    ),

    ?assertError(
        context_required,
        babel_map:update(
            #{<<"identification_number">> => undefined}, T3,  spec()
        )
    ).

update_3_test(_) ->
    Ctxt = <<>>,
    T1 = babel_map:new(data1(), spec(), Ctxt),

    T2 = babel_map:update(
        #{<<"identification_number">> => undefined}, T1,  spec()
    ),
    ?assertEqual(
        undefined,
        babel_map:get_value(<<"identification_number">>, T2, undefined)
    ).

update_4_test(_) ->
    Spec = #{
        <<"mapping">> => {map, #{'_' => {register, binary}}}
    },
    Data = #{
        <<"mapping">> => #{
            <<"key1">> => <<"value1">>,
            <<"key2">> => <<"value2">>
        }
    },
    Map = babel_map:update(Data, babel_map:new(), Spec),
    ?assertEqual(
        Data,
        babel_map:value(Map)
    ).


update_5_test(_) ->
    Spec = #{
        <<"mapping">> => {map, #{
            <<"foo">> => {map, #{'_' => {register, binary}}}
        }}
    },
    Data = #{
        <<"mapping">> => #{
            <<"foo">> => #{
                <<"key1">> => <<"value1">>,
                <<"key2">> => <<"value2">>,
                <<"key3">> => 100
            }
        }
    },
    ?assertError(
        {badkeytype, 100, {register, binary}},
        babel_map:update(Data, babel_map:new(), Spec)
    ).




update_6_test(_) ->
    Spec = #{
        <<"mapping">> => {map, #{
            <<"foo">> => {map, #{'_' => {register, binary}}}
        }}
    },
    Data = #{
        <<"mapping">> => #{
            <<"foo">> => #{
                <<"key1">> => <<"value1">>,
                <<"key2">> => <<"value2">>
            }
        }
    },
    Map0 = babel_map:update(Data, babel_map:new(#{}, Spec)),
    ?assertEqual(
        Data,
        babel_map:value(Map0)
    ),

    Map1 = babel_map:update(
        #{
            <<"mapping">> => #{
                <<"foo">> => #{
                    <<"key2">> => undefined
                }
            }
        },
        Map0
    ),
    ?assertEqual(
        #{
            <<"mapping">> => #{
                <<"foo">> => #{
                    <<"key1">> => <<"value1">>
                }
            }
        },
        babel_map:value(Map1)
    ).


update_7_test(_) ->
    Spec = #{'_' => {map, #{'_' => {register, integer}}}},
    M0 = babel_map:new(#{<<"a">> => #{<<"a1">> => 1}}, Spec),
    Update0 = #{
        <<"a">> => #{<<"a2">> => 2},
        <<"b">> => #{<<"b1">> => 1}
    },
    Expected0 = #{
        <<"a">> => #{<<"a1">> => 1, <<"a2">> => 2},
        <<"b">> => #{<<"b1">> => 1}
    },
    M1 = babel_map:update(Update0, M0, Spec),
    ?assertEqual(Expected0, babel_map:value(M1)),

    Update1 = #{
        <<"a">> => #{<<"a2">> => 20},
        <<"b">> => #{<<"b1">> => 10}
    },
    Expected1 = #{
        <<"a">> => #{<<"a1">> => 1, <<"a2">> => 20},
        <<"b">> => #{<<"b1">> => 10}
    },
    M2 = babel_map:update(Update1, M1, Spec),
    ?assertEqual(Expected1, babel_map:value(M2)).


patch_1_test(_) ->
    Ctxt = <<>>,
    T1 = babel_map:new(data2(), spec(), Ctxt),

    T2 = babel_map:patch(
        [
            #{
                <<"path">> => <<"/identification_number">>,
                <<"action">> => <<"update">>,
                <<"value">> => <<"111111111">>
            },
            #{
                <<"path">> => <<"/address/postal_code">>,
                <<"action">> => <<"update">>,
                <<"value">> => <<"SW12 2XX">>
            },
            #{
                <<"path">> => <<"/set_prop">>,
                <<"action">> => <<"add_element">>,
                <<"value">> => d
            },
            #{
                <<"path">> => <<"/set_prop">>,
                <<"action">> => <<"del_element">>,
                <<"value">> => a
            },
            #{
                <<"path">> => <<"/counter_prop">>,
                <<"action">> => <<"increment">>
            },
            #{
                <<"path">> => <<"/flag_prop">>,
                <<"action">> => <<"disable">>
            }
        ],
        T1,
        spec()
    ),
    ?assertEqual(
        <<"111111111">>,
        babel_map:get_value(<<"identification_number">>, T2)
    ),
    ?assertEqual(
        <<"SW12 2XX">>,
        babel_map:get_value([<<"address">>, <<"postal_code">>], T2)
    ),
    ?assertEqual(
        [b, c, d],
        babel_map:get_value(<<"set_prop">>, T2)
    ),
    ?assertEqual(
        101,
        babel_map:get_value(<<"counter_prop">>, T2)
    ),
    ?assertEqual(
        false,
        babel_map:get_value(<<"flag_prop">>, T2)
    ),
    {Updates, Removes} = babel_map:changed_key_paths(T2),
    ?assertEqual(
        {
            lists:usort([
                [<<"account_type">>],
                [<<"active">>],
                [<<"address">>, <<"address_line1">>],
                [<<"address">>, <<"address_line2">>],
                [<<"address">>, <<"city">>],
                [<<"address">>, <<"country">>],
                [<<"address">>, <<"postal_code">>],
                [<<"address">>, <<"state">>],
                [<<"counter_prop">>],
                [<<"country_id">>],
                [<<"flag_prop">>],
                [<<"id">>],
                [<<"identification_number">>],
                [<<"identification_type">>],
                [<<"name">>],
                [<<"number">>],
                [<<"operation_mode">>],
                [<<"set_prop">>],
                [<<"version">>]
            ]),
            []
        },
        {lists:usort(Updates), Removes}
    ).


patch_2_test(_) ->
    ok.


patch_3_test(_) ->
    ok.


undefined_test_1(_) ->
    TypeSpec = #{<<"a">> => {register, binary}},
    T1 = babel_map:new(#{<<"a">> => undefined}, TypeSpec),
    ?assertEqual([], babel_map:keys(T1)).

set_test_1(_) ->
    TCSpec = #{
        <<"accepted_by">> => {register, binary},
        <<"acceptance_timestamp">> => {register, integer}
    },
    Spec = #{
        <<"version">> => {register, binary},
        <<"id">> => {register, binary},
        <<"name">> => {register, binary},
        <<"active">> => {register, boolean},
        <<"account_type">> => {register, binary},
        <<"operation_mode">> => {register, binary},
        <<"country_id">> => {register, binary},
        <<"number">> => {register, binary},
        <<"identification_type">> => {register, binary},
        <<"identification_number">> => {register, binary},
        <<"logo">> => {register, binary},
        <<"url">> => {register, binary},
        <<"address">> => {map, #{
            <<"address_line1">> => {register, binary},
            <<"address_line2">> => {register, binary},
            <<"city">> => {register, binary},
            <<"state">> => {register, binary},
            <<"country">> => {register, binary},
            <<"postal_code">> => {register, binary}
        }},
        <<"services">> => {map, #{'_' => {map, #{
            <<"description">> => {register, binary},
            <<"expiry_date">> => {register, binary},
            <<"enabled">> => {register, boolean}
        }}}},
        <<"terms_and_conditions">> => {map, #{'_' => {map, TCSpec}}},
        <<"created_by">> => {register, binary},
        <<"last_modified_by">> => {register, binary},
        <<"created_timestamp">> => {register, integer},
        <<"last_modified_timestamp">> => {register, integer}
    },
    Key = <<"terms_and_conditions">>,
    TCs = babel_map:new(
        #{
            <<"accepted_by">> => <<"user@foo.com">>,
            <<"acceptance_timestamp">> => erlang:system_time(millisecond)
        },
        TCSpec
    ),
    Version = <<"20201118">>,
    Ref = babel_map:register_type_spec(Spec),
    Data = #{
        <<"account_type">> => <<"business">>,<<"active">> => true,
        <<"address">> =>#{
            <<"address_line1">> => <<"523">>,
            <<"city">> => <<"La Plata">>,
            <<"country">> => <<"Argentina">>,
            <<"postal_code">> => <<"1900">>,
            <<"state">> => <<"Buenos Aires">>
        },
        <<"country_id">> => <<"AR">>,
        <<"created_by">> => <<"testaccount@test.com.ar">>,
        <<"created_timestamp">> => 1605695133613,
        <<"id">> =>
            <<"mrn:account:business:22ea8fbe-f5a6-48e7-b439-20cfef4bc979">>,
        <<"identification_number">> => <<"33333333">>,
        <<"identification_type">> => <<"DNI">>,
        <<"last_modified_by">> => <<"testaccount@test.com.ar">>,
        <<"last_modified_timestamp">> => 1605695133613,
        <<"name">> => <<"My Account Ale Sin Phones and Emails">>,
        <<"number">> => <<"AB1234567">>,
        <<"operation_mode">> => <<"normal">>,
        <<"services">> => #{
            <<"mrn:service:fleet">> => #{
                <<"description">> => <<"Plan fleet habilitado">>,
                <<"enabled">> => true,
                <<"expiry_date">> => <<"2017-05-12T00:00:00+00:00">>
            }
        },
        <<"version">> => <<"1.0">>
    },
    Map0 = babel_map:set_context(inherited, babel_map:new(Data, Ref)),

    Map1 = babel_map:set([Key, Version], TCs, Map0),
    ?assertEqual(
        babel_map:value(TCs),
        babel_map:value(babel_map:get([Key, Version], Map1))
    ),
    {ok, Conn} = riakc_pb_socket:start_link("127.0.0.1", 8087),
    ?assertEqual(pong, riakc_pb_socket:ping(Conn)),

    Map2 = babel_map:set_context(undefined, Map1),

    ?assertEqual(
        babel_map:to_riak_op(Map2),
        babel_map:to_riak_op(Map2, Spec)
    ),

    ok = babel:put(
        {<<"index_data">>, <<"test">>},
        <<"set_test_1">>,
        %% We revert context to undefine so that Riak does not fail
        Map2,
        Spec,
        #{connection => Conn}
    ),
    ok.


set_undefined_test_1(_) ->
    T1 = babel_map:new(#{<<"a">> => 1}, #{<<"a">> => {register, integer}}),
    T2 = babel_map:set(<<"a">>, undefined, T1),
    ?assertEqual([], babel_map:keys(T2)).


set_undefined_test_2(_) ->
    Ctxt = <<>>,
    T1 = babel_map:new(
        #{<<"a">> => 1}, #{<<"a">> => {register, integer}}, Ctxt
    ),
    T2 = babel_map:set(<<"a">>, undefined, T1),
    ?assertEqual([], babel_map:keys(T2)).


%% =============================================================================
%% RESOURCES
%% =============================================================================




data() ->
    #{
        <<"version">> => <<"2.0">>,
        <<"id">> => <<"mrn:business_account:1">>,
        <<"account_type">> => <<"business">>,
        <<"name">> => <<"Leapsight">>,
        <<"active">> => true,
        <<"operation_mode">> => <<"normal">>,
        <<"country_id">> => <<"AR">>,
        <<"number">> => <<"AC897698769">>,
        <<"identification_type">> => <<"PASSPORT">>,
        <<"identification_number">> => <<"874920948">>,
        <<"address">> => #{
            <<"address_line1">> => <<"Clement Street">>,
            <<"address_line2">> => <<"Floor 8 Room B">>,
            <<"city">> => <<"London">>,
            <<"state">> => <<"London">>,
            <<"country">> => <<"United Kingdom">>,
            <<"postal_code">> => <<"SW12 2RT">>
        },
        %% decode #{Email => Tag} --> [{email => Email, tag => Tag}]
        %% encode [{number => Email, tag => Tag}] --> #{Email => Tag}
        %% <<"emails">> => [
        %%     #{
        %%         <<"email">> =><<"john.doe@foo.com">>,
        %%         <<"tage">> => <<"work">>
        %%     }
        %% ],
        <<"emails">> => #{
            <<"john.doe@foo.com">> => <<"work">>
        },
        %% <<"phones">> =>  [
        %%     #{
        %%         <<"number">> => <<"09823092834">>,
        %%         <<"tage">> => <<"work">>
        %%     }
        %% ],
        <<"phones">> => #{
            <<"09823092834">> => <<"work">>
        },
        <<"services">> => #{
            <<"mrn:service:vehicle_lite">> => #{
                <<"enabled">> => true,
                <<"description">> => <<"Baz Service">>,
                <<"expiry_date">> => <<"2020/10/09">>
            }
        },
        <<"created_by">> => <<"mrn:user:1">>,
        <<"last_modified_by">> => <<"mrn:user:1">>,
        <<"created_timestamp">> => 1599835691640,
        <<"last_modified_timestamp">> => 1599835691640
    }.


data1() ->
    #{
        <<"version">> => <<"2.0">>,
        <<"id">> => <<"mrn:business_account:1">>,
        <<"account_type">> => <<"business">>,
        <<"name">> => <<"Leapsight">>,
        <<"active">> => true,
        <<"operation_mode">> => <<"normal">>,
        <<"country_id">> => <<"AR">>,
        <<"number">> => <<"AC897698769">>,
        <<"identification_type">> => <<"PASSPORT">>,
        <<"identification_number">> => <<"874920948">>,
        <<"address">> => #{
            <<"address_line1">> => <<"Clement Street">>,
            <<"address_line2">> => <<"Floor 8 Room B">>,
            <<"city">> => <<"London">>,
            <<"state">> => <<"London">>,
            <<"country">> => <<"United Kingdom">>,
            <<"postal_code">> => <<"SW12 2RT">>
        }
    }.


data2() ->
    #{
        <<"version">> => <<"2.0">>,
        <<"id">> => <<"mrn:business_account:1">>,
        <<"account_type">> => <<"business">>,
        <<"name">> => <<"Leapsight">>,
        <<"active">> => false,
        <<"operation_mode">> => <<"normal">>,
        <<"country_id">> => <<"UK">>,
        <<"number">> => <<"AC897698769">>,
        <<"identification_type">> => <<"PASSPORT">>,
        <<"identification_number">> => <<"11111111">>,
        <<"address">> => #{
            <<"address_line1">> => <<"Clement Street">>,
            <<"address_line2">> => <<"Floor 8 Room B">>,
            <<"city">> => <<"London">>,
            <<"state">> => <<"London">>,
            <<"country">> => <<"United Kingdom">>,
            <<"postal_code">> => <<"SW12 2RT">>
        },
        <<"set_prop">> => [a, b, c],
        <<"counter_prop">> => 100,
        <<"flag_prop">> => true
    }.


spec() ->
    #{
        <<"version">> => {register, binary},
        <<"id">> => {register, binary},
        <<"account_type">> => {register, binary},
        <<"name">> => {register, binary},
        <<"active">> => {register, boolean},
        <<"operation_mode">> => {register, binary},
        <<"country_id">> => {register, binary},
        <<"number">> => {register, binary},
        <<"identification_type">> => {register, binary},
        <<"identification_number">> => {register, binary},
        <<"address">> => {map, #{
            <<"address_line1">> => {register, binary},
            <<"address_line2">> => {register, binary},
            <<"city">> => {register, binary},
            <<"state">> => {register, binary},
            <<"country">> => {register, binary},
            <<"postal_code">> => {register, binary}
        }},
        %% emails and phones are stored as maps of their values to their tag
        %% value e.g. #{<<"john.doe@example.com">> => <<"work">>}
        %% {register, binary} means "every key in the phones | emails map has
        %% a register associated and we keep the value of the registry as a
        %% binary
        <<"emails">> => {map, #{'_' => {register, binary}}},
        <<"phones">> => {map, #{'_' => {register, binary}}},
        %% services is a mapping of serviceID to service objects
        %% e.g. #{<<"mrn:service:1">> => #{<<"description">> => ...}
        %% {map, #{..}} means "every key in the services map has a map
        %% associated with it which is always of the same type, in this case a
        %% map with 3 properties: description, expired_data and enabled"
        <<"services">> => {map, #{'_' => {map, #{
            <<"description">> => {register, binary},
            <<"expiry_date">> => {register, binary},
            <<"enabled">> => {register, boolean}
        }}}},
        <<"created_by">> => {register, binary},
        <<"last_modified_by">> => {register, binary},
        <<"created_timestamp">> => {register, integer},
        <<"last_modified_timestamp">> => {register, integer},
        <<"set_prop">> => {set, atom},
        <<"counter_prop">> => {counter, integer},
        <<"flag_prop">> => {flag, boolean}
    }.

update_counter_value_roundtrip(_) ->
    {ok, Conn} = riakc_pb_socket:start_link("127.0.0.1", 8087),
    pong = riakc_pb_socket:ping(Conn),
    GetOpts = #{connection => Conn},
    PutOpts = GetOpts#{return_body => true},

    TypedBucket = {<<"index_data">>, <<"test">>},
    Key = <<"update_counter_value_roundtrip">>,
    Spec = #{<<"c">> => {counter, integer}},

    {ok, Map0} = case babel:get(TypedBucket, Key, Spec, GetOpts) of
        {ok, Map} ->
            {ok, Map};
        {error, not_found} ->
            Map = babel_map:new(#{<<"c">> => 100}, Spec),
            babel:put(TypedBucket, Key, Map, Spec, PutOpts)
    end,
    Value = babel_map:get_value(<<"c">>, Map0) + 50,

    Map1 = babel_map:update(#{<<"c">> => Value}, Map0, Spec),
    {ok, Map2} = babel:put(TypedBucket, Key, Map1, Spec, PutOpts),
    ?assertEqual(Value, babel_map:get_value(<<"c">>, Map2)).


update_set_value_roundtrip(_) ->
    {ok, Conn} = riakc_pb_socket:start_link("127.0.0.1", 8087),
    pong = riakc_pb_socket:ping(Conn),
    GetOpts = #{connection => Conn},
    PutOpts = GetOpts#{return_body => true},

    TypedBucket = {<<"index_data">>, <<"test">>},
    Key = <<"update_set_value_roundtrip">>,
    Spec = #{<<"s">> => {set, integer}},

    {ok, Map0} = case babel:get(TypedBucket, Key, Spec, GetOpts) of
        {ok, Map} ->
            {ok, Map};
        {error, not_found} ->
            Map = babel_map:new(#{<<"s">> => [1, 2, 3]}, Spec),
            babel:put(TypedBucket, Key, Map, Spec, PutOpts)
    end,
    Value = [hd(babel_map:get_value(<<"s">>, Map0)) + 1],

    Map1 = babel_map:update(#{<<"s">> => Value}, Map0, Spec),
    {ok, Map2} = babel:put(TypedBucket, Key, Map1, Spec, PutOpts),
    ?assertEqual(Value, babel_map:get_value(<<"s">>, Map2)).


concurrent_set_update(_) ->
    {ok, Conn} = riakc_pb_socket:start_link("127.0.0.1", 8087),
    pong = riakc_pb_socket:ping(Conn),
    GetOpts = #{connection => Conn},
    PutOpts = GetOpts#{return_body => true},

    TypedBucket = {<<"index_data">>, <<"test">>},
    Key = <<"concurrent_set_update">>,
    Spec = #{<<"s">> => {set, integer}},

    {ok, Map0} = case babel:get(TypedBucket, Key, Spec, GetOpts) of
        {ok, Map} ->
            {ok, Map};
        {error, not_found} ->
            Map = babel_map:new(#{<<"s">> => [1, 2, 3]}, Spec),
            babel:put(TypedBucket, Key, Map, Spec, PutOpts)
    end,
    ValueA = [lists:last(babel_map:get_value(<<"s">>, Map0)) + 1],
    ValueB = [hd(ValueA) + 1],

    Map1A = babel_map:update(#{<<"s">> => ValueA}, Map0, Spec),
    {ok, Map2} = babel:put(TypedBucket, Key, Map1A, Spec, PutOpts),
    ?assertEqual(ValueA, babel_map:get_value(<<"s">>, Map2)),

    Map1B = babel_map:update(#{<<"s">> => ValueB}, Map0, Spec),
    {ok, Map3} = babel:put(TypedBucket, Key, Map1B, Spec, PutOpts),

    %% Two concurrent updates should converge
    ?assertEqual(
        lists:append(ValueA, ValueB),
        babel_map:get_value(<<"s">>, Map3)
    ),

    %% We remove the set concurrently
    Map1C = babel_map:update(#{<<"s">> => undefined}, Map0, Spec),
    {ok, Map4} = babel:put(TypedBucket, Key, Map1C, Spec, PutOpts),

    %% Two concurrent updates and a concurrent remove should converge and the %% adds should win as we are using an ORSWOT
    ?assertEqual(
        lists:append(ValueA, ValueB),
        babel_map:get_value(<<"s">>, Map4)
    ),

    %% We now remove the set from a more recent update (Map2)
    Map2C = babel_map:update(#{<<"s">> => undefined}, Map2, Spec),
    {ok, Map5} = babel:put(TypedBucket, Key, Map2C, Spec, PutOpts),

    %% Adds should still win
    ?assertEqual(
        ValueB,
        babel_map:get_value(<<"s">>, Map5)
    ).


nested_update(_) ->
    Data0 = #{<<"AAAAA">> => 1, <<"BBBBB">> => 2},
    Map = babel_map:new(Data0),
    Data1 = #{<<"AAAAA">> => undefined, <<"BBBBB">> => 3},
    Spec = #{'_' => {register, binary}},
    Result1 = babel_map:update(Data1, Map, Spec),
    ?assertEqual(
        #{<<"BBBBB">> => 3},
        babel_map:value(Result1)
    ).


nested_update_1(_) ->
    Spec = #{'_' => {register, integer}},
    Data0 = #{<<"AAAAA">> => 1, <<"BBBBB">> => 2},
    Map = babel_map:new(Data0, Spec),
    Data1 = #{<<"AAAAA">> => undefined, <<"BBBBB">> => 3},
    Result1 = babel_map:update(Data1, Map),
    ?assertEqual(
        #{<<"BBBBB">> => 3},
        babel_map:value(Result1)
    ).


huge_nested_update(_) ->
    Map0 = {babel_map,
    #{<<"account_id">> =>
    <<"mrn:account:business:2e677a54-70a0-4d7a-aba1-d6399f2c202a">>,
    <<"config">> =>
    {babel_map,
    #{<<"mileage_base">> =>
    {babel_map,
    #{<<"since_timestamp">> => 1629496719126,
    <<"timestamp">> => 1629496719126,<<"value">> => 0},
    [],[],undefined,
    {type_spec_ref,103621203}},
    <<"rebase_mileage">> =>
    {babel_map,
    #{<<"since_timestamp">> => 1629496719126,
    <<"timestamp">> => 1629496719126,
    <<"value">> => {babel_flag,false,disable,undefined}},
    [],[],undefined,
    {type_spec_ref,110194771}},
    <<"service_plan">> =>
    {babel_map,
    #{<<"name">> =>
    {babel_map,
    #{<<"since_timestamp">> => 1629496719126,
    <<"timestamp">> => 1629496719126,
    <<"value">> => <<"STRIX FLOTAS LOGISTICA CON RECUPERO">>},
    [],[],undefined,
    {type_spec_ref,113665}},
    <<"status">> =>
    {babel_map,
    #{<<"since_timestamp">> => 1629496719126,
    <<"timestamp">> => 1629496719126,<<"value">> => <<"active">>},
    [],[],undefined,
    {type_spec_ref,113665}}},
    [],[],undefined,
    {type_spec_ref,47253445}},
    <<"services">> =>
    {babel_map,
    #{<<"mrn:service:dual_sim_cl">> =>
    {babel_map,
    #{<<"status">> =>
    {babel_map,
    #{<<"since_timestamp">> => 1629814299997,
      <<"timestamp">> => 1629814299997,
      <<"value">> => <<"active">>},
    [],[],undefined,
    {type_spec_ref,113665}}},
    [],[],undefined,
    {type_spec_ref,110377532}},
    <<"mrn:service:dual_sim_uy">> =>
    {babel_map,
    #{<<"status">> =>
    {babel_map,
    #{<<"since_timestamp">> => 1629814299997,
      <<"timestamp">> => 1629814299997,
      <<"value">> => <<"active">>},
    [],[],undefined,
    {type_spec_ref,113665}}},
    [],[],undefined,
    {type_spec_ref,110377532}},
    <<"mrn:service:gps_recovery">> =>
    {babel_map,
    #{<<"status">> =>
    {babel_map,
    #{<<"since_timestamp">> => 1629496719126,
      <<"timestamp">> => 1629814299997,
      <<"value">> => <<"active">>},
    [],[],undefined,
    {type_spec_ref,113665}}},
    [],[],undefined,
    {type_spec_ref,110377532}},
    <<"mrn:service:gps_roaming">> =>
    {babel_map,
    #{<<"status">> =>
    {babel_map,
    #{<<"since_timestamp">> => 1629496719126,
      <<"timestamp">> => 1629814299997,
      <<"value">> => <<"active">>},
    [],[],undefined,
    {type_spec_ref,113665}}},
    [],[],undefined,
    {type_spec_ref,110377532}},
    <<"mrn:service:live_tracking">> =>
    {babel_map,
    #{<<"status">> =>
    {babel_map,
    #{<<"since_timestamp">> => 1629496719126,
      <<"timestamp">> => 1629814299997,
      <<"value">> => <<"active">>},
    [],[],undefined,
    {type_spec_ref,113665}}},
    [],[],undefined,
    {type_spec_ref,110377532}},
    <<"mrn:service:recovery">> =>
    {babel_map,
    #{<<"status">> =>
    {babel_map,
    #{<<"since_timestamp">> => 1629496719126,
      <<"timestamp">> => 1629814299997,
      <<"value">> => <<"active">>},
    [],[],undefined,
    {type_spec_ref,113665}}},
    [],[],undefined,
    {type_spec_ref,110377532}},
    <<"mrn:service:vlu_recovery">> =>
    {babel_map,
    #{<<"status">> =>
    {babel_map,
    #{<<"since_timestamp">> => 1629496719126,
      <<"timestamp">> => 1629814299997,
      <<"value">> => <<"active">>},
    [],[],undefined,
    {type_spec_ref,113665}}},
    [],[],undefined,
    {type_spec_ref,110377532}}},
    [],[],undefined,
    {type_spec_ref,72946098}}},
    [],[],undefined,
    {type_spec_ref,32197808}},
    <<"created_by">> => <<"mrn:person:5f201f21-c29e-4eb7-aaae-68fa159f29dc">>,
    <<"created_timestamp">> => 1629496719126,
    <<"id">> => <<"mrn:thing:vehicle:8f276b10-85bc-4e2d-90ed-ebe521ce6c35">>,
    <<"info">> =>
    {babel_map,
    #{<<"chassis_number">> => <<"123456789">>,<<"color">> => <<"ROJO">>,
    <<"domain">> => <<"JWT002">>,<<"engine_number">> => <<"123456789">>,
    <<"label">> => <<"Test Vehicle 2">>,<<"make">> => <<"FORD">>,
    <<"mileage_reading">> => 0,<<"model">> => <<"T">>,
    <<"subtype">> => <<"car">>,<<"year">> => 2020},
    [],[],undefined,
    {type_spec_ref,37069971}},
    <<"last_modified_by">> =>
    <<"mrn:person:5f201f21-c29e-4eb7-aaae-68fa159f29dc">>,
    <<"last_modified_timestamp">> => 1629814299997,
    <<"private">> =>
    {babel_map,
    #{<<"unsaved_offsets">> => {babel_set,[],[],[],0,inherited}},
    [<<"unsaved_offsets">>],
    [],
    <<131,108,0,0,0,3,104,2,109,0,0,0,8,156,58,204,30,155,9,147,50,97,46,104,
    2,109,0,0,0,8,156,58,204,30,155,9,147,203,97,99,104,2,109,0,0,0,12,156,
    58,204,30,155,9,148,43,0,0,195,81,97,217,106>>,
    {type_spec_ref,112287443}},
    <<"reported_state">> =>
    {babel_map,
    #{<<"mileage">> =>
    {babel_map,
    #{<<"since_timestamp">> => 1629496719126,
    <<"timestamp">> => 1629496719126,<<"value">> => 0},
    [],[],undefined,
    {type_spec_ref,103621203}}},
    [],[],undefined,
    {type_spec_ref,102274909}},
    <<"type">> => <<"mrn:thing:vehicle">>},
    [<<"private">>],
    [],
    <<131,108,0,0,0,3,104,2,109,0,0,0,8,156,58,204,30,155,9,147,50,97,46,104,2,
    109,0,0,0,8,156,58,204,30,155,9,147,203,97,99,104,2,109,0,0,0,12,156,58,204,
    30,155,9,148,43,0,0,195,81,97,217,106>>,
    {type_spec_ref,90706316}
    },

    Spec = #{
        '$validated' => true,
    <<"account_id">> => {register,binary},
    <<"config">> =>
    {map,
    #{<<"mileage_base">> =>
    {map,
    #{<<"since_timestamp">> => {register,integer},
    <<"timestamp">> => {register,integer},
    <<"value">> => {register,integer}}},
    <<"rebase_mileage">> =>
    {map,
    #{<<"since_timestamp">> => {register,integer},
    <<"timestamp">> => {register,integer},
    <<"value">> => {flag,boolean}}},
    <<"reporting_frequency">> =>
    {map,
    #{<<"since_timestamp">> => {register,integer},
    <<"timestamp">> => {register,integer},
    <<"value">> => {register,integer}}},
    <<"service_plan">> =>
    {map,
    #{<<"name">> =>
    {map,
    #{<<"since_timestamp">> => {register,integer},
    <<"timestamp">> => {register,integer},
    <<"value">> => {register,binary}}},
    <<"status">> =>
    {map,
    #{<<"since_timestamp">> => {register,integer},
    <<"timestamp">> => {register,integer},
    <<"value">> => {register,binary}}}}},
    <<"services">> =>
    {map,
    #{'_' =>
    {map,
    #{<<"expiry_date">> =>
    {map,
    #{<<"since_timestamp">> => {register,integer},
    <<"timestamp">> => {register,integer},
    <<"value">> => {register,binary}}},
    <<"status">> =>
    {map,
    #{<<"since_timestamp">> => {register,integer},
    <<"timestamp">> => {register,integer},
    <<"value">> => {register,binary}}}}}}}}},
    <<"created_by">> => {register,binary},
    <<"created_timestamp">> => {register,integer},
    <<"desired_state">> =>
    {map,
    #{<<"fuel_cut_off">> =>
    {map,
    #{<<"since_timestamp">> => {register,integer},
    <<"timestamp">> => {register,integer},
    <<"value">> => {flag,boolean}}}}},
    <<"id">> => {register,binary},
    <<"info">> =>
    {map,
    #{<<"category">> => {register,binary},
    <<"chassis_number">> => {register,binary},
    <<"color">> => {register,binary},
    <<"domain">> => {register,binary},
    <<"engine_number">> => {register,binary},
    <<"label">> => {register,binary},
    <<"make">> => {register,binary},
    <<"mileage_reading">> => {register,integer},
    <<"model">> => {register,binary},
    <<"subtype">> => {register,binary},
    <<"user_info">> => {map,#{'_' => {register,binary}}},
    <<"year">> => {register,integer}}},
    <<"is_deleted">> => {register,boolean},
    <<"last_modified_by">> => {register,binary},
    <<"last_modified_timestamp">> => {register,integer},
    <<"parent_id">> => {register,binary},
    <<"private">> =>
    {map,
    #{<<"commands">> => {map,#{'_' => {register,binary}}},
    <<"group">> => {register,binary},
    <<"last_sent">> => {map,#{'_' => {register,integer}}},
    <<"offset">> => {register,integer},
    <<"offset_queue">> => {set,integer},
    <<"offset_queue_length">> => {register,integer},
    <<"partition_id">> => {register,integer},
    <<"signal_id">> => {register,binary},
    <<"topic">> => {register,binary},
    <<"unsaved_offsets">> => {set,integer}}},
    <<"reported_state">> =>
    {map,
    #{<<"altitude">> =>
    {map,
    #{<<"since_timestamp">> => {register,integer},
    <<"timestamp">> => {register,integer},
    <<"value">> => {register,float}}},
    <<"contact_on">> =>
    {map,
    #{<<"since_timestamp">> => {register,integer},
    <<"timestamp">> => {register,integer},
    <<"value">> => {flag,boolean}}},
    <<"event_name">> =>
    {map,
    #{<<"since_timestamp">> => {register,integer},
    <<"timestamp">> => {register,integer},
    <<"value">> => {register,binary}}},
    <<"fuel_cut_off">> =>
    {map,
    #{<<"since_timestamp">> => {register,integer},
    <<"timestamp">> => {register,integer},
    <<"value">> => {flag,boolean}}},
    <<"heading">> =>
    {map,
    #{<<"since_timestamp">> => {register,integer},
    <<"timestamp">> => {register,integer},
    <<"value">> => {register,integer}}},
    <<"horizontal_accuracy">> =>
    {map,
    #{<<"since_timestamp">> => {register,integer},
    <<"timestamp">> => {register,integer},
    <<"value">> => {register,float}}},
    <<"in_motion">> =>
    {map,
    #{<<"since_timestamp">> => {register,integer},
    <<"timestamp">> => {register,integer},
    <<"value">> => {flag,boolean}}},
    <<"latitude">> =>
    {map,
    #{<<"since_timestamp">> => {register,integer},
    <<"timestamp">> => {register,integer},
    <<"value">> => {register,float}}},
    <<"longitude">> =>
    {map,
    #{<<"since_timestamp">> => {register,integer},
    <<"timestamp">> => {register,integer},
    <<"value">> => {register,float}}},
    <<"main_power_on">> =>
    {map,
    #{<<"since_timestamp">> => {register,integer},
    <<"timestamp">> => {register,integer},
    <<"value">> => {register,boolean}}},
    <<"mileage">> =>
    {map,
    #{<<"since_timestamp">> => {register,integer},
    <<"timestamp">> => {register,integer},
    <<"value">> => {register,integer}}},
    <<"odometer">> =>
    {map,
    #{<<"since_timestamp">> => {register,integer},
    <<"timestamp">> => {register,integer},
    <<"value">> => {register,integer}}},
    <<"speed">> =>
    {map,
    #{<<"since_timestamp">> => {register,integer},
    <<"timestamp">> => {register,integer},
    <<"value">> => {register,integer}}},
    <<"towing">> =>
    {map,
    #{<<"since_timestamp">> => {register,integer},
    <<"timestamp">> => {register,integer},
    <<"value">> => {flag,boolean}}},
    <<"vertical_accuracy">> =>
    {map,
    #{<<"since_timestamp">> => {register,integer},
    <<"timestamp">> => {register,integer},
    <<"value">> => {register,float}}}}},
    <<"things">> => {set,binary},
    <<"type">> => {register,binary},
    <<"version">> => {register,binary}
    },

    Path = [<<"config">>, <<"services">>, <<"mrn:service:dual_sim_cl">>],

    ?assertEqual(
        true,
        is_tuple(babel_map:get(Path, Map0))
    ),

    ?assertError(
        badkey,
        babel_map:get(Path, babel_map:remove(Path, Map0))
    ),

    Map1 = babel_map:update(
        #{
            <<"config">> => #{
                <<"services">> => #{
                    <<"mrn:service:dual_sim_cl">> => undefined
                }
            }
        },
        Map0,
        Spec
    ),
    ?assertError(
        badkey,
        babel_map:get(
            [<<"config">>, <<"services">>, <<"mrn:service:dual_sim_cl">>],
            Map1
        )
    ).

update_type_check(_) ->
    Spec = #{'_' => {register, binary}},
    M1 = babel_map:update(
        #{<<"foo">> => 3},
        babel_map:new(#{<<"foo">> => 1}),
        Spec
    ),
    ?assertEqual(
        #{<<"foo">> => 3},
        babel_map:value(M1)
    ),

    ?assertError(
        {badkeytype, 1, {register, binary}},
        babel_map:new(#{<<"foo">> => 1}, Spec)
    ),

    M2 = babel_map:update(
        #{<<"foo">> => 3},
        babel_map:new(#{<<"foo">> => <<"1">>}, Spec)
    ),
    ?assertEqual(
        #{<<"foo">> => 3},
        babel_map:value(M2)
    ).


nested_flags(_) ->
    Spec = #{
        <<"f">> => {flag, boolean},
        <<"m">> => {map, #{
            <<"f">> => {flag, boolean},
            <<"m">> => {map, #{
                <<"f">> => {flag, boolean}
            }}
        }}
    },
    M0 = babel_map:new(#{}, Spec),
    M1 = babel_map:put(<<"f">>, false, M0),
    M2 = babel_map:put([<<"m">>, <<"f">>], false, M1),

    ?assertEqual(false, babel_map:get_value([<<"f">>], M2)),
    ?assertEqual(false, babel_map:get_value([<<"m">>, <<"f">>], M2)),

    TypedBucket = {<<"index_data">>, <<"test">>},
    Key = <<"nested_flags">>,
    {ok, M3} = babel:put(TypedBucket, Key, M2, Spec, #{return_body => true}),

    ?assertEqual(false, babel_map:get_value([<<"f">>], M3)),
    ?assertEqual(false, babel_map:get_value([<<"m">>, <<"f">>], M3)),

    %% Set to true
    M4 = babel_map:put(<<"f">>, true, M3),
    M5 = babel_map:put([<<"m">>, <<"f">>], true, M4),

    ?assertEqual(true, babel_map:get_value([<<"f">>], M5)),
    ?assertEqual(true, babel_map:get_value([<<"m">>, <<"f">>], M5)),

    {ok, M6} = babel:put(TypedBucket, Key, M5, Spec, #{return_body => true}),
    {ok, M6} = babel:get(TypedBucket, Key, Spec, #{}),
    ?assertEqual(true, babel_map:get_value([<<"f">>], M6)),
    ?assertEqual(true, babel_map:get_value([<<"m">>, <<"f">>], M6)),

    %% Set to false
    M7 = babel_map:put(<<"f">>, false, M6),
    M8 = babel_map:put([<<"m">>, <<"f">>], false, M7),
    ?assertEqual(false, babel_map:get_value([<<"f">>], M8)),
    ?assertEqual(false, babel_map:get_value([<<"m">>, <<"f">>], M8)),


    {ok, M9} = babel:put(TypedBucket, Key, M8, Spec, #{return_body => true}),
    {ok, M9} = babel:get(TypedBucket, Key, Spec, #{}),
    ?assertEqual(false, babel_map:get_value([<<"f">>], M9)),
    ?assertEqual(false, babel_map:get_value([<<"m">>, <<"f">>], M9)),


    %% Set to true again
    M10 = babel_map:put(<<"f">>, true, M9),
    M11 = babel_map:put([<<"m">>, <<"f">>], true, M10),

    ?assertEqual(true, babel_map:get_value([<<"f">>], M11)),
    ?assertEqual(true, babel_map:get_value([<<"m">>, <<"f">>], M11)),

    {ok, M12} = babel:put(TypedBucket, Key, M11, Spec, #{return_body => true}),
    {ok, M12} = babel:get(TypedBucket, Key, Spec, #{}),
    ?assertEqual(true, babel_map:get_value([<<"f">>], M12)),
    ?assertEqual(true, babel_map:get_value([<<"m">>, <<"f">>], M12)).


