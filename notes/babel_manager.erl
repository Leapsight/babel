%% =============================================================================
%%  babel_manager.erl -
%%
%%  Copyright (c) 2022 Leapsight Technologies Limited. All rights reserved.
%%
%%  Licensed under the Apache License, Version 2.0 (the "License");
%%  you may not use this file except in compliance with the License.
%%  You may obtain a copy of the License at
%%
%%     http://www.apache.org/licenses/LICENSE-2.0
%%
%%  Unless required by applicable law or agreed to in writing, software
%%  distributed under the License is distributed on an "AS IS" BASIS,
%%  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
%%  See the License for the specific language governing permissions and
%%  limitations under the License.
%% =============================================================================

%% -----------------------------------------------------------------------------
%% @doc  LEGACY CODE TO RE-INDEX USING SOLR, TO BE REPLACED BY BABEL
%% @end
%% -----------------------------------------------------------------------------
-module(babel_manager).
-behaviour(gen_server).
-include_lib("kernel/include/logger.hrl").

-define(RIAK_TIMEOUT, 5000).

-define(OPTS_SPEC, #{
    <<"pr">> => #{
        alias => pr,
        key => pr,
        required => true,
        allow_null => false,
        allow_undefined => false,
        datatype => integer,
        default => 1
    },
    <<"pw">> => #{
        alias => pw,
        key => pw,
        required => true,
        allow_null => false,
        allow_undefined => false,
        datatype => integer,
        default => 1
    },
    <<"bucket">> => #{
        alias => bucket,
        key => bucket,
        required => false,
        allow_null => false,
        allow_undefined => false,
        datatype => atom
    }
}).

-define(MULTI_OPTS_SPEC, (?OPTS_SPEC)#{
    <<"backoff_every">> => #{
        alias => backoff_every,
        key => backoff_every,
        required => false,
        allow_null => false,
        allow_undefined => false,
        datatype => integer
    },
    <<"backoff_delay">> => #{
        alias => backoff_delay,
        key => backoff_delay,
        required => false,
        allow_null => false,
        allow_undefined => false,
        datatype => integer
    },
    <<"use_bucket_index">> => #{
        alias => use_bucket_index,
        key => use_bucket_index,
        required => true,
        allow_null => false,
        allow_undefined => false,
        default => true,
        datatype => boolean
    }
}).

-record(state, {
    worker              ::  pid() | undefined,
    info                ::  map() | undefined
}).

-type info()    ::  #{
    connection => #{host => list(), port => integer()},
    options => map(),
    bucket_type => atom(),
    bucket => atom(),
    start_ts => non_neg_integer(),
    end_ts => non_neg_integer() | undefined,
    succeded_count => integer(),
    failed_count => integer(),
    total_count => integer(),
    status => in_progress | finished | failed | canceled
}.

%% API
-export([info/0]).
-export([cancel/0]).
-export([rebuild_index/1]).
-export([rebuild_index/2]).
-export([rebuild_indices/0]).
-export([rebuild_indices/1]).
-export([start_link/0]).

%% GEN_SERVER CALLBACKS
-export([init/1]).
-export([handle_info/2]).
-export([terminate/2]).
-export([code_change/3]).
-export([handle_call/3]).
-export([handle_cast/2]).



%% =============================================================================
%% API
%% =============================================================================


%% -----------------------------------------------------------------------------
%% @doc
%% @end
%% -----------------------------------------------------------------------------
start_link() ->
    gen_server:start_link({local, ?MODULE}, ?MODULE, [], []).


%% -----------------------------------------------------------------------------
%% @doc
%% @end
%% -----------------------------------------------------------------------------
-spec info() -> undefined | info().

info() ->
    gen_server:call(?MODULE, info).


%% -----------------------------------------------------------------------------
%% @doc
%% @end
%% -----------------------------------------------------------------------------
-spec cancel() -> undefined | info().

cancel() ->
    gen_server:call(?MODULE, cancel).


