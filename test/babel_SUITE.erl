-module(babel_SUITE).
-include_lib("common_test/include/ct.hrl").
-include_lib("stdlib/include/assert.hrl").

-export([all/0]).

-compile([nowarn_export_all, export_all]).



all() ->
    [
        nothing_test,
        error_test,
        delete_index_test,
        index_creation_1_test,
        scheduled_for_delete_test,
        update_indices_1_test,
        match_1_test
    ].


init_per_suite(Config) ->
    ok = common:setup(),
    meck:unload(),
    Config.

end_per_suite(Config) ->
    meck:unload(),
    {save_config, Config}.



nothing_test(_) ->
    {ok, ok} = babel:workflow(fun() -> ok end).


error_test(_) ->
    ?assertEqual({error, foo}, babel:workflow(fun() -> throw(foo) end)),
    ?assertError(foo, babel:workflow(fun() -> error(foo) end)),
    ?assertError(foo, babel:workflow(fun() -> exit(foo) end)).


index_creation_1_test(_) ->
    %% Not really storing the index, we intercept the reliable enqueue call
    %% here to validate we are getting the right struct
    meck:new(reliable, [passthrough]),
    meck:expect(reliable, enqueue, fun
        (_, Work) ->
            %% 8 partitions + 1 collection
            ?assertEqual(9, length(Work)),
            ok
    end),

    Conf = index_conf_crdt(),

    Fun = fun() ->
        Index = babel_index:new(Conf),
        Collection0 = babel_index_collection:new(
            <<"babel_SUITE">>, <<"users">>),
        _Collection1 = babel:create_index(Index, Collection0),
        ok
    end,

    {scheduled, _, ok} = babel:workflow(Fun),
    timer:sleep(5000),
    ok.



scheduled_for_delete_test(_) ->
    Conf = index_conf_crdt(),
    Fun = fun() ->
        Index = babel_index:new(Conf),
        Collection0 = babel_index_collection:new(
            <<"babel_SUITE">>, <<"users">>),
        ok = babel:delete_collection(Collection0),
        _Collection1 = babel:create_index(Index, Collection0),
        ok
    end,

    {error, {scheduled_for_delete, _Id}} = babel:workflow(Fun),
    ok.


update_indices_1_test(_) ->

    {ok, Conn} = riakc_pb_socket:start_link("127.0.0.1", 8087),
    pong = riakc_pb_socket:ping(Conn),

    RiakOpts = #{
        connection => Conn
    },

    Conf = index_conf_crdt(),

    Fun = fun() ->
        Index = babel_index:new(Conf),
        Collection0 = babel_index_collection:new(
            <<"babel_SUITE">>, <<"users">>),
        _Collection1 = babel:create_index(Index, Collection0),
        ok
    end,

    {scheduled, _, ok} =  babel:workflow(Fun),
    timer:sleep(5000),

    Object = #{
        {<<"email">>, register} => <<"johndoe@me.com">>,
        {<<"user_id">>, register} => <<"mrn:user:1">>,
        {<<"account_id">>, register} => <<"mrn:account:1">>,
        {<<"name">>, register} => <<"john">>
    },

    Fun2 = fun() ->
        %% We fetch the collection from Riak KV
        Collection = babel_index_collection:fetch(
            <<"babel_SUITE">>, <<"users">>, RiakOpts
        ),
        {ok, <<"users">>} = babel:update_all_indices([{insert, Object}], Collection, RiakOpts),
        ok
    end,

    {scheduled, _, ok} =  babel:workflow(Fun2),

    ok.


match_1_test(_) ->
    {ok, Conn} = riakc_pb_socket:start_link("127.0.0.1", 8087),
    pong = riakc_pb_socket:ping(Conn),

    RiakOpts = #{
        connection => Conn
    },
    Collection = babel_index_collection:fetch(
        <<"babel_SUITE">>, <<"users">>, RiakOpts
    ),
    Index = babel_index_collection:index(<<"users_by_email">>, Collection),
    Res = babel_index:match(
        #{{<<"email">>, register} => <<"johndoe@me.com">>}, Index, RiakOpts),
    Expected = [
        #{
            {<<"user_id">>, register} => <<"mrn:user:1">>,
            {<<"account_id">>, register} => <<"mrn:account:1">>
        }
    ],
    ?assertEqual(Expected, Res).


delete_index_test(_) ->
    {ok, Conn} = riakc_pb_socket:start_link("127.0.0.1", 8087),
    pong = riakc_pb_socket:ping(Conn),

    RiakOpts = #{
        connection => Conn
    },

    Fun = fun() ->
        Res = babel_index_collection:lookup(
            <<"mytenant">>, <<"users">>, RiakOpts
        ),

        case Res of
            {error, not_found} ->
                ok;
            {ok, Collection} ->
                try
                    Index = babel_index_collection:index(
                        <<"users_by_email">>, Collection),
                    _Collection1 = babel:delete_index(Index, Collection),
                    ok
                catch
                    error:badindex ->
                        ok
                end
        end
    end,

    {ok, ok} =  babel:workflow(Fun),

    %% Sleep for 5 seconds for write to happen.
    timer:sleep(5000),
    ok.



index_conf_crdt() ->
    #{
        name => <<"users_by_email">>,
        bucket_type => <<"index_data">>,
        bucket_prefix => <<"babel_SUITE/johndoe">>,
        type => babel_hash_partitioned_index,
        config => #{
            sort_ordering => asc,
            number_of_partitions => 8,
            partition_algorithm => jch,
            partition_by => [{<<"email">>, register}],
            index_by => [{<<"email">>, register}],
            covered_fields => [
                {<<"user_id">>, register}, {<<"account_id">>, register}
            ]
        }
    }.


%% index_conf() ->
%%     Sort = asc,
%%     N = 8,
%%     Algo = jch,
%%     PartBy = [<<"email">>],
%%     IndexBy = [<<"email">>],
%%     Covered = [<<"user_id">>, <<"account_id">>],

%%     #{
%%         name => <<"users_by_email">>,
%%         bucket_type => <<"index_data">>,
%%         bucket_prefix => <<"babel_SUITE/johndoe">>,
%%         type => babel_hash_partitioned_index,
%%         config => #{
%%             sort_ordering => Sort,
%%             number_of_partitions => N,
%%             partition_algorithm => Algo,
%%             partition_by => PartBy,
%%             index_by => IndexBy,
%%             covered_fields => Covered
%%         }
%%     }.