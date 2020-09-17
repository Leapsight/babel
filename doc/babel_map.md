

# Module babel_map #
* [Description](#description)
* [Data Types](#types)
* [Function Index](#index)
* [Function Details](#functions)

Provides an alternative to Riak map datatype.

<a name="description"></a>

## Description ##

# Overview

Babel maps (maps) differ from Riak's and Erlang's maps in several ways:

* Maps are special key-value structures where the key is a binary name and
the value is either an Erlang term or another Babel data structure (each one
an alternative of the Riak's counterparts). In case the value is an Erlang
term, it is denoted as a Riak register but without the restriction of them
being binaries as in Riak. To be able to do this certain map operations
require a Specification object, a sort of schema that tells Babel map the
type of each value. This enables the map to use Erlang terms and only
convert them to the required Riak datatypes when storing the object in the
database.
* Maps maintain the same semantics as Riak Maps but with some key differences
* As with Riak Map, removals, and modifications are captured for later
application by Riak but they are also applied to the local state. That is,
maps resolve the issue of not being able to read your object mutations in
memory that occurs when using Riak maps.
* Removals are processed before updates in Riak.
Also, removals performed without a context may result in failure.
* Updating an entry followed by removing that same entry will result in
no operation being recorded. Likewise, removing an entry followed by
updating that entry  will cancel the removal operation.
* You may store or remove values in a map by using `set/3`, `remove/2`,
and other functions targetting embedded babel containers e.g. `add_element/
3`, `add_elements/3`, `del_element/3` to modify an embeded [`babel_set`](babel_set.md)
. This is a complete departure from Riak's cumbersome `update/3` function.
As in Riak Maps, setting or adding a value to an embedded container that is
not present will create a new container before the set/add operation.
* Certain function e.g. `set/3` allows you to set a value in a key or a
path (list of nested keys).

# Map Specification

A map specification is an Erlang map where the keys are Riak keys i.e. a
pair of a binary name and data type and value is another specification or a
`type()`. This can be seen as an encoding specification. For example the
specification `#{ {<<"friends">>, set} => list}`, says the map contains a
single key name "friends" containing a set which individual elements we want
to convert to lists i.e. a set of lists. This will result in a map
containing the key `<<"friends">>` and a babel set contining the elements
converted from binaries to lists.

The special '_' key name provides the capability to convert a Riak Map where
the keys are not known in advance, and their values are all of the same
type. These specs can only have a single entry as follows
`#{{`_', set}, binary}'.

<a name="types"></a>

## Data Types ##




### <a name="type-datatype">datatype()</a> ###


<pre><code>
datatype() = counter | flag | register | set | map
</code></pre>




### <a name="type-key_path">key_path()</a> ###


<pre><code>
key_path() = binary() | [binary()]
</code></pre>




### <a name="type-key_type_spec">key_type_spec()</a> ###


<pre><code>
key_type_spec() = atom | existing_atom | boolean | integer | float | binary | list | <a href="#type-type_spec">type_spec()</a> | <a href="babel_set.md#type-type_spec">babel_set:type_spec()</a> | fun((encode, any()) -&gt; <a href="#type-value">value()</a>) | fun((decode, <a href="#type-value">value()</a>) -&gt; any())
</code></pre>




### <a name="type-riak_key">riak_key()</a> ###


<pre><code>
riak_key() = {binary(), <a href="#type-datatype">datatype()</a>}
</code></pre>




### <a name="type-t">t()</a> ###


__abstract datatype__: `t()`




### <a name="type-type_spec">type_spec()</a> ###


<pre><code>
type_spec() = #{<a href="#type-riak_key">riak_key()</a> =&gt; <a href="#type-key_type_spec">key_type_spec()</a>} | #{{_, <a href="#type-datatype">datatype()</a>} =&gt; <a href="#type-key_type_spec">key_type_spec()</a>}
</code></pre>




### <a name="type-update_fun">update_fun()</a> ###


<pre><code>
update_fun() = fun((<a href="babel.md#type-datatype">babel:datatype()</a> | term()) -&gt; <a href="babel.md#type-datatype">babel:datatype()</a> | term())
</code></pre>




### <a name="type-value">value()</a> ###


<pre><code>
value() = any()
</code></pre>

<a name="index"></a>

## Function Index ##


<table width="100%" border="1" cellspacing="0" cellpadding="2" summary="function index"><tr><td valign="top"><a href="#add_element-3">add_element/3</a></td><td>Adds element <code>Value</code> to a babel set associated with key or path
<code>Key</code> in map <code>Map</code> and inserts the association into map <code>NewMap</code>.</td></tr><tr><td valign="top"><a href="#add_elements-3">add_elements/3</a></td><td>Adds a list of values <code>Values</code> to a babel set associated with key or
path <code>Key</code> in map <code>Map</code> and inserts the association into map <code>NewMap</code>.</td></tr><tr><td valign="top"><a href="#collect-2">collect/2</a></td><td></td></tr><tr><td valign="top"><a href="#context-1">context/1</a></td><td>Returns the Riak KV context.</td></tr><tr><td valign="top"><a href="#del_element-3">del_element/3</a></td><td>Returns a new map <code>NewMap</code> were the value <code>Value</code> has been removed from
a babel set associated with key or path <code>Key</code> in
map <code>Map</code>.</td></tr><tr><td valign="top"><a href="#from_riak_map-2">from_riak_map/2</a></td><td></td></tr><tr><td valign="top"><a href="#get-2">get/2</a></td><td>Returns value <code>Value</code> associated with <code>Key</code> if <code>T</code> contains <code>Key</code>.</td></tr><tr><td valign="top"><a href="#get-3">get/3</a></td><td>Returns value <code>Value</code> associated with <code>Key</code> if <code>T</code> contains <code>Key</code>, or
the default value <code>Default</code> in case <code>T</code> does not contain <code>Key</code>.</td></tr><tr><td valign="top"><a href="#is_type-1">is_type/1</a></td><td>Returns true if term <code>Term</code> is a babel map.</td></tr><tr><td valign="top"><a href="#new-0">new/0</a></td><td></td></tr><tr><td valign="top"><a href="#new-1">new/1</a></td><td></td></tr><tr><td valign="top"><a href="#new-2">new/2</a></td><td></td></tr><tr><td valign="top"><a href="#remove-2">remove/2</a></td><td>Removes a key and its value from the map.</td></tr><tr><td valign="top"><a href="#set-3">set/3</a></td><td>Associates <code>Key</code> with value <code>Value</code> and inserts the association into
map <code>NewMap</code>.</td></tr><tr><td valign="top"><a href="#to_riak_op-2">to_riak_op/2</a></td><td></td></tr><tr><td valign="top"><a href="#type-0">type/0</a></td><td>Returns the symbolic name of this container.</td></tr><tr><td valign="top"><a href="#update-3">update/3</a></td><td></td></tr><tr><td valign="top"><a href="#value-1">value/1</a></td><td>Returns an external representation of the babel map <code>Map</code> as an erlang
map.</td></tr></table>


<a name="functions"></a>

## Function Details ##

<a name="add_element-3"></a>

### add_element/3 ###

<pre><code>
add_element(Key::<a href="#type-key">key()</a>, Value::<a href="#type-value">value()</a>, Map::<a href="#type-t">t()</a>) -&gt; NewMap::<a href="#type-maybe_no_return">maybe_no_return</a>(<a href="#type-t">t()</a>)
</code></pre>
<br />

Adds element `Value` to a babel set associated with key or path
`Key` in map `Map` and inserts the association into map `NewMap`.

If the key `Key` does not exist in map `Map`, this function creates a new
babel set containining `Value`.

The call might fail with the following exception reasons:

* `{badset, Set}` - if the initial value associated with `Key` in map `Map0`
is not a babel set;
* `{badmap, Map}` exception if `Map` is not a babel map.
* `{badkey, Key}` - exception if no value is associated with `Key` or `Key`
is not of type binary.

<a name="add_elements-3"></a>

### add_elements/3 ###

<pre><code>
add_elements(Key::<a href="#type-key">key()</a>, Values::[<a href="#type-value">value()</a>], Map::<a href="#type-t">t()</a>) -&gt; NewMap::<a href="#type-maybe_no_return">maybe_no_return</a>(<a href="#type-t">t()</a>)
</code></pre>
<br />

Adds a list of values `Values` to a babel set associated with key or
path `Key` in map `Map` and inserts the association into map `NewMap`.

If the key `Key` does not exist in map `Map`, this function creates a new
babel set containining `Values`.

The call might fail with the following exception reasons:

* `{badset, Set}` - if the initial value associated with `Key` in map `Map0`
is not a babel set;
* `{badmap, Map}` exception if `Map` is not a babel map.
* `{badkey, Key}` - exception if no value is associated with `Key` or `Key`
is not of type binary.

<a name="collect-2"></a>

### collect/2 ###

<pre><code>
collect(Keys::[<a href="#type-key">key()</a>], Map::<a href="#type-t">t()</a>) -&gt; [any()]
</code></pre>
<br />

<a name="context-1"></a>

### context/1 ###

<pre><code>
context(T::<a href="#type-t">t()</a>) -&gt; <a href="riakc_datatype.md#type-context">riakc_datatype:context()</a>
</code></pre>
<br />

Returns the Riak KV context

<a name="del_element-3"></a>

### del_element/3 ###

<pre><code>
del_element(Key::<a href="#type-key">key()</a>, Value::<a href="#type-value">value()</a>, Map::<a href="#type-t">t()</a>) -&gt; NewMap::<a href="#type-maybe_no_return">maybe_no_return</a>(<a href="#type-t">t()</a>)
</code></pre>
<br />

Returns a new map `NewMap` were the value `Value` has been removed from
a babel set associated with key or path `Key` in
map `Map`.

If the key `Key` does not exist in map `Map`, this function creates a new
babel set recording the removal of `Value`.

The call might fail with the following exception reasons:

* `{badset, Set}` - if the initial value associated with `Key` in map `Map0`
is not a babel set;
* `{badmap, Map}` exception if `Map` is not a babel map.
* `{badkey, Key}` - exception if no value is associated with `Key` or `Key`
is not of type binary.

<a name="from_riak_map-2"></a>

### from_riak_map/2 ###

<pre><code>
from_riak_map(RMap::<a href="riakc_map.md#type-crdt_map">riakc_map:crdt_map()</a> | list(), Spec::<a href="#type-type_spec">type_spec()</a>) -&gt; <a href="#type-t">t()</a>
</code></pre>
<br />

<a name="get-2"></a>

### get/2 ###

<pre><code>
get(Key::<a href="#type-key">key()</a>, T::<a href="#type-t">t()</a>) -&gt; any()
</code></pre>
<br />

Returns value `Value` associated with `Key` if `T` contains `Key`.
`Key` can be a binary or a path represented as a list of binaries.

The call fails with a {badarg, `T`} exception if `T` is not a Babel Map.
It also fails with a {badkey, `Key`} exception if no value is associated
with `Key`.

<a name="get-3"></a>

### get/3 ###

<pre><code>
get(Key::<a href="#type-key_path">key_path()</a>, Map::<a href="#type-t">t()</a>, Default::any()) -&gt; <a href="#type-value">value()</a>
</code></pre>
<br />

Returns value `Value` associated with `Key` if `T` contains `Key`, or
the default value `Default` in case `T` does not contain `Key`.

`Key` can be a binary or a path represented as a list of binaries.

The call fails with a `{badarg, T}` exception if `T` is not a Babel Map.
It also fails with a `{badkey, Key}` exception if no value is associated
with `Key`.

<a name="is_type-1"></a>

### is_type/1 ###

<pre><code>
is_type(Term::any()) -&gt; boolean()
</code></pre>
<br />

Returns true if term `Term` is a babel map.

<a name="new-0"></a>

### new/0 ###

<pre><code>
new() -&gt; <a href="#type-t">t()</a>
</code></pre>
<br />

<a name="new-1"></a>

### new/1 ###

<pre><code>
new(Data::map()) -&gt; <a href="#type-t">t()</a>
</code></pre>
<br />

<a name="new-2"></a>

### new/2 ###

<pre><code>
new(Data::map(), Spec::<a href="#type-type_spec">type_spec()</a>) -&gt; <a href="#type-t">t()</a>
</code></pre>
<br />

<a name="remove-2"></a>

### remove/2 ###

<pre><code>
remove(Key::<a href="#type-key">key()</a>, T::<a href="#type-t">t()</a>) -&gt; NewT::<a href="#type-maybe_no_return">maybe_no_return</a>(<a href="#type-t">t()</a>)
</code></pre>
<br />

throws `context_required`

Removes a key and its value from the map. Removing a key that
does not exist simply records a remove operation.

<a name="set-3"></a>

### set/3 ###

<pre><code>
set(Key::<a href="#type-key">key()</a>, Value::<a href="#type-value">value()</a>, Map::<a href="#type-t">t()</a>) -&gt; NewMap::<a href="#type-maybe_no_return">maybe_no_return</a>(<a href="#type-t">t()</a>)
</code></pre>
<br />

Associates `Key` with value `Value` and inserts the association into
map `NewMap`. If key `Key` already exists in map `Map`, the old associated
value is replaced by value `Value`. The function returns a new map `NewMap`
containing the new association and the old associations in `Map`.

The call fails with a `{badmap, Term}` exception if `Map` or any value of a
partial key path is not a babel map.

<a name="to_riak_op-2"></a>

### to_riak_op/2 ###

<pre><code>
to_riak_op(T::<a href="#type-t">t()</a>, Spec::<a href="#type-type_spec">type_spec()</a>) -&gt; <a href="riakc_datatype.md#type-update">riakc_datatype:update</a>(<a href="riakc_map.md#type-map_op">riakc_map:map_op()</a>)
</code></pre>
<br />

<a name="type-0"></a>

### type/0 ###

<pre><code>
type() -&gt; atom()
</code></pre>
<br />

Returns the symbolic name of this container.

<a name="update-3"></a>

### update/3 ###

<pre><code>
update(Key::<a href="#type-key">key()</a>, Fun::<a href="#type-update_fun">update_fun()</a>, T::<a href="#type-t">t()</a>) -&gt; NewT::<a href="#type-t">t()</a>
</code></pre>
<br />

<a name="value-1"></a>

### value/1 ###

<pre><code>
value(Map::<a href="#type-t">t()</a>) -&gt; map()
</code></pre>
<br />

Returns an external representation of the babel map `Map` as an erlang
map. This is build recursively by calling the value/1 function on any
embedded babel datatype.

