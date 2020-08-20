%% --------------------------------------------------------------
%% Copyright Alejandro M. Ramallo. All rights reserved.
%% Copyright Ericsson AB 1996-2016. All Rights Reserved.
%%
%% Licensed under the Apache License, Version 2.0 (the "License");
%% you may not use this file except in compliance with the License.
%% You may obtain a copy of the License at
%%
%%     http://www.apache.org/licenses/LICENSE-2.0
%%
%% Unless required by applicable law or agreed to in writing, software
%% distributed under the License is distributed on an "AS IS" BASIS,
%% WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
%% See the License for the specific language governing permissions and
%% limitations under the License.
%% --------------------------------------------------------------

%% -----------------------------------------------------------------------------
%% @doc An implementation of digraph.erl using dict instead of ets tables.
%% The idea is to use this implementation when the data structure needs to be
%% passed between processes and | or is required to be persisted as a binary.
%%
%% Use Cases that require this data module:
%%
%% * Generation and storage of a datalog programme dependency graph
%% * Generation and storage of a datalog programme QSQ Net Structure (QSQN)
%%
%% **Notes**:
%% The API is not strictly compatible with digraph.erl as all operations return
%% a new version of the graph which is not the case in digraph.erl as it uses
%% an ets table e.g. add_vertex/1 and add_edge/3 return a new babel_digraph as
%% opposed to returning the vertex or edge as is the case with digraph.erl
%% @end
%% -----------------------------------------------------------------------------
-module(babel_digraph).


-record(babel_digraph, {
  vtree = dict:new()    :: dict:dict(),
  etree = dict:new()    :: dict:dict(),
  ntree = dict:new()    :: dict:dict(),
  cyclic = true         :: boolean(),
  vseq = 0              :: non_neg_integer(),
  eseq = 0              :: non_neg_integer(),
  vers = 0              :: non_neg_integer()
}).

-record(babel_digraph_view, {
  edges = undefined     :: dict:dict(),
  vers = 0              :: non_neg_integer()
}).

-type t()               :: #babel_digraph{}.
-type edge()            :: term().
-type label()           :: term().
-type vertex()          :: term().

-type babel_digraph_view() :: #babel_digraph_view{}.

-export_type([t/0]).
-export_type([edge/0]).
-export_type([vertex/0]).
-export_type([label/0]).


-export([add_edge/3]).
-export([add_edge/4]).
-export([add_edge/5]).
-export([add_edges/2]).
-export([add_vertex/1]).
-export([add_vertex/2]).
-export([add_vertex/3]).
-export([add_vertices/2]).
-export([add_vertices/3]).
-export([del_edge/2]).
-export([del_edges/2]).
-export([del_path/3]).
-export([del_vertex/2]).
-export([del_vertices/2]).
-export([edge/2]).
-export([edges/1]).
-export([edges/2]).
-export([filter_edge_labels/2]).
-export([filter_edges/2]).
-export([filter_vertex_labels/2]).
-export([filter_vertices/2]).
-export([fold/3]).
-export([fold_view/4]).
-export([get_cycle/2]).
-export([get_path/3]).
-export([get_short_cycle/2]).
-export([get_short_path/3]).
-export([has_edge/2]).
-export([in_degree/2]).
-export([in_edges/2]).
-export([in_neighbours/2]).
-export([info/1]).
-export([new/0]).
-export([new/1]).
-export([no_edges/1]).
-export([no_vertices/1]).
-export([out_degree/2]).
-export([out_edges/2]).
-export([out_neighbours/2]).
-export([reverse_edge/2]).
-export([reverse_edges/2]).
-export([sink_vertices/1]).
-export([source_vertices/1]).
-export([to_dot/2]).
-export([vertex/2]).
-export([vertices/1]).
-export([view/2]).

%% UTILS API
-export([arborescence_root/1]).
-export([components/1]).
-export([condensation/1]).
-export([cyclic_strong_components/1]).
-export([is_acyclic/1]).
-export([is_arborescence/1]).
-export([is_tree/1]).
-export([loop_vertices/1]).
-export([postorder/1]).
-export([preorder/1]).
-export([reachable/2]).
-export([reachable_neighbours/2]).
-export([reaching/2]).
-export([reaching_neighbours/2]).
-export([strong_components/1]).
-export([subgraph/2]).
-export([subgraph/3]).
-export([topsort/1]).


%% ============================================================================
%% API
%% ============================================================================



%% -----------------------------------------------------------------------------
%% @doc Returns a new instance of a babel_digraph of type cyclic.
%% @end
%% -----------------------------------------------------------------------------
-spec new() -> t().

new() ->
    new(cyclic).


%% -----------------------------------------------------------------------------
%% @doc Returns a new instance of a babel_digraph with type Type.
%% @end
%% -----------------------------------------------------------------------------
-spec new(Type :: atom() | {atom(), boolean()}) -> t().

new(Type) ->
    #babel_digraph{cyclic = type_to_boolean(Type)}.


%% -----------------------------------------------------------------------------
%% @doc
%% @end
%% -----------------------------------------------------------------------------
-spec info(G :: t()) -> [tuple()].

