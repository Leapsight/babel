

# Module riakc_pool #
* [Data Types](#types)
* [Function Index](#index)
* [Function Details](#functions)

<a name="types"></a>

## Data Types ##




### <a name="type-connection">connection()</a> ###


<pre><code>
connection() = <a href="riakc_pb_socket.md#type-riakc_pb_socket">riakc_pb_socket:riakc_pb_socket()</a>
</code></pre>

<a name="index"></a>

## Function Index ##


<table width="100%" border="1" cellspacing="0" cellpadding="2" summary="function index"><tr><td valign="top"><a href="#get_connection-1">get_connection/1</a></td><td></td></tr><tr><td valign="top"><a href="#get_connection-2">get_connection/2</a></td><td></td></tr><tr><td valign="top"><a href="#get_connection-3">get_connection/3</a></td><td></td></tr><tr><td valign="top"><a href="#start-1">start/1</a></td><td></td></tr><tr><td valign="top"><a href="#stop-0">stop/0</a></td><td></td></tr></table>


<a name="functions"></a>

## Function Details ##

<a name="get_connection-1"></a>

### get_connection/1 ###

<pre><code>
get_connection(Pool::atom()) -&gt; <a href="#type-connection">connection()</a> | {error, timeout}
</code></pre>
<br />

<a name="get_connection-2"></a>

### get_connection/2 ###

<pre><code>
get_connection(Pool::atom(), Timeout::timeout()) -&gt; <a href="#type-connection">connection()</a> | {error, timeout}
</code></pre>
<br />

<a name="get_connection-3"></a>

### get_connection/3 ###

`get_connection(PoolName, Timeout, Retries) -> any()`

<a name="start-1"></a>

### start/1 ###

`start(Opts) -> any()`

<a name="stop-0"></a>

### stop/0 ###

`stop() -> any()`

