-module(babel_hash_partitioned_index_SUITE).
-include_lib("common_test/include/ct.hrl").
-include_lib("stdlib/include/assert.hrl").
-compile(export_all).
-compile([nowarn_export_all, export_all]).


groups() ->
    [
        {accounts_by_id_one, [sequence], [
            accounts_by_id_create,
            accounts_by_id_update
        ]},
        {accounts_by_id_many, [sequence], [
            accounts_by_id_many_test
        ]}
    ].


all() ->
    [
        bad_index_test,
        index_1_test,
        index_2_test,
        index_3_test,
        index_4_test,
        index_5_test,
        index_6_test,
        distinguished_key_paths_1_test,
        huge_index_test,
        {group, accounts_by_id_one},
        {group, accounts_by_id_many}
    ].


init_per_suite(Config) ->
    ok = common:setup(),
    Config.

end_per_suite(_) ->
    ok.


bad_index_test(_) ->
    Empty = [],
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
            index_by => Empty,
            covered_fields => [<<"user_id">>]
        }
    },
    ?assertError(#{code := invalid_value}, babel_index:new(Conf)).


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

index_5_test(_) ->
    Prefix = <<"babel-test">>,
    IdxName = <<"persons">>,
    Conf = #{
        name => <<"persons_by_account">>,
        bucket_type => <<"index_data">>,
        bucket_prefix => <<"babel_hash_partitioned_index_SUITE/johndoe">>,
        type => babel_hash_partitioned_index,
        config => #{
            sort_ordering => asc,
            number_of_partitions => 8,
            partition_algorithm => jch,
            partition_by => [
                <<"account_id">>
            ],
            index_by => [
                <<"account_id">>
            ],
            %% aggregate_by => [
            %%     <<"account_id">>
            %% ],
            covered_fields => [<<"id">>]
        }
    },

    {ok, Conn} = riakc_pb_socket:start_link("127.0.0.1", 8087),
    pong = riakc_pb_socket:ping(Conn),

    BabelOpts = #{connection => Conn},

    %% Cleanup previous runs
    Cleanup = fun() ->
        case babel_index_collection:lookup(Prefix, IdxName, BabelOpts) of
            {ok, Collection} ->
                case babel_index_collection:is_index(IdxName, Collection) of
                    true ->
                        _ = babel:drop_index(IdxName, Collection),
                        ok;
                    false ->
                        ok
                end;
            _ ->
                ok
        end
    end,
    _ = babel:workflow(Cleanup),
    %% we wait 5 secs for reliable to perform the work
    timer:sleep(5000),

    %% We schedule the creation of a new collection and we add the index
    Create = fun() ->
        Index = babel_index:new(Conf),
        Collection0 = babel_index_collection:new(
            Prefix, IdxName
        ),
        {true, #{is_nested := true}} = babel:create_index(Index, Collection0),
        ok
    end,
    {true, #{work_ref := WorkRef2, result := ok}} = babel:workflow(Create),
    %% we wait 5 secs for reliable to perform the work
    {ok, _} = babel:yield(WorkRef2, 5000),



    %% We create 10 objects to be indexed
    Actions = [
        begin
            UserId = integer_to_binary(X),
            AccId = integer_to_binary(X),
            Obj = #{
                <<"id">> => <<"mrn:person:", UserId/binary>>,
                <<"account_id">> => <<"mrn:account:", AccId/binary>>
            },
            {insert, Obj}
        end || X <- lists:seq(1, 2)
    ],

    Update = fun() ->
        %% We fetch the collection from Riak KV
        Collection = babel_index_collection:fetch(Prefix, IdxName, BabelOpts),
        {true, #{is_nested := true}} = babel:update_all_indices(
            Actions,
            Collection,
            BabelOpts#{force => true} % as Obj is not a babel_map
        ),
        ok
    end,

    {true, #{work_ref := WorkRef3, result := ok}} = babel:workflow(Update),
    {ok, _} = babel:yield(WorkRef3, 10000),

    Collection = babel_index_collection:fetch(Prefix, IdxName, BabelOpts),
    Index = babel_index_collection:index(
        <<"persons_by_account">>, Collection),

    Pattern = #{
        <<"account_id">> =>  <<"mrn:account:2">>
    },

    ?assertEqual(
        [#{<<"id">> => <<"mrn:person:2">>}],
        babel_index:match(Pattern, Index, BabelOpts)
    ),
    ok.


huge_index_test(_) ->
    %% We create the Index config

    Prefix = <<"babel-test">>,
    CName = <<"users">>,
    IdxName = <<"users_by_post_code_and_email">>,

    Conf = #{
        name => IdxName,
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

    {ok, Conn} = riakc_pb_socket:start_link("127.0.0.1", 8087),
    pong = riakc_pb_socket:ping(Conn),

    BabelOpts = #{connection => Conn},

    %% Cleanup previous runs
    Cleanup = fun() ->
        case babel_index_collection:lookup(Prefix, CName, BabelOpts) of
            {ok, Collection} ->
                case babel_index_collection:is_index(IdxName, Collection) of
                    true ->
                        _ = babel:drop_index(IdxName, Collection),
                        ok;
                    false ->
                        ok
                end;
            _ ->
                ok
        end
    end,
    _ = babel:workflow(Cleanup),
    %% we wait 5 secs for reliable to perform the work
    timer:sleep(10000),

    %% We schedule the creation of a new collection and we add the index
    Fun = fun() ->
        Index = babel_index:new(Conf),
        Collection0 = babel_index_collection:new(Prefix, CName),
        {true, #{is_nested := true}} = babel:create_index(Index, Collection0),
        ok
    end,

    {true, #{work_ref := WorkRef2, result := ok}} = babel:workflow(Fun),
    %% we wait 5 secs for reliable to perform the work
    {ok, _} = babel:yield(WorkRef2, 10000),


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
            {insert, Obj}
        end || X <- lists:seq(1, 2), Y <- lists:seq(1, 5000)
    ],

    Fun2 = fun() ->
        %% We fetch the collection from Riak KV
        Collection = babel_index_collection:fetch(Prefix, CName, BabelOpts),
        {true, #{is_nested := true}} = babel:update_all_indices(
            Actions,
            Collection,
            BabelOpts#{force => true} % as Obj is not a babel_map
        ),
        ok
    end,

    {true, #{work_ref := WorkRef, result := ok}} = babel:workflow(Fun2),
    {ok, _} = babel:yield(WorkRef, 15000),

    Collection = babel_index_collection:fetch(Prefix, CName, BabelOpts),
    Index = babel_index_collection:index(IdxName, Collection),

    Pattern1 = #{
        <<"post_code">> => <<"PC1">>
    },

    Res1 = babel_index:match(Pattern1, Index, BabelOpts),
    ?assertEqual(5000, length(Res1)),
    Pattern2 = #{
        <<"post_code">> => <<"PC1">>,
        <<"email">> => <<"1@example.com">>
    },
    Res2 = babel_index:match(Pattern2, Index, BabelOpts),
    ?assertEqual(1, length(Res2)),

    ?assertEqual(
        [<<"account_id">>, <<"user_id">>],
        maps:keys(hd(Res2))
    ),

    ok.


index_6_test(_) ->
    Prefix = <<"babel-test">>,
    IdxName = <<"persons">>,
    CName = <<"many">>,
    Conf = #{
        name => <<"persons_by_account">>,
        bucket_type => <<"index_data">>,
        bucket_prefix => <<"babel_hash_partitioned_index_SUITE/johndoe">>,
        type => babel_hash_partitioned_index,
        config => #{
            cardinality => many, %% <<<<<<<<<<<<<<<<<<<<<<<<<<<<
            sort_ordering => asc,
            number_of_partitions => 8,
            partition_algorithm => jch,
            partition_by => [
                <<"account_id">>
            ],
            index_by => [
                <<"account_id">>, <<"foo">>
            ],
            aggregate_by => [
                <<"account_id">>
            ],
            covered_fields => [<<"id">>]
        }
    },

    {ok, Conn} = riakc_pb_socket:start_link("127.0.0.1", 8087),
    pong = riakc_pb_socket:ping(Conn),

    BabelOpts = #{connection => Conn},

    %% Cleanup previous runs
    Cleanup = fun() ->
        case babel_index_collection:lookup(Prefix, CName, BabelOpts) of
            {ok, Collection} ->
                case babel_index_collection:is_index(IdxName, Collection) of
                    true ->
                        {true, #{is_nested := true}} = babel:drop_index(
                            IdxName, Collection
                        ),
                        ok;
                    false ->
                        ok
                end;
            _ ->
                ok
        end
    end,
    _ = babel:workflow(Cleanup),
    %% we wait 5 secs for reliable to perform the work
    timer:sleep(5000),

    %% We schedule the creation of a new collection and we add the index
    Create = fun() ->
        Index = babel_index:new(Conf),
        Collection0 = babel_index_collection:new(
            Prefix, CName
        ),
        {true, #{is_nested := true}} = babel:create_index(Index, Collection0),
        ok
    end,
    {true, #{work_ref := WorkRef2, result := ok}} = babel:workflow(Create),
    {ok, _} = babel:yield(WorkRef2, 5000),



    %% We create 10 objects to be indexed
    Actions = [
        begin
            UserId = integer_to_binary(X),
            AccId = integer_to_binary(Y),
            Obj = #{
                <<"id">> => <<"mrn:person:", UserId/binary>>,
                <<"foo">> => <<"bar">>,
                <<"account_id">> => <<"mrn:account:", AccId/binary>>
            },
            {insert, Obj}
        end || X <- [1, 2], Y <- [1, 2] %% duplicates
    ],

    Update = fun() ->
        %% We fetch the collection from Riak KV
        Collection = babel_index_collection:fetch(Prefix, CName, BabelOpts),
        {true, #{is_nested := true}} = babel:update_all_indices(
            Actions,
            Collection,
            BabelOpts#{force => true} % as Obj is not a babel_map
            ),
        ok
    end,

    {true, #{work_ref := WorkRef3, result := ok}} = babel:workflow(Update),
    {ok, _} = babel:yield(WorkRef3, 10000),

    Collection = babel_index_collection:fetch(Prefix, CName, BabelOpts),
    Index = babel_index_collection:index(
        <<"persons_by_account">>, Collection),

    Pattern = #{
        <<"account_id">> =>  <<"mrn:account:2">>
    },

    Result = babel_index:match(Pattern, Index, BabelOpts),
    ?assertEqual(
        2,
        length(Result)
    ),
    ok.

distinguished_key_paths_1_test(_) ->

    Conf = #{
        name => <<"users_by_email">>,
        bucket_type => <<"index_data">>,
        bucket_prefix => <<"babel_hash_partitioned_index_SUITE/johndoe">>,
        type => babel_hash_partitioned_index,
        config => #{
            sort_ordering => asc,
            number_of_partitions => 8,
            partition_algorithm => jch,
            partition_by => [<<"a">>, [<<"b">>, <<"ba">>]],
            index_by => [<<"a">>],
            covered_fields => [<<"b">>, [<<"c">>, <<"ca">>]]
        }
    },
    Index = babel_index:new(Conf),
    ?assertEqual(
        lists:usort([
            <<"a">>,
            <<"b">>,
            [<<"b">>, <<"ba">>],
            [<<"c">>, <<"ca">>]
        ]),
        babel_index:distinguished_key_paths(Index)
    ).


