-include_lib("riakc/include/riakc.hrl").

-define(DEFAULT_REQ_TIMEOUT, 60000).
-define(DEFAULT_REQ_DEADLINE, 5 * ?DEFAULT_REQ_TIMEOUT).
%% Riak HTTP does not like the $/
-define(PATH_SEPARATOR, $-).
-define(KEY(Bucket), <<Bucket/binary, "idx">>).


%% =============================================================================
%% TYPES
%% =============================================================================


-type maybe_no_return(T)    ::  T | no_return().
-type maybe_error(T)        ::  T | {error, Reason :: any()}.
-type typed_bucket()        ::  bucket_and_type().
-type babel_context()       ::  riakc_datatype:context()
                                | undefined
                                | inherited.




%% =============================================================================
%% VALIDATION SPECS
%% =============================================================================



-define(RIAK_EC_TYPE, [non_neg_integer , {in, [one, all, quorum, default]}]).

-define(RIAK_GET_KEYS, [
    r,
    pr,
    if_modified,
    notfound_ok,
    n_val,
    basic_quorum,
    sloppy_quorum,
    head,
    deletedvclock,
    timeout
]).

-define(EXECUTE_OPTS_SPEC, #{
    connection_pool => #{
        required => true,
        allow_undefined => true,
        datatype => atom,
        default => undefined
    },
    connection => #{
        required => false,
        datatype => pid
    },
    deadline => #{
        required => false,
        datatype => pos_integer
    },
    timeout => #{
        required => false,
        datatype => pos_integer
    },
    max_retries => #{
        required => false,
        datatype => non_neg_integer
    },
    retry_backoff_interval_min => #{
        required => false,
        datatype => non_neg_integer
    },
    retry_backoff_interval_max => #{
        required => false,
        datatype => non_neg_integer
    },
    retry_backoff_type => #{
        required => false,
        datatype => {in, [jitter, normal]}
    },
    telemetry => #{
        required => false,
        validator => #{
            event_name => #{
                required => false,
                datatype => {list, [atom]}
            },
            event_metadata => #{
                required => false,
                datatype => map
            }
        }
    }

}).

-define(GET_OPTS_SPEC, (?EXECUTE_OPTS_SPEC)#{
    cache => #{
        required => false,
        allow_undefined => false,
        datatype => boolean
    },
    cache_force_refresh => #{
        required => false,
        allow_undefined => false,
        datatype => boolean
    },
    r => #{
        alias => <<"r">>,
        key => r,
        required => false,
        datatype => ?RIAK_EC_TYPE
    },
    pr => #{
        alias => <<"pr">>,
        key => pr,
        required => false,
        datatype => ?RIAK_EC_TYPE
    },
    %% The request will fail if the object has not changed
    if_modified => #{
        alias => <<"if_modified">>,
        key => if_modified,
        required => false,
        datatype => binary % riakc_obj:vclock()
    },
    notfound_ok => #{
        alias => <<"notfound_ok">>,
        key => notfound_ok,
        required => false,
        datatype => boolean
    },
    n_val => #{
        alias => <<"n_val">>,
        key => n_val,
        required => false,
        datatype => non_neg_integer
    },
    basic_quorum => #{
        alias => <<"basic_quorum">>,
        key => basic_quorum,
        required => false,
        datatype => boolean
    },
    sloppy_quorum => #{
        alias => <<"sloppy_quorum">>,
        key => sloppy_quorum,
        required => false,
        datatype => boolean
    },
    %% Returns only the metadata for the object
    head => #{
        alias => <<"head">>,
        key => head,
        required => false,
        datatype => boolean
    },
    %% The vector clock of the tombstone will be returned if the object has
    %% been recently deleted.
    deletedvclock => #{
        alias => <<"deletedvclock">>,
        key => deletedvclock,
        required => false,
        datatype => boolean
    },
    %% The timeout for a Riak request.
    timeout => #{
        alias => <<"timeout">>,
        key => timeout,
        required => true,
        default => ?DEFAULT_REQ_TIMEOUT,
        datatype => non_neg_integer
    }
}).


