
{ok, Conn} = riakc_pb_socket:start_link("127.0.0.1", 8087).
pong = riakc_pb_socket:ping(Conn).
RiakOpts = #{connection => Conn}.
Collection = babel_index_collection:fetch(<<"mytenant">>, <<"users">>, RiakOpts).
Index = babel_index_collection:index(<<"users_by_post_code_and_email">>, Collection).
Pattern1 = #{{<<"post_code">>, register} => <<"PC1">>}.
babel_index:match(Pattern1, Index, RiakOpts).

element(1, timer:tc(babel_index, match, [Pattern1, Index, RiakOpts])) / 1000.

Pattern2 = #{
    {<<"post_code">>, register} => <<"PC1">>,
    {<<"email">>, register} => <<"1@example.com">>
}.
babel_index:match(Pattern2, Index, RiakOpts).

%% Time in secs
element(1, timer:tc(babel_index, match, [Pattern2, Index, RiakOpts])) / 1000.