

# Module babel_digraph #
* [Description](#description)
* [Data Types](#types)
* [Function Index](#index)
* [Function Details](#functions)

An implementation of digraph.erl using dict instead of ets tables.

<a name="description"></a>

## Description ##
The idea is to use this implementation when the data structure needs to be
passed between processes and | or is required to be persisted as a binary.
Use Cases that require this data module:
* Generation and storage of a datalog programme dependency graph
* Generation and storage of a datalog programme QSQ Net Structure (QSQN)
Notes:
The API is not strictly compatible with digraph.erl as all operations return
a new version of the graph which is not the case in digraph.erl as it uses
an ets table e.g. add_vertex/1 and add_edge/3 return a new babel_digraph as
opposed to returning the vertex or edge as is the case with digraph.erl
<a name="types"></a>

## Data Types ##




### <a name="type-babel_digraph_view">babel_digraph_view()</a> ###


<pre><code>
babel_digraph_view() = #babel_digraph_view{edges = <a href="dict.md#type-dict">dict:dict()</a>, vers = non_neg_integer()}
</code></pre>




### <a name="type-edge">edge()</a> ###


<pre><code>
edge() = term()
</code></pre>




### <a name="type-label">label()</a> ###


<pre><code>
label() = term()
</code></pre>




### <a name="type-t">t()</a> ###


<pre><code>
t() = #babel_digraph{vtree = <a href="dict.md#type-dict">dict:dict()</a>, etree = <a href="dict.md#type-dict">dict:dict()</a>, ntree = <a href="dict.md#type-dict">dict:dict()</a>, cyclic = boolean(), vseq = non_neg_integer(), eseq = non_neg_integer(), vers = non_neg_integer()}
</code></pre>




### <a name="type-vertex">vertex()</a> ###


<pre><code>
vertex() = term()
</code></pre>

<a name="index"></a>

## Function Index ##


<table width="100%" border="1" cellspacing="0" cellpadding="2" summary="function index"><tr><td valign="top"><a href="#add_edge-3">add_edge/3</a></td><td></td></tr><tr><td valign="top"><a href="#add_edge-4">add_edge/4</a></td><td></td></tr><tr><td valign="top"><a href="#add_edge-5">add_edge/5</a></td><td></td></tr><tr><td valign="top"><a href="#add_edges-2">add_edges/2</a></td><td></td></tr><tr><td valign="top"><a href="#add_vertex-1">add_vertex/1</a></td><td></td></tr><tr><td valign="top"><a href="#add_vertex-2">add_vertex/2</a></td><td></td></tr><tr><td valign="top"><a href="#add_vertex-3">add_vertex/3</a></td><td></td></tr><tr><td valign="top"><a href="#add_vertices-2">add_vertices/2</a></td><td></td></tr><tr><td valign="top"><a href="#add_vertices-3">add_vertices/3</a></td><td></td></tr><tr><td valign="top"><a href="#arborescence_root-1">arborescence_root/1</a></td><td></td></tr><tr><td valign="top"><a href="#components-1">components/1</a></td><td></td></tr><tr><td valign="top"><a href="#condensation-1">condensation/1</a></td><td></td></tr><tr><td valign="top"><a href="#cyclic_strong_components-1">cyclic_strong_components/1</a></td><td></td></tr><tr><td valign="top"><a href="#del_edge-2">del_edge/2</a></td><td></td></tr><tr><td valign="top"><a href="#del_edges-2">del_edges/2</a></td><td></td></tr><tr><td valign="top"><a href="#del_path-3">del_path/3</a></td><td></td></tr><tr><td valign="top"><a href="#del_vertex-2">del_vertex/2</a></td><td></td></tr><tr><td valign="top"><a href="#del_vertices-2">del_vertices/2</a></td><td></td></tr><tr><td valign="top"><a href="#edge-2">edge/2</a></td><td></td></tr><tr><td valign="top"><a href="#edges-1">edges/1</a></td><td></td></tr><tr><td valign="top"><a href="#edges-2">edges/2</a></td><td></td></tr><tr><td valign="top"><a href="#filter_edge_labels-2">filter_edge_labels/2</a></td><td></td></tr><tr><td valign="top"><a href="#filter_edges-2">filter_edges/2</a></td><td></td></tr><tr><td valign="top"><a href="#filter_vertex_labels-2">filter_vertex_labels/2</a></td><td></td></tr><tr><td valign="top"><a href="#filter_vertices-2">filter_vertices/2</a></td><td></td></tr><tr><td valign="top"><a href="#fold-3">fold/3</a></td><td></td></tr><tr><td valign="top"><a href="#fold_view-4">fold_view/4</a></td><td></td></tr><tr><td valign="top"><a href="#get_cycle-2">get_cycle/2</a></td><td></td></tr><tr><td valign="top"><a href="#get_path-3">get_path/3</a></td><td></td></tr><tr><td valign="top"><a href="#get_short_cycle-2">get_short_cycle/2</a></td><td></td></tr><tr><td valign="top"><a href="#get_short_path-3">get_short_path/3</a></td><td></td></tr><tr><td valign="top"><a href="#has_edge-2">has_edge/2</a></td><td></td></tr><tr><td valign="top"><a href="#in_degree-2">in_degree/2</a></td><td></td></tr><tr><td valign="top"><a href="#in_edges-2">in_edges/2</a></td><td></td></tr><tr><td valign="top"><a href="#in_neighbours-2">in_neighbours/2</a></td><td></td></tr><tr><td valign="top"><a href="#info-1">info/1</a></td><td></td></tr><tr><td valign="top"><a href="#is_acyclic-1">is_acyclic/1</a></td><td></td></tr><tr><td valign="top"><a href="#is_arborescence-1">is_arborescence/1</a></td><td></td></tr><tr><td valign="top"><a href="#is_tree-1">is_tree/1</a></td><td></td></tr><tr><td valign="top"><a href="#loop_vertices-1">loop_vertices/1</a></td><td></td></tr><tr><td valign="top"><a href="#new-0">new/0</a></td><td>Returns a new instance of a babel_digraph of type cyclic.</td></tr><tr><td valign="top"><a href="#new-1">new/1</a></td><td>Returns a new instance of a babel_digraph with type Type.</td></tr><tr><td valign="top"><a href="#no_edges-1">no_edges/1</a></td><td></td></tr><tr><td valign="top"><a href="#no_vertices-1">no_vertices/1</a></td><td></td></tr><tr><td valign="top"><a href="#out_degree-2">out_degree/2</a></td><td></td></tr><tr><td valign="top"><a href="#out_edges-2">out_edges/2</a></td><td></td></tr><tr><td valign="top"><a href="#out_neighbours-2">out_neighbours/2</a></td><td></td></tr><tr><td valign="top"><a href="#postorder-1">postorder/1</a></td><td></td></tr><tr><td valign="top"><a href="#preorder-1">preorder/1</a></td><td></td></tr><tr><td valign="top"><a href="#reachable-2">reachable/2</a></td><td></td></tr><tr><td valign="top"><a href="#reachable_neighbours-2">reachable_neighbours/2</a></td><td></td></tr><tr><td valign="top"><a href="#reaching-2">reaching/2</a></td><td></td></tr><tr><td valign="top"><a href="#reaching_neighbours-2">reaching_neighbours/2</a></td><td></td></tr><tr><td valign="top"><a href="#sink_vertices-1">sink_vertices/1</a></td><td></td></tr><tr><td valign="top"><a href="#source_vertices-1">source_vertices/1</a></td><td></td></tr><tr><td valign="top"><a href="#strong_components-1">strong_components/1</a></td><td></td></tr><tr><td valign="top"><a href="#subgraph-2">subgraph/2</a></td><td></td></tr><tr><td valign="top"><a href="#subgraph-3">subgraph/3</a></td><td></td></tr><tr><td valign="top"><a href="#to_dot-2">to_dot/2</a></td><td></td></tr><tr><td valign="top"><a href="#topsort-1">topsort/1</a></td><td></td></tr><tr><td valign="top"><a href="#vertex-2">vertex/2</a></td><td></td></tr><tr><td valign="top"><a href="#vertices-1">vertices/1</a></td><td></td></tr><tr><td valign="top"><a href="#view-2">view/2</a></td><td></td></tr></table>


<a name="functions"></a>

## Function Details ##

<a name="add_edge-3"></a>

### add_edge/3 ###

<pre><code>
add_edge(G::<a href="#type-t">t()</a>, V1::<a href="#type-vertex">vertex()</a>, V2::<a href="#type-vertex">vertex()</a>) -&gt; <a href="#type-t">t()</a>
</code></pre>
<br />

<a name="add_edge-4"></a>

### add_edge/4 ###

<pre><code>
add_edge(G::<a href="#type-t">t()</a>, V1::<a href="#type-vertex">vertex()</a>, V2::<a href="#type-vertex">vertex()</a>, Label::<a href="#type-label">label()</a>) -&gt; <a href="#type-t">t()</a>
</code></pre>
<br />

<a name="add_edge-5"></a>

### add_edge/5 ###

<pre><code>
add_edge(G::<a href="#type-t">t()</a>, E::<a href="#type-edge">edge()</a>, V1::<a href="#type-vertex">vertex()</a>, V2::<a href="#type-vertex">vertex()</a>, Label::<a href="#type-label">label()</a>) -&gt; <a href="#type-t">t()</a>
</code></pre>
<br />

<a name="add_edges-2"></a>

### add_edges/2 ###

<pre><code>
add_edges(G::<a href="#type-t">t()</a>, Es::[{<a href="#type-vertex">vertex()</a>, <a href="#type-vertex">vertex()</a>, <a href="#type-label">label()</a>}] | [{<a href="#type-edge">edge()</a>, <a href="#type-vertex">vertex()</a>, <a href="#type-vertex">vertex()</a>, <a href="#type-label">label()</a>}]) -&gt; <a href="#type-t">t()</a>
</code></pre>
<br />

<a name="add_vertex-1"></a>

### add_vertex/1 ###

<pre><code>
add_vertex(G::<a href="#type-t">t()</a>) -&gt; {<a href="#type-vertex">vertex()</a>, <a href="#type-t">t()</a>} | {error, string()}
</code></pre>
<br />

<a name="add_vertex-2"></a>

### add_vertex/2 ###

<pre><code>
add_vertex(G::<a href="#type-t">t()</a>, V::<a href="#type-vertex">vertex()</a>) -&gt; <a href="#type-t">t()</a>
</code></pre>
<br />

<a name="add_vertex-3"></a>

### add_vertex/3 ###

<pre><code>
add_vertex(G::<a href="#type-t">t()</a>, V::<a href="#type-vertex">vertex()</a>, Label::<a href="#type-label">label()</a>) -&gt; <a href="#type-t">t()</a>
</code></pre>
<br />

<a name="add_vertices-2"></a>

### add_vertices/2 ###

<pre><code>
add_vertices(G::<a href="#type-t">t()</a>, Vs::[<a href="#type-vertex">vertex()</a>]) -&gt; <a href="#type-t">t()</a>
</code></pre>
<br />

<a name="add_vertices-3"></a>

### add_vertices/3 ###

<pre><code>
add_vertices(G::<a href="#type-t">t()</a>, Vs::[<a href="#type-vertex">vertex()</a>], Ls::[any()]) -&gt; <a href="#type-t">t()</a>
</code></pre>
<br />

<a name="arborescence_root-1"></a>

### arborescence_root/1 ###

<pre><code>
arborescence_root(Digraph) -&gt; no | {yes, Root}
</code></pre>

<ul class="definitions"><li><code>Digraph = <a href="#type-t">t()</a></code></li><li><code>Root = <a href="#type-vertex">vertex()</a></code></li></ul>

<a name="components-1"></a>

### components/1 ###

<pre><code>
components(Digraph::<a href="#type-t">t()</a>) -&gt; Component::[[<a href="#type-vertex">vertex()</a>]]
</code></pre>
<br />

<a name="condensation-1"></a>

### condensation/1 ###

<pre><code>
condensation(Digraph) -&gt; CondensedDigraph
</code></pre>

<ul class="definitions"><li><code>Digraph = <a href="#type-t">t()</a></code></li><li><code>CondensedDigraph = <a href="#type-t">t()</a></code></li></ul>

<a name="cyclic_strong_components-1"></a>

### cyclic_strong_components/1 ###

<pre><code>
cyclic_strong_components(Digraph) -&gt; [StrongComponent]
</code></pre>

<ul class="definitions"><li><code>Digraph = <a href="#type-t">t()</a></code></li><li><code>StrongComponent = [<a href="#type-vertex">vertex()</a>]</code></li></ul>

<a name="del_edge-2"></a>

### del_edge/2 ###

<pre><code>
del_edge(G::<a href="#type-t">t()</a>, E::<a href="#type-edge">edge()</a>) -&gt; <a href="#type-t">t()</a>
</code></pre>
<br />

<a name="del_edges-2"></a>

### del_edges/2 ###

<pre><code>
del_edges(G::<a href="#type-t">t()</a>, Es::[<a href="#type-edge">edge()</a>]) -&gt; <a href="#type-t">t()</a>
</code></pre>
<br />

<a name="del_path-3"></a>

### del_path/3 ###

<pre><code>
del_path(G::<a href="#type-t">t()</a>, V1::<a href="#type-vertex">vertex()</a>, V2::<a href="#type-vertex">vertex()</a>) -&gt; <a href="#type-t">t()</a>
</code></pre>
<br />

<a name="del_vertex-2"></a>

### del_vertex/2 ###

<pre><code>
del_vertex(G::<a href="#type-t">t()</a>, V::<a href="#type-vertex">vertex()</a>) -&gt; <a href="#type-t">t()</a>
</code></pre>
<br />

<a name="del_vertices-2"></a>

### del_vertices/2 ###

<pre><code>
del_vertices(G::<a href="#type-t">t()</a>, Vs::[<a href="#type-vertex">vertex()</a>]) -&gt; <a href="#type-t">t()</a>
</code></pre>
<br />

<a name="edge-2"></a>

### edge/2 ###

<pre><code>
edge(G::<a href="#type-t">t()</a>, V::<a href="#type-edge">edge()</a>) -&gt; {<a href="#type-edge">edge()</a>, <a href="#type-vertex">vertex()</a>, <a href="#type-vertex">vertex()</a>, <a href="#type-label">label()</a>} | false
</code></pre>
<br />

<a name="edges-1"></a>

### edges/1 ###

<pre><code>
edges(G::<a href="#type-t">t()</a>) -&gt; [<a href="#type-edge">edge()</a>]
</code></pre>
<br />

<a name="edges-2"></a>

### edges/2 ###

<pre><code>
edges(G::<a href="#type-t">t()</a>, V::<a href="#type-vertex">vertex()</a>) -&gt; [<a href="#type-edge">edge()</a>]
</code></pre>
<br />

<a name="filter_edge_labels-2"></a>

### filter_edge_labels/2 ###

<pre><code>
filter_edge_labels(G::<a href="#type-t">t()</a>, Pred::fun((Edge::<a href="#type-edge">edge()</a>, Value::{<a href="#type-vertex">vertex()</a>, <a href="#type-vertex">vertex()</a>, <a href="#type-label">label()</a>}) -&gt; boolean())) -&gt; [<a href="#type-edge">edge()</a>]
</code></pre>
<br />

<a name="filter_edges-2"></a>

### filter_edges/2 ###

<pre><code>
filter_edges(G::<a href="#type-t">t()</a>, Pred::fun((Edge::<a href="#type-edge">edge()</a>, Value::{<a href="#type-vertex">vertex()</a>, <a href="#type-vertex">vertex()</a>, <a href="#type-label">label()</a>}) -&gt; boolean())) -&gt; [<a href="#type-edge">edge()</a>]
</code></pre>
<br />

<a name="filter_vertex_labels-2"></a>

### filter_vertex_labels/2 ###

<pre><code>
filter_vertex_labels(G::<a href="#type-t">t()</a>, Pred::fun((Vertex::<a href="#type-vertex">vertex()</a>, Label::<a href="#type-label">label()</a>) -&gt; boolean())) -&gt; [<a href="#type-vertex">vertex()</a>]
</code></pre>
<br />

<a name="filter_vertices-2"></a>

### filter_vertices/2 ###

<pre><code>
filter_vertices(G::<a href="#type-t">t()</a>, Pred::fun((Vertex::<a href="#type-vertex">vertex()</a>, Label::<a href="#type-label">label()</a>) -&gt; boolean())) -&gt; [<a href="#type-vertex">vertex()</a>]
</code></pre>
<br />

<a name="fold-3"></a>

### fold/3 ###

<pre><code>
fold(G::<a href="#type-t">t()</a>, Fun::fun((Elem::{<a href="#type-edge">edge()</a>, {<a href="#type-vertex">vertex()</a>, <a href="#type-label">label()</a>}, {<a href="#type-vertex">vertex()</a>, <a href="#type-label">label()</a>}, <a href="#type-label">label()</a>}, Acc::term()) -&gt; boolean()), Acc0::term()) -&gt; Acc1::term()
</code></pre>
<br />

<a name="fold_view-4"></a>

### fold_view/4 ###

`fold_view(G, View, Fun, Acc0) -> any()`

<a name="get_cycle-2"></a>

### get_cycle/2 ###

<pre><code>
get_cycle(G::<a href="#type-t">t()</a>, V::<a href="#type-vertex">vertex()</a>) -&gt; [<a href="#type-vertex">vertex()</a>]
</code></pre>
<br />

<a name="get_path-3"></a>

### get_path/3 ###

<pre><code>
get_path(G::<a href="#type-t">t()</a>, V1::<a href="#type-vertex">vertex()</a>, V2::<a href="#type-vertex">vertex()</a>) -&gt; [<a href="#type-vertex">vertex()</a>]
</code></pre>
<br />

<a name="get_short_cycle-2"></a>

### get_short_cycle/2 ###

<pre><code>
get_short_cycle(G::<a href="#type-t">t()</a>, V::<a href="#type-vertex">vertex()</a>) -&gt; [<a href="#type-vertex">vertex()</a>]
</code></pre>
<br />

<a name="get_short_path-3"></a>

### get_short_path/3 ###

<pre><code>
get_short_path(G::<a href="#type-t">t()</a>, V1::<a href="#type-vertex">vertex()</a>, V2::<a href="#type-vertex">vertex()</a>) -&gt; [<a href="#type-vertex">vertex()</a>]
</code></pre>
<br />

<a name="has_edge-2"></a>

### has_edge/2 ###

<pre><code>
has_edge(G::<a href="#type-t">t()</a>, E::<a href="#type-edge">edge()</a>) -&gt; boolean()
</code></pre>
<br />

<a name="in_degree-2"></a>

### in_degree/2 ###

<pre><code>
in_degree(G::<a href="#type-t">t()</a>, V::<a href="#type-vertex">vertex()</a>) -&gt; non_neg_integer()
</code></pre>
<br />

<a name="in_edges-2"></a>

### in_edges/2 ###

<pre><code>
in_edges(G::<a href="#type-t">t()</a>, V::<a href="#type-vertex">vertex()</a>) -&gt; [<a href="#type-edge">edge()</a>]
</code></pre>
<br />

<a name="in_neighbours-2"></a>

### in_neighbours/2 ###

<pre><code>
in_neighbours(G::<a href="#type-t">t()</a>, V::<a href="#type-vertex">vertex()</a>) -&gt; [<a href="#type-vertex">vertex()</a>]
</code></pre>
<br />

<a name="info-1"></a>

### info/1 ###

<pre><code>
info(G::<a href="#type-t">t()</a>) -&gt; [tuple()]
</code></pre>
<br />

<a name="is_acyclic-1"></a>

### is_acyclic/1 ###

<pre><code>
is_acyclic(Digraph) -&gt; boolean()
</code></pre>

<ul class="definitions"><li><code>Digraph = <a href="#type-t">t()</a></code></li></ul>

<a name="is_arborescence-1"></a>

### is_arborescence/1 ###

<pre><code>
is_arborescence(Digraph) -&gt; boolean()
</code></pre>

<ul class="definitions"><li><code>Digraph = <a href="#type-t">t()</a></code></li></ul>

<a name="is_tree-1"></a>

### is_tree/1 ###

<pre><code>
is_tree(Digraph) -&gt; boolean()
</code></pre>

<ul class="definitions"><li><code>Digraph = <a href="#type-t">t()</a></code></li></ul>

<a name="loop_vertices-1"></a>

### loop_vertices/1 ###

<pre><code>
loop_vertices(Digraph) -&gt; Vertices
</code></pre>

<ul class="definitions"><li><code>Digraph = <a href="#type-t">t()</a></code></li><li><code>Vertices = [<a href="#type-vertex">vertex()</a>]</code></li></ul>

<a name="new-0"></a>

### new/0 ###

<pre><code>
new() -&gt; <a href="#type-t">t()</a>
</code></pre>
<br />

Returns a new instance of a babel_digraph of type cyclic.

<a name="new-1"></a>

### new/1 ###

<pre><code>
new(Type::atom() | {atom(), boolean()}) -&gt; <a href="#type-t">t()</a>
</code></pre>
<br />

Returns a new instance of a babel_digraph with type Type.

<a name="no_edges-1"></a>

### no_edges/1 ###

<pre><code>
no_edges(G::<a href="#type-t">t()</a>) -&gt; non_neg_integer()
</code></pre>
<br />

<a name="no_vertices-1"></a>

### no_vertices/1 ###

<pre><code>
no_vertices(G::<a href="#type-t">t()</a>) -&gt; non_neg_integer()
</code></pre>
<br />

<a name="out_degree-2"></a>

### out_degree/2 ###

<pre><code>
out_degree(G::<a href="#type-t">t()</a>, V::<a href="#type-vertex">vertex()</a>) -&gt; non_neg_integer()
</code></pre>
<br />

<a name="out_edges-2"></a>

### out_edges/2 ###

<pre><code>
out_edges(G::<a href="#type-t">t()</a>, V::<a href="#type-vertex">vertex()</a>) -&gt; [<a href="#type-edge">edge()</a>]
</code></pre>
<br />

<a name="out_neighbours-2"></a>

### out_neighbours/2 ###

<pre><code>
out_neighbours(G::<a href="#type-t">t()</a>, V::<a href="#type-vertex">vertex()</a>) -&gt; [<a href="#type-vertex">vertex()</a>]
</code></pre>
<br />

<a name="postorder-1"></a>

### postorder/1 ###

<pre><code>
postorder(Digraph) -&gt; Vertices
</code></pre>

<ul class="definitions"><li><code>Digraph = <a href="#type-t">t()</a></code></li><li><code>Vertices = [<a href="#type-vertex">vertex()</a>]</code></li></ul>

<a name="preorder-1"></a>

### preorder/1 ###

<pre><code>
preorder(Digraph) -&gt; Vertices
</code></pre>

<ul class="definitions"><li><code>Digraph = <a href="#type-t">t()</a></code></li><li><code>Vertices = [<a href="#type-vertex">vertex()</a>]</code></li></ul>

<a name="reachable-2"></a>

### reachable/2 ###

<pre><code>
reachable(Vertices, Digraph) -&gt; Reachable
</code></pre>

<ul class="definitions"><li><code>Digraph = <a href="#type-t">t()</a></code></li><li><code>Vertices = [<a href="#type-vertex">vertex()</a>]</code></li><li><code>Reachable = [<a href="#type-vertex">vertex()</a>]</code></li></ul>

<a name="reachable_neighbours-2"></a>

### reachable_neighbours/2 ###

<pre><code>
reachable_neighbours(Vertices, Digraph) -&gt; Reachable
</code></pre>

<ul class="definitions"><li><code>Digraph = <a href="#type-t">t()</a></code></li><li><code>Vertices = [<a href="#type-vertex">vertex()</a>]</code></li><li><code>Reachable = [<a href="#type-vertex">vertex()</a>]</code></li></ul>

<a name="reaching-2"></a>

### reaching/2 ###

<pre><code>
reaching(Vertices, Digraph) -&gt; Reaching
</code></pre>

<ul class="definitions"><li><code>Digraph = <a href="#type-t">t()</a></code></li><li><code>Vertices = [<a href="#type-vertex">vertex()</a>]</code></li><li><code>Reaching = [<a href="#type-vertex">vertex()</a>]</code></li></ul>

<a name="reaching_neighbours-2"></a>

### reaching_neighbours/2 ###

<pre><code>
reaching_neighbours(Vertices, Digraph) -&gt; Reaching
</code></pre>

<ul class="definitions"><li><code>Digraph = <a href="#type-t">t()</a></code></li><li><code>Vertices = [<a href="#type-vertex">vertex()</a>]</code></li><li><code>Reaching = [<a href="#type-vertex">vertex()</a>]</code></li></ul>

<a name="sink_vertices-1"></a>

### sink_vertices/1 ###

<pre><code>
sink_vertices(G::<a href="#type-t">t()</a>) -&gt; [<a href="#type-vertex">vertex()</a>]
</code></pre>
<br />

<a name="source_vertices-1"></a>

### source_vertices/1 ###

<pre><code>
source_vertices(G::<a href="#type-t">t()</a>) -&gt; [<a href="#type-vertex">vertex()</a>]
</code></pre>
<br />

<a name="strong_components-1"></a>

### strong_components/1 ###

<pre><code>
strong_components(Digraph) -&gt; [StrongComponent]
</code></pre>

<ul class="definitions"><li><code>Digraph = <a href="#type-t">t()</a></code></li><li><code>StrongComponent = [<a href="#type-vertex">vertex()</a>]</code></li></ul>

<a name="subgraph-2"></a>

### subgraph/2 ###

<pre><code>
subgraph(Digraph, Vertices) -&gt; SubGraph
</code></pre>

<ul class="definitions"><li><code>Digraph = <a href="#type-t">t()</a></code></li><li><code>Vertices = [<a href="#type-vertex">vertex()</a>]</code></li><li><code>SubGraph = <a href="#type-t">t()</a></code></li></ul>

<a name="subgraph-3"></a>

### subgraph/3 ###

<pre><code>
subgraph(Digraph, Vertices, Options) -&gt; SubGraph
</code></pre>

<ul class="definitions"><li><code>Digraph = <a href="#type-t">t()</a></code></li><li><code>SubGraph = <a href="#type-t">t()</a></code></li><li><code>Vertices = [<a href="#type-vertex">vertex()</a>]</code></li><li><code>Options = [{type, SubgraphType} | {keep_labels, boolean()}]</code></li><li><code>SubgraphType = inherit | [term()]</code></li></ul>

<a name="to_dot-2"></a>

### to_dot/2 ###

`to_dot(G, File) -> any()`

<a name="topsort-1"></a>

### topsort/1 ###

<pre><code>
topsort(Digraph) -&gt; Vertices | false
</code></pre>

<ul class="definitions"><li><code>Digraph = <a href="#type-t">t()</a></code></li><li><code>Vertices = [<a href="#type-vertex">vertex()</a>]</code></li></ul>

<a name="vertex-2"></a>

### vertex/2 ###

<pre><code>
vertex(G::<a href="#type-t">t()</a>, V::<a href="#type-vertex">vertex()</a>) -&gt; {<a href="#type-vertex">vertex()</a>, <a href="#type-label">label()</a>} | false
</code></pre>
<br />

<a name="vertices-1"></a>

### vertices/1 ###

<pre><code>
vertices(G::<a href="#type-t">t()</a>) -&gt; [<a href="#type-vertex">vertex()</a>]
</code></pre>
<br />

<a name="view-2"></a>

### view/2 ###

<pre><code>
view(G::<a href="#type-t">t()</a>, EdgesOrPred::[<a href="#type-edge">edge()</a>] | fun((Edge::<a href="#type-edge">edge()</a>, Value::{<a href="#type-vertex">vertex()</a>, <a href="#type-vertex">vertex()</a>, <a href="#type-label">label()</a>}) -&gt; boolean())) -&gt; <a href="#type-babel_digraph_view">babel_digraph_view()</a>
</code></pre>
<br />

