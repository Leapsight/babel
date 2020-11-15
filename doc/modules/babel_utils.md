

# Module babel_utils #
* [Data Types](#types)
* [Function Index](#index)
* [Function Details](#functions)

<a name="types"></a>

## Data Types ##


<a name="type()"></a>


### type() ###


<pre><code>
type() = atom | existing_atom | boolean | integer | float | binary | list
</code></pre>


<a name="functions"></a>

## Function Details ##

<a name="from_binary-2"></a>

### from_binary/2 ###

<pre><code>
from_binary(Value::binary(), Type::<a href="#type-type">type()</a>) -&gt; any()
</code></pre>
<br />

<a name="opts_to_riak_opts-1"></a>

### opts_to_riak_opts/1 ###

<pre><code>
opts_to_riak_opts(Opts::map()) -&gt; list()
</code></pre>
<br />

<a name="to_binary-2"></a>

### to_binary/2 ###

<pre><code>
to_binary(Value::any(), Fun::<a href="#type-type">type()</a>) -&gt; binary()
</code></pre>
<br />

