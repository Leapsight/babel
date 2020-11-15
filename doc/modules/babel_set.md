

# Module babel_set #
* [Data Types](#types)
* [Function Index](#index)
* [Function Details](#functions)

<a name="types"></a>

## Data Types ##




### <a name="type-t">t()</a> ###


__abstract datatype__: `t()`




### <a name="type-type_spec">type_spec()</a> ###


<pre><code>
type_spec() = atom | existing_atom | boolean | integer | float | binary | list | fun((encode, any()) -&gt; binary()) | fun((decode, binary()) -&gt; any())
</code></pre>

<a name="index"></a>

## Function Index ##


<table width="100%" border="1" cellspacing="0" cellpadding="2" summary="function index"><tr><td valign="top"><a href="#add_element-2">add_element/2</a></td><td>Adds an element to the set.</td></tr><tr><td valign="top"><a href="#add_elements-2">add_elements/2</a></td><td></td></tr><tr><td valign="top"><a href="#context-1">context/1</a></td><td>Returns the Riak KV context.</td></tr><tr><td valign="top"><a href="#del_element-2">del_element/2</a></td><td>Removes an element from the set.</td></tr><tr><td valign="top"><a href="#del_elements-2">del_elements/2</a></td><td>Removes an element from the set.</td></tr><tr><td valign="top"><a href="#fold-3">fold/3</a></td><td>Folds over the members of the set.</td></tr><tr><td valign="top"><a href="#from_riak_set-2">from_riak_set/2</a></td><td></td></tr><tr><td valign="top"><a href="#from_riak_set-3">from_riak_set/3</a></td><td>Overrides context.</td></tr><tr><td valign="top"><a href="#is_element-2">is_element/2</a></td><td>Test whether an element is a member of the set.</td></tr><tr><td valign="top"><a href="#is_original_element-2">is_original_element/2</a></td><td>Test whether an element is a member of the original set i,e.</td></tr><tr><td valign="top"><a href="#is_type-1">is_type/1</a></td><td></td></tr><tr><td valign="top"><a href="#is_valid_type_spec-1">is_valid_type_spec/1</a></td><td></td></tr><tr><td valign="top"><a href="#new-0">new/0</a></td><td></td></tr><tr><td valign="top"><a href="#new-1">new/1</a></td><td></td></tr><tr><td valign="top"><a href="#new-2">new/2</a></td><td></td></tr><tr><td valign="top"><a href="#original_value-1">original_value/1</a></td><td>Returns the original value of the set as an ordset.</td></tr><tr><td valign="top"><a href="#set_context-2">set_context/2</a></td><td>Sets the context <code>Ctxt</code>.</td></tr><tr><td valign="top"><a href="#set_elements-2">set_elements/2</a></td><td></td></tr><tr><td valign="top"><a href="#size-1">size/1</a></td><td>Returns the cardinality (size) of the set.</td></tr><tr><td valign="top"><a href="#to_riak_op-2">to_riak_op/2</a></td><td></td></tr><tr><td valign="top"><a href="#type-0">type/0</a></td><td>Returns the symbolic name of this container.</td></tr><tr><td valign="top"><a href="#value-1">value/1</a></td><td>Returns the current value of the set.</td></tr></table>


<a name="functions"></a>

## Function Details ##

<a name="add_element-2"></a>

### add_element/2 ###

<pre><code>
add_element(Element::any(), T::<a href="#type-t">t()</a>) -&gt; <a href="#type-t">t()</a>
</code></pre>
<br />

Adds an element to the set.
You may add an element that already exists in the original set
value, but it does not count for the object's size calculation. Adding an
element that already exists is non-intuitive, but acts as a safety feature: a
client code path that requires an element to be present in the set
(or removed) can ensure that intended state by applying an
operation.

<a name="add_elements-2"></a>

### add_elements/2 ###

<pre><code>
add_elements(Elements::[any()], T::<a href="#type-t">t()</a>) -&gt; <a href="#type-t">t()</a>
</code></pre>
<br />

<a name="context-1"></a>

### context/1 ###

<pre><code>
context(T::<a href="#type-t">t()</a>) -&gt; <a href="riakc_datatype.md#type-context">riakc_datatype:context()</a>
</code></pre>
<br />

Returns the Riak KV context

<a name="del_element-2"></a>

### del_element/2 ###

<pre><code>
del_element(Element::any(), T::<a href="#type-t">t()</a>) -&gt; <a href="#type-t">t()</a> | no_return()
</code></pre>
<br />

throws `context_required`

Removes an element from the set.
You may remove an element that does not appear in the original
set value. This is non-intuitive, but acts as a safety feature: a
client code path that requires an element to be present in the set
(or removed) can ensure that intended state by applying an
operation.

<a name="del_elements-2"></a>

### del_elements/2 ###

<pre><code>
del_elements(Elements::[any()], T::<a href="#type-t">t()</a>) -&gt; <a href="#type-t">t()</a> | no_return()
</code></pre>
<br />

throws `context_required`

Removes an element from the set.
You may remove an element that does not appear in the original
set value. This is non-intuitive, but acts as a safety feature: a
client code path that requires an element to be present in the set
(or removed) can ensure that intended state by applying an
operation.

<a name="fold-3"></a>

### fold/3 ###

<pre><code>
fold(Fun::fun((term(), term()) -&gt; term()), Acc::term(), T::<a href="#type-t">t()</a>) -&gt; Acc::term()
</code></pre>
<br />

Folds over the members of the set.

<a name="from_riak_set-2"></a>

### from_riak_set/2 ###

<pre><code>
from_riak_set(RiakSet::<a href="riakc_set.md#type-riakc_set">riakc_set:riakc_set()</a> | <a href="ordsets.md#type-ordset">ordsets:ordset()</a>, Type::<a href="#type-type_spec">type_spec()</a>) -&gt; <a href="#type-maybe_no_return">maybe_no_return</a>(<a href="#type-t">t()</a>)
</code></pre>
<br />

throws `{badindex, term()}`

<a name="from_riak_set-3"></a>

### from_riak_set/3 ###

<pre><code>
from_riak_set(RiakSet::<a href="riakc_set.md#type-riakc_set">riakc_set:riakc_set()</a> | <a href="ordsets.md#type-ordset">ordsets:ordset()</a>, Ctxt::<a href="riakc_datatype.md#type-context">riakc_datatype:context()</a>, Type::<a href="#type-type_spec">type_spec()</a>) -&gt; <a href="#type-maybe_no_return">maybe_no_return</a>(<a href="#type-t">t()</a>)
</code></pre>
<br />

throws `{badindex, term()}`

Overrides context

<a name="is_element-2"></a>

### is_element/2 ###

<pre><code>
is_element(Element::binary(), Babel_set::<a href="#type-t">t()</a>) -&gt; boolean()
</code></pre>
<br />

Test whether an element is a member of the set.

<a name="is_original_element-2"></a>

### is_original_element/2 ###

<pre><code>
is_original_element(Element::binary(), Babel_set::<a href="#type-t">t()</a>) -&gt; boolean()
</code></pre>
<br />

Test whether an element is a member of the original set i,e. the one
retrieved from Riak.

<a name="is_type-1"></a>

### is_type/1 ###

<pre><code>
is_type(Term::any()) -&gt; boolean()
</code></pre>
<br />

<a name="is_valid_type_spec-1"></a>

### is_valid_type_spec/1 ###

<pre><code>
is_valid_type_spec(Fun::term()) -&gt; boolean()
</code></pre>
<br />

<a name="new-0"></a>

### new/0 ###

<pre><code>
new() -&gt; <a href="#type-t">t()</a>
</code></pre>
<br />

<a name="new-1"></a>

### new/1 ###

<pre><code>
new(Data::<a href="ordsets.md#type-ordset">ordsets:ordset</a>(any())) -&gt; <a href="#type-t">t()</a>
</code></pre>
<br />

<a name="new-2"></a>

### new/2 ###

<pre><code>
new(Data::<a href="ordsets.md#type-ordset">ordsets:ordset</a>(any()), Ctxt::<a href="riakc_datatype.md#type-context">riakc_datatype:context()</a>) -&gt; <a href="#type-t">t()</a>
</code></pre>
<br />

<a name="original_value-1"></a>

### original_value/1 ###

<pre><code>
original_value(Babel_set::<a href="#type-t">t()</a>) -&gt; <a href="ordsets.md#type-ordset">ordsets:ordset</a>(any())
</code></pre>
<br />

Returns the original value of the set as an ordset.
This is equivalent to riakc_set:value/1 but where the elements are binaries
but of the type defined by the conversion `spec()` used to create the set.

<a name="set_context-2"></a>

### set_context/2 ###

<pre><code>
set_context(Ctxt::<a href="riakc_datatype.md#type-set_context">riakc_datatype:set_context()</a>, T::<a href="#type-t">t()</a>) -&gt; NewT::<a href="#type-t">t()</a>
</code></pre>
<br />

Sets the context `Ctxt`.

<a name="set_elements-2"></a>

### set_elements/2 ###

<pre><code>
set_elements(Elements::[any()], T::<a href="#type-t">t()</a>) -&gt; NewT::<a href="#type-t">t()</a>
</code></pre>
<br />

<a name="size-1"></a>

### size/1 ###

<pre><code>
size(T::<a href="#type-t">t()</a>) -&gt; pos_integer()
</code></pre>
<br />

Returns the cardinality (size) of the set.

<a name="to_riak_op-2"></a>

### to_riak_op/2 ###

<pre><code>
to_riak_op(T::<a href="#type-t">t()</a>, Type::<a href="#type-type_spec">type_spec()</a>) -&gt; <a href="riakc_datatype.md#type-update">riakc_datatype:update</a>(<a href="riakc_set.md#type-set_op">riakc_set:set_op()</a>)
</code></pre>
<br />

<a name="type-0"></a>

### type/0 ###

<pre><code>
type() -&gt; set
</code></pre>
<br />

Returns the symbolic name of this container.

<a name="value-1"></a>

### value/1 ###

<pre><code>
value(T::<a href="#type-t">t()</a>) -&gt; <a href="ordsets.md#type-ordset">ordsets:ordset</a>(any())
</code></pre>
<br />

Returns the current value of the set.