%% -----------------------------------------------------------------------------
%% @doc
%% `things_service_index_manager:rebuild_index(<<"mrn:agent:f5a1...">>).'
%% @end
%% -----------------------------------------------------------------------------
-spec rebuild_index(Key :: binary()) -> ok | {error, any()}.

rebuild_index(Key) ->
    rebuild_index(Key, #{pr => 1, pw => 1}).


%% -----------------------------------------------------------------------------
%% @doc
%% ```
%% things_service_index_manager:rebuild_index(
%%     <<"mrn:agent:f5a1...">>, #{pr => 1, pw => 3}
%% ).
%% '''
%% @end
%% -----------------------------------------------------------------------------
-spec rebuild_index(Key :: binary(), Opts :: map()) -> ok | {error, any()}.

rebuild_index(Key, Opts) ->
    try
        NewOpts = maps_utils:validate(Opts, ?OPTS_SPEC),
        gen_server:call(?MODULE, {rebuild_index, Key, NewOpts})
    catch
        error:Reason ->
            {error, Reason}
    end.


%% -----------------------------------------------------------------------------
%% @doc
%% ```
%% things_service_index_manager:rebuild_indices(
%%     #{pr => 1, pw => 3, backoff_every => 100, backoff_delay => 50}
%% ).
%% '''
%% @end
%% -----------------------------------------------------------------------------
-spec rebuild_indices() ->
    ok | {error, {in_progress, info()}} | {error, any()}.

