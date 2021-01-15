-module(demo_vehicle).
-include_lib("kernel/include/logger.hrl").
-compile([export_all]).


%% =============================================================================
%% RIAKC API Examples
%% =============================================================================


typed_bucket() ->
    {<<"vehicles">>, <<"demo_vehicles">>}.


data() ->
    data(
        <<"vehicle1">>,
        <<"1a33b7532aec">>,
        <<"Tesla">>,
        <<"Model S">>,
        <<"blue">>
    ).


data(Id, Account, Make, Model, Color) ->
    #{
        <<"id">> => Id,
        <<"type">> => <<"Vehicle">>,
        <<"account_id">> => Account,
        <<"info">> => #{
            <<"make">> => Make,
            <<"model">> => Model,
            <<"color">> => Color,
            <<"user_info">> => #{}
        },
        <<"reported_state">> => #{
            <<"location">> => #{
                <<"latitude">> => #{
                    <<"value">> => 51.500729,
                    <<"timestamp">> => 1613296406000
                },
                <<"longitude">> => #{
                    <<"value">> => -0.124625,
                    <<"timestamp">> => 1613296406000
                }
            },
            <<"speed">> => #{
                <<"value">> => 60,
                <<"timestamp">> => 1613296406000
            }
        }
    }.

%% -----------------------------------------------------------------------------
%% @doc Creates a new riakc_map using the new function.
%% We first need to transform the input value into what riakc_map expects
%% @end
%% -----------------------------------------------------------------------------

as_riak_map() ->
    Ts = 1613296406000,
    Thing0 = riakc_map:update(
        {<<"id">>, register},
        fun(TypeReg) -> riakc_register:set(<<"vehicle1">>, TypeReg) end,
        riakc_map:new()
    ),
    Thing1 = riakc_map:update(
        {<<"type">>, register},
        fun(TypeReg) -> riakc_register:set(<<"Vehicle">>, TypeReg) end,
        Thing0
    ),
    Thing2 = riakc_map:update(
        {<<"account_id">>, register},
        fun(AccReg) -> riakc_register:set(<<"1a33b7532aec">>, AccReg) end,
        Thing1
    ),
    Thing3 = riakc_map:update(
        {<<"info">>, map},
        fun(InfoMap0) ->
            InfoMap1 = riakc_map:update(
                {<<"make">>, register},
                fun(MakeReg) ->
                    riakc_register:set(<<"Tesla">>, MakeReg)
                end,
                InfoMap0
            ),
            InfoMap2 = riakc_map:update(
                {<<"model">>, register},
                fun(Model) -> riakc_register:set(<<"Model S">>, Model) end,
                InfoMap1
            ),
            riakc_map:update(
                {<<"color">>, register},
                fun(Color) -> riakc_register:set(<<"blue">>, Color) end,
                InfoMap2
            )
        end,
        Thing2
    ),
    riakc_map:update(
        {<<"reported_state">>, map},
        fun(RS0) ->
            RS1 = riakc_map:update(
                {<<"location">>, map},
                fun(Loc0) ->
                    Loc1 = riakc_map:update(
                        {<<"latitude">>, map},
                        fun(LatMap0) ->
                            LatMap1 = riakc_map:update(
                                {<<"value">>, register},
                                fun(LatReg) ->
                                    Bin = float_to_binary(51.500729),
                                    riakc_register:set(Bin, LatReg)
                                end,
                                LatMap0
                            ),
                            riakc_map:update(
                                {<<"timestamp">>, register},
                                fun(LTReg) ->
                                    Bin = integer_to_binary(1613296406000),
                                    riakc_register:set(Bin, LTReg)
                                end,
                                LatMap1
                            )
                        end,
                        Loc0
                    ),
                    riakc_map:update(
                        {<<"longitude">>, map},
                        fun(LongMap0) ->
                            LongMap1 = riakc_map:update(
                                {<<"value">>, register},
                                fun(LongReg) ->
                                    Bin = float_to_binary(-0.124625),
                                    riakc_register:set(Bin, LongReg)
                                end,
                                LongMap0
                            ),
                            riakc_map:update(
                                {<<"timestamp">>, register},
                                fun(LGReg) ->
                                    Bin = integer_to_binary(1613296406000),
                                    riakc_register:set(Bin, LGReg)
                                end,
                                LongMap1
                            )
                        end,
                        Loc1
                    )
                end,
                RS0
            ),
            riakc_map:update(
                {<<"speed">>, map},
                fun(SpeedMap0) ->
                    SpeedMap1 = riakc_map:update(
                        {<<"value">>, register},
                        fun(LongReg) ->
                            Bin = integer_to_binary(60),
                            riakc_register:set(Bin, LongReg)
                        end,
                        SpeedMap0
                    ),
                    riakc_map:update(
                        {<<"timestamp">>, register},
                        fun(TsReg) ->
                            Bin = integer_to_binary(Ts),
                            riakc_register:set(Bin, TsReg)
                        end,
                        SpeedMap1
                    )
                end,
                RS1
            )
        end,
        Thing3
    ).



