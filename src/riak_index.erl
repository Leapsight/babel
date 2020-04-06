%% -----------------------------------------------------------------------------
%% @doc An object that specifies the type and configuration of a Riak KV index
%% and the location `({bucket_type(), bucket()}, key()})' of its partitions
%% in Riak KV.
%%
%% Every index has one or more partition objects which are modelled as Riak KV
%% maps.
%%
%% An index is persisted as part of an index collection {@link
%% riak_index_collection}. An index collection aggregates all indices
%% for a topic e.g. domain model entity.
%%
%% @end
%% -----------------------------------------------------------------------------
-module(riak_index).
-include("riak_index.hrl").
-include_lib("riakc/include/riakc.hrl").
-include_lib("kernel/include/logger.hrl").

%% Validator for maps_utils:validate/2,3
-define(BINARY_VALIDATOR, fun
    (Val) when is_atom(Val) ->
        {ok, atom_to_binary(Val, utf8)};
    (Val) when is_binary(Val) ->
        true;
    (_) ->
        false
end).

%% Spec for maps_utils:validate/2,3
-define(SPEC, #{
    id => #{
        required => true,
        datatype => binary
    },
    bucket_type => #{
        description => <<
            "The bucket type used to store the index_partition() objects. "
            "This bucket type should have a datatype of `map`."
        >>,
        required => true,
        datatype => [binary, atom],
        default => <<"default">>,
        validator => ?BINARY_VALIDATOR
    },
    bucket => #{
        description => <<
            "The bucket name used to store the index_partition() objects"
            " of this index. Typically the name of an entity in plural form"
            " e.g. 'accounts'."
        >>,
        required => true,
        datatype => [binary, atom],
        validator => ?BINARY_VALIDATOR
    },
    type => #{
        description => <<
            "The index type (Erlang module) used by this index."
        >>,
        required => true,
        datatype => atom
    },
    config => #{
        description => <<
            "The configuration data for the index type used by this index."
        >>,
        required => false,
        default => #{},
        datatype => map
    }
}).

-record(riak_index_partition_iter, {
    partition_identifiers   ::  [partition_id()],
    current_id              ::  partition_id(),
    bucket_type             ::  bucket_type(),
    bucket                  ::  bucket(),
    done = false            ::  boolean()
}).

-record(riak_index_element_iter, {
    partition_iter          ::  partition_iterator(),
    key                     ::  binary(),
    bucket_type             ::  bucket_type(),
    bucket                  ::  bucket(),
    done = false            ::  boolean()
}).


-type t()                       ::  riakc_map:crdt_map().
-type config()                  ::  riakc_map:crdt_map().
-type partition()               ::  riakc_map:crdt_map().
-type partition_id()            ::  binary().
-type partition_key()           ::  binary().
-type local_key()               ::  binary().
-type action()                  ::  insert | delete.
-type data()                    ::  riakc_map:crdt_map()
                                    | proplists:proplist()
                                    | map().
-type partition_iterator()      ::  #riak_index_partition_iter{}.
-type element_iterator()        ::  #riak_index_element_iter{}.

-export_type([t/0]).
-export_type([config/0]).
-export_type([partition/0]).
-export_type([partition_id/0]).
-export_type([partition_key/0]).
-export_type([local_key/0]).
-export_type([action/0]).
-export_type([data/0]).
-export_type([partition_iterator/0]).
-export_type([element_iterator/0]).


%% API
-export([bucket/1]).
-export([bucket_type/1]).
-export([config/1]).
-export([new/1]).
-export([partition_identifiers/1]).
-export([partition_identifiers/2]).
-export([type/1]).
-export([update/3]).
%% -export([get/4]).
%% -export([remove_entry/4]).
%% -export([match/4]).
%% -export([list/4]).





%% =============================================================================
%% CALLBACKS
%% =============================================================================



-callback init(t(), map()) ->
    {ok, config(), [{key(), partition()}]}
    | {error, any()}.

-callback number_of_partitions(config()) -> pos_integer().

-callback partition_identifier(config(), data()) -> partition_id().

-callback partition_identifiers(config(), asc | desc) -> [partition_id()].

-callback partition_size(config(), partition()) -> non_neg_integer().

-callback update_partition(config(), partition(), {action(), data()}) ->
    partition().




%% =============================================================================
%% API
%% =============================================================================



%% -----------------------------------------------------------------------------
%% @doc Returns a new index based on the specification map. It fails in case
%% the specification in invalid.
%%
%% A specification is map with the following fields (required fields are in
%% bold):
%%
%% **id** :: binary() – a unique name for this index.
%% **bucket_type** :: binary() | atom() – the bucket type used to store the
%% index_partition() objects. This bucket type should have a datatype of `map`.
%% **bucket** :: binary() | atom() – the bucket name used to store the
%% index_partition() objects of this index. Typically the name of an entity in
%% plural form e.g. 'accounts'.
%% **type** :: atom() – the index type (Erlang module) used by this index.
%% config :: map() – the configuration data for the index type used by this
%% index.
%%
%% @end
%% -----------------------------------------------------------------------------
-spec new(Spec :: map()) -> maybe_error(t()).

new(Spec0) ->
    Spec1 = maps_utils:validate(Spec0, ?SPEC),
    #{type := Type, config := ConfigSpec} = Spec1,

    case Type:init(ConfigSpec) of
        {ok, ConfigCRDT} ->
            spec_to_crdt(Spec1#{config => ConfigCRDT});
        {error, _} = Error ->
            Error
    end.


%% -----------------------------------------------------------------------------
%% @doc Returns the Riak KV bucket were this index partitions are stored.
%% @end
%% -----------------------------------------------------------------------------
-spec bucket(t()) -> maybe_error(binary()).

bucket(Index) ->
    riakc_map:fetch({<<"bucket">>, register}, Index).


%% -----------------------------------------------------------------------------
%% @doc Returns the Riak KV bucket type associated with this index.
%% @end
%% -----------------------------------------------------------------------------
-spec bucket_type(t()) -> maybe_error(binary()).

bucket_type(Index) ->
    riakc_map:fetch({<<"bucket_type">>, register}, Index).


%% -----------------------------------------------------------------------------
%% @doc Returns the type of this index. A type is a module name implementing
%% the riak_index behaviour.
%% @end
%% -----------------------------------------------------------------------------
-spec type(t()) -> maybe_error(module()).

type(Index) ->
    binary_to_existing_atom(
        riakc_map:fetch({<<"type">>, register}, Index),
        utf8
    ).


%% -----------------------------------------------------------------------------
%% @doc Returns the configuration associated with this index.
%% The configuration depends on the index type {@link riak_index:type/1}.
%% @end
%% -----------------------------------------------------------------------------
-spec config(t()) -> maybe_error(riakc_map:crdt_map()).

config(Index) ->
    riakc_map:fetch({<<"config">>, map}, Index).


%% -----------------------------------------------------------------------------
%% @doc
%% @end
%% -----------------------------------------------------------------------------
-spec update(
    Conn :: pid(), Index :: t(), {action(), data()} | [{action(), data()}]) ->
    ok | {error, any()}.

update(Conn, Index, {_, Data} = Action) ->
    Mod = type(Index),
    Config = config(Index),
    TypeBucket = {bucket_type(Index), bucket(Index)},

    Key = Mod:partition_identifier(Config, Data),
    Part0 = riak_index_partition:fetch(Conn, TypeBucket, Key),
    Part1 = Mod:update_partition(Config, Part0, Action),

    case riak_index_partition:update(Conn, TypeBucket, Key, Part1) of
        ok ->
            ok;
        {error, Reason} ->
            ?LOG_ERROR(#{
                text => "Error while updating partition",
                partition_id => Key,
                type_bucket => TypeBucket,
                reason => Reason
            }),
            ok
    end;

update(Conn, Index, List) when is_list(List) ->
    Mod = type(Index),
    Config = config(Index),
    TypeBucket = {bucket_type(Index), bucket(Index)},

    Update = fun({Key, Actions}) when is_list(Actions) ->
        Part0 = riak_index_partition:fetch(Conn, TypeBucket, Key),
        Part1 = Mod:update_partition(Config, Part0, Actions),

        case riak_index_partition:update(Conn, TypeBucket, Key, Part1) of
            ok ->
                ok;
            {error, Reason} ->
                ?LOG_ERROR(#{
                    text => "Error while updating partition",
                    partition_id => Key,
                    type_bucket => TypeBucket,
                    reason => Reason
                }),
                ok
        end
    end,
    lists:foreach(Update, actions_by_partition_id(Mod, Config, List)).



%% -----------------------------------------------------------------------------
%% @doc Returns the list of Riak KV keys under which the partitions are stored,
%% in ascending order.
%% This is equivalent to the call `partition_identifiers(Index, asc)'.
%% @end
%% -----------------------------------------------------------------------------
-spec partition_identifiers(t()) -> maybe_error([binary()]).