info(G) ->
    VT = G#babel_digraph.vtree,
    ET = G#babel_digraph.etree,
    NT = G#babel_digraph.ntree,
    Cyclicity = case G#babel_digraph.cyclic of
        true  -> cyclic;
        false -> acyclic
    end,
    Memory =
        erts_debug:flat_size(VT)
        + erts_debug:flat_size(ET)
        + erts_debug:flat_size(NT),
    [
        {cyclicity, Cyclicity},
        {memory, Memory},
        {no_vertices, no_vertices(G)},
        {no_edges, no_edges(G)}
    ].



%% ==========================================================================
%% VERTICES
%% ==========================================================================

%% -----------------------------------------------------------------------------
%% @doc
%% @end
%% -----------------------------------------------------------------------------
-spec vertex(G :: t(), V :: vertex()) -> {vertex(), label()} | 'false'.

vertex(G, V) ->
    case dict:find(V, G#babel_digraph.vtree) of
        error ->
            false;
        {ok, Label} ->
            {V, Label}
    end.


%% -----------------------------------------------------------------------------
%% @doc
%% @end
%% -----------------------------------------------------------------------------
-spec no_vertices(G :: t()) -> non_neg_integer().

no_vertices(G) ->
    dict:size(G#babel_digraph.vtree).


%% -----------------------------------------------------------------------------
%% @doc
%% @end
%% -----------------------------------------------------------------------------
-spec vertices(G :: t()) -> [vertex()].

vertices(G) ->
    dict:fetch_keys(G#babel_digraph.vtree).


%% -----------------------------------------------------------------------------
%% @doc
%% @end
%% -----------------------------------------------------------------------------
-spec source_vertices(G :: t()) -> [vertex()].

source_vertices(G) ->
    collect_vertices(G, in).

%% -----------------------------------------------------------------------------
%% @doc
%% @end
%% -----------------------------------------------------------------------------

-spec sink_vertices(G :: t()) -> [vertex()].

sink_vertices(G) ->
    collect_vertices(G, out).


%% -----------------------------------------------------------------------------
%% @doc
%% @end
%% -----------------------------------------------------------------------------
-spec has_vertex(G :: t(), V::vertex()) -> boolean().

has_vertex(G, V) ->
    dict:is_key(V, G#babel_digraph.vtree).


%% -----------------------------------------------------------------------------
%% @doc
%% @end
%% -----------------------------------------------------------------------------
-spec add_vertex(G :: t()) -> {vertex(), t()} | {error, string()}.

add_vertex(G) ->
    % We create a new vertex id by increasing G's vseq number
    K = G#babel_digraph.vseq + 1,
    V = ['$v' | K],
    {V, add_vertex(G#babel_digraph{vseq=K}, V, [])}.


%% -----------------------------------------------------------------------------
%% @doc
%% @end
%% -----------------------------------------------------------------------------
-spec add_vertex(G :: t(), V::vertex()) -> t().

add_vertex(G, V) ->
    add_vertex(G, V, []).


%% -----------------------------------------------------------------------------
%% @doc
%% @end
%% -----------------------------------------------------------------------------
-spec add_vertex(G :: t(), V::vertex(), Label::label()) -> t().

add_vertex(G, V, L) ->
    G#babel_digraph{vtree = dict:store(V, L, G#babel_digraph.vtree)}.


%% -----------------------------------------------------------------------------
%% @doc
%% @end
%% -----------------------------------------------------------------------------
-spec add_vertices(G :: t(), Vs::[vertex()]) -> t().

add_vertices(G, []) ->
    G;

add_vertices(G, Vs) when is_list(Vs) ->
    lists:foldl(fun(V, Acc) -> add_vertex(Acc, V) end, G, Vs).


%% -----------------------------------------------------------------------------
%% @doc
%% @end
%% -----------------------------------------------------------------------------
-spec add_vertices(G :: t(), Vs::[vertex()], Ls::[any()]) -> t().

add_vertices(G, [], _) ->
  G;

add_vertices(G, Vs, Ls)
when is_list(Vs), is_list(Ls), length(Vs) == length(Ls) ->
    lists:foldl(
        fun({V, L}, Acc) -> add_vertex(Acc, V, L) end,
        G,
        lists:zip(Vs, Ls)
    );

add_vertices(G, Vs, Ls) ->
    erlang:error({badarg, [G, Vs, Ls]}).


%% -----------------------------------------------------------------------------
%% @doc
%% @end
%% -----------------------------------------------------------------------------
-spec del_vertex(G :: t(), V::vertex()) -> t().

del_vertex(G, V) ->
    G2 = del_edges(G, lists:append(in_edges(G, V), out_edges(G, V))),
    G3 = remove_vertex_from_ntree(G2, V),
    remove_vertex_from_vtree(G3, V).


%% -----------------------------------------------------------------------------
%% @doc
%% @end
%% -----------------------------------------------------------------------------
-spec del_vertices(G :: t(), Vs::[vertex()]) -> t().

del_vertices(G, []) ->
    G;

del_vertices(G, Vs) when is_list(Vs) ->
  lists:foldl(fun(X, Acc) -> del_vertex(Acc, X) end, G, Vs).



%% ==========================================================================
%% EDGES
%% ==========================================================================



%% -----------------------------------------------------------------------------
%% @doc
%% @end
%% -----------------------------------------------------------------------------
-spec edge(G :: t(), V :: edge()) ->
  {edge(), vertex(), vertex(), label()} | 'false'.

edge(G, V) ->
    case dict:find(V, G#babel_digraph.etree) of
        error -> false;
        {ok, {V1, V2, Label}} -> {V, V1, V2, Label}
    end.


%% -----------------------------------------------------------------------------
%% @doc
%% @end
%% -----------------------------------------------------------------------------
-spec no_edges(G :: t()) -> non_neg_integer().

no_edges(G) ->
    dict:size(G#babel_digraph.etree).


%% -----------------------------------------------------------------------------
%% @doc
%% @end
%% -----------------------------------------------------------------------------
-spec edges(G :: t()) -> [edge()].

edges(G) ->
    dict:fetch_keys(G#babel_digraph.etree).


%% -----------------------------------------------------------------------------
%% @doc
%% @end
%% -----------------------------------------------------------------------------
-spec edges(G :: t(), V::vertex()) -> [edge()].

edges(G, V) ->
	lists:append(out_edges(G, V), in_edges(G, V)).


%% -----------------------------------------------------------------------------
%% @doc
%% @end
%% -----------------------------------------------------------------------------
-spec has_edge(G :: t(), E::edge()) -> boolean().

has_edge(G, E) ->
    dict:is_key(E, G#babel_digraph.etree).


%% -----------------------------------------------------------------------------
%% @doc
%% @end
%% -----------------------------------------------------------------------------
-spec out_edges(G :: t(), V::vertex()) -> [edge()].

out_edges(G, V) ->
    case dict:find({out, V}, G#babel_digraph.ntree) of
        error -> [];
        {ok, List} -> List
    end.


%% -----------------------------------------------------------------------------
%% @doc
%% @end
%% -----------------------------------------------------------------------------
-spec in_edges(G :: t(), V::vertex()) -> [edge()].

in_edges(G, V) ->
    case dict:find({in, V}, G#babel_digraph.ntree) of
        error -> [];
        {ok, List} -> List
    end.


%% -----------------------------------------------------------------------------
%% @doc
%% @end
%% -----------------------------------------------------------------------------
-spec out_degree(G :: t(), V::vertex()) -> non_neg_integer().

out_degree(G, V) ->
    case out_edges(G, V) of
        [] -> 0;
        List -> length(List)
    end.


%% -----------------------------------------------------------------------------
%% @doc
%% @end
%% -----------------------------------------------------------------------------
-spec in_degree(G :: t(), V::vertex()) -> non_neg_integer().

in_degree(G, V) ->
    case in_edges(G, V) of
        [] -> 0;
        List -> length(List)
    end.


%% -----------------------------------------------------------------------------
%% @doc
%% @end
%% -----------------------------------------------------------------------------
-spec out_neighbours(G :: t(), V::vertex()) -> [vertex()].

out_neighbours(G, V) ->
    case out_edges(G, V) of
        [] ->
            [];
        List ->
            [Out || {X, Out, _} <- collect_neighbours(G, List), X =:= V]
    end.


%% -----------------------------------------------------------------------------
%% @doc
%% @end
%% -----------------------------------------------------------------------------
-spec in_neighbours(G :: t(), V::vertex()) -> [vertex()].

in_neighbours(G, V) ->
    case in_edges(G, V) of
        [] ->
            [];
        List ->
            [In || {In, X, _} <- collect_neighbours(G, List), X =:= V]
    end.


%% -----------------------------------------------------------------------------
%% @doc
%% @end
%% -----------------------------------------------------------------------------
-spec add_edge(G :: t(), V1::vertex(), V2::vertex()) -> t().

add_edge(G, V1, V2) ->
    add_edge(G, V1, V2, []).


%% -----------------------------------------------------------------------------
%% @doc
%% @end
%% -----------------------------------------------------------------------------
-spec add_edge(G :: t(), V1::vertex(), V2::vertex(), Label::label()) -> t().

add_edge(G, V1, V2, Label) ->
    add_edge(G, [], V1, V2, Label).


%% -----------------------------------------------------------------------------
%% @doc
%% @end
%% -----------------------------------------------------------------------------
-spec add_edge(
    G :: t(), E::edge(), V1::vertex(), V2::vertex(), Label::label()) -> t().

add_edge(G, E, V1, V2, Label) ->
  G2 = do_add_edge(G, E, V1, V2, Label),
  increment_version(G2).


%% @private
do_add_edge(G, [], V1, V2, Label) ->
    K = G#babel_digraph.eseq + 1,
    E = ['$e' | K],
    do_add_edge(G#babel_digraph{eseq=K}, E, V1, V2, Label);

do_add_edge(G, E, V1, V2, Label) ->
    case has_vertex(G, V1) of
        true ->
            case has_vertex(G, V2) of
                true ->
                    Value = {V1, V2, Label},
                    G2 = add_edge_to_etree(G, E, Value),
                    add_edge_to_ntree(G2, E, Value);
                false ->
                    erlang:exit("Vertex 2 does not exist", V2)
            end;
        false ->
            erlang:exit("Vertex 1 does not exist", V1)
    end.


%% -----------------------------------------------------------------------------
%% @doc
%% @end
%% -----------------------------------------------------------------------------
-spec add_edges(
    G :: t(),
    Es :: [{vertex(), vertex(), label()}]
    | [{edge(), vertex(), vertex(), label()}]) -> t().

add_edges(G, []) ->
    G;

add_edges(G, Es) when is_list(Es) ->
    Fun = fun(Tuple, Acc0) ->
        case Tuple of
            {V1, V2, Label} ->  do_add_edge(Acc0, [], V1, V2, Label);
            {E, V1, V2, Label} -> do_add_edge(Acc0, E, V1, V2, Label)
        end
    end,
    increment_version(lists:foldl(Fun, G, Es)).



%% -----------------------------------------------------------------------------
%% @doc
%% @end
%% -----------------------------------------------------------------------------
-spec del_edge(G :: t(), E::edge()) -> t().

del_edge(G, E) ->
    increment_version(do_del_edge(G, E)).

do_del_edge(G, E) ->
    G2 = remove_edge_from_ntree(G, E),
    remove_edge_from_etree(G2, E).


%% -----------------------------------------------------------------------------
%% @doc
%% @end
%% -----------------------------------------------------------------------------
-spec del_edges(G :: t(), Es::[edge()]) -> t().

del_edges(G, []) ->
    G;
del_edges(G, Es) when is_list(Es) ->
    increment_version(
        lists:foldl(fun(X, Acc) -> do_del_edge(Acc, X) end, G, Es)
    ).


%% -----------------------------------------------------------------------------
%% @doc
%% @end
%% -----------------------------------------------------------------------------
-spec del_edges(G :: t(), V1::vertex(), V2::vertex()) -> t().

del_edges(G, V1, V2) ->
    increment_version(del_edges_aux(G, out_edges(G, V1), V1, V2)).


%% @private
del_edges_aux(G, [H|T], V1, V2) ->
    case dict:find(H, G#babel_digraph.etree) of
        {ok, {V1, V2, _Label}}  ->
            del_edges_aux(do_del_edge(G, H), T, V1, V2);
        _ ->
            del_edges_aux(T, V1, V2, G)
    end;
    del_edges_aux(G, [], _, _) -> G.


%% @private
reverse_edge(G0, E) ->
    case edge(G0, E) of
        {E, V1, V2, Label} ->
            add_edge(del_edge(G0, E), V2, V1, Label);
        false ->
            G0
    end.


%% @private
reverse_edges(G0, []) ->
    G0;
reverse_edges(G0, Edges) when is_list(Edges) ->
    lists:foldl(fun(E, Acc) -> reverse_edge(Acc, E) end, G0, Edges).



%% ==========================================================================
%% OPS
%% ==========================================================================



%% -----------------------------------------------------------------------------
%% @doc
%% @end
%% -----------------------------------------------------------------------------
-spec get_cycle(G :: t(), V::vertex()) -> [vertex()].

get_cycle(G, V) ->
    case one_path(out_neighbours(G, V), V, [], [V], [V], 2, G, 1) of
        false ->
            case lists:member(V, out_neighbours(G, V)) of
                true -> [V];
                false -> false
            end;
        Vs ->
            Vs
    end.


%% -----------------------------------------------------------------------------
%% @doc
%% @end
%% -----------------------------------------------------------------------------
-spec get_short_cycle(G :: t(), V::vertex()) -> [vertex()].

get_short_cycle(G, V) ->
	get_short_path(G, V, V).


%% -----------------------------------------------------------------------------
%% @doc
%% @end
%% -----------------------------------------------------------------------------
-spec get_path(G :: t(), V1::vertex(), V2::vertex()) -> [vertex()].

get_path(G, V1, V2) ->
	one_path(out_neighbours(G, V1), V2, [], [V1], [V1], 1, G, 1).


%% -----------------------------------------------------------------------------
%% @doc
%% @end
%% -----------------------------------------------------------------------------
-spec get_short_path(G :: t(), V1::vertex(), V2::vertex()) -> [vertex()].

get_short_path(G, V1, V2) ->
    T = new(),
    T1 = add_vertex(T, V1),
    Q = queue:new(),
    Q1 = queue_out_neighbours(V1, G, Q),
    spath(Q1, G, V2, T1).


%% -----------------------------------------------------------------------------
%% @doc
%% @end
%% -----------------------------------------------------------------------------
-spec del_path(G :: t(), V1::vertex(), V2::vertex()) -> t().

del_path(G, V1, V2) ->
    case get_path(G, V1, V2) of
        false ->
            G;
        Path ->
            G1 = remove_edges_in_path(G, Path),
            del_path(G1, V1, V2)
    end.


%% -----------------------------------------------------------------------------
%% @doc
%% @end
%% -----------------------------------------------------------------------------
-spec filter_vertices(
    G :: t(), Pred::fun((Vertex::vertex(), Label::label()) -> boolean())) ->
    [vertex()].

filter_vertices(G, Pred) ->
    dict:fetch_keys(dict:filter(Pred, G#babel_digraph.vtree)).


%% -----------------------------------------------------------------------------
%% @doc
%% @end
%% -----------------------------------------------------------------------------
-spec filter_vertex_labels(
    G :: t(), Pred::fun((Vertex::vertex(), Label::label()) -> boolean())) ->
    [vertex()].

filter_vertex_labels(G, Pred) ->
    dict:to_list(dict:filter(Pred, G#babel_digraph.vtree)).


%% -----------------------------------------------------------------------------
%% @doc
%% @end
%% -----------------------------------------------------------------------------
-spec filter_edges(
    G :: t(),
    Pred::fun((Edge::edge(), Value::{vertex(), vertex(), label()}) -> boolean())) -> [edge()].

filter_edges(G, Pred) ->
    dict:fetch_keys(dict:filter(Pred, G#babel_digraph.etree)).


%% -----------------------------------------------------------------------------
%% @doc
%% @end
%% -----------------------------------------------------------------------------
-spec filter_edge_labels(
    G :: t(),
    Pred::fun((Edge::edge(), Value::{vertex(), vertex(), label()}) -> boolean())) -> [edge()].

filter_edge_labels(G, Pred) ->
    dict:to_list(dict:filter(Pred, G#babel_digraph.etree)).



%% -----------------------------------------------------------------------------
%% @doc
%% @end
%% -----------------------------------------------------------------------------
-spec fold(
    G :: t(),
    Fun::fun((Elem :: {edge(), {vertex(), label()}, {vertex(), label()}, label()}, Acc::term()) -> boolean()),
    Acc0::term()) -> Acc1::term().

fold(G, Fun, Acc0) ->
    VT = G#babel_digraph.vtree,
    Adapter = fun(K, {V1, V2, Label}, Acc) ->
        VL1 = dict:fetch(V1, VT),
        VL2 = dict:fetch(V2, VT),
        Fun({K, {V1, VL1}, {V2, VL2}, Label}, Acc)
    end,
    dict:fold(Adapter, Acc0, G#babel_digraph.etree).


%% -----------------------------------------------------------------------------
%% @doc
%% @end
%% -----------------------------------------------------------------------------
-spec view(
    G :: t(),
    EdgesOrPred::[edge()] | fun((Edge::edge(),
    Value::{vertex(), vertex(), label()})-> boolean())) -> babel_digraph_view().

view(G, EdgesOrPred) when is_list(EdgesOrPred) ->
    #babel_digraph_view{
        edges = dict:filter(fun(K, _V)-> lists:member(K, EdgesOrPred) end, G#babel_digraph.etree),
        vers = G#babel_digraph.vers
    };

view(G, EdgesOrPred) when is_function(EdgesOrPred, 2) ->
    #babel_digraph_view{
        edges = dict:filter(EdgesOrPred, G#babel_digraph.etree),
        vers = G#babel_digraph.vers
    }.


%% -----------------------------------------------------------------------------
%% @doc
%% @end
%% -----------------------------------------------------------------------------
fold_view(G, View, Fun, Acc0) ->
    G#babel_digraph.vers =:= View#babel_digraph_view.vers
    orelse erlang:exit("View out-of-date."),

    VT = G#babel_digraph.vtree,
    Adapter = fun(K, {V1, V2, Label}, Acc) ->
        VL1 = dict:fetch(V1, VT),
        VL2 = dict:fetch(V2, VT),
        Fun({K, {V1, VL1}, {V2, VL2}, Label}, Acc)
    end,
    dict:fold(Adapter, Acc0, View#babel_digraph_view.edges).


%% ==========================================================================
%% PRIVATE
%% ==========================================================================

%% @private
add_edge_to_etree(G, E, Value={_V1, _V2, _Label}) ->
    ET = dict:store(E, Value, G#babel_digraph.etree),
    G#babel_digraph{etree = ET}.


%% @private
add_edge_to_ntree(G, E, {V1, V2, _Label}) ->
    NT = G#babel_digraph.ntree,
    Adder = fun(X, Acc) ->
        dict:update(X, fun(Edges) -> [E|Edges] end, [E], Acc)
    end,
    G#babel_digraph{ntree=Adder({in, V2}, Adder({out, V1}, NT))}.


%% @private
remove_vertex_from_vtree(G, V) ->
  NewVT = dict:erase(V, G#babel_digraph.vtree),
  G#babel_digraph{vtree=NewVT}.


%% @private
remove_vertex_from_ntree(G, V) ->
    NT = dict:erase({in, V}, G#babel_digraph.ntree),
    NewNT = dict:erase({out, V}, NT),
    G#babel_digraph{ntree=NewNT}.


%% @private
remove_edge_from_etree(G, E) ->
    NewET = dict:erase(E, G#babel_digraph.etree),
    G#babel_digraph{etree=NewET}.


%% @private
remove_edge_from_ntree(G, E) ->
    NT = G#babel_digraph.ntree,
    {E, V1, V2, _Label} = edge(G, E),
    Deleter = fun(X, Acc) ->
        case dict:find(X, Acc) of
            error ->
                Acc;
            {ok, [E]} ->
                dict:erase(X, Acc);
            {ok, List} ->
                case lists:subtract(List, [E]) of
                    [] ->
                    dict:erase(X, Acc);
                    NewList ->
                    dict:store(X, NewList, Acc)
                end;
            _Other ->
                Acc
        end
    end,
    NewNT = lists:foldl(Deleter, NT, [{out, V1}, {in, V2}]),
    G#babel_digraph{ntree=NewNT}.


%% @private
remove_edges_in_path(G, [V1, V2|Vs]) ->
    G1 = del_edges(G, V1, V2),
	remove_edges_in_path(G1, [V2|Vs]);

remove_edges_in_path(G, _) ->
    G.


%% @private
collect_vertices(G, Direction) ->
        Fun = fun(V, Acc) ->
            case dict:is_key({Direction, V}, G#babel_digraph.ntree) of
                    true -> Acc;
                    false -> [V|Acc]
            end
        end,
        lists:foldl(Fun, [], vertices(G)).


%% @private
collect_neighbours(G, Edges) ->
    collect_neighbours(G, Edges, []).


%% @private
collect_neighbours(G, [H|T], Acc) ->
    ET = G#babel_digraph.etree,
    case dict:find(H, ET) of
        error -> collect_neighbours(G, T, Acc);
        {ok, Val} -> collect_neighbours(G, T, [Val|Acc])
    end;

collect_neighbours(_G, [], Acc) ->
    Acc.


%%
%% prune_short_path (evaluate conditions on path)
%% short : if path is too short
%% ok    : if path is ok
%%
%% @private
prune_short_path(Counter, Min) when Counter < Min ->
	short;

prune_short_path(_Counter, _Min) ->
	ok.


%% @private
one_path([W|Ws], W, Cont, Xs, Ps, Prune, G, Counter) ->
    case prune_short_path(Counter, Prune) of
        short -> one_path(Ws, W, Cont, Xs, Ps, Prune, G, Counter);
        ok -> lists:reverse([W|Ps])
    end;

one_path([V|Vs], W, Cont, Xs, Ps, Prune, G, Counter) ->
    case lists:member(V, Xs) of
        true ->
            one_path(Vs, W, Cont, Xs, Ps, Prune, G, Counter);
        false ->
            one_path(out_neighbours(G, V), W,
            [{Vs,Ps} | Cont], [V|Xs], [V|Ps],
            Prune, G, Counter+1)
    end;

one_path([], W, [{Vs,Ps}|Cont], Xs, _, Prune, G, Counter) ->
	one_path(Vs, W, Cont, Xs, Ps, Prune, G, Counter-1);

one_path([], _, [], _, _, _, _, _Counter) ->
    false.


%% @private
spath(Q, G, Sink, T) ->
    case queue:out(Q) of
        {{value, E}, Q1} ->
            {_E, V1, V2, _Label} = edge(G, E),
            if
                Sink =:= V2 ->
                    follow_path(V1, T, [V2]);
                true ->
                    case vertex(T, V2) of
                    false ->
                        G2 = add_edge(add_vertex(T, V2), V2, V1),
                        NQ = queue_out_neighbours(V2, G2, Q1),
                        spath(NQ, G2, Sink, T);
                    _V ->
                        spath(Q1, G, Sink, T)
                    end
            end;
        {empty, _Q1} ->
            false
    end.


%% @private
follow_path(V, T, P) ->
    P1 = [V | P],
    case out_neighbours(T, V) of
        [N] ->
            follow_path(N, T, P1);
        [] ->
            P1
    end.


%% @private
queue_out_neighbours(V, G, Q0) ->
	lists:foldl(fun(E, Q) -> queue:in(E, Q) end, Q0, out_edges(G, V)).


%% @private
increment_version(G) ->
    G#babel_digraph{vers=G#babel_digraph.vers + 1}.


%% ==========================================================================
%% UTILS
%% ==========================================================================

%% From OTP module digraph_utils
%% %CopyrightBegin%
%%
%% Copyright Ericsson AB 1999-2012. All Rights Reserved.
%%
%% The contents of this file are subject to the Erlang Public License,
%% Version 1.1, (the "License"); you may not use this file except in
%% compliance with the License. You should have received a copy of the
%% Erlang Public License along with this software. If not, it can be
%% retrieved online at http://www.erlang.org/.
%%
%% Software distributed under the License is distributed on an "AS IS"
%% basis, WITHOUT WARRANTY OF ANY KIND, either express or implied. See
%% the License for the specific language governing rights and limitations
%% under the License.
%%
%% %CopyrightEnd%
%%


%%% Operations on directed (and undirected) graphs.
%%%
%%% Implementation based on Launchbury, John: Graph Algorithms with a
%%% Functional Flavour, in Jeuring, Johan, and Meijer, Erik (Eds.):
%%% Advanced Functional Programming, Lecture Notes in Computer
%%% Science 925, Springer Verlag, 1995.

-spec components(Digraph :: t()) -> Component :: [[vertex()]].

components(G) ->
	forest(G, fun inout/3).


-spec strong_components(Digraph) -> [StrongComponent] when
    Digraph :: t(),
    StrongComponent :: [vertex()].

strong_components(G) ->
	forest(G, fun in/3, revpostorder(G)).


-spec cyclic_strong_components(Digraph) -> [StrongComponent] when
    Digraph :: t(),
    StrongComponent :: [vertex()].

cyclic_strong_components(G) ->
	remove_singletons(strong_components(G), G, []).


-spec reachable(Vertices, Digraph) -> Reachable when
    Digraph :: t(),
    Vertices :: [vertex()],
    Reachable :: [vertex()].

reachable(Vs, G) when is_list(Vs) ->
	lists:append(forest(G, fun out/3, Vs, first)).


-spec reachable_neighbours(Vertices, Digraph) -> Reachable when
    Digraph :: t(),
    Vertices :: [vertex()],
    Reachable :: [vertex()].

reachable_neighbours(Vs, G) when is_list(Vs) ->
	lists:append(forest(G, fun out/3, Vs, not_first)).


-spec reaching(Vertices, Digraph) -> Reaching when
    Digraph :: t(),
    Vertices :: [vertex()],
    Reaching :: [vertex()].

reaching(Vs, G) when is_list(Vs) ->
    lists:append(forest(G, fun in/3, Vs, first)).


-spec reaching_neighbours(Vertices, Digraph) -> Reaching when
    Digraph :: t(),
    Vertices :: [vertex()],
    Reaching :: [vertex()].

reaching_neighbours(Vs, G) when is_list(Vs) ->
    lists:append(forest(G, fun in/3, Vs, not_first)).


-spec topsort(Digraph) -> Vertices | 'false' when
    Digraph :: t(),
    Vertices :: [vertex()].

topsort(G) ->
    L = revpostorder(G),
    case length(forest(G, fun in/3, L)) =:= length(vertices(G)) of
        true  -> L;
        false -> false
    end.


-spec is_acyclic(Digraph) -> boolean() when
	Digraph :: t().


is_acyclic(G) ->
    loop_vertices(G) =:= [] andalso topsort(G) =/= false.


-spec arborescence_root(Digraph) -> 'no' | {'yes', Root} when
    Digraph :: t(),
    Root :: vertex().

arborescence_root(G) ->
    case no_edges(G) =:= no_vertices(G) - 1 of
        true ->
            try
                F = fun(V, Z) ->
                    case in_degree(G, V) of
                        1 -> Z;
                        0 when Z =:= [] -> [V]
                    end
                end,
                [Root] = lists:foldl(F, [], vertices(G)),
                {yes, Root}
            catch _:_ ->
                no
            end;
        false ->
            no
    end.


-spec is_arborescence(Digraph) -> boolean() when
    Digraph :: t().

is_arborescence(G) ->
    arborescence_root(G) =/= no.


-spec is_tree(Digraph) -> boolean() when
    Digraph :: t().

is_tree(G) ->
    (no_edges(G) =:= no_vertices(G) - 1)
    andalso (length(components(G)) =:= 1).


-spec loop_vertices(Digraph) -> Vertices when
    Digraph :: t(),
    Vertices :: [vertex()].

loop_vertices(G) ->
    [V || V <- vertices(G), is_reflexive_vertex(V, G)].


-spec subgraph(Digraph, Vertices) -> SubGraph when
    Digraph :: t(),
    Vertices :: [vertex()],
    SubGraph :: t().

subgraph(G, Vs) ->
	try
		subgraph_opts(G, Vs, [])
	catch
		throw:badarg ->
			erlang:error(badarg)
	end.


-spec subgraph(Digraph, Vertices, Options) -> SubGraph when
    Digraph :: t(),
    SubGraph :: t(),
    Vertices :: [vertex()],
    Options :: [{'type', SubgraphType} | {'keep_labels', boolean()}],
    SubgraphType :: 'inherit' | [term()].

subgraph(G, Vs, Opts) ->
	try
		subgraph_opts(G, Vs, Opts)
	catch
		throw:badarg ->
			erlang:error(badarg)
	end.


-spec condensation(Digraph) -> CondensedDigraph when
    Digraph :: t(),
    CondensedDigraph :: t().

condensation(G) ->
    SCs = strong_components(G),
    %% Each component is assigned a number.
    %% V2I: from vertex to number.
    %% I2C: from number to component.
    V2I = dict:new(),
    I2C = dict:new(),

    CFun = fun(SC, {V2I0, I2C0, N}) ->
        V2I1 = lists:foldl(fun(V, Acc) -> dict:store(V, N, Acc) end, V2I0, SC),
        I2C1 = dict:store(N, SC, I2C0),
        {V2I1, I2C1, N + 1}
    end,

    {NewV2I, NewI2C, _} = lists:foldl(CFun, {V2I, I2C, 1}, SCs),
    SCG = subgraph_opts(G, [], []),

    lists:foldl(
        fun(SC, SCG0) ->
            condense(SC, G, SCG0, NewV2I, NewI2C)
        end,
        SCG,
        SCs
    ).


-spec preorder(Digraph) -> Vertices when
    Digraph :: t(),
    Vertices :: [vertex()].

preorder(G) ->
    lists:reverse(revpreorder(G)).


-spec postorder(Digraph) -> Vertices when
    Digraph :: t(),
    Vertices :: [vertex()].

postorder(G) ->
    lists:reverse(revpostorder(G)).

%%
%%  Local functions
%%

forest(G, SF) ->
    forest(G, SF, vertices(G)).

forest(G, SF, Vs) ->
    forest(G, SF, Vs, first).

forest(G, SF, Vs, HandleFirst) ->
	F = fun(V, {LL, T}) ->
		pretraverse(HandleFirst, V, SF, G, T, LL)
	end,
	{LL, _} = lists:foldl(F, {[], sets:new()}, Vs),
    LL.


pretraverse(first, V, SF, G, T, LL) ->
    ptraverse([V], SF, G, T, [], LL);
pretraverse(not_first, V, SF, G, T, LL) ->
	case sets:is_element(V, T) of
		false ->
			ptraverse(SF(G, V, []), SF, G, T, [], LL);
		true ->
			{LL, T}
	end.

ptraverse([V | Vs], SF, G, T, Rs, LL) ->
	case sets:is_element(V, T) of
		false ->
			T1 = sets:add_element(V, T),
			ptraverse(SF(G, V, Vs), SF, G, T1, [V | Rs], LL);
		true ->
			ptraverse(Vs, SF, G, T, Rs, LL)
	end;
ptraverse([], _SF, _G, T, [], LL) ->
	{LL, T};
ptraverse([], _SF, _G, T, Rs, LL) ->
	{[Rs | LL], T}.

revpreorder(G) ->
    lists:append(forest(G, fun out/3)).

revpostorder(G) ->
    T = sets:new(),
	{L, _} = posttraverse(vertices(G), G, {[], T}),
    L.

posttraverse([V | Vs], G, {L, T0}) ->
	Acc = case sets:is_element(V, T0) of
		false ->
			T1 = sets:add_element(V, T0),
            {L1, T2} = posttraverse(out(G, V, []), G, {L, T1}),
			{[V | L1], T2};
		true ->
			{L, T0}
	end,
	posttraverse(Vs, G, Acc);

posttraverse([], _G, Acc) ->
	Acc.

in(G, V, Vs) ->
	in_neighbours(G, V) ++ Vs.

out(G, V, Vs) ->
	out_neighbours(G, V) ++ Vs.

inout(G, V, Vs) ->
	in(G, V, out(G, V, Vs)).

remove_singletons([C=[V] | Cs], G, L) ->
	case is_reflexive_vertex(V, G) of
		true  -> remove_singletons(Cs, G, [C | L]);
		false -> remove_singletons(Cs, G, L)
	end;
remove_singletons([C | Cs], G, L) ->
	remove_singletons(Cs, G, [C | L]);
remove_singletons([], _G, L) ->
	L.

is_reflexive_vertex(V, G) ->
	lists:member(V, out_neighbours(G, V)).

subgraph_opts(G, Vs, Opts) ->
	subgraph_opts(Opts, inherit, true, G, Vs).

subgraph_opts([{type, Type} | Opts], _Type0, Keep, G, Vs)
when Type =:= inherit; is_list(Type) ->
	subgraph_opts(Opts, Type, Keep, G, Vs);
subgraph_opts([{keep_labels, Keep} | Opts], Type, _Keep0, G, Vs)
when is_boolean(Keep) ->
	subgraph_opts(Opts, Type, Keep, G, Vs);
subgraph_opts([], inherit, Keep, G, Vs) ->
    Info = info(G),
    {_, {_, Cyclicity}} = lists:keysearch(cyclicity, 1, Info),
    {_, {_, Protection}} = lists:keysearch(protection, 1, Info),
    subgraph(G, Vs, [Cyclicity, Protection], Keep);
subgraph_opts([], Type, Keep, G, Vs) ->
    subgraph(G, Vs, Type, Keep);
subgraph_opts(_, _Type, _Keep, _G, _Vs) ->
    throw(badarg).

subgraph(G, Vs, Type, Keep) ->
	try new(Type) of
		SG ->
			lists:foreach(
				fun(V) ->
					subgraph_vertex(V, G, SG, Keep) end, Vs),
					EFun = fun(V) ->
						lists:foreach(fun(E) ->
						subgraph_edge(E, G, SG, Keep)
					end,
					out_edges(G, V))
				end,
				lists:foreach(EFun, vertices(SG)
			),
			SG
	catch
		error:badarg ->
			throw(badarg)
	end.

subgraph_vertex(V, G, SG, Keep) ->
	case vertex(G, V) of
		false -> ok;
		_ when not Keep -> add_vertex(SG, V);
		{_V, Label} when Keep -> add_vertex(SG, V, Label)
	end.

subgraph_edge(E, G, SG, Keep) ->
	{_E, V1, V2, Label} = edge(G, E),
	case vertex(SG, V2) of
		false -> ok;
		_ when not Keep -> add_edge(SG, E, V1, V2, []);
		_ when Keep -> add_edge(SG, E, V1, V2, Label)
	end.

-spec condense(list(), t(), t(), dict:dict(), dict:dict()) ->
	t().

condense(SC, G, SCG0, V2I, I2C) ->
	NFun = fun(Neighbour, Acc) ->
		[{_V,I}] = dict:fetch(Neighbour, V2I),
		dict:store(I, Acc)
	end,
	VFun = fun(V, VAcc) ->
		lists:foldl(NFun, VAcc, out_neighbours(G, V))
	end,
	T = lists:foldl(VFun, dict:new(), SC),
	SCG1 = add_vertex(SCG0, SC),
	FoldFun = fun(I, SCGA0) ->
		[{_,C}] = dict:fetch(I, I2C),
	 	SCGA1 = add_vertex(SCGA0, C),
	 	case C =/= SC of
	 		true ->
	 			add_edge(SCGA1, SC, C);
	 		false ->
	 			SCGA1
	 	end
    end,
    dict:fold(FoldFun, SCG1, T).





to_dot(G = #babel_digraph{}, File) ->
  Edges = [babel_digraph:edge(G, E) || E <- babel_digraph:edges(G)],
  {ok, S} = file:open(File, write),
  io:format(S, "~s~n", ["digraph G {"]),
  io:format(S, "~s~n", ["node [shape=oval]"]),
  lists:foreach(
    fun({ID, U, V, _}) ->
      Label = case ID of
        [A|Int] when is_atom(A) ->
          Int;
        Val ->
          Val
        end,
      io:format(S, "  ~s -> ~s [label=~p];~n", [U, V, Label])
    end,
    Edges),
  io:format(S, "~s~n", ["}"]),
  file:close(S),
  ok.



%% @private
type_to_boolean(cyclic) -> true;
type_to_boolean(acyclic) -> false;
type_to_boolean({cyclic, Val}) when is_boolean(Val) -> Val;
type_to_boolean({acyclic, Val}) when is_boolean(Val) -> not Val.