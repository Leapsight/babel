

# Module babel_flag #
* [Description](#description)
* [Data Types](#types)
* [Function Index](#index)
* [Function Details](#functions)

Flags behave much like Boolean values, except that instead of true or
false flags have the values enable or disable.

<a name="description"></a>

## Description ##
Flags cannot be used on their own, i.e. a flag cannot be stored in a bucket/
key by itself. Instead, flags can only be stored within maps.
To disable an existing flag, you have to read it or provide a context.
<a name="types"></a>

## Data Types ##


<a name="t()"></a>


### t() ###


__abstract datatype__: `t()`


<a name="type_spec()"></a>


### type_spec() ###


<pre><code>
type_spec() = boolean
</code></pre>


<a name="functions"></a>

## Function Details ##

<a name="context-1"></a>

### context/1 ###

<pre><code>
context(T::<a href="#type-t">t()</a>) -&gt; <a href="riakc_datatype.md#type-context">riakc_datatype:context()</a>
</code></pre>
<br />

Returns the Riak KV context

<a name="disable-1"></a>

### disable/1 ###

<pre><code>
disable(Babel_flag::<a href="#type-t">t()</a>) -&gt; <a href="#type-t">t()</a>
</code></pre>
<br />

throws `context_required`

Disables the flag, setting its value to false.

<a name="enable-1"></a>

### enable/1 ###

<pre><code>
enable(Babel_flag::<a href="#type-t">t()</a>) -&gt; <a href="#type-t">t()</a>
</code></pre>
<br />

Enables the flag, setting its value to true.

<a name="from_riak_flag-3"></a>

### from_riak_flag/3 ###

<pre><code>
from_riak_flag(RiakFlag::<a href="riakc_flag.md#type-riakc_t">riakc_flag:riakc_t()</a> | boolean, Ctxt::<a href="riakc_datatype.md#type-context">riakc_datatype:context()</a>, Type::<a href="#type-type_spec">type_spec()</a>) -&gt; <a href="#type-maybe_no_return">maybe_no_return</a>(<a href="#type-t">t()</a>)
</code></pre>
<br />

<a name="is_type-1"></a>

### is_type/1 ###

<pre><code>
is_type(Term::any()) -&gt; boolean()
</code></pre>
<br />

<a name="is_valid_type_spec-1"></a>

### is_valid_type_spec/1 ###

<pre><code>
is_valid_type_spec(X1::term()) -&gt; boolean()
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
new(Value::boolean()) -&gt; <a href="#type-t">t()</a>
</code></pre>
<br />

<a name="new-2"></a>

### new/2 ###

<pre><code>
new(Value::boolean(), Ctxt::<a href="riakc_datatype.md#type-context">riakc_datatype:context()</a>) -&gt; <a href="#type-t">t()</a>
</code></pre>
<br />

<a name="original_value-1"></a>

### original_value/1 ###

<pre><code>
original_value(T::<a href="#type-t">t()</a>) -&gt; boolean()
</code></pre>
<br />

Returns the original value of the flag.

<a name="set-2"></a>

### set/2 ###

<pre><code>
set(X1::boolean(), T::<a href="#type-t">t()</a>) -&gt; <a href="#type-t">t()</a>
</code></pre>
<br />

<a name="set_context-2"></a>

### set_context/2 ###

<pre><code>
set_context(Ctxt::<a href="riakc_datatype.md#type-set_context">riakc_datatype:set_context()</a>, T::<a href="#type-t">t()</a>) -&gt; NewT::<a href="#type-t">t()</a>
</code></pre>
<br />

Sets the context `Ctxt`.

<a name="to_riak_op-2"></a>

### to_riak_op/2 ###

<pre><code>
to_riak_op(Babel_flag::<a href="#type-t">t()</a>, X2::<a href="#type-type_spec">type_spec()</a>) -&gt; <a href="riakc_datatype.md#type-update">riakc_datatype:update</a>(<a href="riak_flag.md#type-flag_op">riak_flag:flag_op()</a>)
</code></pre>
<br />

<a name="type-0"></a>

### type/0 ###

<pre><code>
type() -&gt; flag
</code></pre>
<br />

Returns the symbolic name of this container.

<a name="value-1"></a>

### value/1 ###

<pre><code>
value(T::<a href="#type-t">t()</a>) -&gt; boolean()
</code></pre>
<br />

Returns the current value of the flag.