-define(RIAK_PUT_KEYS, [
    w,
    dw,
    pw,
    if_not_modified,
    if_none_match,
    notfound_ok,
    n_val,
    sloppy_quorum,
    return_body,
    return_head,
    timeout
]).


-define(PUT_OPTS_SPEC, (?EXECUTE_OPTS_SPEC)#{
    connection_pool => #{
        required => true,
        allow_undefined => true,
        datatype => atom,
        default => undefined
    },
    cache => #{
        required => false,
        allow_undefined => false,
        datatype => boolean
    },
    w => #{
        alias => <<"w">>,
        key => w,
        required => false,
        datatype => ?RIAK_EC_TYPE
    },
    dw => #{
        alias => <<"dw">>,
        key => dw,
        required => false,
        datatype => ?RIAK_EC_TYPE
    },
    pw => #{
        alias => <<"pw">>,
        key => pw,
        required => false,
        datatype => ?RIAK_EC_TYPE
    },
    %% Causes the request to fail if the local and remote vclocks do not match
    if_not_modified => #{
        alias => <<"if_not_modified">>,
        key => if_not_modified,
        required => false,
        datatype => boolean
    },
    %% Causes the request to fail if the object already exists in Riak
    if_none_match => #{
        alias => <<"if_none_match">>,
        key => if_none_match,
        required => false,
        datatype => boolean
    },
    notfound_ok => #{
        alias => <<"notfound_ok">>,
        key => notfound_ok,
        required => false,
        datatype => boolean
    },
    n_val => #{
        alias => <<"n_val">>,
        key => n_val,
        required => false,
        datatype => non_neg_integer
    },
    sloppy_quorum => #{
        alias => <<"sloppy_quorum">>,
        key => sloppy_quorum,
        required => false,
        datatype => boolean
    },
    %% Returns the entire result of storing the object
    return_body => #{
        alias => <<"return_body">>,
        key => return_body,
        required => false,
        datatype => boolean
    },
    %% Returns the metadata from the result of storing the object.
    return_head => #{
        alias => <<"return_head">>,
        key => return_head,
        required => false,
        datatype => boolean
    },
    timeout => #{
        alias => <<"timeout">>,
        key => timeout,
        description => <<
            "The timeout for a Riak request. The default is 5 secs."
        >>,
        required => true,
        default => ?DEFAULT_REQ_TIMEOUT,
        datatype => non_neg_integer
    }
}).


-define(RIAK_DELETE_KEYS, [
    r,
    pr,
    w,
    dw,
    pw,
    n_val,
    sloppy_quorum,
    timeout
]).


-define(DELETE_OPTS_SPEC, (?EXECUTE_OPTS_SPEC)#{
    connection_pool => #{
        required => true,
        allow_undefined => true,
        datatype => atom,
        default => undefined
    },
    r => #{
        alias => <<"r">>,
        key => r,
        required => false,
        datatype => ?RIAK_EC_TYPE
    },
    pr => #{
        alias => <<"pr">>,
        key => pr,
        required => false,
        datatype => ?RIAK_EC_TYPE
    },
    w => #{
        alias => <<"w">>,
        key => w,
        required => false,
        datatype => ?RIAK_EC_TYPE
    },
    dw => #{
        alias => <<"dw">>,
        key => dw,
        required => false,
        datatype => ?RIAK_EC_TYPE
    },
    pw => #{
        alias => <<"pw">>,
        key => pw,
        required => false,
        datatype => ?RIAK_EC_TYPE
    },
    n_val => #{
        alias => <<"n_val">>,
        key => n_val,
        required => false,
        datatype => non_neg_integer
    },
    sloppy_quorum => #{
        alias => <<"sloppy_quorum">>,
        key => sloppy_quorum,
        required => false,
        datatype => boolean
    },
    %% The timeout for a Riak request.
    timeout => #{
        alias => <<"timeout">>,
        key => timeout,
        required => true,
        default => ?DEFAULT_REQ_TIMEOUT,
        datatype => non_neg_integer
    }
}).