accounts_by_id_create(_) ->
    Prefix = <<"babel-test">>,
    CName = <<"accounts">>,
    IdxName = <<"accounts_by_identification_type_and_number">>,

    {ok, Conn} = riakc_pb_socket:start_link("127.0.0.1", 8087),
    pong = riakc_pb_socket:ping(Conn),

    GetOpts = #{connection => Conn},

    %% Cleanup previous runs
    Cleanup = fun() ->
        case babel_index_collection:lookup(Prefix, CName, GetOpts) of
            {ok, Collection} ->
                case babel_index_collection:is_index(IdxName, Collection) of
                    true ->
                        _ = babel:drop_index(IdxName, Collection),
                        ok;
                    false ->
                        ok
                end;
            _ ->
                ok
        end
    end,
    case babel:workflow(Cleanup) of
        {true, #{work_ref := WorkRef1}} ->
            {ok, _} = babel:yield(WorkRef1, 5000),
            ok;
        _ ->
            ok
    end,

    Create = fun() ->
        Conf = #{
            name => IdxName,
            bucket_type => <<"index_data">>,
            bucket_prefix => Prefix,
            type => babel_hash_partitioned_index,
            config => #{
                sort_ordering => asc,
                number_of_partitions => 128,
                partition_algorithm => jch,
                cardinality => one,
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
        Collection = babel_index_collection:new(Prefix, CName),
        {true, #{is_nested := true}} = babel:create_index(Index, Collection),
        ok
    end,
    {true, #{work_ref := WorkRef2, result := ok}} = babel:workflow(Create),
    {ok, _} = babel:yield(WorkRef2, 5000),

    Update = fun() ->
        Actions = [
            begin
                ID = integer_to_binary(X),
                Obj = #{
                    <<"identification_type">> => <<"DNI">>,
                    <<"identification_number">> => ID,
                    <<"account_id">> => <<"mrn:account:1">>
                },
                {insert, Obj}
            end || X <- lists:seq(1, 10)
        ],

        Collection = babel_index_collection:fetch(Prefix, CName, GetOpts),
        _Index = babel_index_collection:index(IdxName, Collection),
        {true, #{is_nested := true}} = babel:update_all_indices(
            Actions,
            Collection,
            GetOpts#{force => true} % as Obj is not a babel_map
        ),
        ok
    end,
    {true, #{work_ref := WorkRef3, result := ok}} = babel:workflow(
        Update, #{timeout => 5000}
    ),
    {ok, _} = babel:yield(WorkRef3, 15000),

    Collection = babel_index_collection:fetch(Prefix, CName, GetOpts),
    Index = babel_index_collection:index(IdxName, Collection),

    Pattern = #{
        <<"identification_type">> => <<"DNI">>,
        <<"identification_number">> => <<"1">>
    },
    Res = babel_index:match(Pattern, Index, GetOpts),
    ?assertEqual(1, length(Res)),

    NewConfig = [{collection, Collection}, {index, Index}],
    {save_config, NewConfig}.



accounts_by_id_update(Config) ->
    {_, OldConfig} = ?config(saved_config, Config),
    Collection = ?config(collection, OldConfig),
    Index = ?config(index, OldConfig),


    Old = {babel_map,
        #{
            <<"account_id">> => <<"mrn:account:1">>,
            <<"identification_type">> => <<"DNI">>,
            <<"identification_number">> => <<"1">>
        },
        [], % no updates
        [], % no removes
        undefined
    },
    New = {babel_map,
        #{
            <<"account_id">> => <<"mrn:account:1">>,
            <<"foo">> => 1
        },
        [<<"foo">>], % no updates
        [<<"identification_type">>, <<"identification_number">>],
        undefined
    },
    Actions = [{update, Old, New}],

    {true, #{
        work_ref := WorkRef,
        result := Updated
    }} = babel:update_all_indices(
        Actions,
        Collection,
        #{}
    ),
    %% We should have updated the two indices in the collection
    ?assertEqual(2, length(Updated)),
    {ok, _} = babel:yield(WorkRef, 10000),

    %% No ops on this index
    Pattern = #{
        <<"identification_type">> => <<"DNI">>,
        <<"identification_number">> => <<"1">>
    },
    Res = babel_index:match(Pattern, Index, #{}),
    ?assertEqual(0, length(Res)),

    NewConfig = [{collection, Collection}, {index, Index}],
    {save_config, NewConfig}.


accounts_by_id_many_test(_) ->
    Prefix = <<"babel-test">>,
    CName = <<"accounts">>,
    IdxName = <<"accounts_by_identification_type_and_number_many">>,

    {ok, Conn} = riakc_pb_socket:start_link("127.0.0.1", 8087),
    pong = riakc_pb_socket:ping(Conn),

    GetOpts = #{connection => Conn},

    %% Cleanup previous runs
    Cleanup = fun() ->
        case babel_index_collection:lookup(Prefix, CName, GetOpts) of
            {ok, Collection} ->
                case babel_index_collection:is_index(IdxName, Collection) of
                    true ->
                        _ = babel:drop_index(IdxName, Collection),
                        ok;
                    false ->
                        ok
                end;
            _ ->
                ok
        end
    end,
    case babel:workflow(Cleanup) of
        {true, #{work_ref := WorkRef1}} ->
            {ok, _} = babel:yield(WorkRef1, 5000),
            ok;
        _ ->
            ok
    end,

    Create = fun() ->
        Conf = #{
            name => IdxName,
            bucket_type => <<"index_data">>,
            bucket_prefix => Prefix,
            type => babel_hash_partitioned_index,
            config => #{
                sort_ordering => asc,
                number_of_partitions => 128,
                partition_algorithm => jch,
                cardinality => many,
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
        Collection = babel_index_collection:new(Prefix, CName),
        {true, #{is_nested := true}} = babel:create_index(Index, Collection),
        ok
    end,
    {true, #{work_ref := WorkRef2, result := ok}} = babel:workflow(Create),
    {ok, _} = babel:yield(WorkRef2, 5000),

    Update = fun() ->
        Actions = [
            begin
                ID = integer_to_binary(X),
                Rand = integer_to_binary(rand:uniform(100)),

                Obj = #{
                    <<"identification_type">> => <<"DNI">>,
                    <<"identification_number">> => ID,
                    <<"account_id">> => <<"mrn:account:", Rand/binary>>
                },
                {insert, Obj}
            end || X <- [1,1,2,2,3,3]
        ],

        Collection = babel_index_collection:fetch(
            Prefix, CName, GetOpts),
        _Index = babel_index_collection:index(IdxName, Collection),
        {true, #{is_nested := true}} = babel:update_all_indices(
            Actions,
            Collection,
            GetOpts#{force => true} % as Obj is not a babel_map
        ),
        ok
    end,

    {true, #{work_ref := WorkRef3, result := ok}} = babel:workflow(
        Update, #{timeout => 5000})
    ,
    {ok, _} = babel:yield(WorkRef3, 15000),

    Collection = babel_index_collection:fetch(Prefix, CName, GetOpts),
    Idx = babel_index_collection:index(IdxName, Collection),

    Pattern = #{
        <<"identification_type">> => <<"DNI">>,
        <<"identification_number">> => <<"1">>
    },

    Res = babel_index:match(Pattern, Idx, GetOpts),
    ?assertEqual(2, length(Res)),
    ?assertEqual(
        [<<"account_id">>],
        maps:keys(hd(Res))
    ),
    ok.