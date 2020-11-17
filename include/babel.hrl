-include_lib("riakc/include/riakc.hrl").

-define(DEFAULT_REQ_TIMEOUT, 5000).
-define(DEFAULT_REQ_DEADLINE, 5 * 60 * 1000).
%% Riak HTTP does not like the $/
-define(PATH_SEPARATOR, $-).
-define(KEY(Bucket), <<Bucket/binary, "idx">>).




%% =============================================================================
%% TYPES
%% =============================================================================


-type maybe_no_return(T)    ::  T | no_return().
-type maybe_error(T)        ::  T | {error, Reason :: any()}.
-type typed_bucket()        ::  bucket_and_type().