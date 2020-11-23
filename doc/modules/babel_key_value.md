

# Module babel_key_value #
* [Description](#description)
* [Data Types](#types)
* [Function Index](#index)
* [Function Details](#functions)

A Key Value coding interface for property lists and maps.

<a name="types"></a>

## Data Types ##


<a name="fold_fun()"></a>


### fold_fun() ###


<pre><code>
fold_fun() = fun((Key::<a href="#type-key">key()</a>, Value::any(), AccIn::any()) -&gt; AccOut::any())
</code></pre>


<a name="key()"></a>


### key() ###


<pre><code>
key() = atom() | binary() | tuple() | <a href="riakc_map.md#type-key">riakc_map:key()</a> | <a href="#type-path">path()</a>
</code></pre>


<a name="path()"></a>


### path() ###


<pre><code>
path() = [atom() | binary() | tuple() | <a href="riakc_map.md#type-key">riakc_map:key()</a>]
</code></pre>


<a name="t()"></a>


### t() ###


<pre><code>
t() = map() | [<a href="proplists.md#type-property">proplists:property()</a>] | <a href="babel_map.md#type-t">babel_map:t()</a> | <a href="riakc_map.md#type-crdt_map">riakc_map:crdt_map()</a>
</code></pre>


<a name="functions"></a>

## Function Details ##

<a name="collect-2"></a>

### collect/2 ###

<pre><code>
collect(Keys::[<a href="#type-key">key()</a>], KVTerm::<a href="#type-t">t()</a>) -&gt; [any()]
</code></pre>
<br />

<a name="collect-3"></a>

### collect/3 ###

<pre><code>
collect(Keys::[<a href="#type-key">key()</a>], KVTerm::<a href="#type-t">t()</a>, Default::any()) -&gt; [any()]
</code></pre>
<br />

<a name="fold-3"></a>

### fold/3 ###

<pre><code>
fold(Fun::<a href="#type-fold_fun">fold_fun()</a>, Acc::any(), KVTerm::<a href="#type-t">t()</a>) -&gt; NewAcc::any()
</code></pre>
<br />

<a name="get-2"></a>

### get/2 ###

<pre><code>
get(Key::<a href="#type-key">key()</a>, KVTerm::<a href="#type-t">t()</a>) -&gt; Value::term()
</code></pre>
<br />

Returns value `Value` associated with `Key` if `KVTerm` contains `Key`.
`Key` can be an atom, a binary or a path represented as a list of atoms and/
or binaries, or as a tuple of atoms and/or binaries.

The call fails with a {badarg, `KVTerm`} exception if `KVTerm` is not a
property list, map or Riak CRDT Map.
It also fails with a {badkey, `Key`} exception if no
value is associated with `Key`.

> In the case of Riak CRDT Maps a key MUST be a `riakc_map:key()`.

<a name="get-3"></a>

### get/3 ###

<pre><code>
get(Key::<a href="#type-key">key()</a>, KVTerm::<a href="#type-t">t()</a>, Default::term()) -&gt; term()
</code></pre>
<br />

<a name="put-3"></a>

### put/3 ###

<pre><code>
put(Key::<a href="#type-key">key()</a>, Value::any(), KVTerm::<a href="#type-t">t()</a>) -&gt; <a href="#type-t">t()</a>
</code></pre>
<br />

Equivalent to `set / 3`.

<a name="set-3"></a>

### set/3 ###

<pre><code>
set(Key::<a href="#type-key">key()</a>, Value::any(), KVTerm::<a href="#type-t">t()</a>) -&gt; <a href="#type-t">t()</a>
</code></pre>
<br />

