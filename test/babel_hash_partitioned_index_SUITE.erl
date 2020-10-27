-module(babel_hash_partitioned_index_SUITE).
-include_lib("eunit/include/eunit.hrl").
-compile(export_all).
-compile([nowarn_export_all, export_all]).



all() ->
    [
        index_1_test,
        index_2_test,
        index_3_test,
        index_4_test,
        %% huge_index_test,
        accounts_by_identification_type_and_number_test
    ].


init_per_suite(Config) ->
    ok = common:setup(),
    Config.

end_per_suite(Config) ->
    {save_config, Config}.


index_1_test(_) ->
    Conf = #{
        name => <<"users_by_email">>,
        bucket_type => <<"index_data">>,
        bucket_prefix => <<"babel_hash_partitioned_index_SUITE/johndoe">>,
        type => babel_hash_partitioned_index,
        config => #{
            sort_ordering => asc,
            number_of_partitions => 8,
            partition_algorithm => jch,
            partition_by => [<<"email">>],
            index_by => [<<"email">>],
            covered_fields => [<<"user_id">>]
        }
    },
    Index = babel_index:new(Conf),

    CRDT = babel_index:to_riak_object(Index),
    ?assertEqual(true, riakc_map:is_type(CRDT)),

    Partitions = babel_index:create_partitions(Index),
    ?assertEqual(8, length(Partitions)),
    ok.


index_2_test(_) ->
    Conf = #{
        name => <<"users_by_email">>,
        bucket_type => <<"index_data">>,
        bucket_prefix => <<"babel_hash_partitioned_index_SUITE/johndoe">>,
        type => babel_hash_partitioned_index,
        config => #{
            sort_ordering => asc,
            number_of_partitions => 8,
            partition_algorithm => jch,
            partition_by => [<<"email">>],
            index_by => [<<"email">>],
            covered_fields => [
                <<"user_id">>,
                <<"account_id">>
            ]
        }
    },
    Index = babel_index:new(Conf),
    Partitions = babel_index:create_partitions(Index),
    ?assertEqual(8, length(Partitions)),
    ok.


index_3_test(_) ->
    Conf = #{
        name => <<"users_by_email">>,
        bucket_type => <<"index_data">>,
        bucket_prefix => <<"babel_hash_partitioned_index_SUITE/johndoe">>,
        type => babel_hash_partitioned_index,
        config => #{
            sort_ordering => asc,
            number_of_partitions => 8,
            partition_algorithm => jch,
            partition_by => [<<"email">>],
            index_by => [<<"email">>],
            covered_fields => [<<"user_id">>]
        }
    },
    Index = babel_index:new(Conf),
    Partitions = babel_index:create_partitions(Index),
    ?assertEqual(8, length(Partitions)),
    ok.


index_4_test(_) ->
    Conf = #{
        name => <<"users_by_post_code_and_email">>,
        bucket_type => <<"index_data">>,
        bucket_prefix => <<"babel_hash_partitioned_index_SUITE/johndoe">>,
        type => babel_hash_partitioned_index,
        config => #{
            sort_ordering => asc,
            number_of_partitions => 8,
            partition_algorithm => jch,
            partition_by => [<<"email">>],
            aggregate_by => [<<"post_code">>],
            index_by => [
                <<"post_code">>,
                <<"email">>
            ],
            covered_fields => [
                <<"user_id">>,
                <<"account_id">>
            ]
        }
    },
    Index = babel_index:new(Conf),
    Partitions = babel_index:create_partitions(Index),
    ?assertEqual(8, length(Partitions)),
    ok.


