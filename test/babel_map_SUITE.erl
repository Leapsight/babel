-module(babel_map_SUITE).
-include_lib("common_test/include/ct.hrl").
-include_lib("stdlib/include/assert.hrl").

-export([all/0]).

-compile([nowarn_export_all, export_all]).


all() ->
    [
        create_test,
        create_test_2,
        to_riak_op_test,
        put_test,
        get_test
    ].



init_per_suite(Config) ->
    Env = [
        {babel, [
            {reliable_instances, ["test_1", "test_2", "test_3"]},
            {bucket_types, [
                {index_collection, <<"index_collection">>},
                {index_data, <<"index_data">>}
            ]}
        ]},
        {kernel, [
            {logger, [
                {handler, default, logger_std_h, #{
                    formatter => {logger_formatter, #{ }}
                }}
            ]}
        ]}
    ],
    application:set_env(Env),

    ok = babel_config:set(
        [bucket_types, index_collection], <<"index_collection">>),
    ok = babel_config:set(
        [bucket_types, index_data], <<"index_data">>),

    %% Start the application.
    application:ensure_all_started(reliable),
    application:ensure_all_started(babel),
    meck:unload(),

    ct:pal("Config ~p", [application:get_all_env(reliable)]),

    Config.

end_per_suite(Config) ->
    meck:unload(),
    {save_config, Config}.


create_test(_) ->
    %% dbg:tracer(), dbg:p(all,c),
    %% dbg:tpl(babel_map, '_', x),

    M = babel_map:new(data(), spec()),
    ?assertEqual(true, babel_map:is_type(M)).

create_test_2(_) ->
    %% dbg:tracer(), dbg:p(all,c),
    %% dbg:tpl(babel_map, '_', x),

    M = babel_map:new(data1(), spec()),
    ?assertEqual(true, babel_map:is_type(M)).


to_riak_op_test(_) ->
    M = babel_map:new(data(), spec()),
    Op = babel_map:to_riak_op(M, spec()),
    ?assertEqual(true, is_tuple(Op)).


put_test(_) ->
    M0 = babel_map:new(data(), spec()),
    {ok, Conn} = riakc_pb_socket:start_link("127.0.0.1", 8087),
    pong = riakc_pb_socket:ping(Conn),

    Opts = #{return_body => true, connection => Conn},

    ?assertEqual(false, babel_reliable:is_in_workflow()),

    {ok, M1} = babel:put(
        {<<"index_data">>, <<"test">>},<<"to_riak_op_test">>, M0, spec(), Opts
    ),
    ?assertEqual(true, babel_map:is_type(M1)).


get_test(_) ->
    {ok, Conn} = riakc_pb_socket:start_link("127.0.0.1", 8087),
    pong = riakc_pb_socket:ping(Conn),
    {ok, M} = babel:get(
        {<<"index_data">>, <<"test">>},
        <<"to_riak_op_test">>,
        spec(),
        #{connection => Conn}
    ),
    ?assertEqual(true, babel_map:is_type(M)).



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


spec() ->
    #{
        {<<"version">>, register} => binary,
        {<<"id">>, register} => binary,
        {<<"account_type">>, register} => binary,
        {<<"name">>, register} => binary,
        {<<"active">>, register} => boolean,
        {<<"operation_mode">>, register} => binary,
        {<<"country_id">>, register} => binary,
        {<<"number">>, register} => binary,
        {<<"identification_type">>, register} => binary,
        {<<"identification_number">>, register} => binary,
        {<<"address">>, map} => #{
            {<<"address_line1">>, register} => binary,
            {<<"address_line2">>, register} => binary,
            {<<"city">>, register} => binary,
            {<<"state">>, register} => binary,
            {<<"country">>, register} => binary,
            {<<"postal_code">>, register} => binary
        },
        %% emails and phones are stored as maps of their values to their tag
        %% value e.g. #{<<"john.doe@example.com">> => <<"work">>}
        %% {register, binary} means "every key in the phones | emails map has
        %% a register associated and we keep the value of the registry as a
        %% binary
        {<<"emails">>, map} => #{{'_', register} => binary},
        {<<"phones">>, map} => #{{'_', register} => binary},
        %% services is a mapping of serviceID to service objects
        %% e.g. #{<<"mrn:service:1">> => #{<<"description">> => ...}
        %% {map, #{..}} means "every key in the services map has a map
        %% associated with it which is always of the same type, in this case a
        %% map with 3 properties: description, expired_data and enabled"
        {<<"services">>, map} => #{{'_', map} => #{
            {<<"description">>, register} => binary,
            {<<"expiry_date">>, register} => binary,
            {<<"enabled">>, register} => boolean
        }},
        {<<"created_by">>, register} => binary,
        {<<"last_modified_by">>, register} => binary,
        {<<"created_timestamp">>, register} => integer,
        {<<"last_modified_timestamp">>, register} => integer
    }.