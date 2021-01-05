-module(babel_simple_index_SUITE).
-include_lib("common_test/include/ct.hrl").
-include_lib("stdlib/include/assert.hrl").
-compile(export_all).
-compile([nowarn_export_all, export_all]).


groups() ->
    [
        {main, [sequence], [
            index_2_test,
            error_delete_action_updated,
            delete_action_force,
            nop_delete_action_missing_keys,
            ok_delete_action,
            nop_insert_action_1,
            nop_insert_action_2,
            update_action_1,
            update_action_2,
            update_action_3
        ]}
    ].

all() ->
    [
        bad_index_test,
        data_structure_test,
        {group, main}
    ].


init_per_suite(Config) ->
    ok = common:setup(),
    Config.

end_per_suite(_) ->
    ok.


bad_index_test(_) ->
    Empty = [],
    Conf = #{
        name => <<"things_by_account">>,
        bucket_type => <<"index_data">>,
        bucket_prefix => <<"babel_simple_index_SUITE">>,
        type => babel_simple_index,
        config => #{
            index_by => Empty,
            covered_fields => [<<"id">>]
        }
    },
    ?assertError(#{code := invalid_value}, babel_index:new(Conf)).


data_structure_test(_) ->
    Conf = #{
        name => <<"things_by_account">>,
        bucket_type => <<"index_data">>,
        bucket_prefix => <<"babel_simple_index_SUITE">>,
        type => babel_simple_index,
        config => #{
            index_by => [<<"account_id">>],
            covered_fields => [<<"id">>]
        }
    },
    Index = babel_index:new(Conf),

    CRDT = babel_index:to_riak_object(Index),
    ?assertEqual(true, riakc_map:is_type(CRDT)),

    %% This index does not create any partitions, they are dynamically created
    Partitions = babel_index:create_partitions(Index),
    ?assertEqual(0, length(Partitions)),
    ok.

