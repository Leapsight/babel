

%% =============================================================================
%% SETUP
%% =============================================================================

[rr(M) || M <- [riakc_map, babel_map, reliable]].

TypeSpec = demo_vehicle:type_spec().
TypedBucket = demo_vehicle:typed_bucket().


%% =============================================================================
%% RIAK DATA TYPES
%% =============================================================================

RM0 = demo_vehicle:as_riak_map().
riakc_map:value(RM0).
riakc_map:is_key({<<"info">>, map}, RM0).
riakc_map:fetch({<<"info">>, map}, RM0).
riakc_map:erase({<<"info">>, map}, RM0).


%% =============================================================================
%% BABEL DATA TYPES
%% =============================================================================


BM0 = demo_vehicle:as_babel_map().
babel_map:value(BM0).
babel_map:get(<<"info">>, BM0).
babel_map:get_value(<<"info">>, BM0).

babel_map:get_value([<<"info">>, <<"color">>], BM0).
babel_map:collect_values(
    [<<"id">>, [<<"reported_state">>, <<"speed">>, <<"value">>]],
    BM0,
    #{return => list}
).
babel_map:collect_values(
    [<<"id">>, [<<"reported_state">>, <<"speed">>, <<"value">>]],
    BM0,
    #{return => map}
).
BM1 = babel_map:put([<<"info">>, <<"color">>], <<"red">>, BM0).
babel_map:get_value([<<"info">>, <<"color">>], BM1).


babel_map:update(#{<<"info">> => #{<<"make">> => <<"Jaguar">>, <<"model">> => <<"I-Pace Type">>}}, BM1).
babel_map:get_value(<<"info">>, BM1).

BM2 = babel_map:remove(<<"info">>, BM1).
babel_map:get(<<"info">>, BM1).



babel:get(TypedBucket, <<"vehicle90">>, TypeSpec, #{}).



%% =============================================================================
%% VALIDATION
%% =============================================================================



riakc_map:to_op(demo_vehicle:as_riak_map()) == babel_map:to_riak_op(demo_vehicle:as_babel_map()).



%% =============================================================================
%% INDICES
%% =============================================================================


demo_vehicle:find_by_account(<<"A">>).

demo_vehicle:find_by_make(<<"Jaguar">>).



## List Vehicle Indices Partitions
curl "http://localhost:8098/types/index_data/buckets/demo-index_data/keys?keys=true"
