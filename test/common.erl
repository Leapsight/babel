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
    %% Start the application.
    {ok, Apps} = application:ensure_all_started(babel),
    application:ensure_all_started(cache),
    ct:pal("Started ~p", [Apps]),
    ok.