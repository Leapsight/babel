

# Module babel_crdt #
* [Function Index](#index)
* [Function Details](#functions)

<a name="index"></a>

## Function Index ##


<table width="100%" border="1" cellspacing="0" cellpadding="2" summary="function index"><tr><td valign="top"><a href="#dirty_fetch-2">dirty_fetch/2</a></td><td>Returns the "unwrapped" value associated with the key in the
map.</td></tr><tr><td valign="top"><a href="#dirty_fetch_keys-1">dirty_fetch_keys/1</a></td><td></td></tr><tr><td valign="top"><a href="#map_entry-3">map_entry/3</a></td><td></td></tr><tr><td valign="top"><a href="#register_to_atom-2">register_to_atom/2</a></td><td></td></tr><tr><td valign="top"><a href="#register_to_binary-1">register_to_binary/1</a></td><td></td></tr><tr><td valign="top"><a href="#register_to_existing_atom-2">register_to_existing_atom/2</a></td><td></td></tr><tr><td valign="top"><a href="#register_to_integer-1">register_to_integer/1</a></td><td></td></tr><tr><td valign="top"><a href="#register_to_integer-2">register_to_integer/2</a></td><td></td></tr><tr><td valign="top"><a href="#register_to_term-1">register_to_term/1</a></td><td></td></tr><tr><td valign="top"><a href="#to_integer-1">to_integer/1</a></td><td></td></tr></table>


<a name="functions"></a>

## Function Details ##

<a name="dirty_fetch-2"></a>

### dirty_fetch/2 ###

<pre><code>
dirty_fetch(Key::<a href="riakc_map.md#type-key">riakc_map:key()</a>, Map::<a href="riakc_map.md#type-crdt_map">riakc_map:crdt_map()</a>) -&gt; term()
</code></pre>
<br />

Returns the "unwrapped" value associated with the key in the
map. As opposed to riakc_map:fetch/2 this function searches for the key in
the removed and updated private structures of the map first. If the key was
found on the removed set, fails with a `removed` exception. If they key was
in the updated set, it returns the updated value otherwise calls
riakc_map:fetch/2.

<a name="dirty_fetch_keys-1"></a>

### dirty_fetch_keys/1 ###

<pre><code>
dirty_fetch_keys(Map::<a href="riakc_map.md#type-crdt_map">riakc_map:crdt_map()</a>) -&gt; [<a href="riakc_map.md#type-key">riakc_map:key()</a>]
</code></pre>
<br />

<a name="map_entry-3"></a>

### map_entry/3 ###

<pre><code>
map_entry(Type::<a href="riakc_datatype.md#type-typename">riakc_datatype:typename()</a>, Field::binary(), Value::binary() | list()) -&gt; <a href="riakc_map.md#type-raw_entry">riakc_map:raw_entry()</a>
</code></pre>
<br />

<a name="register_to_atom-2"></a>

### register_to_atom/2 ###

<pre><code>
register_to_atom(Unwrapped::<a href="riakc_register.md#type-register">riakc_register:register()</a> | binary(), Encoding::latin1 | unicode | utf8) -&gt; atom() | no_return()
</code></pre>
<br />

<a name="register_to_binary-1"></a>

### register_to_binary/1 ###

<pre><code>
register_to_binary(Unwrapped::<a href="riakc_register.md#type-register">riakc_register:register()</a> | binary()) -&gt; binary() | no_return()
</code></pre>
<br />

<a name="register_to_existing_atom-2"></a>

### register_to_existing_atom/2 ###

<pre><code>
register_to_existing_atom(Unwrapped::<a href="riakc_register.md#type-register">riakc_register:register()</a> | binary(), Encoding::latin1 | unicode | utf8) -&gt; atom() | no_return()
</code></pre>
<br />

<a name="register_to_integer-1"></a>

### register_to_integer/1 ###

<pre><code>
register_to_integer(Unwrapped::<a href="riakc_register.md#type-register">riakc_register:register()</a> | binary()) -&gt; integer() | no_return()
</code></pre>
<br />

<a name="register_to_integer-2"></a>

### register_to_integer/2 ###

<pre><code>
register_to_integer(Unwrapped::<a href="riakc_register.md#type-register">riakc_register:register()</a> | binary(), Base::2..36) -&gt; integer() | no_return()
</code></pre>
<br />

<a name="register_to_term-1"></a>

### register_to_term/1 ###

<pre><code>
register_to_term(Unwrapped::<a href="riakc_register.md#type-register">riakc_register:register()</a> | binary()) -&gt; term() | no_return()
</code></pre>
<br />

<a name="to_integer-1"></a>

### to_integer/1 ###

<pre><code>
to_integer(Unwrapped::binary() | <a href="riakc_register.md#type-register">riakc_register:register()</a> | <a href="riakc_counter.md#type-counter">riakc_counter:counter()</a>) -&gt; <a href="#type-maybe_no_return">maybe_no_return</a>(integer())
</code></pre>
<br />