huge_index_test(_) ->
    %% We create the Index config
    Conf = #{
        name => <<"users_by_post_code_and_email">>,
        bucket_type => <<"index_data">>,
        bucket_prefix => <<"babel_hash_partitioned_index_SUITE/johndoe">>,
        type => babel_hash_partitioned_index,
        config => #{
            sort_ordering => asc,
            number_of_partitions => 8,
            partition_algorithm => jch,
            partition_by => [<<"post_code">>],
            aggregate_by => [<<"post_code">>],
            index_by => [
                <<"post_code">>,
                <<"email">>
            ],
            covered_fields => [
                <<"user_id">>,
                <<"account_id">>
            ]
        }
    },

    %% We schedule the creation of a new collection and we add the index
    Fun = fun() ->
        Index = babel_index:new(Conf),
        Collection0 = babel_index_collection:new(<<"babel_test">>, <<"users">>),
        _Collection1 = babel:create_index(Index, Collection0),
        ok
    end,

    {scheduled, _, ok} =  babel:workflow(Fun),

    %% we wait 5 secs for reliable to perform the work
    timer:sleep(5000),


    {ok, Conn} = riakc_pb_socket:start_link("127.0.0.1", 8087),
    pong = riakc_pb_socket:ping(Conn),

    RiakOpts = #{
        connection => Conn
    },

    %% We create 10,000 objects to be indexed
    Actions = [
        begin
            UserId = integer_to_binary(Y),
            AccId = integer_to_binary(X),
            %% PostCode = integer_to_binary(rand:uniform(100)),
            PostCode = AccId,

            %% Not a CRDT but becuase we use babel_key_value we can get away
            %% with it
            Obj = #{
                <<"email">> => <<UserId/binary, "@example.com">>,
                <<"user_id">> => <<"mrn:user:", UserId/binary>>,
                <<"account_id">> => <<"mrn:account:", AccId/binary>>,
                <<"post_code">> => <<"PC", PostCode/binary>>
            },
            {update, Obj}
        end || X <- lists:seq(1, 2), Y <- lists:seq(1, 5000)
    ],

    Fun2 = fun() ->
        %% We fetch the collection from Riak KV
        Collection = babel_index_collection:fetch(
            <<"babel-test">>, <<"users">>, RiakOpts
        ),
        ok = babel:update_indices(Actions, Collection, RiakOpts),
        ok
    end,

    {scheduled, _, ok} =  babel:workflow(Fun2),

    timer:sleep(5000),

    Collection = babel_index_collection:fetch(
        <<"babel-test">>, <<"users">>, RiakOpts
    ),
    Index = babel_index_collection:index(
        <<"users_by_post_code_and_email">>, Collection),

    Pattern1 = #{
        <<"post_code">> => <<"PC1">>
    },
    Res1 = babel_index:match(Pattern1, Index, RiakOpts),
    ?assertEqual(5000, length(Res1)),

    Pattern2 = #{
        <<"post_code">> => <<"PC1">>,
        <<"email">> => <<"1@example.com">>
    },
    Res2 = babel_index:match(Pattern2, Index, RiakOpts),
    ?assertEqual(1, length(Res2)),

    ?assertEqual(
        [<<"account_id">>, <<"user_id">>],
        maps:keys(hd(Res2))
    ),

    ok.


accounts_by_identification_type_and_number_test(_) ->
    BucketPrefix = <<"babel-test">>,
    Accounts = <<"accounts">>,
    IndexName = <<"accounts_by_identification_type_and_number">>,

    {ok, Conn} = riakc_pb_socket:start_link("127.0.0.1", 8087),
    pong = riakc_pb_socket:ping(Conn),

    RiakOpts = #{
        connection => Conn
    },

    Create = fun() ->
        Conf = #{
            name => IndexName,
            bucket_type => <<"index_data">>,
            bucket_prefix => BucketPrefix,
            type => babel_hash_partitioned_index,
            config => #{
                sort_ordering => asc,
                number_of_partitions => 128,
                partition_algorithm => jch,
                partition_by => [
                    <<"identification_type">>,
                    <<"identification_number">>
                ],
                index_by => [
                    <<"identification_type">>,
                    <<"identification_number">>
                ],
                covered_fields => [<<"account_id">>]
            }
        },
        Index = babel_index:new(Conf),
        Collection = babel_index_collection:new(BucketPrefix, Accounts),
        _ = babel:create_index(Index, Collection),
        ok
    end,
    {scheduled, _, ok} = babel:workflow(Create),

    timer:sleep(10000),

    Update = fun() ->
        Actions = [
            begin
                ID = integer_to_binary(X),
                Obj = #{
                    <<"identification_type">> => Type,
                    <<"identification_number">> => ID,
                    <<"account_id">> => <<"mrn:account:", ID/binary>>
                },
                {update, Obj}
            end || Type <- [<<"DNI">>, <<"CUIL">>], X <- lists:seq(1, 5000)
        ],

        Collection = babel_index_collection:fetch(
            BucketPrefix, Accounts, RiakOpts),
        _Index = babel_index_collection:index(IndexName, Collection),
        ok = babel:update_indices(Actions, Collection, RiakOpts),
        ok
    end,

    Ts0 = erlang:system_time(millisecond),

    {scheduled, _, ok} = babel:workflow(Update, #{timeout => 5000}),
    Ts1 = erlang:system_time(millisecond),
    ct:pal("elapsed_time_secs = ~p", [(Ts1 - Ts0) / 1000]),
    timer:sleep(15000),

    Collection = babel_index_collection:fetch(BucketPrefix, Accounts, RiakOpts),
    Idx = babel_index_collection:index(IndexName, Collection),

    Pattern = #{
        <<"identification_type">> => <<"DNI">>,
        <<"identification_number">> => <<"1">>
    },

    Res = babel_index:match(Pattern, Idx, RiakOpts),
    ?assertEqual(1, length(Res)),
    ok.