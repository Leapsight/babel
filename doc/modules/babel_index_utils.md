

# Module babel_index_utils #
* [Description](#description)
* [Function Index](#index)
* [Function Details](#functions)

A collection of utility functions used by the different index type
implementations.

<a name="description"></a>

## Description ##

<a name="functions"></a>

## Function Details ##

<a name="build_output-2"></a>

### build_output/2 ###

<pre><code>
build_output(Keys::[<a href="babel_key_value.md#type-key">babel_key_value:key()</a>], Bin::binary() | undefined) -&gt; map()
</code></pre>
<br />

<a name="build_output-3"></a>

### build_output/3 ###

<pre><code>
build_output(Keys::[<a href="babel_key_value.md#type-key">babel_key_value:key()</a>], Bin::binary() | undefined, Acc::map()) -&gt; map()
</code></pre>
<br />

<a name="gen_key-3"></a>

### gen_key/3 ###

<pre><code>
gen_key(Keys::[<a href="babel_key_value.md#type-key">babel_key_value:key()</a>], Data::binary(), X3::map()) -&gt; binary()
</code></pre>
<br />

Collects keys `Keys` from key value data `Data` and joins them using a
separator.
We do this as Riak does not support list and sets are ordered.

<a name="safe_gen_key-3"></a>

### safe_gen_key/3 ###

<pre><code>
safe_gen_key(Keys::[<a href="babel_key_value.md#type-key">babel_key_value:key()</a>], Data::binary(), Config::map()) -&gt; binary()
</code></pre>
<br />

Collects keys `Keys` from key value data `Data` and joins them using a
separator.
We do this as Riak does not support list and sets are ordered.
The diff between this function and gen_key/2 is that this one catches
exceptions and returns a value.

