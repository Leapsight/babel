%% -----------------------------------------------------------------------------
%% @doc A riak_index_collection is a CRDT map (Riak KV Datatype), that maps
%% binary keys to {@link riak_index} objects.
%% Keys typically represent a resource (or entity) name in your domain model
%% e.g. accounts, users.
%%
%% A riak_index_collection object is store in Riak KV under a bucket_type named
%% "index_collection" and a bucket name which results from concatenating a
%% prefix provided as argument in this module functions a key separator and the
%% suffix "index_collection".
%%
%% ## Configuring the "index_collection" bucket type
%%
%% The "index_collection" bucket type needs to be configured and activated
%% in Riak KV before using this module. The `datatype' property of the bucket
%% type should be configured to `map'.
%%
%% The following example shows how to configure and activate the
%% index_collection bucket type with the recommeded default replication
%% properties:
%%
%% ```shell
%% riak-admin bucket-type create index_data '{"props":{"datatype":"map",
%% "n_val":3, "pw":"quorum", "pr":"quorum", "notfound_ok":false,
%% "basic_quorum":true}}'
%% riak-admin bucket-type activate index_data
%% ```
%%
%% ## Default replication properties
%%
%% All functions in this module resulting in reading or writing to Riak KV
%% allow an optional map with Riak KV's replication properties, but it we
%% recommend the use of the functions which provide the default replication
%% properties.
%%
%% @end
%% -----------------------------------------------------------------------------
-module(riak_index_collection).
-include("riak_index.hrl").
-include_lib("riakc/include/riakc.hrl").

-define(BUCKET_TYPE, <<"index_collection">>).
-define(BUCKET(Prefix), <<Prefix/binary, ?KEY_SEPARATOR, "index_collection">>).

-type t()           ::  riakc_map:crdt_map().

-export_type([t/0]).
-export_type([req_opts/0]).


%% API
-export([bucket/1]).
-export([bucket_type/1]).
-export([create/4]).
-export([create/5]).
-export([delete/3]).
-export([delete/4]).
-export([fetch/3]).
-export([fetch/4]).
-export([from_list/1]).
-export([from_map/1]).
-export([index/2]).
-export([lookup/3]).
-export([lookup/4]).
-export([size/1]).
-export([to_map/1]).




%% =============================================================================
%% API
%% =============================================================================




%% -----------------------------------------------------------------------------
%% @doc Takes a list of pairs mapping a list of binary keys to values of type
%% `riak_index:t()' and returns an index collection.
%% @end
%% -----------------------------------------------------------------------------
-spec from_list(Indices :: [{binary(), riak_index:t()}]) -> t().

from_list(Indices) when is_list(Indices) ->
    from_map(maps:from_list(Indices)).


%% -----------------------------------------------------------------------------
%% @doc Takes a map of binary keys to values of type `riak_index:t()' and
%% returns an index collection.
%% @end
%% -----------------------------------------------------------------------------
-spec from_map(Indices :: #{binary => riak_index:t()}) -> t().

from_map(Indices) when is_map(Indices) ->
    ToCRDT = fun
        ToCRDT(K, V, Acc) when is_atom(K) ->
            ToCRDT(atom_to_binary(K, utf8), V, Acc);
        ToCRDT(K, V, Acc) when is_binary(K) ->
            [{{K, map}, V}|Acc]
    end,
    Values = maps:fold(ToCRDT, [], Indices),
    Ctxt = undefined,

    riakc_map:new(Values, Ctxt).



%% -----------------------------------------------------------------------------
%% @doc Creates and stores an index collection in Riak KV under the bucket_type
%% `map' and bucket resulting from joining the BucketPrefix with the
%% binary <<"index_collection">> using the separator <<"/">>.
%% @end
%% -----------------------------------------------------------------------------
-spec create(
    Conn :: pid(),
    BucketPrefix :: binary(),
    Key :: binary(),
    Term :: t() | [{binary(), riak_index:t()}] | #{binary() => riak_index:t()}
    ) ->
    {ok, Index :: t()} | {error, Reason :: any()}.


create(Conn, BucketPrefix, Key, Indices) ->
    ReqOpts = #{
        w => quorum,
        pw => quorum
    },
    create(Conn, BucketPrefix, Key, Indices, ReqOpts).


%% -----------------------------------------------------------------------------
%% @doc Creates and stores an index collection in Riak KV under the bucket_type
%% `map' and bucket resulting from joining the BucketPrefix with the
%% binary <<"index_collection">> using the separator <<"/">>.
%% @end
%% -----------------------------------------------------------------------------
-spec create(
    Conn :: pid(),
    BucketPrefix :: binary(),
    Key :: binary(),
    Term :: t() | [{binary(), riak_index:t()}] | #{binary() => riak_index:t()},
    Opts :: req_opts()) ->
    {ok, Index :: t()} | {error, Reason :: any()}.

create(Conn, BucketPrefix, Key, Term, ReqOpts) when is_list(Term) ->
    create(Conn, BucketPrefix, Key, from_list(Term), ReqOpts);

create(Conn, BucketPrefix, Key, Term, ReqOpts) when is_map(Term) ->
    create(Conn, BucketPrefix, Key, from_map(Term), ReqOpts);

create(Conn, BucketPrefix, Key, IndexCollection, ReqOpts)
when is_pid(Conn) andalso is_binary(BucketPrefix) andalso is_binary(Key) ->
    Opts = validate_req_opts(ReqOpts),
    TypeBucket = {?BUCKET_TYPE, ?BUCKET(BucketPrefix)},
    Op = riakc_map:to_op(IndexCollection),

    case riakc_pb_socket:update_type(Conn, TypeBucket, Key, Op, Opts) of
        {error, _} = Error ->
            Error;
        _ ->
            ok
    end.


%% -----------------------------------------------------------------------------
%% @doc
%% @end
%% -----------------------------------------------------------------------------
-spec fetch(
    Conn :: pid(),
    BucketPrefix :: binary(),
    Key :: binary()) ->
    {ok, t()} | no_return().

fetch(Conn, BucketPrefix, Key) ->
    ReqOpts = #{
        r => quorum,
        pr => quorum
    },
    fetch(Conn, BucketPrefix, Key, ReqOpts).


