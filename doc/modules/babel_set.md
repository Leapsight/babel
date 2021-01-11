

# Module babel_set #
* [Data Types](#types)
* [Function Index](#index)
* [Function Details](#functions)

<a name="types"></a>

## Data Types ##


<a name="t()"></a>


### t() ###


__abstract datatype__: `t()`


<a name="type_spec()"></a>


### type_spec() ###


<pre><code>
type_spec() = atom | existing_atom | boolean | integer | float | binary | list | fun((encode, any()) -&gt; binary()) | fun((decode, binary()) -&gt; any())
</code></pre>


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
context(T::<a href="#type-t">t()</a>) -&gt; <a href="#type-babel_context">babel_context()</a>
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

!> **Important**. Notice that using this function might result in
incompatible types when later using a type specification e.g. [`to_riak_op/2`](#to_riak_op-2). We strongly suggest not using this function and using [`new/2`](#new-2) instead.

<a name="new-2"></a>

### new/2 ###

<pre><code>
new(Data::<a href="ordsets.md#type-ordset">ordsets:ordset</a>(any()), Type::<a href="#type-type_spec">type_spec()</a>) -&gt; <a href="#type-t">t()</a>
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
set_context(Ctxt::<a href="#type-babel_context">babel_context()</a>, T::<a href="#type-t">t()</a>) -&gt; NewT::<a href="#type-t">t()</a>
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

