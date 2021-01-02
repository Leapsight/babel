%% =============================================================================
%%  babel_simple_index.erl -
%%
%%  Copyright (c) 2020 Leapsight Holdings Limited. All rights reserved.
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
%% @doc
%%
%% This object is immutable.
%%
%% @end
%% -----------------------------------------------------------------------------
-module(babel_simple_index).
-behaviour(babel_index).
-include("babel.hrl").
-include_lib("kernel/include/logger.hrl").

%% TODO Leaf nodes in the index should be either SET or REGISTER depending on the new option 'cardinality' :: one | many.

-define(KEYPATH_LIST_SPEC, {list, [binary, tuple, {list, [binary, tuple]}]}).

-define(SPEC, #{
    case_sensitive => #{
        required => true,
        allow_null => false,
        allow_undefined => false,
        default => false,
        datatype => boolean
    },
    sort_ordering => #{
        required => true,
        allow_null => false,
        allow_undefined => false,
        default => asc,
        datatype => {in, [asc, desc]}
    },
    index_by => #{
        required => true,
        allow_null => false,
        allow_undefined => false,
        datatype => ?KEYPATH_LIST_SPEC,
        validator => fun
            ([]) -> false;
            (_) -> true
        end
    },
    covered_fields => #{
        required => true,
        allow_null => false,
        allow_undefined => false,
        datatype => ?KEYPATH_LIST_SPEC
    }
}).

-type t()           ::  #{
    case_sensitive := boolean(),
    sort_ordering := asc | desc,
    partition_identifier_prefix := binary(),
    index_by := fields(),
    covered_fields := fields()
}.

-type fields()      ::  [babel_key_value:key()].
-type iterator()    ::  term().

-export_type([fields/0]).


%% API
-export([covered_fields/1]).
-export([index_by/1]).
-export([partition_identifier_prefix/1]).
-export([sort_ordering/1]).


%% BEHAVIOUR CALLBACKS
-export([from_riak_dict/1]).
-export([init/2]).
-export([init_partitions/1]).
-export([init_partition/2]).
-export([iterator/3]).
-export([iterator_done/1]).
-export([iterator_key/1]).
-export([iterator_move/3]).
-export([iterator_values/1]).
-export([match/3]).
-export([number_of_partitions/1]).
-export([partition_identifier/2]).
-export([partition_identifiers/2]).
-export([to_riak_object/1]).
-export([update_partition/3]).
-export([distinguished_key_paths/1]).


%% =============================================================================
%% API
%% =============================================================================




%% -----------------------------------------------------------------------------
%% @doc Returns true if the index is case sensitivity.
%% @end
%% -----------------------------------------------------------------------------
-spec case_sensitive(t()) -> boolean().

