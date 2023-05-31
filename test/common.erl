-module(common).

-include_lib("kernel/include/logger.hrl").


-export([setup/0]).
-export([handle_telemetry_event/4]).


setup() ->
    Key = {?MODULE, setup_done},
    case persistent_term:get(Key, false) of
        false ->
            ok = do_setup(),
            persistent_term:put(Key, true);
        true ->
            ok
    end.



handle_telemetry_event(EventName, Measurements, Metadata, _) ->
    ?LOG_INFO(#{
        name => EventName,
        description => "Got telemetry event",
        measurements => Measurements,
        metadata => Metadata
    }).





%% =============================================================================
%% PRIVATE
%% =============================================================================



do_setup() ->
    %% Start the application.
    {ok, Apps} = application:ensure_all_started(babel),
    application:ensure_all_started(cache),
    ct:pal("Started ~p", [Apps]),
    _ = logger:set_application_level(reliable, info),
    ok.