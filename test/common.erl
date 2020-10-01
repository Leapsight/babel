-module(common).

-export([setup/0]).


setup() ->
    Key = {?MODULE, setup_done},
    case persistent_term:get(Key, false) of
        false ->
            ok = do_setup(),
            persistent_term:put(Key, true);
        true ->
            ok
    end.


do_setup() ->
    Env = [
        {babel, [
            {reliable, [
                {backend, reliable_riak_storage_backend},
                {riak_host, "127.0.0.1"},
                {riak_port, 8087},
                {instance_name, <<"babel_test">>},
                {number_of_partitions, 5}
            ]},
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

    application:ensure_all_started(babel),
    application:ensure_all_started(reliable),
    application:ensure_all_started(cache),
    ok.