partition_identifiers(Index) ->
    partition_identifiers(Index, asc).


%% -----------------------------------------------------------------------------
%% @doc Returns the list of Riak KV keys under which the partitions are stored
%% in a defined order i.e. `asc` | `desc`.
%% @end
%% -----------------------------------------------------------------------------
-spec partition_identifiers(t(), asc | desc) -> maybe_error([binary()]).

partition_identifiers(Index, Order) ->
    Mod = type(Index),
    Config = config(Index),
    Mod:partition_identifiers(Config, Order).


%% -----------------------------------------------------------------------------
%% @doc
%% @end
%% -----------------------------------------------------------------------------
%% -spec get(
%%     Conn :: pid(),
%%     IndexNameOrSpec :: binary() | spec(),
%%     Pattern :: binary(),
%%     Opts :: get_options()) ->
%%     {ok, t()} | {error, term()} | unchanged.

%% get(Conn, IndexName, Pattern, Opts) when is_binary(IndexName) ->
%%     Spec = get_index_metadata(IndexName),
%%     get(Conn, Spec, Pattern, Opts);

%% get(Conn, Spec, Pattern, Opts) when is_map(Spec) ->
%%     TB = type_bucket(Spec),
%%     Key = partition_key(Spec, Pattern),
%%     riakc_pb_socket:get(Conn, TB, Key, Opts).



