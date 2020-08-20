

# Module babel_manager #
* [Data Types](#types)
* [Function Index](#index)
* [Function Details](#functions)

__Behaviours:__ [`gen_server`](gen_server.md).

<a name="types"></a>

## Data Types ##




### <a name="type-info">info()</a> ###


<pre><code>
info() = #{connection =&gt; #{host =&gt; list(), port =&gt; integer()}, options =&gt; map(), bucket_type =&gt; atom(), bucket =&gt; atom(), start_ts =&gt; non_neg_integer(), end_ts =&gt; non_neg_integer() | undefined, succeded_count =&gt; integer(), failed_count =&gt; integer(), total_count =&gt; integer(), status =&gt; in_progress | finished | failed | canceled}
</code></pre>

<a name="index"></a>

## Function Index ##


<table width="100%" border="1" cellspacing="0" cellpadding="2" summary="function index"><tr><td valign="top"><a href="#cancel-0">cancel/0</a></td><td></td></tr><tr><td valign="top"><a href="#code_change-3">code_change/3</a></td><td></td></tr><tr><td valign="top"><a href="#handle_call-3">handle_call/3</a></td><td></td></tr><tr><td valign="top"><a href="#handle_cast-2">handle_cast/2</a></td><td></td></tr><tr><td valign="top"><a href="#handle_info-2">handle_info/2</a></td><td></td></tr><tr><td valign="top"><a href="#info-0">info/0</a></td><td></td></tr><tr><td valign="top"><a href="#init-1">init/1</a></td><td></td></tr><tr><td valign="top"><a href="#rebuild_index-1">rebuild_index/1</a></td><td>
<code>things_service_index_manager:rebuild_index(<<"mrn:agent:f5a1...">>).</code></td></tr><tr><td valign="top"><a href="#rebuild_index-2">rebuild_index/2</a></td><td>
<pre>  things_service_index_manager:rebuild_index(
      <<"mrn:agent:f5a1...">>, #{pr => 1, pw => 3}
  ).</pre></td></tr><tr><td valign="top"><a href="#rebuild_indices-0">rebuild_indices/0</a></td><td>
<pre>  things_service_index_manager:rebuild_indices(
      #{pr => 1, pw => 3, backoff_every => 100, backoff_delay => 50}
  ).</pre></td></tr><tr><td valign="top"><a href="#rebuild_indices-1">rebuild_indices/1</a></td><td>Do not run this function.</td></tr><tr><td valign="top"><a href="#start_link-0">start_link/0</a></td><td></td></tr><tr><td valign="top"><a href="#terminate-2">terminate/2</a></td><td></td></tr></table>


<a name="functions"></a>

## Function Details ##

<a name="cancel-0"></a>

### cancel/0 ###

<pre><code>
cancel() -&gt; undefined | <a href="#type-info">info()</a>
</code></pre>
<br />

<a name="code_change-3"></a>

### code_change/3 ###

`code_change(OldVsn, State, Extra) -> any()`

<a name="handle_call-3"></a>

### handle_call/3 ###

`handle_call(X1, From, St0) -> any()`

<a name="handle_cast-2"></a>

### handle_cast/2 ###

`handle_cast(Event, State) -> any()`

<a name="handle_info-2"></a>

### handle_info/2 ###

`handle_info(Info, State) -> any()`

<a name="info-0"></a>

### info/0 ###

<pre><code>
info() -&gt; undefined | <a href="#type-info">info()</a>
</code></pre>
<br />

<a name="init-1"></a>

### init/1 ###

`init(X1) -> any()`

<a name="rebuild_index-1"></a>

### rebuild_index/1 ###

<pre><code>
rebuild_index(Key::binary()) -&gt; ok | {error, any()}
</code></pre>
<br />

`things_service_index_manager:rebuild_index(<<"mrn:agent:f5a1...">>).`

<a name="rebuild_index-2"></a>

### rebuild_index/2 ###

<pre><code>
rebuild_index(Key::binary(), Opts::map()) -&gt; ok | {error, any()}
</code></pre>
<br />


```
  things_service_index_manager:rebuild_index(
      <<"mrn:agent:f5a1...">>, #{pr => 1, pw => 3}
  ).
```

<a name="rebuild_indices-0"></a>

### rebuild_indices/0 ###

<pre><code>
rebuild_indices() -&gt; ok | {error, {in_progress, <a href="#type-info">info()</a>}} | {error, any()}
</code></pre>
<br />


```
  things_service_index_manager:rebuild_indices(
      #{pr => 1, pw => 3, backoff_every => 100, backoff_delay => 50}
  ).
```

<a name="rebuild_indices-1"></a>

### rebuild_indices/1 ###

<pre><code>
rebuild_indices(Opts::map()) -&gt; ok | {error, any()}
</code></pre>
<br />

Do not run this function

<a name="start_link-0"></a>

### start_link/0 ###

`start_link() -> any()`

<a name="terminate-2"></a>

### terminate/2 ###

`terminate(Reason, State) -> any()`