riak_put() ->
    Map = demo_vehicle:riak_data_new(),

    Result = riak_pool:execute(default,
        fun(Pid) ->
            Oper = riakc_map:to_op(Map),
            Opts = [{return_body, true}],

            riakc_pb_socket:update_type(
                Pid, typed_bucket(), <<"vehicle1">>, Oper, Opts
            )

        end,
        #{max_retries => 0}
    ),
    case Result of
        {false, Value} -> error(Value);
        {true, Res} -> Res
    end.





%% =============================================================================
%% BABEL
%% =============================================================================



type_spec() ->
    #{
        <<"id">> => {register, binary},
        <<"type">> => {register, binary},
        <<"account_id">> => {register, binary},
        <<"info">> => {map, #{
            <<"make">> => {register, binary},
            <<"model">> => {register, binary},
            <<"color">> => {register, binary},
            <<"user_info">> => {map, #{'_' => {register, binary}}}
        }},
        <<"reported_state">> => {map, #{
            <<"location">> => {map, #{
                <<"latitude">> => {map, #{
                    <<"value">> => {register, float},
                    <<"timestamp">> => {register, integer}
                }},
                <<"longitude">> => {map, #{
                    <<"value">> => {register, float},
                    <<"timestamp">> => {register, integer}
                }}
            }},
            <<"speed">> => {map, #{
                <<"value">> => {register, integer},
                <<"timestamp">> => {register, integer}
            }}
        }}
    }.


as_babel_map() ->
    Data = data(),
    TypeSpec = type_spec(),
    babel_map:new(Data, TypeSpec).





%% -----------------------------------------------------------------------------
%% @doc For presentation purposes only
%% @end
%% -----------------------------------------------------------------------------
map_to_riak_map_value(Map) when is_map(Map) ->
    maps:fold(
        fun
            Convert(Key, Value, Acc) when is_map(Value) ->
                [{{Key, map}, map_to_riak_map_value(Value)} | Acc];
            Convert(Key, Value, Acc) when is_integer(Value) ->
                Convert(Key, integer_to_binary(Value), Acc);
            Convert(Key, Value, Acc) when is_float(Value) ->
                Convert(Key, float_to_binary(Value), Acc);
            Convert(Key, Value, Acc) when is_binary(Value) ->
                [{{Key, register}, Value} | Acc]
        end,
        [],
        Map
    ).


create_vehicles() ->
    Spec = type_spec(),
    Accounts = [<<"A">>, <<"B">>, <<"C">>],
    MakeModels = [
        {<<"Tesla">>, <<"Model S">>},
        {<<"Jaguar">>, <<"I Pace">>}
    ],
    Colors = [<<"blue">>, <<"red">>],


    BucketPrefix = <<"demo">>,
    Key = <<"vehicles">>,
    {ok, Collection} = babel_index_collection:lookup(BucketPrefix, Key, #{}),


    Seq = lists:seq(1, 1000),
    _ = [
        begin
            Id = <<"vehicle", (integer_to_binary(X))/binary>>,
            Account = lists:nth(
                rand:uniform(length(Accounts)), Accounts
            ),
            {Make, Model} = lists:nth(
                rand:uniform(length(MakeModels)), MakeModels
            ),
            Color= lists:nth(rand:uniform(length(Colors)), Colors),
            Map = babel_map:new(data(Id, Account, Make, Model, Color), Spec),

            babel:execute(default,
                fun(Pid) ->
                    %% This adds a workflow to a reliable queue
                    {true, _} = babel:update_all_indices(
                        [{insert, Map}], Collection, #{}
                    ),
                    %% This writes to Riak sync
                    babel:put(
                        typed_bucket(), Id, Map, Spec, #{connection => Pid}
                    )
                end,
                #{}
            )

        end || X <- Seq
    ],
    ok.


indices() ->
    [
        #{
            name => <<"things_by_account">>,
            bucket_type => <<"index_data">>,
            bucket_prefix => <<"demo">>,
            type => babel_simple_index,
            config => #{
                sort_ordering => asc,
                index_by => [<<"account_id">>],
                covered_fields => [<<"id">>]
            }
        },
        #{
            name => <<"vehicles_by_brand">>,
            bucket_type => <<"index_data">>,
            bucket_prefix => <<"demo">>,
            type => babel_hash_partitioned_index,
            config => #{
                sort_ordering => asc,
                number_of_partitions => 32,
                partition_algorithm => jch,
                partition_by => [
                    [<<"info">>, <<"make">>]
                ],
                index_by => [
                    [<<"info">>, <<"make">>]
                ],
                cardinality => many,
                covered_fields => [<<"id">>, [<<"info">>, <<"color">>]]
            }
        }
    ].


