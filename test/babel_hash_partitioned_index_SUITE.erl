-module(babel_hash_partitioned_index_SUITE).
-include_lib("eunit/include/eunit.hrl").
-compile(export_all).



all() ->
    [
        index_1_test,
        index_2_test,
        index_3_test,
        index_4_test,
        huge_index_test
    ].


init_per_suite(Config) ->
    ok = babel_config:set(
        [bucket_types, index_collection], <<"index_collection">>),
    ok = babel_config:set(
        [bucket_types, index_data], <<"index_data">>),

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
            partition_by => [{<<"email">>, register}],
            index_by => [{<<"email">>, register}],
            covered_fields => [{<<"user_id">>, register}]
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
            partition_by => [{<<"email">>, register}],
            index_by => [{<<"email">>, register}],
            covered_fields => [
                {<<"user_id">>, register},
                {<<"account_id">>, register}
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
            partition_by => [{<<"email">>, register}],
            index_by => [{<<"email">>, register}],
            covered_fields => [{<<"user_id">>, register}]
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
            partition_by => [{<<"email">>, register}],
            aggregate_by => [{<<"post_code">>, register}],
            index_by => [
                {<<"post_code">>, register},
                {<<"email">>, register}
            ],
            covered_fields => [
                {<<"user_id">>, register},
                {<<"account_id">>, register}
            ]
        }
    },
    Index = babel_index:new(Conf),
    Partitions = babel_index:create_partitions(Index),
    ?assertEqual(8, length(Partitions)),
    ok.


huge_index_test(_) ->
    Conf = #{
        name => <<"users_by_post_code_and_email">>,
        bucket_type => <<"index_data">>,
        bucket_prefix => <<"babel_hash_partitioned_index_SUITE/johndoe">>,
        type => babel_hash_partitioned_index,
        config => #{
            sort_ordering => asc,
            number_of_partitions => 8,
            partition_algorithm => jch,
            partition_by => [{<<"post_code">>, register}],
            aggregate_by => [{<<"post_code">>, register}],
            index_by => [
                {<<"post_code">>, register},
                {<<"email">>, register}
            ],
            covered_fields => [
                {<<"user_id">>, register},
                {<<"account_id">>, register}
            ]
        }
    },

    Fun = fun() ->
        Index = babel_index:new(Conf),
        Collection0 = babel_index_collection:new(<<"mytenant">>, <<"users">>),
        _Collection1 = babel:create_index(Index, Collection0),
        ok
    end,

    {ok, _, _} =  babel:workflow(Fun),

    timer:sleep(5000),

    {ok, Conn} = riakc_pb_socket:start_link("127.0.0.1", 8087),
    pong = riakc_pb_socket:ping(Conn),

    RiakOpts = #{
        connection => Conn
    },


    Actions = [
        begin
            UserId = integer_to_binary(Y),
            AccId = integer_to_binary(X),
            %% PostCode = integer_to_binary(rand:uniform(100)),
            PostCode = AccId,

            %% Not a CRDT but becuase we use babel_key_value we can get away
            %% with it
            Obj = #{
                {<<"email">>, register} => <<UserId/binary, "@example.com">>,
                {<<"user_id">>, register} => <<"mrn:user:", UserId/binary>>,
                {<<"account_id">>, register} => <<"mrn:account:", AccId/binary>>,
                {<<"post_code">>, register} => <<"PC", PostCode/binary>>
            },
            {update, Obj}
        end || X <- lists:seq(1, 2), Y <- lists:seq(1, 5000)
    ],

    Fun2 = fun() ->
        %% We fetch the collection from Riak KV
        Collection = babel_index_collection:fetch(
            <<"mytenant">>, <<"users">>, RiakOpts
        ),
        ok = babel:update_indices(Actions, Collection, RiakOpts),
        ok
    end,

    {ok, _, ok} =  babel:workflow(Fun2),

    timer:sleep(15000),

    Collection = babel_index_collection:fetch(
        <<"mytenant">>, <<"users">>, RiakOpts
    ),
    Index = babel_index_collection:index(
        <<"users_by_post_code_and_email">>, Collection),

    Pattern1 = #{
        {<<"post_code">>, register} => <<"PC1">>
    },
    Res1 = babel_index:match(Pattern1, Index, RiakOpts),
    ?assertEqual(5000, length(Res1)),

    Pattern2 = #{
        {<<"post_code">>, register} => <<"PC1">>,
        {<<"email">>, register} => <<"1@example.com">>
    },
    Res2 = babel_index:match(Pattern2, Index, RiakOpts),
    ?assertEqual(1, length(Res2)),

    ?assertEqual(
        [{<<"account_id">>, register}, {<<"user_id">>, register}],
        maps:keys(hd(Res2))
    ),

    ok.