rebuild_indices() ->
    rebuild_indices(#{pr => 1, pw => 1}).


%% -----------------------------------------------------------------------------
%% @doc Do not run this function
%% @end
%% -----------------------------------------------------------------------------
-spec rebuild_indices(map()) -> ok | {error, any()}.

rebuild_indices(Opts) ->
    try
        NewOpts = maps_utils:validate(Opts, ?MULTI_OPTS_SPEC),
        gen_server:call(?MODULE, {rebuild_indices, NewOpts})
    catch
        error:Reason ->
            {error, Reason}
    end.



%% =============================================================================
%% GEN_SERVER CALLBACKS
%% =============================================================================



init([]) ->
    {ok, #state{}}.


handle_call({rebuild_index, Key, Map}, _From, St0) ->
    {Resp, St1} = do_rebuild_index(Key, Map, St0),
    {reply, Resp, St1};

handle_call({rebuild_indices, Map}, _From, #state{worker = undefined} = St0) ->
    {ok, St1} = async_rebuild_indices(Map, St0),
    {reply, ok, St1};

handle_call({rebuild_indices, _}, _From, State) ->
    %% We do not allow concurrency for this task
    {reply, {error, {in_progress, State#state.info}}, State};

handle_call(info, _From, State)  ->
    {reply, State#state.info, State};

handle_call(cancel, _From, #state{worker = undefined} = State)  ->
    Info0 = maps:put(end_ts, erlang:system_time(millisecond), State#state.info),
    Info1 = maps:put(status, canceled, Info0),
    {reply, Info1, State#state{info = Info1}};

handle_call(cancel, _From, #state{worker = Pid} = State)  ->
    true = exit(Pid, normal),
    {reply, State#state.info, State};

handle_call(_, _, State) ->
    {reply, ok, State}.


handle_cast(_Event, State) ->
    {noreply, State}.



handle_info({ok, Info0, Pid}, #state{worker = Pid} = State) ->
    Info1 = maps:put(end_ts, erlang:system_time(millisecond), Info0),
    Info2 = maps:put(status, finished, Info1),
    Elapsed = elapsed(Info2),

    _ = ?LOG_INFO(#{
        message => "Finished rebuilding indices",
        elapsed_time_secs => Elapsed,
        info => Info2
    }),
    %% We store the last info and remove worker pid
    NewState = State#state{info = Info2, worker = undefined},
    {noreply, NewState};

handle_info({error, Reason, Info0, Pid}, #state{worker = Pid} = State) ->
    Info1 = maps:put(end_ts, erlang:system_time(millisecond), Info0),
    Info2 = maps:put(status, failed, Info1),
    Elapsed = elapsed(Info2),
    ?LOG_ERROR(#{
        message => "Error while rebuilding indices",
        reason => Reason,
        elapsed_time_secs => Elapsed,
        info => Info2
    }),
    %% We store the last info and remove worker pid
    NewState = State#state{info = Info2, worker = undefined},
    {noreply, NewState};

handle_info({update, Info, Pid}, #state{worker = Pid} = State) ->
    {noreply, State#state{info = Info}};

handle_info(Info, State) ->
    _ = ?LOG_DEBUG(#{
        message => "Unexpected event",
        event => Info
    }),
    {noreply, State}.


terminate(_Reason, _State) ->
    ok.


code_change(_OldVsn, State, _Extra) ->
    {ok, State}.



%% =============================================================================
%% PRIVATE
%% =============================================================================



%% @private
init_info(Opts) ->
    Ts = erlang:system_time(millisecond),
    {Type, Bucket0} = things_thing:bucket_and_type(),
    Bucket = maps:get(bucket, Opts, Bucket0),
    {ok, Host} = babel_config:get(riak_host),
    {ok, Port} = babel_config:get(riak_port),
    #{
        connection => #{
            host => Host,
            port => Port
        },
        options => Opts,
        bucket_type => Type,
        bucket => Bucket,
        start_ts => Ts,
        end_ts => undefined,
        succeded_count => 0,
        failed_count => 0,
        total_count => 0,
        status => in_progress
    }.


%% @private
do_rebuild_index(Key, Opts0, State) ->
    Info = init_info(Opts0),
    #{host := Host, port := Port} = maps:get(connection, Info),
    {ok, Conn} = magenta_riak:connect(Host, Port),
    Bucket = to_binary(maps:get(bucket, Info)),
    Type = to_binary(maps:get(bucket_type, Info)),
    Prefix = {Type, Bucket},
    Opts = maps:to_list(Opts0),

    try
        {ok, Obj} = maybe_throw(get(Conn, Prefix, Key, Opts)),
        ok = maybe_throw(put(Conn, Prefix, Key, Obj, Opts)),
        {ok, State}
    catch
        _:Reason:_ ->
            {{error, Reason}, State}
    end.


%% @private
async_rebuild_indices(Opts , State0) ->
    Manager = self(),
    Info0 = init_info(Opts),

    Pid = spawn_link(fun() ->
        try do_rebuild_indices(Manager, Info0) of
            {ok, Info1} ->
                Manager ! {ok, Info1, self()};
            {error, Reason, _} ->
                throw(Reason)
        catch
            _:EReason:Stacktrace ->
                _ = ?LOG_ERROR(#{
                    message => "Error rebuilding Riak KV indices",
                    rason => EReason,
                    stacktrace => Stacktrace
                }),
                Manager ! {error, EReason, Info0, self()}
        end
    end),

    State1 = State0#state{info = Info0, worker = Pid},
    {ok, State1}.


%% @private
do_rebuild_indices(Manager, Info) ->
    _ = ?LOG_INFO(#{
        message => "Rebuilding Riak KV indices",
        info => Info
    }),

    #{host := Host, port := Port} = maps:get(connection, Info),
    {ok, Conn} = magenta_riak:connect(Host, Port),
    Bucket = to_binary(maps:get(bucket, Info)),
    Type = to_binary(maps:get(bucket_type, Info)),
    Prefix = {Type, Bucket},
    Opts = maps:get(options, Info),

    Fun = fun(Keys, {Acc0, Counter0}) ->
        PList = maps:to_list(Opts),
        FoldFun = fun(Key, FoldAcc0) ->
            ok = maybe_backoff(Opts, FoldAcc0, Counter0),
            try
                {ok, Obj} = maybe_throw(get(Conn, Prefix, Key, PList)),
                ok = maybe_throw(put(Conn, Prefix, Key, Obj, PList)),
                FoldAcc1 = maps:update_with(
                    succeded_count, fun(V) -> V + 1 end, FoldAcc0
                ),
                maps:update_with(
                    total_count, fun(V) -> V + 1 end, FoldAcc1
                )
            catch
                throw:Reason:Stacktrace ->
                    _ = ?LOG_WARNING(#{
                        message => "Skipped rebuilding Riak KV indices for object",
                        reason => Reason,
                        key => Key,
                        stacktrace => Stacktrace
                    }),
                    EFoldAcc1 = maps:update_with(
                        failed_count, fun(V) -> V + 1 end, FoldAcc0
                    ),
                    maps:update_with(
                        total_count, fun(V) -> V + 1 end, EFoldAcc1
                    )
            end
        end,
        Acc1 = lists:foldl(FoldFun, Acc0, Keys),
        ok = maybe_notify_manager(Manager, Acc1, Counter0),
        ok = maybe_gc(Acc1, Counter0),
        {Acc1, Counter0 + length(Keys)}
    end,

    case magenta_riak:stream_keys(Conn, Prefix, Fun, {Info, 0}) of
        {ok, {Info1, _}} ->
            {ok, Info1};
        Error ->
            Error
    end.


%% @private
get(Conn, Prefix, Key, PList) ->
    riakc_pb_socket:fetch_type(
        Conn, Prefix, Key, [{timeout, ?RIAK_TIMEOUT} | PList]
    ).


%% @private
put(Conn, Prefix, Key, Obj0, PList) ->
    %% We do this to increment the version vector,
    %% otherwise Riak returns an {error, unmodified}
    case riakc_map:find({<<"id">>, register}, Obj0) of
        {ok, Id} ->
            Obj1 = riakc_map:update(
                {<<"id">>, register}, fun(R) -> riakc_register:set(Id, R) end,
                Obj0
            ),
            DTOps = riakc_map:to_op(Obj1),
            riakc_pb_socket:update_type(
                Conn, Prefix, Key, DTOps, [{timeout, ?RIAK_TIMEOUT} | PList]
            );
        error ->
            _ = ?LOG_WARNING(#{
                message => "Skipped rebuilding Riak KV indices for object",
                reason => invalid_object,
                key => Key,
                object => Obj0
            }),
            ok
    end.


%% @private
elapsed(#{start_ts := T0, end_ts := T1}) ->
    trunc((T1 - T0) / 1000).


%% @private
to_binary(B) when is_atom(B) ->
    atom_to_binary(B, utf8);

to_binary(B) when is_binary(B) ->
    B.


%% @private
maybe_throw(ok) ->
    ok;
maybe_throw({ok, _} = OK) ->
    OK;
maybe_throw({error, Reason}) ->
    throw(Reason).


%% -----------------------------------------------------------------------------
%% @private
%% @doc Notifies the manager of an update every 1000 keys
%% @end
%% -----------------------------------------------------------------------------
maybe_notify_manager(_, #{total_count := N}, Counter) when N - Counter < 1000 ->
    ok;

maybe_notify_manager(Manager, Info, _) ->
    Manager ! {update, Info, self()},
    ok.


maybe_gc(#{total_count := N}, Counter) when N - Counter < 5000 ->
    ok;

maybe_gc(_, _) ->
    true = erlang:garbage_collect(),
    ok.


%% -----------------------------------------------------------------------------
%% @private
%% @doc Decides wether to backoff in order to give Riak some leeway
%% @end
%% -----------------------------------------------------------------------------
maybe_backoff(#{backoff_every := Backoff}, #{total_count := N}, Counter)
when N - Counter < Backoff ->
    ok;

maybe_backoff(#{backoff_delay := Millis}, _, _) ->
    timer:sleep(Millis).