index_2_test(_) ->
    Prefix = <<"babel_simple_index_SUITE">>,
    CollectionName = <<"things">>,
    IdxName = <<"things_by_account">>,
    Conf = #{
        name => IdxName,
        bucket_type => <<"index_data">>,
        bucket_prefix => Prefix,
        type => babel_simple_index,
        config => #{
            index_by => [<<"account_id">>],
            covered_fields => [<<"id">>]
        }
    },

    {ok, Conn} = riakc_pb_socket:start_link("127.0.0.1", 8087),
    pong = riakc_pb_socket:ping(Conn),

    BabelOpts = #{connection => Conn},

    %% Cleanup previous runs
    Cleanup = fun() ->
        case babel_index_collection:lookup(Prefix, CollectionName, BabelOpts) of
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
    %% we do not use yield as we might have nothing to do in case the
    %% collection dod not exit
    timer:sleep(5000),

    %% We schedule the creation of a new collection and we add the index
    Create = fun() ->
        Index = babel_index:new(Conf),
        Collection0 = babel_index_collection:new(Prefix, CollectionName),
        {true, #{is_nested := true}} = babel:create_index(Index, Collection0),
        ok
    end,
    {true, #{work_ref := WorkRef2, result := ok}} = babel:workflow(Create),
    %% we wait 5 secs for reliable to perform the work
    {ok, _} = babel:yield(WorkRef2, 5000),

    %% We create 1000 accounts with 700 things each
    Actions = [
        begin
            AccId = integer_to_binary(X),
            UserId = integer_to_binary(Y),
            Obj = #{
                <<"id">> => <<"mrn:thing:", AccId/binary, "_", UserId/binary>>,
                <<"account_id">> => <<"mrn:account:", AccId/binary>>
            },
            {insert, Obj}
        end || X <- [1], Y <- lists:seq(1, 700)
    ],

    Update = fun() ->
        %% We fetch the collection from Riak KV
        Collection = babel_index_collection:fetch(
            Prefix, CollectionName, BabelOpts
        ),
        {true, #{is_nested := true}} = babel:update_all_indices(
            Actions,
            Collection,
            BabelOpts#{force => true} % we force as Obj is not a babel_map
        ),
        ok
    end,

    {true, #{work_ref := WorkRef3, result := ok}} = babel:workflow(Update),
    {ok, _} = babel:yield(WorkRef3, 10000),

    Collection = babel_index_collection:fetch(Prefix, CollectionName, BabelOpts),
    Index = babel_index_collection:index(IdxName, Collection),

    Pattern = #{
        <<"account_id">> =>  <<"mrn:account:1">>
    },
    L = babel_index:match(Pattern, Index, BabelOpts),
    ?assertEqual(700, length(L)),
    Map = hd(L),
    ?assertEqual(<<"mrn:thing:1_1">>, maps:get(<<"id">>, Map)),

    NewConfig = [{collection, Collection}, {index, Index}],
    {save_config, NewConfig}.


error_delete_action_updated(Config) ->
    {_, OldConfig} = ?config(saved_config, Config),
    Collection = ?config(collection, OldConfig),
    Index = ?config(index, OldConfig),

    AccMRN = <<"mrn:account:1">>,
    MRN = <<"mrn:thing:1_1">>,
    Data = #{<<"id">> => MRN, <<"account_id">> => AccMRN},
    Map = babel_map:new(Data),
    Actions = [{delete, Map}],
    ?assertError(
        {badaction, {delete, Map}},
        babel:update_all_indices(Actions, Collection, #{})
    ),

    NewConfig = [{collection, Collection}, {index, Index}],
    {save_config, NewConfig}.


delete_action_force(Config) ->
    {_, OldConfig} = ?config(saved_config, Config),
    Collection = ?config(collection, OldConfig),
    Index = ?config(index, OldConfig),

    AccMRN = <<"mrn:account:1">>,
    MRN = <<"mrn:thing:1_1">>,
    Data = #{<<"id">> => MRN, <<"account_id">> => AccMRN},
    Actions = [{delete, Data}],

    {false, #{result := []}} = babel:update_all_indices(
        Actions,
        Collection,
        #{force => false} % <<<<<<<<<<<<<<<<<<
    ),

    {true, #{work_ref := WorkRef, result := [_]}} = babel:update_all_indices(
        Actions,
        Collection,
        #{force => true} % <<<<<<<<<<<<<<<<<<
    ),
    {ok, _} = babel:yield(WorkRef, 10000),

    Pattern = #{<<"account_id">> =>  <<"mrn:account:1">>},
    L = babel_index:match(Pattern, Index, #{}),
    ?assertEqual(699, length(L)),
    ?assertEqual(<<"mrn:thing:1_10">>, maps:get(<<"id">>, hd(L))),

    NewConfig = [{collection, Collection}, {index, Index}],
    {save_config, NewConfig}.


nop_delete_action_missing_keys(Config) ->
    {_, OldConfig} = ?config(saved_config, Config),
    Collection = ?config(collection, OldConfig),
    Index = ?config(index, OldConfig),

    Data = #{
        <<"id">> => <<"mrn:thing:1_2">>
    },
    Map = {babel_map,
        Data,
        [], % no updates
        [], % no removes
        undefined
    },
    Actions = [{delete, Map}],
    {false, #{result := []}} = babel:update_all_indices(
        Actions, Collection, #{}
    ),

    NewConfig = [{collection, Collection}, {index, Index}],
    {save_config, NewConfig}.


ok_delete_action(Config) ->
    {_, OldConfig} = ?config(saved_config, Config),
    Collection = ?config(collection, OldConfig),
    Index = ?config(index, OldConfig),

    AccMRN = <<"mrn:account:1">>,
    Data = #{
        <<"account_id">> => AccMRN,
        <<"id">> => <<"mrn:thing:1_2">>
    },
    Map = {babel_map,
        Data,
        [], % no updates
        [], % no removes
        undefined
    },
    Actions = [{delete, Map}],

    {true, #{work_ref := WorkRef, result := [_]}} = babel:update_all_indices(
        Actions,
        Collection,
        #{}
    ),
    {ok, _} = babel:yield(WorkRef, 10000),

    Pattern = #{<<"account_id">> =>  <<"mrn:account:1">>},
    L = babel_index:match(Pattern, Index, #{}),
    ?assertEqual(698, length(L)),
    ?assertEqual(<<"mrn:thing:1_10">>, maps:get(<<"id">>, hd(L))),

    NewConfig = [{collection, Collection}, {index, Index}],
    {save_config, NewConfig}.


nop_insert_action_1(Config) ->
    {_, OldConfig} = ?config(saved_config, Config),
    Collection = ?config(collection, OldConfig),
    Index = ?config(index, OldConfig),

    AccMRN = <<"mrn:account:1">>,
    MRN = <<"mrn:thing:1_2">>,
    Data = #{
        <<"account_id">> => AccMRN,
        <<"id">> => MRN
    },
    Map = {babel_map,
        Data,
        [], % no updates
        [], % no removes
        undefined
    },
    Actions = [{insert, Map}],

    {false, #{result := []}} = babel:update_all_indices(
        Actions,
        Collection,
        #{}
    ),

    NewConfig = [{collection, Collection}, {index, Index}],
    {save_config, NewConfig}.


nop_insert_action_2(Config) ->
    {_, OldConfig} = ?config(saved_config, Config),
    Collection = ?config(collection, OldConfig),
    Index = ?config(index, OldConfig),

    Map = {babel_map,
        #{}, % missing keys
        [], % no updates
        [], % no removes
        undefined
    },
    Actions = [{insert, Map}],

    {false, #{result := []}} = babel:update_all_indices(
        Actions,
        Collection,
        #{}
    ),

    NewConfig = [{collection, Collection}, {index, Index}],
    {save_config, NewConfig}.


update_action_1(Config) ->
    {_, OldConfig} = ?config(saved_config, Config),
    Collection = ?config(collection, OldConfig),
    Index = ?config(index, OldConfig),


    Old = {babel_map,
        #{
            <<"account_id">> => <<"mrn:account:1">>,
            <<"id">> => <<"mrn:thing:1_3">>
        },
        [], % no updates
        [], % no removes
        undefined
    },
    New = babel_map:new(#{
        <<"account_id">> => <<"mrn:account:2">>, % New Acc
        <<"id">> => <<"mrn:thing:1_3">>
    }),
    Actions = [{update, Old, New}],


    {true, #{work_ref := WorkRef, result := [_]}} = babel:update_all_indices(
        Actions,
        Collection,
        #{}
    ),
    {ok, _} = babel:yield(WorkRef, 10000),

    Pattern1 = #{<<"account_id">> =>  <<"mrn:account:1">>},
    L1 = babel_index:match(Pattern1, Index, #{}),
    ?assertEqual(697, length(L1)),
    ?assertEqual(<<"mrn:thing:1_10">>, maps:get(<<"id">>, hd(L1))),

    Pattern2 = #{<<"account_id">> =>  <<"mrn:account:2">>},
    L2 = babel_index:match(Pattern2, Index, #{}),
    ?assertEqual(1, length(L2)),
    ?assertEqual(<<"mrn:thing:1_3">>, maps:get(<<"id">>, hd(L2))),

    NewConfig = [{collection, Collection}, {index, Index}],
    {save_config, NewConfig}.



update_action_2(Config) ->
    {_, OldConfig} = ?config(saved_config, Config),
    Collection = ?config(collection, OldConfig),
    Index = ?config(index, OldConfig),


    Old = {babel_map,
        #{
            <<"account_id">> => <<"mrn:account:2">>,
            <<"id">> => <<"mrn:thing:1_3">>
        },
        [], % no updates
        [], % no removes
        undefined
    },
    New = babel_map:new(#{}),
    Actions = [{update, Old, New}],


    {true, #{work_ref := WorkRef, result := [_]}} = babel:update_all_indices(
        Actions,
        Collection,
        #{}
    ),
    {ok, _} = babel:yield(WorkRef, 10000),

    %% No ops on this index
    Pattern1 = #{<<"account_id">> =>  <<"mrn:account:1">>},
    L1 = babel_index:match(Pattern1, Index, #{}),
    ?assertEqual(697, length(L1)),
    ?assertEqual(<<"mrn:thing:1_10">>, maps:get(<<"id">>, hd(L1))),

    %% Old deleted in this index
    Pattern2 = #{<<"account_id">> =>  <<"mrn:account:2">>},
    L2 = babel_index:match(Pattern2, Index, #{}),
    ?assertEqual(0, length(L2)),

    NewConfig = [{collection, Collection}, {index, Index}],
    {save_config, NewConfig}.


update_action_3(Config) ->
    {_, OldConfig} = ?config(saved_config, Config),
    Collection = ?config(collection, OldConfig),
    Index = ?config(index, OldConfig),


    Old = {babel_map,
        #{
            <<"account_id">> => <<"mrn:account:1">>,
            <<"id">> => <<"mrn:thing:1_700">>
        },
        [], % no updates
        [], % no removes
        undefined
    },
    New = {babel_map,
        #{
            <<"account_id">> => <<"mrn:account:1">>
        },
        [], % no updates
        [<<"id">>],
        undefined
    },
    Actions = [{update, Old, New}],

    {true, #{work_ref := WorkRef, result := [_]}} = babel:update_all_indices(
        Actions,
        Collection,
        #{}
    ),
    {ok, _} = babel:yield(WorkRef, 10000),

    %% No ops on this index
    Pattern1 = #{<<"account_id">> =>  <<"mrn:account:1">>},
    L1 = babel_index:match(Pattern1, Index, #{}),
    ?assertEqual(696, length(L1)),

    NewConfig = [{collection, Collection}, {index, Index}],
    {save_config, NewConfig}.


update_action_4(Config) ->
    {_, OldConfig} = ?config(saved_config, Config),
    Collection = ?config(collection, OldConfig),
    Index = ?config(index, OldConfig),


    Old = {babel_map,
        #{
            <<"account_id">> => <<"mrn:account:1">>,
            <<"id">> => <<"mrn:thing:1_800">>
        },
        [], % no updates
        [], % no removes
        undefined
    },
    New = {babel_map,
        #{
            <<"account_id">> => <<"mrn:account:1">>,
            <<"id">> => <<"mrn:thing:1_700">>
        },
        [<<"id">>], % no updates
        [], % no removes
        undefined
    },
    Actions = [{update, Old, New}],

    {true, #{work_ref := WorkRef, result := [_]}} = babel:update_all_indices(
        Actions,
        Collection,
        #{}
    ),
    {ok, _} = babel:yield(WorkRef, 10000),

    %% No ops on this index
    Pattern1 = #{<<"account_id">> =>  <<"mrn:account:1">>},
    L1 = babel_index:match(Pattern1, Index, #{}),
    ?assertEqual(697, length(L1)),

    NewConfig = [{collection, Collection}, {index, Index}],
    {save_config, NewConfig}.
