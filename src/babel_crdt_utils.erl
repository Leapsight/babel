-module(babel_crdt_utils).

-define(BADKEY, '$error_badkey').

-export([map_entry/3]).
-export([dirty_fetch/2]).

-compile({no_auto_import, [get/1]}).


%% =============================================================================
%% API
%% =============================================================================



%% -----------------------------------------------------------------------------
%% @doc Returns the "unwrapped" value associated with the key in the
%% map. As opposed to riakc_map:fetch/2 this function searches for the key in
%% the removed and updated private structures of the map first. If the key was
%% found on the removed set, fails with a `removed' exception. If they key was
%% in the updated set, it returns the updated value otherwise calls
%% riakc_map:fetch/2.
%% @end
%% -----------------------------------------------------------------------------
-spec dirty_fetch(riakc_map:key(), riakc_map:crdt_map()) -> term().

dirty_fetch(Key, {map, _, Updates, Removes, _} = Map) ->
    case ordsets:is_element(Key, Removes) of
        true ->
            error(removed);
        false ->
            case orddict:find(Key, Updates) of
                {ok, Value} ->
                    Value;
                error ->
                    riakc_map:fetch(Key, Map)
            end
    end.


%% -----------------------------------------------------------------------------
%% @doc
%% @end
%% -----------------------------------------------------------------------------
-spec map_entry(
    Type :: riakc_datatype:typename(), Field :: binary(), Value :: binary()) ->
    riakc_map:raw_entry().

map_entry(register, Field, Value) ->
    {{Field, register}, riakc_register:new(Value, undefined)};

map_entry(counter, Field, Value) ->
    {{Field, counter}, riakc_counter:new(Value, undefined)};

map_entry(set, Field, Values) ->
    {{Field, set}, riakc_set:new(Values, undefined)};

map_entry(map, Field, Values) ->
    {{Field, map}, riakc_map:new(Values, undefined)}.