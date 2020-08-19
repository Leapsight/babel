%% -----------------------------------------------------------------------------
%% @doc An object that specifies the type and configuration of a Riak KV index
%% and the location `({bucket_type(), bucket()}, key()})' of its partitions
%% in Riak KV.
%%
%% Every index has one or more partition objects which are modelled as Riak KV
%% maps.
%%
%% An index is persisted as a read-only CRDT Map as part of an index collection
%% {@linkbabel_collection}. An index collection aggregates all indices
%% for a topic e.g. domain model entity.
%%
%% As this object is read-only we turn it into an Erlang map as soon as we read
%% it from the collection for enhanced performance. So loosing its CRDT context
%% it not an issue.
%%
%% @end
%% -----------------------------------------------------------------------------
-module(babel_index).
-include("babel.hrl").
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
            "The bucket type used to store the babel_index_partition:t() objects. "
            "This bucket type should have a datatype of `map`."
        >>,
        required => true,
        datatype => [binary, atom],
        allow_undefined => true,
        default => babel_config:get([bucket_types, index_data]),
        validator => ?BINARY_VALIDATOR
    },
    bucket_prefix => #{
        description => <<
            "The bucket name used to store the babel_index_partition:t() objects"
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

-record(babel_index_partition_iter, {
    partition_identifiers   ::  [partition_id()],
    current_id              ::  partition_id(),
    bucket_type             ::  bucket_type(),
    bucket                  ::  bucket(),
    done = false            ::  boolean()
}).

-record(babel_element_iter, {
    partition_iter          ::  partition_iterator(),
    key                     ::  binary(),
    bucket_type             ::  bucket_type(),
    bucket                  ::  bucket(),
    done = false            ::  boolean()
}).


-type t()                       ::  map().
-type t_crdt()                  ::  riakc_map:crdt_map().
-type config()                  ::  map().
-type config_crdt()             ::  riakc_map:crdt_map().
-type partition_id()            ::  binary().
-type partition_key()           ::  binary().
-type local_key()               ::  binary().
-type action()                  ::  insert | delete.
-type data()                    ::  riakc_map:crdt_map()
                                    | proplists:proplist()
                                    | map().
-type partition_iterator()      ::  #babel_index_partition_iter{}.
-type element_iterator()        ::  #babel_element_iter{}.

-export_type([t/0]).
-export_type([t_crdt/0]).
-export_type([config/0]).
-export_type([config_crdt/0]).
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
-export([create_partitions/1]).
-export([from_crdt/1]).
-export([new/1]).
-export([partition_identifiers/1]).
-export([partition_identifiers/2]).
-export([to_crdt/1]).
-export([type/1]).
-export([update/3]).
%% -export([get/4]).
%% -export([remove_entry/4]).
%% -export([match/4]).
%% -export([list/4]).





%% =============================================================================
%% CALLBACKS
%% =============================================================================



-callback init(IndexId :: binary(), ConfigData :: map()) ->
    {ok, Config :: config()}
    | {error, any()}.

-callback init_partitions(config()) ->
    {ok, [babel_index_partition:t()]}
    | {error, any()}.

-callback from_crdt(ConfigCRDT :: config_crdt()) -> Config :: config().

-callback to_crdt(Config :: config()) -> ConfigCRDT :: config_crdt().

-callback number_of_partitions(config()) -> pos_integer().

-callback partition_identifier(data(), config()) -> partition_id().

-callback partition_identifiers(asc | desc, config()) -> [partition_id()].

-callback update_partition(
    {action(), data()}, babel_index_partition:t(), config()) ->
    babel_index_partition:t().




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
%% babel_index_partition:t() objects. This bucket type should have a datatype
%% of `map`.
%% **bucket** :: binary() | atom() – the bucket name used to store the
%% babel_index_partition:t() objects of this index. Typically the name of an
%% entity in plural form e.g. 'accounts'.
%% **type** :: atom() – the index type (Erlang module) used by this index.
%% config :: map() – the configuration data for the index type used by this
%% index.
%%
%% @end
%% -----------------------------------------------------------------------------
-spec new(IndexData :: map()) -> Index :: t() | no_return().

new(IndexData) ->
    Index0 = maps_utils:validate(IndexData, ?SPEC),
    #{
        id := IndexId,
        type := Type,
        config := ConfigSpec,
        bucket_prefix := BucketPrefix
    } = Index0,

    Index1 = maps:without([bucket_prefix], Index0),
    Bucket = <<BucketPrefix/binary, ?PATH_SEPARATOR, "index_data">>,
    Index = Index1#{bucket => Bucket},

    case Type:init(IndexId, ConfigSpec) of
        {ok, Config} ->
            Index#{config => Config};
        {error, Reason} ->
            error(Reason)
    end.


%% -----------------------------------------------------------------------------
%% @doc
%% @end
%% -----------------------------------------------------------------------------
-spec from_crdt(ConfigCRDT :: t_crdt()) -> Index :: t().

from_crdt(Index) ->
    Id = babel_crdt:register_to_binary(
        riakc_map:fetch({<<"id">>, register}, Index)
    ),
    BucketType = babel_crdt:register_to_binary(
        riakc_map:fetch({<<"bucket_type">>, register}, Index)
    ),
    Bucket = babel_crdt:register_to_binary(
        riakc_map:fetch({<<"bucket">>, register}, Index)
    ),
    Type = babel_crdt:register_to_existing_atom(
        riakc_map:fetch({<<"type">>, register}, Index),
        utf8
    ),
    Config = Type:from_crdt(
        riakc_map:fetch({<<"config">>, map}, Index)
    ),

    #{
        id => Id,
        bucket_type => BucketType,
        bucket => Bucket,
        type => Type,
        config => Config
    }.


%% -----------------------------------------------------------------------------
%% @doc
%% @end
%% -----------------------------------------------------------------------------
-spec to_crdt(Index :: t()) -> IndexCRDT :: t_crdt().

to_crdt(Index) ->
    #{
        id := Id,
        bucket_type := BucketType,
        bucket := Bucket,
        type := Type,
        config := Config
    } = Index,

    ConfigCRDT =  Type:to_crdt(Config),

    Values = [
        babel_crdt:map_entry(register, <<"id">>, Id),
        babel_crdt:map_entry(register, <<"bucket_type">>, BucketType),
        babel_crdt:map_entry(register, <<"bucket">>, Bucket),
        babel_crdt:map_entry(
            register, <<"type">>, atom_to_binary(Type, utf8)),
        {{<<"config">>, map}, ConfigCRDT}
    ],
    riakc_map:new(Values, undefined).


%% -----------------------------------------------------------------------------
%% @doc
%% @end
%% -----------------------------------------------------------------------------
-spec create_partitions(t()) -> [babel_index_partition:t()] | no_return().

create_partitions(#{type := Type, config := Config}) ->
    case Type:init_partitions(Config) of
        {ok, Partitions} -> Partitions;
        {error, Reason} -> error(Reason)
    end.


%% -----------------------------------------------------------------------------
%% @doc Returns the Riak KV bucket were this index partitions are stored.
%% @end
%% -----------------------------------------------------------------------------
-spec bucket(t()) -> maybe_error(binary()).

bucket(#{bucket := Value}) -> Value.


%% -----------------------------------------------------------------------------
%% @doc Returns the Riak KV bucket type associated with this index.
%% @end
%% -----------------------------------------------------------------------------
-spec bucket_type(t()) -> maybe_error(binary()).

bucket_type(#{bucket_type := Value}) -> Value.


%% -----------------------------------------------------------------------------
%% @doc Returns the type of this index. A type is a module name implementing
%% the babel behaviour.
%% @end
%% -----------------------------------------------------------------------------
-spec type(t()) -> maybe_error(module()).

type(#{type := Value}) -> Value.


%% -----------------------------------------------------------------------------
%% @doc Returns the configuration associated with this index.
%% The configuration depends on the index type {@link babel:type/1}.
%% @end
%% -----------------------------------------------------------------------------
-spec config(t()) -> maybe_error(riakc_map:crdt_map()).

config(#{config := Value}) -> Value.


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
    Part0 = babel_index_partition:fetch(Conn, TypeBucket, Key),
    Part1 = Mod:update_partition(Config, Part0, Action),

    case babel_index_partition:store(Conn, TypeBucket, Key, Part1) of
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
        Part0 = babel_index_partition:fetch(Conn, TypeBucket, Key),
        Part1 = Mod:update_partition(Config, Part0, Actions),

        case babel_index_partition:store(Conn, TypeBucket, Key, Part1) of
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
actions_by_partition_id(Mod, Config, List) ->
    Tuples = [
        %% We generate the tuple {partition_id(), {action(), data()}}.
        {Mod:partition_identifier(Config, Data), X}
        || {_, Data} = X <- List
    ],

    %% We generate the list [ {partition_id(), [{action(), data()}]} ]
    %% by grouping by the 1st element and collecting the 2nd element
    Proj = {1, {function, collect, [2]}},
    leap_tuples:summarize(Tuples, Proj, #{}).
