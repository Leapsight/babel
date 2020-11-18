

# Module babel_map #
* [Description](#description)
* [Data Types](#types)
* [Function Index](#index)
* [Function Details](#functions)

Provides an alternative to Riak Map Datatype.

<a name="description"></a>

## Description ##

# Overview

Babel maps (maps) differ from Riak's and Erlang's maps in several ways:

* Maps are special key-value structures where the key is a binary name and
the value is a Babel datatype, each one an alternative of the Riak's
counterparts, with the exception of the Riak Register type which can be
represented by any Erlang Term in Babel (and not just a binary) provided
there exists a valid type conversion specification (see [Type Specifications](#type-specifications)).
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

# <a name="type-specifications"></a>Type Specifications

A type specification is an Erlang map where the keys are the Babel map keys
and their value is another specification or a
`type_mapping()`.

For example the specification `#{<<"friends">> => {set, list}}`, says the
map contains a single key name "friends" containing a Babel Set (compatible
with Riak Set) where the individual
elements are represented in Erlang as lists i.e. a set of lists. This will
result in a map containing the key `<<"friends">>` and a babel set contining
the elements converted from binaries to lists.

The special '\_' key name provides the capability to convert a Riak Map where
the keys are not known in advance, and their values are all of the same
type. These specs can only have a single entry as follows
`#{{`\_', set}, binary}'.

<a name="types"></a>

## Data Types ##


<a name="action()"></a>


### action() ###


<pre><code>
action() = map()
</code></pre>


<a name="erl_type()"></a>


### erl_type() ###


<pre><code>
erl_type() = atom | existing_atom | boolean | integer | float | binary | list | fun((encode, any()) -&gt; <a href="#type-value">value()</a>) | fun((decode, <a href="#type-value">value()</a>) -&gt; any())
</code></pre>


<a name="key_path()"></a>


### key_path() ###


<pre><code>
key_path() = binary() | [binary()]
</code></pre>


<a name="t()"></a>


### t() ###


__abstract datatype__: `t()`


<a name="type_mapping()"></a>


### type_mapping() ###


<pre><code>
type_mapping() = {map, <a href="#type-type_spec">type_spec()</a>} | {set, <a href="#type-erl_type">erl_type()</a>} | {counter, <a href="#type-erl_type">erl_type()</a>} | {flag, <a href="#type-erl_type">erl_type()</a>} | {register, <a href="#type-erl_type">erl_type()</a>}
</code></pre>


<a name="type_spec()"></a>


### type_spec() ###


<pre><code>
type_spec() = #{$validated =&gt; true, <a href="#type-key">key()</a> | _ =&gt; <a href="#type-type_mapping">type_mapping()</a>}
</code></pre>


<a name="value()"></a>


### value() ###


<pre><code>
value() = any()
</code></pre>


<a name="functions"></a>

## Function Details ##

<a name="add_element-3"></a>

### add_element/3 ###

<pre><code>
add_element(Key::<a href="#type-key_path">key_path()</a>, Value::<a href="#type-value">value()</a>, Map::<a href="#type-t">t()</a>) -&gt; NewMap::<a href="#type-maybe_no_return">maybe_no_return</a>(<a href="#type-t">t()</a>)
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
add_elements(Key::<a href="#type-key_path">key_path()</a>, Values::[<a href="#type-value">value()</a>], Map::<a href="#type-t">t()</a>) -&gt; NewMap::<a href="#type-maybe_no_return">maybe_no_return</a>(<a href="#type-t">t()</a>)
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

<a name="change_status-2"></a>

### change_status/2 ###

<pre><code>
change_status(KeyPath::<a href="babel_key_value.md#type-path">babel_key_value:path()</a>, Map::<a href="#type-t">t()</a>) -&gt; none | both | removed | updated
</code></pre>
<br />

Returns the status of a key path `KeyPath` in map `Map`, where status
can be one of `updated`, `removed`, `both` or `none`.

<a name="changed_key_paths-1"></a>

### changed_key_paths/1 ###

<pre><code>
changed_key_paths(T::<a href="#type-t">t()</a>) -&gt; {Updated::[<a href="#type-key_path">key_path()</a>], Removed::[<a href="#type-key_path">key_path()</a>]} | no_return()
</code></pre>
<br />

Returns a tuple where the first element is the list of the key paths
that have been updated and the second one those which have been removed
in map `T`.
Notice that a key path might be both removed and updated, in which case it
will be a mamber of both result elements.
The call fails with a `{badmap, T}` exception if `T` is not a map.

<a name="collect-2"></a>

### collect/2 ###

<pre><code>
collect(Keys::[<a href="#type-key_path">key_path()</a>], Map::<a href="#type-t">t()</a>) -&gt; [any()]
</code></pre>
<br />

Returns a list of values associated with the keys `Keys`.
Fails with a `{badkey, K}` exeception if any key `K` in `Keys` is not
present in the map.

<a name="collect-3"></a>

### collect/3 ###

<pre><code>
collect(Keys::[<a href="#type-key_path">key_path()</a>], Map::<a href="#type-t">t()</a>, Default::any()) -&gt; [any()]
</code></pre>
<br />

Returns a list of values associated with the keys `Keys`. If any key
`K` in `Keys` is not present in the map the value `Default` is returned.

<a name="collect_map-2"></a>

### collect_map/2 ###

<pre><code>
collect_map(Keys::[<a href="#type-key_path">key_path()</a>], Map::<a href="#type-t">t()</a>) -&gt; map()
</code></pre>
<br />

Returns a list of values associated with the keys `Keys`.
Fails with a `{badkey, K}` exeception if any key `K` in `Keys` is not
present in the map.

<a name="collect_map-3"></a>

### collect_map/3 ###

<pre><code>
collect_map(Keys::[<a href="#type-key_path">key_path()</a>], Map::<a href="#type-t">t()</a>, Default::any()) -&gt; map()
</code></pre>
<br />

Returns a list of values associated with the keys `Keys`. If any key
`K` in `Keys` is not present in the map the value `Default` is returned.

<a name="context-1"></a>

### context/1 ###

<pre><code>
context(T::<a href="#type-t">t()</a>) -&gt; <a href="riakc_datatype.md#type-context">riakc_datatype:context()</a> | no_return()
</code></pre>
<br />

Returns the Riak KV context associated with map `T`.
The call fails with a `{badmap, T}` exception if `T` is not a map.

<a name="decrement-2"></a>

### decrement/2 ###

<pre><code>
decrement(Key::<a href="#type-key_path">key_path()</a>, T::<a href="#type-t">t()</a>) -&gt; NewT::<a href="#type-t">t()</a>
</code></pre>
<br />

<a name="decrement-3"></a>

### decrement/3 ###

<pre><code>
decrement(Key::<a href="#type-key_path">key_path()</a>, Value::integer(), T::<a href="#type-t">t()</a>) -&gt; NewT::<a href="#type-t">t()</a>
</code></pre>
<br />

<a name="del_element-3"></a>

### del_element/3 ###

<pre><code>
del_element(Key::<a href="#type-key_path">key_path()</a>, Value::<a href="#type-value">value()</a>, Map::<a href="#type-t">t()</a>) -&gt; NewMap::<a href="#type-maybe_no_return">maybe_no_return</a>(<a href="#type-t">t()</a>)
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

<a name="disable-2"></a>

### disable/2 ###

<pre><code>
disable(Key::<a href="#type-key_path">key_path()</a>, T::<a href="#type-t">t()</a>) -&gt; NewT::<a href="#type-t">t()</a>
</code></pre>
<br />

<a name="enable-2"></a>

### enable/2 ###

<pre><code>
enable(Key::<a href="#type-key_path">key_path()</a>, T::<a href="#type-t">t()</a>) -&gt; NewT::<a href="#type-t">t()</a>
</code></pre>
<br />

<a name="find-2"></a>

### find/2 ###

<pre><code>
find(Key::<a href="#type-key_path">key_path()</a>, T::<a href="#type-t">t()</a>) -&gt; {ok, any()} | error
</code></pre>
<br />

Returns the tuple `{ok, Value :: any()}` if the key 'Key' is associated
with value `Value` in map `T`. Otherwise returns the atom `error`.
The call fails with a `{badmap, T}` exception if `T` is not a map and
`{badkey, Key}` exception if `Key` is not a binary term.

<a name="from_riak_map-2"></a>

### from_riak_map/2 ###

<pre><code>
from_riak_map(RMap::<a href="riakc_map.md#type-crdt_map">riakc_map:crdt_map()</a> | list(), Spec::<a href="#type-type_spec">type_spec()</a>) -&gt; <a href="#type-t">t()</a>
</code></pre>
<br />

Returns a new map by applying the type specification `Spec` to the Riak
Map `RMap`.

<a name="get-2"></a>

### get/2 ###

<pre><code>
get(Key::<a href="#type-key_path">key_path()</a>, T::<a href="#type-t">t()</a>) -&gt; any() | no_return()
</code></pre>
<br />

Returns value `Value` associated with `Key` if `T` contains `Key`.
`Key` can be a binary or a path represented as a list of binaries.

The call fails with a {badarg, `T`} exception if `T` is not a Babel Map.
It also fails with a {badkey, `Key`} exception if no value is associated
with `Key` or if `Key` is not a binary term.

<a name="get-3"></a>

### get/3 ###

<pre><code>
get(Key::<a href="#type-key_path">key_path()</a>, Map::<a href="#type-t">t()</a>, Default::any()) -&gt; Value::<a href="#type-value">value()</a>
</code></pre>
<br />

Returns value `Value` associated with `Key` if `T` contains `Key`, or
the default value `Default` in case `T` does not contain `Key`.

`Key` can be a binary or a path represented as a list of binaries.

The call fails with a `{badarg, T}` exception if `T` is not a Babel Map.
It also fails with a `{badkey, Key}` exception if no value is associated
with `Key` or if `Key` is not a binary term.

<a name="get_value-2"></a>

### get_value/2 ###

<pre><code>
get_value(Key::<a href="#type-key_path">key_path()</a>, T::<a href="#type-t">t()</a>) -&gt; any()
</code></pre>
<br />

An util function equivalent to calling `DatatypeMod:value(get(Key, T))`.

<a name="get_value-3"></a>

### get_value/3 ###

<pre><code>
get_value(Key::<a href="#type-key_path">key_path()</a>, T::<a href="#type-t">t()</a>, Default::any()) -&gt; any() | no_return()
</code></pre>
<br />

An util function equivalent to calling
`DatatypeMod:value(get(Key, T, Default))`.

<a name="increment-2"></a>

### increment/2 ###

<pre><code>
increment(Key::<a href="#type-key_path">key_path()</a>, T::<a href="#type-t">t()</a>) -&gt; NewT::<a href="#type-t">t()</a>
</code></pre>
<br />

<a name="increment-3"></a>

### increment/3 ###

<pre><code>
increment(Key::<a href="#type-key_path">key_path()</a>, Value::integer(), T::<a href="#type-t">t()</a>) -&gt; NewT::<a href="#type-t">t()</a>
</code></pre>
<br />

<a name="is_type-1"></a>

### is_type/1 ###

<pre><code>
is_type(Term::any()) -&gt; boolean()
</code></pre>
<br />

Returns true if term `Term` is a babel map.
The call fails with a `{badmap, Term}` exception if `Term` is not a map.

<a name="keys-1"></a>

### keys/1 ###

<pre><code>
keys(T::<a href="#type-t">t()</a>) -&gt; [binary()] | no_return()
</code></pre>
<br />

Returns a complete list of keys, in any order, which resides within map
`T`.
The call fails with a `{badmap, T}` exception if `T` is not a map.

<a name="merge-2"></a>

### merge/2 ###

<pre><code>
merge(T1::<a href="#type-t">t()</a>, T2::<a href="#type-t">t()</a> | map()) -&gt; Map3::<a href="#type-t">t()</a>
</code></pre>
<br />

Merges two maps into a single map `Map3`.
The function implements a deep merge.
This function implements minimal type checking so merging two maps that use
different type specs can potentially result in an exception being thrown or
in an invalid map at time of storing.

The call fails with a {badmap,Map} exception if `T1` or `T2` is not a map.

<a name="new-0"></a>

### new/0 ###

<pre><code>
new() -&gt; <a href="#type-t">t()</a>
</code></pre>
<br />

Creates a new empty map.

<a name="new-1"></a>

### new/1 ###

<pre><code>
new(Data::map()) -&gt; <a href="#type-t">t()</a>
</code></pre>
<br />

Creates a new map from the erlang map `Data`, previously
filtering out all keys assigned to the `undefined`.
This function converts the erlang types `map()`, `list()` and `boolean()` to
their corresponding Babel Datatypes `babel_map:t()`, `babel_map:set()` and
`babel_map:flag()`. Any other value will be assumed to be a register. Also,
there is not type validation or coersion when creating a `babel_set:t()` out
of a list.

!> **Important**. Notice that using this function might result in
incompatible types when later using a type specification e.g. [`to_riak_op/2`](#to_riak_op-2). We strongly suggest not using this function and using [`new/2`](#new-2) instead.

<a name="new-2"></a>

### new/2 ###

<pre><code>
new(Data::map(), Spec::<a href="#type-type_spec">type_spec()</a>) -&gt; <a href="#type-t">t()</a>
</code></pre>
<br />

<a name="new-3"></a>

### new/3 ###

<pre><code>
new(Data::map(), Spec::<a href="#type-type_spec">type_spec()</a>, Ctxt::<a href="riakc_datatype.md#type-context">riakc_datatype:context()</a>) -&gt; <a href="#type-t">t()</a>
</code></pre>
<br />

Creates a new Babel Map from the erlang map `Data`, previously
filtering out all keys assigned to the `undefined`.

<a name="patch-3"></a>

### patch/3 ###

<pre><code>
patch(ActionList::[<a href="#type-action">action()</a>], T::<a href="#type-t">t()</a>, Spec::<a href="#type-type_spec">type_spec()</a>) -&gt; NewT::<a href="#type-t">t()</a>
</code></pre>
<br />

Updates a map `T` with the provide key-value action list `ActionList`.
If the value associated with a key `Key` in `Values` is equal to `undefined`
this equivalent to calling `remove(Key, Map)` with the difference that an
exception will not be raised in case the map had no context assigned.

Example:

<a name="put-3"></a>

### put/3 ###

<pre><code>
put(Key::<a href="#type-key_path">key_path()</a>, Value::<a href="#type-value">value()</a>, Map::<a href="#type-t">t()</a>) -&gt; NewMap::<a href="#type-maybe_no_return">maybe_no_return</a>(<a href="#type-t">t()</a>)
</code></pre>
<br />

Same as [`set/3`](#set-3).

<a name="remove-2"></a>

### remove/2 ###

<pre><code>
remove(Key::<a href="#type-key_path">key_path()</a>, T::<a href="#type-t">t()</a>) -&gt; NewT::<a href="#type-maybe_no_return">maybe_no_return</a>(<a href="#type-t">t()</a>)
</code></pre>
<br />

throws `context_required`

Removes a key and its value from the map. Removing a key that
does not exist simply records a remove operation.

<a name="set-3"></a>

### set/3 ###

<pre><code>
set(Key::<a href="#type-key_path">key_path()</a>, Value::<a href="#type-value">value()</a>, Map::<a href="#type-t">t()</a>) -&gt; NewMap::<a href="#type-maybe_no_return">maybe_no_return</a>(<a href="#type-t">t()</a>)
</code></pre>
<br />

Associates `Key` with value `Value` and inserts the association into
map `NewMap`. If key `Key` already exists in map `Map`, the old associated
value is replaced by value `Value`. The function returns a new map `NewMap`
containing the new association and the old associations in `Map`.

Passing a `Value` of `undefined` is equivalent to calling `remove(Key, Map)`
with the difference that an exception will not be raised in case the map had
no context assigned.

The call fails with a `{badmap, Term}` exception if `Map` or any value of a
partial key path is not a babel map.

<a name="set_context-2"></a>

### set_context/2 ###

<pre><code>
set_context(Ctxt::<a href="riakc_datatype.md#type-set_context">riakc_datatype:set_context()</a>, T::<a href="#type-t">t()</a>) -&gt; NewT::<a href="#type-t">t()</a>
</code></pre>
<br />

Sets the context `Ctxt`.

<a name="set_elements-3"></a>

### set_elements/3 ###

<pre><code>
set_elements(Key::<a href="#type-key_path">key_path()</a>, Values::[<a href="#type-value">value()</a>], Map::<a href="#type-t">t()</a>) -&gt; NewMap::<a href="#type-maybe_no_return">maybe_no_return</a>(<a href="#type-t">t()</a>)
</code></pre>
<br />

Sets a list of values `Values` to a babel set associated with key or
path `Key` in map `Map` and inserts the association into map `NewMap`.
See [`babel_set:set_elements/2`](babel_set.md#set_elements-2).

If the key `Key` does not exist in map `Map`, this function creates a new
babel set containining `Values`.

The call might fail with the following exception reasons:

* `{badset, Set}` - if the initial value associated with `Key` in map `Map0`
is not a babel set;
* `{badmap, Map}` exception if `Map` is not a babel map.
* `{badkey, Key}` - exception if no value is associated with `Key` or `Key`
is not of type binary.

<a name="size-1"></a>

### size/1 ###

<pre><code>
size(T::<a href="#type-t">t()</a>) -&gt; non_neg_integer() | no_return()
</code></pre>
<br />

Returns the size of the values of the map `T`.
The call fails with a `{badmap, T}` exception if `T` is not a map.

<a name="to_riak_op-2"></a>

### to_riak_op/2 ###

<pre><code>
to_riak_op(T::<a href="#type-t">t()</a>, Spec::<a href="#type-type_spec">type_spec()</a>) -&gt; <a href="riakc_datatype.md#type-update">riakc_datatype:update</a>(<a href="riakc_map.md#type-map_op">riakc_map:map_op()</a>) | no_return()
</code></pre>
<br />

Extracts a Riak Operation from the map to be used with a Riak Client
update request.
The call fails with a `{badmap, T}` exception if `T` is not a map.

<a name="type-0"></a>

### type/0 ###

<pre><code>
type() -&gt; map
</code></pre>
<br />

Returns the symbolic name of this container.

<a name="update-3"></a>

### update/3 ###

<pre><code>
update(Values::<a href="babel_key_value.md#type-t">babel_key_value:t()</a>, T::<a href="#type-t">t()</a>, Spec::<a href="#type-type_spec">type_spec()</a>) -&gt; NewT::<a href="#type-t">t()</a>
</code></pre>
<br />

Updates a map `T` with the provide key-value pairs `Values`.
If the value associated with a key `Key` in `Values` is equal to `undefined`
this equivalent to calling `remove(Key, Map)` with the difference that an
exception will not be raised in case the map had no context assigned.

<a name="validate_type_spec-1"></a>

### validate_type_spec/1 ###

<pre><code>
validate_type_spec(Spec::<a href="#type-type_spec">type_spec()</a>) -&gt; <a href="#type-type_spec">type_spec()</a> | no_return()
</code></pre>
<br />

<a name="value-1"></a>

### value/1 ###

<pre><code>
value(Map::<a href="#type-t">t()</a>) -&gt; map() | no_return()
</code></pre>
<br />

Returns an external representation of the map `Map` as an Erlang
map(). This is build recursively by calling the value/1 function on any
embedded datatype.
The call fails with a `{badmap, T}` exception if `T` is not a map.

