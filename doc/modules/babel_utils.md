

# Module babel_utils #
* [Data Types](#types)
* [Function Index](#index)
* [Function Details](#functions)

<a name="types"></a>

## Data Types ##




### <a name="type-type">type()</a> ###


<pre><code>
type() = atom | existing_atom | boolean | integer | float | binary | list
</code></pre>

<a name="index"></a>

## Function Index ##


<table width="100%" border="1" cellspacing="0" cellpadding="2" summary="function index"><tr><td valign="top"><a href="#from_binary-2">from_binary/2</a></td><td></td></tr><tr><td valign="top"><a href="#opts_to_riak_opts-1">opts_to_riak_opts/1</a></td><td></td></tr><tr><td valign="top"><a href="#to_binary-2">to_binary/2</a></td><td></td></tr></table>


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