create_collection() ->
    BucketPrefix = <<"demo">>, % demo-index_collection
    Key = <<"vehicles">>,

    Fun = fun(Pid) ->
        Opts = #{
            connection => Pid,
            riak_opts => #{
                r => quorum,
                notfound_ok => false
            }
        },
        case babel_index_collection:lookup(BucketPrefix, Key, Opts) of
            {ok, Collection} ->
                %% Check if we have all indices
                maybe_add_indices(Collection);
            {error, not_found} ->
                Collection = babel_index_collection:new(BucketPrefix, Key),
                maybe_add_indices(Collection);
            {error, _} = Error ->
                Error
        end
    end,

    case babel:execute(default, Fun, #{}) of
        {false, Reason} ->
            {error, Reason};
        {true, {error, _} = Error} ->
            Error;
        {true, NewCollection} ->
            {ok, NewCollection}
    end.



%% -----------------------------------------------------------------------------
%% @doc
%% @end
%% -----------------------------------------------------------------------------
-spec maybe_add_indices(Collection :: babel_index_collection:t()) ->
    babel_index_collection:t() | no_return().

maybe_add_indices(Collection) ->
    Existing = ordsets:from_list(
        babel_index_collection:index_names(Collection)
    ),
    Expected = ordsets:from_list([maps:get(name, Idx) || Idx <- indices()]),
    Missing = ordsets:subtract(Expected, Existing),

    ?LOG_DEBUG(#{
        message => "Index creation",
        missing => Missing,
        expected => Expected
    }),

    add_indices(Collection, Missing).


%% -----------------------------------------------------------------------------
%% @private
%% @doc
%% @end
%% -----------------------------------------------------------------------------
-spec add_indices(
    Collection :: babel_index_collection:t(), Names :: ordsets:ordset()) -> babel_index_collection:t() | no_return().

add_indices(Collection, Names) ->
    Fun = fun() ->
        Indices = [
            Index
            || Index <- indices(),
            lists:member(maps:get(name, Index), Names)
        ],
        Fun = fun(IndexConf, Acc) ->
            Index = babel_index:new(IndexConf),
            {true, #{result := NewCollection}} = babel:create_index(Index, Acc),

            ?LOG_INFO(#{
                message => "Adding index creation task to workflow",
                index => babel_index:name(Index),
                collection => babel_index_collection:id(Collection)
            }),
            NewCollection
        end,
        lists:foldl(Fun, Collection, Indices)
    end,

    case babel:workflow(Fun, #{}) of
        %{true|false, Map|error}
        {false, _} ->
            %% Nothing has been scheduled
            Collection;
        {true, #{work_ref := WorkRef, result := NewCollection}} ->
            Timeout = 30 * 60000,
            ?LOG_INFO(#{
                message => "Waiting for index creation workflow to complete",
                timeout => Timeout,
                work_ref => WorkRef,
                collection => babel_index_collection:id(Collection)
            }),
            %% We give it a long time (30 mins) as opposed to infinity.
            case babel:yield(WorkRef, Timeout) of
                {ok, undefined} ->
                    NewCollection;
                timeout ->
                    {error, {index_creation_failed, timeout}}
            end;
        {error, _} = Error ->
            Error
    end.


find_by_account(Acc) ->
    BucketPrefix = <<"demo">>, % demo-index_collection
    Key = <<"vehicles">>,
    {ok, C} = babel_index_collection:lookup(BucketPrefix, Key, #{}),
    Index = babel_index_collection:index(<<"things_by_account">>, C),
    babel_index:match(#{<<"account_id">> => Acc}, Index, #{}).


find_by_make(Make) ->
    BucketPrefix = <<"demo">>, % demo-index_collection
    Key = <<"vehicles">>,
    {ok, C} = babel_index_collection:lookup(BucketPrefix, Key, #{}),
    Index = babel_index_collection:index(<<"vehicles_by_brand">>, C),
    babel_index:match(
        #{<<"info">> => #{<<"make">> => Make}},
        Index,
        #{}
    ).