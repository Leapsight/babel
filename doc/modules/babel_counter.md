

# Module babel_counter #
* [Description](#description)
* [Data Types](#types)
* [Function Index](#index)
* [Function Details](#functions)

Counters are a bucket-level data type that can be used by themselves,
associated with a bucket/key pair, or used within a [`babel_map`](babel_map.md).

<a name="description"></a>

## Description ##
A counter’s value can only be a positive integer, negative integer, or zero.
<a name="types"></a>

## Data Types ##




### <a name="type-t">t()</a> ###


__abstract datatype__: `t()`




### <a name="type-type_spec">type_spec()</a> ###


<pre><code>
type_spec() = integer
</code></pre>

<a name="index"></a>

## Function Index ##


<table width="100%" border="1" cellspacing="0" cellpadding="2" summary="function index"><tr><td valign="top"><a href="#context-1">context/1</a></td><td>Returns the Riak KV context.</td></tr><tr><td valign="top"><a href="#decrement-1">decrement/1</a></td><td>Decrements the counter by 1.</td></tr><tr><td valign="top"><a href="#decrement-2">decrement/2</a></td><td>Decrements the counter by amount <code>Amount</code>.</td></tr><tr><td valign="top"><a href="#from_riak_counter-2">from_riak_counter/2</a></td><td></td></tr><tr><td valign="top"><a href="#increment-1">increment/1</a></td><td>Increments the counter by 1.</td></tr><tr><td valign="top"><a href="#increment-2">increment/2</a></td><td>Increments the counter by amount <code>Amount</code>.</td></tr><tr><td valign="top"><a href="#is_type-1">is_type/1</a></td><td></td></tr><tr><td valign="top"><a href="#is_valid_type_spec-1">is_valid_type_spec/1</a></td><td></td></tr><tr><td valign="top"><a href="#new-0">new/0</a></td><td></td></tr><tr><td valign="top"><a href="#new-1">new/1</a></td><td></td></tr><tr><td valign="top"><a href="#original_value-1">original_value/1</a></td><td>Returns the original value of the counter.</td></tr><tr><td valign="top"><a href="#set-2">set/2</a></td><td>Increments or decrements the counter so that its resulting value would
be equal to <code>Amount</code>.</td></tr><tr><td valign="top"><a href="#set_context-2">set_context/2</a></td><td>
This has call has no effect and it is provided for compliance withe the
datatype interface.</td></tr><tr><td valign="top"><a href="#to_riak_op-2">to_riak_op/2</a></td><td></td></tr><tr><td valign="top"><a href="#type-0">type/0</a></td><td>Returns the symbolic name of this container.</td></tr><tr><td valign="top"><a href="#value-1">value/1</a></td><td>Returns the current value of the counter.</td></tr></table>


<a name="functions"></a>

## Function Details ##

<a name="context-1"></a>

### context/1 ###

<pre><code>
context(T::<a href="#type-t">t()</a>) -&gt; <a href="riakc_datatype.md#type-context">riakc_datatype:context()</a>
</code></pre>
<br />

Returns the Riak KV context

<a name="decrement-1"></a>

### decrement/1 ###

<pre><code>
decrement(Babel_counter::<a href="#type-t">t()</a>) -&gt; <a href="#type-t">t()</a>
</code></pre>
<br />

Decrements the counter by 1.

<a name="decrement-2"></a>

### decrement/2 ###

<pre><code>
decrement(Amount::integer(), Babel_counter::<a href="#type-t">t()</a>) -&gt; <a href="#type-t">t()</a>
</code></pre>
<br />

Decrements the counter by amount `Amount`.

<a name="from_riak_counter-2"></a>

### from_riak_counter/2 ###

<pre><code>
from_riak_counter(RiakCounter::<a href="riakc_counter.md#type-counter">riakc_counter:counter()</a> | integer, Type::integer) -&gt; <a href="#type-maybe_no_return">maybe_no_return</a>(<a href="#type-t">t()</a>)
</code></pre>
<br />

<a name="increment-1"></a>

### increment/1 ###

<pre><code>
increment(Babel_counter::<a href="#type-t">t()</a>) -&gt; <a href="#type-t">t()</a>
</code></pre>
<br />

Increments the counter by 1.

<a name="increment-2"></a>

### increment/2 ###

<pre><code>
increment(Amount::integer(), Babel_counter::<a href="#type-t">t()</a>) -&gt; <a href="#type-t">t()</a>
</code></pre>
<br />

Increments the counter by amount `Amount`.

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
new(Value::integer()) -&gt; <a href="#type-t">t()</a>
</code></pre>
<br />

<a name="original_value-1"></a>

### original_value/1 ###

<pre><code>
original_value(T::<a href="#type-t">t()</a>) -&gt; integer()
</code></pre>
<br />

Returns the original value of the counter.

<a name="set-2"></a>

### set/2 ###

<pre><code>
set(Amount::integer(), Babel_counter::<a href="#type-t">t()</a>) -&gt; <a href="#type-t">t()</a>
</code></pre>
<br />

Increments or decrements the counter so that its resulting value would
be equal to `Amount`.

<a name="set_context-2"></a>

### set_context/2 ###

<pre><code>
set_context(Ctxt::<a href="riakc_datatype.md#type-set_context">riakc_datatype:set_context()</a>, T::<a href="#type-t">t()</a>) -&gt; NewT::<a href="#type-t">t()</a>
</code></pre>
<br />

This has call has no effect and it is provided for compliance withe the
datatype interface.

<a name="to_riak_op-2"></a>

### to_riak_op/2 ###

<pre><code>
to_riak_op(Babel_counter::<a href="#type-t">t()</a>, X2::<a href="#type-type_spec">type_spec()</a>) -&gt; <a href="riakc_datatype.md#type-update">riakc_datatype:update</a>(<a href="riak_counter.md#type-coutner_op">riak_counter:coutner_op()</a>)
</code></pre>
<br />

<a name="type-0"></a>

### type/0 ###

<pre><code>
type() -&gt; counter
</code></pre>
<br />

Returns the symbolic name of this container.

<a name="value-1"></a>

### value/1 ###

<pre><code>
value(T::<a href="#type-t">t()</a>) -&gt; integer()
</code></pre>
<br />

Returns the current value of the counter.