%% -----------------------------------------------------------------------------
%% @doc Returns a list of matching index entries
%% @end
%% -----------------------------------------------------------------------------
%% -spec match(Index :: t(), Pattern :: binary(), Opts :: get_options()) ->
%%     [entry()].

%% match(_Index, _Pattern, _Opts) ->
%%     %% riakc_set:fold()
%%     error(not_implemented).



%% -----------------------------------------------------------------------------
%% @doc Returns a list of matching index entries
%% @end
%% -----------------------------------------------------------------------------
%% -spec match(
%%     Conn :: pid(),
%%     IndexNameOrSpec :: binary() | spec(),
%%     Pattern :: binary(),
%%     Opts :: get_options()) ->
%%     [entry()].

%% match(Conn, IndexName, Pattern, Opts) when is_binary(IndexName) ->
%%     Spec = get_spec(IndexName),
%%     Index = get(Conn, Spec, Opts),
%%     match(Index, Pattern, Opts);

%% match(_Conn, Spec, _Pattern, _Opts)  when is_map(Spec) ->
%%     error(not_implemented).




%% =============================================================================
%% PRIVATE
%% =============================================================================



%% @private
spec_to_crdt(Spec) ->
    #{
        id := Id,
        bucket_type := BucketType,
        bucket := Bucket,
        type := Type,
        config := Config
    } = Spec,

    Ctxt = undefined,

    Values = [
        {{<<"id">>, register}, riakc_register:new(Id, Ctxt)},
        {{<<"bucket_type">>, register}, riakc_register:new(BucketType, Ctxt)},
        {{<<"bucket">>, register}, riakc_register:new(Bucket, Ctxt)},
        {
            {<<"type">>, register},
            riakc_register:new(atom_to_binary(Type, utf8), Ctxt)
        },
        {{<<"config">>, map}, Config}
    ],

    riakc_map:new(Values, Ctxt).


%% @private
actions_by_partition_id(Mod, Config, List) ->
    Tuples = [
        %% We generate the tuple {partition_id(), {action(), data()}}.
        {Mod:partition_identifier(Config, Data), X}
        || {_, Data} = X <- List
    ],

    %% We generate the list [ {partition_id(), [{action(), data()}]} ].
    Proj = {1, {function, collection, [2]}},
    leap_tuples:summarize(Tuples, Proj, #{}).




%% @private
%% gen_bucket_name(TenantId, Name) ->
%%     <<
%%         $<, TenantId/binary, $>,
%%         ?KEY_SEPARATOR,
%%         Name/binary
%%     >>.




%% @private
%% type_bucket(#{bucket_type := BucketType, bucket := Bucket}) ->
%%     {BucketType, Bucket}.


%% @private
%% get_index_metadata(_IndexName) ->
%%     %% Get metadata from ets or shall we store metadata in Riak too?
%%     error(not_implemented).

%% @private
%% partition(#{partition := N}, _) when is_integer(N) ->
%%     N;

%% partition(Spec, Pattern) ->
%%     #{
%%         number_of_partitions := N,
%%         partition := Fun
%%     } = Spec,
%%     integer_to_binary(Fun(Pattern, N)).


%% %% @private
%% partition_key(Spec, Pattern) ->
%%     Name = maps:get(name, Spec),
%%     Partition = partition(Spec, Pattern),
%%     <<Name/binary, $:, Partition>>.


%% @private
%% opts_to_riak_opts(Map) ->
%%     Keys = [deadline],
%%     maps:to_list(maps:without(Keys, Map)).