%% -----------------------------------------------------------------------------
%% @doc
%% @end
%% -----------------------------------------------------------------------------
-spec fetch(
    Conn :: pid(),
    BucketPrefix :: binary(),
    Key :: binary(),
    Opts :: req_opts()) ->
    {ok, t()} | no_return().

fetch(Conn, BucketPrefix, Key, ReqOpts) ->
    case lookup(Conn, BucketPrefix, Key, ReqOpts) of
        {ok, Value} -> Value;
        {error, Reason} -> error(Reason)
    end.


%% -----------------------------------------------------------------------------
%% @doc
%% @end
%% -----------------------------------------------------------------------------
-spec lookup(
    Conn :: pid(),
    BucketPrefix :: binary(),
    Key :: binary()) ->
    {ok, t()} | {error, not_found | term()}.

lookup(Conn, BucketPrefix, Key) ->
    ReqOpts = #{
        r => quorum,
        pr => quorum
    },
    lookup(Conn, BucketPrefix, Key, ReqOpts).


%% -----------------------------------------------------------------------------
%% @doc
%% @end
%% -----------------------------------------------------------------------------
-spec lookup(
    Conn :: pid(),
    BucketPrefix :: binary(),
    Key :: binary(),
    Opts :: req_opts()) ->
    {ok, t()} | {error, not_found | term()}.

lookup(Conn, BucketPrefix, Key, ReqOpts)
when is_pid(Conn) andalso is_binary(BucketPrefix) andalso is_binary(Key) ->
    Opts = validate_req_opts(ReqOpts),
    TypeBucket = {?BUCKET_TYPE, ?BUCKET(BucketPrefix)},

    case riakc_pb_socket:fetch_type(Conn, TypeBucket, Key, Opts) of
        {ok, _} = OK -> OK;
        {error, {notfound, _}} -> {error, not_found};
        {error, _} = Error -> Error
    end.


%% -----------------------------------------------------------------------------
%% @doc
%% @end
%% -----------------------------------------------------------------------------
-spec delete(
    Conn :: pid(),
    BucketPrefix :: binary(),
    Key :: binary()) ->
    ok | {error, not_found | term()}.

delete(Conn, BucketPrefix, Key) ->
    ReqOpts = #{
        r => quorum,
        w => quorum,
        pr => quorum,
        pw => quorum
    },
    delete(Conn, BucketPrefix, Key, ReqOpts).


%% -----------------------------------------------------------------------------
%% @doc
%% @end
%% -----------------------------------------------------------------------------
-spec delete(
    Conn :: pid(),
    BucketPrefix :: binary(),
    Key :: binary(),
    Opts :: req_opts()) ->
    ok | {error, not_found | term()}.

delete(Conn, BucketPrefix, Key, ReqOpts)
when is_pid(Conn) andalso is_binary(BucketPrefix) andalso is_binary(Key) ->
    Opts = validate_req_opts(ReqOpts),
    TypeBucket = {?BUCKET_TYPE, ?BUCKET(BucketPrefix)},

    case riakc_pb_socket:delete(Conn, TypeBucket, Key, Opts) of
        ok -> ok;
        {error, {notfound, _}} -> {error, not_found};
        {error, _} = Error -> Error
    end.


%% -----------------------------------------------------------------------------
%% @doc
%% @end
%% -----------------------------------------------------------------------------
-spec bucket(IndexCollection :: t()) -> binary().

bucket(IndexCollection) ->
    riakc_map:fetch({<<"bucket">>, register}, IndexCollection).


%% -----------------------------------------------------------------------------
%% @doc
%% @end
%% -----------------------------------------------------------------------------
-spec bucket_type(IndexCollection :: t()) -> binary().

bucket_type(IndexCollection) ->
    riakc_map:fetch({<<"bucket_type">>, register}, IndexCollection).


%% -----------------------------------------------------------------------------
%% @doc
%% @end
%% -----------------------------------------------------------------------------
-spec index(IndexCollection :: t(), Key :: binary()) -> riak_index:t().

index(IndexCollection, Key) when is_binary(Key) ->
    riakc_map:fetch({Key, map}, IndexCollection).


%% -----------------------------------------------------------------------------
%% @doc
%% @end
%% -----------------------------------------------------------------------------
-spec size(IndexCollection :: t()) -> non_neg_integer().

size(IndexCollection) ->
    riakc_map:size(IndexCollection).



%% -----------------------------------------------------------------------------
%% @doc Returns an erlang map representation of the index collection.
%% The values are also represented as erlang maps by calling {@link
%% riak_index:to_map/1}.
%% @end
%% -----------------------------------------------------------------------------
-spec to_map(t()) -> map().

to_map(IndexCollection) ->
    riakc_map:fold(
        fun({K, map}, V, Acc) ->
            maps:put(K, riak_index:to_map(V), Acc)
        end,
        #{},
        IndexCollection
    ).


%% =============================================================================
%% PRIVATE
%% =============================================================================



%% -----------------------------------------------------------------------------
%% @private
%% @doc Validates and returns the options in proplist format as expected by
%% Riak KV.
%% @end
%% -----------------------------------------------------------------------------
validate_req_opts(Opts) ->
    maps:to_list(maps:validate(Opts, ?REQ_OPTS_SPEC)).