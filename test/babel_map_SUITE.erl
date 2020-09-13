-module(babel_map_SUITE).
-include_lib("common_test/include/ct.hrl").
-include_lib("stdlib/include/assert.hrl").

-export([all/0]).

-compile([nowarn_export_all, export_all]).


all() ->
    [
        create_test,
        fetch_test
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
    M = babel_map:new(data()),
    ?assertEqual(true, babel_map:is_type(M)).


fetch_test(_) ->
    ok.



%% =============================================================================
%% RESOURCES
%% =============================================================================




data() ->
    #{
        <<"version">> => <<"2.0">>,
        <<"id">> => <<"mrn:business_account:1">>,
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
        <<"emails">> => [
            #{
                <<"email">> =><<"john.doe@foo.com">>,
                <<"tage">> => <<"work">>
            }
        ],
        <<"phones">> =>  [
            #{
                <<"number">> => <<"09823092834">>,
                <<"tage">> => <<"work">>
            }
        ],
        <<"services">> => [
            #{
                <<"enabled">> => true,
                <<"description">> => <<"Baz Service">>,
                <<"expiry_date">> => <<"2020/10/09">>
            }
        ],
        <<"username">> => <<"john.doe@foo.com">>,
        <<"owner_id">> => <<"mrn:user:1">>,
        <<"created_by">> => <<"mrn:user:1">>,
        <<"last_modified_by">> => <<"mrn:user:1">>,
        <<"created_timestamp">> => 1599835691640,
        <<"last_modified_timestamp">> => 1599835691640
    }.

spec() ->
    #{
        {<<"version">>, register} => binary,
        {<<"id">>, register} => binary,
        {<<"name">>, register} => binary,
        {<<"active">>, register} => boolean,
        {<<"operation_mode">>, register} => boolean,
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
        %% decode #{Email => Tag} --> [{email => Email, tag => Tag}]
        %% encode [{number => Email, tag => Tag}] --> #{Email => Tag}
        {<<"emails">>, map} => {register, binary},
        {<<"phones">>, map} => {register, binary},
        {<<"services">>, map} => {register, #{
            {<<"enabled">>, flag} => boolean,
            {<<"expiry_date">>, register} => binary
        }},
        {<<"username">>, register} => binary,
        {<<"owner_id">>, register} => binary,
        {<<"created_by">>, register} => binary,
        {<<"last_modified_by">>, register} => binary,
        {<<"created_timestamp">>, register} => integer,
        {<<"last_modified_timestamp">>, register} => integer
    }.