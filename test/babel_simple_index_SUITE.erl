-module(babel_simple_index_SUITE).
-include_lib("eunit/include/eunit.hrl").
-compile(export_all).
-compile([nowarn_export_all, export_all]).



all() ->
    [
        bad_index_test,
        index_1_test,
        index_2_test
    ].


init_per_suite(Config) ->
    ok = common:setup(),
    Config.

end_per_suite(Config) ->
    {save_config, Config}.


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


index_1_test(_) ->
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

    RiakOpts = #{connection => Conn},

    %% Cleanup previous runs
    Cleanup = fun() ->
        case babel_index_collection:lookup(Prefix, CollectionName, RiakOpts) of
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
            Prefix, CollectionName, RiakOpts
        ),
        {true, #{is_nested := true}} = babel:update_all_indices(
            Actions, Collection, RiakOpts
        ),
        ok
    end,

    {true, #{work_ref := WorkRef3, result := ok}} = babel:workflow(Update),
    {ok, _} = babel:yield(WorkRef3, 10000),

    Collection = babel_index_collection:fetch(Prefix, CollectionName, RiakOpts),
    Index = babel_index_collection:index(IdxName, Collection),

    Pattern = #{
        <<"account_id">> =>  <<"mrn:account:1">>
    },
    L = babel_index:match(Pattern, Index, RiakOpts),
    ?assertEqual(700, length(L)),
    Map = hd(L),
    ?assertEqual(<<"mrn:thing:1_1">>, maps:get(<<"id">>, Map)),
    ok.
