-include_lib("riakc/include/riakc.hrl").

-define(DEFAULT_REQ_TIMEOUT, 5000).
-define(DEFAULT_REQ_DEADLINE, 5 * 60 * 1000).
%% We use the ASCII unit separator ($\31) which was designed to separate
%% fields of a record.
-define(PATH_SEPARATOR, $/).
-define(KEY(Bucket), <<Bucket/binary, "_idx">>).




%% =============================================================================
%% UTILS
%% =============================================================================



-define(RIAK_EC_TYPE, [non_neg_integer , {in, [one, all, quorum, default]}]).
-define(RIAK_OPTS_SPEC, #{
    connection => #{
        required => true,
        datatype => [pid, function]
    },
    n_val => #{
        alias => <<"n_val">>,
        key => n_val,
        required => false,
        allow_null => false,
        allow_undefined => false,
        datatype => non_neg_integer
    },
    r => #{
        alias => <<"r">>,
        key => r,
        required => false,
        allow_null => false,
        allow_undefined => false,
        datatype => ?RIAK_EC_TYPE
    },
    w => #{
        alias => <<"w">>,
        key => w,
        required => false,
        allow_null => false,
        allow_undefined => false,
        datatype => ?RIAK_EC_TYPE
    },
    dw => #{
        alias => <<"dw">>,
        key => dw,
        required => false,
        allow_null => false,
        allow_undefined => false,
        datatype => ?RIAK_EC_TYPE
    },
    pr => #{
        alias => <<"pr">>,
        key => pr,
        required => false,
        allow_null => false,
        allow_undefined => false,
        datatype => ?RIAK_EC_TYPE
    },
    pw => #{
        alias => <<"pw">>,
        key => pw,
        required => false,
        allow_null => false,
        allow_undefined => false,
        datatype => ?RIAK_EC_TYPE
    },
    rw => #{
        alias => <<"rw">>,
        key => rw,
        required => false,
        allow_null => false,
        allow_undefined => false,
        datatype => ?RIAK_EC_TYPE
    },
    notfound_ok => #{
        alias => <<"notfound_ok">>,
        key => notfound_ok,
        required => false,
        allow_null => false,
        allow_undefined => false,
        datatype => boolean
    },
    basic_quorum => #{
        alias => <<"basic_quorum">>,
        key => basic_quorum,
        required => false,
        allow_null => false,
        allow_undefined => false,
        datatype => boolean
    },
    sloppy_quorum => #{
        alias => <<"sloppy_quorum">>,
        key => sloppy_quorum,
        required => false,
        allow_null => false,
        allow_undefined => false,
        datatype => boolean
    },
    return_body => #{
        alias => <<"return_body">>,
        key => return_body,
        required => false,
        datatype => boolean
    },
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
        datatype => timeout
    }
}).

-type riak_opts()   :: #{
    connection := pid() | fun(() -> pid()),
    r => quorum(),
    pr => quorum(),
    w => quorum(),
    dw => quorum(),
    pw => quorum(),
    notfound_ok => boolean(),
    basic_quorum => boolean(),
    sloppy_quorum => boolean(),
    timeout => timeout(),
    return_body => boolean(),
    '$validated' => boolean()
}.




%% =============================================================================
%% TYPES
%% =============================================================================


-type maybe_no_return(T)    ::  T | no_return().
-type maybe_error(T)        ::  T | {error, Reason :: any()}.
-type typed_bucket()        ::  bucket_and_type().