case_sensitive(#{case_sensitive := Value}) -> Value.


%% -----------------------------------------------------------------------------
%% @doc Returns the sort ordering configured for this index. The result can be
%% the atoms `asc' or `desc'.
%% @end
%% -----------------------------------------------------------------------------
-spec sort_ordering(t()) -> asc | desc.

sort_ordering(#{sort_ordering := Value}) -> Value.


%% -----------------------------------------------------------------------------
%% @doc
%% @end
%% -----------------------------------------------------------------------------
-spec index_by(t()) -> [binary()].

index_by(#{index_by := Value}) -> Value.


%% -----------------------------------------------------------------------------
%% @doc
%% @end
%% -----------------------------------------------------------------------------
-spec covered_fields(t()) -> [binary()].

covered_fields(#{covered_fields := Value}) -> Value.


%% -----------------------------------------------------------------------------
%% @doc
%% @end
%% -----------------------------------------------------------------------------
-spec partition_identifier_prefix(t()) -> binary().

partition_identifier_prefix(#{partition_identifier_prefix := Value}) -> Value.



%% =============================================================================
%% BEHAVIOUR CALLBACKS
%% =============================================================================



%% -----------------------------------------------------------------------------
%% @doc
%% @end
%% -----------------------------------------------------------------------------
-spec init(IndexId :: binary(), ConfigData :: map()) ->
    {ok, t()} | {error, any()}.

init(IndexId, ConfigData0) ->
    Config0 = validate(ConfigData0),
    Prefix = <<IndexId/binary, "_partition">>,
    Config = maps:put(partition_identifier_prefix, Prefix, Config0),
    {ok, Config}.


%% -----------------------------------------------------------------------------
%% @doc
%% @end
%% -----------------------------------------------------------------------------
-spec from_riak_dict(Dict :: orddict:orddict()) -> Config :: t().

from_riak_dict(Dict) ->
    Sort = babel_crdt:register_to_existing_atom(
        orddict:fetch({<<"sort_ordering">>, register}, Dict),
        utf8
    ),

    Prefix = babel_crdt:register_to_binary(
        orddict:fetch({<<"partition_identifier_prefix">>, register}, Dict)
    ),

    IndexBy = decode_fields(
        babel_crdt:register_to_binary(
            orddict:fetch({<<"index_by">>, register}, Dict)
        )
    ),

    CoveredFields = decode_fields(
        babel_crdt:register_to_binary(
            orddict:fetch({<<"covered_fields">>, register}, Dict)
        )
    ),

    CaseSensitive = case orddict:find({<<"case_sensitive">>, flag}, Dict) of
        {ok, Value} -> Value;
        error -> false
    end,

    %% As this object is read-only and embeded in an Index Collection we turn it
    %% into an Erlang map as soon as we read it from the collection for enhanced
    %% performance. So loosing its CRDT context it not an issue.
    #{
        case_sensitive => CaseSensitive,
        sort_ordering => Sort,
        partition_identifier_prefix => Prefix,
        index_by => IndexBy,
        covered_fields => CoveredFields
    }.


%% -----------------------------------------------------------------------------
%% @doc
%% @end
%% -----------------------------------------------------------------------------
-spec to_riak_object(Config :: t()) ->
    ConfigCRDT :: babel_index:riak_object().

to_riak_object(Config) ->
    #{
        case_sensitive := CaseSensitive,
        sort_ordering := Sort,
        partition_identifier_prefix := Prefix,
        index_by := IndexBy,
        covered_fields := CoveredFields
    } = Config,


    Values = [
        {{<<"case_sensitive">>, flag}, CaseSensitive},
        {{<<"sort_ordering">>, register}, atom_to_binary(Sort, utf8)},
        {{<<"partition_identifier_prefix">>, register}, Prefix},
        {{<<"index_by">>, register}, encode_fields(IndexBy)},
        {{<<"covered_fields">>, register}, encode_fields(CoveredFields)}
    ],

    lists:foldl(
        fun({K, V}, Acc) ->
            babel_key_value:set(K, V, Acc)
        end,
        riakc_map:new(),
        Values
    ).


%% -----------------------------------------------------------------------------
%% @doc
%% @end
%% -----------------------------------------------------------------------------
-spec init_partitions(t()) ->
    {ok, [babel_index_partition:t()]}
    | {error, any()}.

init_partitions(_) ->
    %% We comply with the behaviour but our partitions are dynamic,
    %% there is one partition per index_by key, so we return the empty list.
    {ok, []}.


%% -----------------------------------------------------------------------------
%% @doc
%% @end
%% -----------------------------------------------------------------------------
-spec init_partition(PartitionId :: binary(), ConfigData :: t()) ->
    {ok, babel_index_partition:t()}
    | {error, any()}.

init_partition(PartitionId, _) ->
    Partition = babel_index_partition:new(PartitionId, #{type => set}),
    {ok, Partition}.


%% -----------------------------------------------------------------------------
%% @doc
%% @end
%% -----------------------------------------------------------------------------
-spec number_of_partitions(t()) -> pos_integer() | undefined.

number_of_partitions(_) ->
    %% We comply with the behaviour but our partitions are dynamic,
    %% there is one partition per index_by key, so we return the empty list.
    undefined.


%% -----------------------------------------------------------------------------
%% @doc
%% @end
%% -----------------------------------------------------------------------------
-spec partition_identifier(babel_index:key_value(), t()) ->
    babel_index:partition_id() | no_return().

partition_identifier(KeyValue, Config) ->

    %% There is one partition per index_by key.
    Keys = index_by(Config),
    Prefix = maps:get(partition_identifier_prefix, Config),

    %% We collect the partition keys from the key value object and build a
    %% binary key that we use as id for the partition i.e. we use as key in
    %% Riak KV.
    try gen_key(Keys, KeyValue, Config) of
        PKey -> gen_identifier(Prefix, PKey)
    catch
        error:{badkey, Key} ->
            error({missing_pattern_key, Key})
    end.


%% -----------------------------------------------------------------------------
%% @doc
%% @end
%% -----------------------------------------------------------------------------
-spec partition_identifiers(asc | desc, t()) ->
    [babel_index:partition_id()].

partition_identifiers(_, _) ->
    %% Partitions are dynamic
    [].


%% -----------------------------------------------------------------------------
%% @doc
%% @end
%% -----------------------------------------------------------------------------
-spec distinguished_key_paths(Config :: t()) -> [babel_key_value:key()].

distinguished_key_paths(Config) ->
    ordsets:to_list(
        ordsets:union([
            ordsets:from_list(index_by(Config)),
            ordsets:from_list(covered_fields(Config))
        ])
    ).


%% -----------------------------------------------------------------------------
%% @doc
%% @end
%% -----------------------------------------------------------------------------
-spec update_partition(
    ActionData :: babel_index:update_action() | [babel_index:update_action()],
    Partition :: babel_index_partition:t(),
    Config :: t()) -> babel_index_partition:t() | no_return().

update_partition([H|T], Partition0, Config) ->
    Partition1 = update_partition(H, Partition0, Config),
    update_partition(T, Partition1, Config);

update_partition([], Partition, _) ->
    Partition;

update_partition({delete, Data}, Partition, Config) ->
    Value = gen_key(covered_fields(Config), Data, Config),

    babel_index_partition:update_data(
        fun(Set) -> riakc_set:del_element(Value, Set) end,
        Partition
    );

update_partition({insert, Data}, Partition, Config) ->
    Value = gen_key(covered_fields(Config), Data, Config),

    babel_index_partition:update_data(
        fun(Set) -> riakc_set:add_element(Value, Set) end,
        Partition
    ).


%% -----------------------------------------------------------------------------
%% @doc
%% @end
%% -----------------------------------------------------------------------------
match(Pattern, Partition, Config) ->
    IndexBy = index_by(Config),
    IndexKey = safe_gen_key(IndexBy, Pattern, Config),

    case IndexKey of
        error ->
            %% At least an aggregate key is required to match
            error(badpattern);

        undefined ->
            %% This should be imposible, we could not have created an index
            %% with IndexKey = []
            error(invalid_metadata);

        IndexKey ->
            Type = babel_index_partition:type(Partition),
            Type == set orelse error({inconsistent_partition_type, Type}),

            %% Data is a riakc_set
            case babel_index_partition:data(Partition) of
                [] ->
                    [];
                Results ->
                    Covered = covered_fields(Config),
                    [covered_fields_output(Covered, Bin) || Bin <- Results]
            end

    end.


%% -----------------------------------------------------------------------------
%% @doc
%% @end
%% -----------------------------------------------------------------------------
-spec iterator(
    babel_index:t(), babel_index:config(), Opts :: babel:riak_opts()) ->
    Iterator :: iterator().

iterator(_, _, _) ->
    error(not_implemented).


%% -----------------------------------------------------------------------------
%% @doc
%% @end
%% -----------------------------------------------------------------------------
-spec iterator_move(
     Action :: babel_index:iterator_action(), Iterator :: iterator(), t()) ->
    iterator().

iterator_move(_Action, _Iterator, _Config) ->
    %% TODO
    error(not_implemented).


%% -----------------------------------------------------------------------------
%% @doc
%% @end
%% -----------------------------------------------------------------------------
-spec iterator_done(Iterator :: any()) -> boolean().

iterator_done(_) ->
    error(not_implemented).


%% -----------------------------------------------------------------------------
%% @doc
%% @end
%% -----------------------------------------------------------------------------
-spec iterator_key(Iterator :: any()) -> Key :: babel_index:index_key().

iterator_key(_) ->
    error(not_implemented).


%% -----------------------------------------------------------------------------
%% @doc
%% @end
%% -----------------------------------------------------------------------------
-spec iterator_values(Iterator :: any()) -> Key :: babel_index:index_values().

iterator_values(_) ->
    error(not_implemented).


%% =============================================================================
%% PRIVATE
%% =============================================================================


%% @private
-dialyzer({nowarn_function, validate/1}).

validate(Config0) ->
    maps_utils:validate(Config0, ?SPEC).


%% @private
gen_identifier(Prefix, IndexKey) ->
    <<Prefix/binary, $_, IndexKey/binary>>.


%% -----------------------------------------------------------------------------
%% @private
%% @doc Collects keys `Keys' from key value data `Data' and joins them using a
%% separator.
%% We do this as Riak does not support list and sets are ordered.
%% @end
%% -----------------------------------------------------------------------------
gen_key(Keys, Data, #{case_sensitive := true}) ->
    binary_utils:join(babel_key_value:collect(Keys, Data));

gen_key(Keys, Data, #{case_sensitive := false}) ->
    L = [
        string:lowercase(X) || X <- babel_key_value:collect(Keys, Data)
    ],
    binary_utils:join(L).


%% -----------------------------------------------------------------------------
%% @private
%% @doc Collects keys `Keys' from key value data `Data' and joins them using a
%% separator.
%% We do this as Riak does not support list and sets are ordered.
%% The diff between this function and gen_key/2 is that this one catches
%% exceptions and returns a value.
%% @end
%% -----------------------------------------------------------------------------
safe_gen_key([], _, _) ->
    undefined;

safe_gen_key(Keys, Data, Config) ->
    try
        gen_key(Keys, Data, Config)
    catch
        error:{badkey, _} ->
            error
    end.


%% -----------------------------------------------------------------------------
%% @private
%% @doc We encode the term in JSON for interoperability with clients in other
%% programming languages.
%% @end
%% -----------------------------------------------------------------------------
encode_fields(List) ->
    jsone:encode(List).


%% -----------------------------------------------------------------------------
%% @private
%% @doc We encode the term in JSON for interoperability with clients in other
%% programming languages.
%% @end
%% -----------------------------------------------------------------------------
decode_fields(Data) ->
    [
        case X of
            {Key, Type} ->
                {Key, binary_to_existing_atom(Type,  utf8)};
            Key ->
                Key
        end
        || X <- jsone:decode(Data, [{object_format, proplist}])
    ].


%% @private
covered_fields_output(CoveredFields, Bin) when is_binary(Bin) ->
    maps:from_list(lists:zip(CoveredFields, binary:split(Bin, <<$\31>>))).
