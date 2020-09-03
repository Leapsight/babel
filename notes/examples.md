# Users By Email


## Example 1 - Simple case

```erlang
Conf = #{
    id => <<"users_by_email">>,
    bucket_type => <<"map">>,
    bucket => <<"lojack/johndoe/index_data">>,
    type => babel_hash_partitioned_index,
    config => #{
        sort_ordering => asc,
        number_of_partitions => 8,
        partition_algorithm => jch,
        partition_by => [{<<"email">>, register}],
        index_by => [{<<"email">>, register}],
        covered_fields => [{<<"user_id">>, register}]
    }
}.
```

This will produce an index partition equivalent(*) to the following Erlang term.

```erlang
#{
    meta => #{},
    data => #{{<<"johndoe@example.com">>, register} => <<"mrn:user:...">>}
}
```

(*) This is not the actual representation as we will use RIAK KV CRDT datatypes, but it would be the case if we implemented a function to represent the CRDT in erlang terms.

Then:

```erlang
> babel_index:match(<<"johndoe@example.com">>, Index, Opts).
#{<<"user_id">>> => <<"mrn:user:...">>}
```

## Example 2 - Covering multiple fields

```erlang
Index = #{
    id => <<"users_by_email">>,
    bucket_type => <<"map">>,
    bucket => <<"lojack/johndoe/index_data">>,
    type => babel_hash_partitioned_index,
    config => #{
        sort_ordering => asc,
        number_of_partitions => 8,
        partition_algorithm => jch,
        partition_by => [email],
        index_by => [email],
        covered_fields => [user_id, account_id]
    }
}.
```

This will produce an index partition equivalent(*) to the following Erlang term.

```erlang
#{
    meta => #{},
    data => #{
        {<<"johndoe@example.com">>, register} => {<<"mrn:user:...">>,  <<"mrn:account:...">>}
    }
}
```

Then:

```erlang
> babel_index:match(<<"johndoe@example.com">>, Index, Opts).
#{
    <<"user_id">>> => <<"mrn:user:...">>,
    <<"account_id">> =>  <<"mrn:account:...">>
}
```

## Case 3 - Aggregate By

If we wanted to supported multiple users per email i.e. a person can be a usr in multiple accounts using the same email then we need to use the `aggregate_by` option.


```erlang
Index = #{
    id => <<"users_by_email">>,
    bucket_type => <<"map">>,
    bucket => <<"lojack/johndoe/index_data">>,
    type => babel_hash_partitioned_index,
    config => #{
        sort_ordering => asc,
        number_of_partitions => 8,
        partition_algorithm => jch,
        partition_by => [email],
        index_by => [email],
        aggregate_by => [email],
        covered_fields => [user_id]
    }
}.
```

This will produce an index partition that looks like the following

```erlang
#{
    meta => #{},
    data => #{
        {<<"johndoe@example.com">>, register} => [
            <<"mrn:user:..X">>,
            <<"mrn:user:..Y">>
        ]
    }
}
```

Then:

```erlang
> babel_index:match(<<"johndoe@example.com">>, Index, Opts).
[
    #{<<"user_id">>> => <<"mrn:user:..X">>},
    #{<<"user_id">>> => <<"mrn:user:..Y">>}
]
```

## Case

If we wanted the index to cover the tuple {`account_id`, `email`} then we would do:


```erlang
Index = #{
    id => <<"users_by_email">>,
    bucket_type => <<"map">>,
    bucket => <<"lojack/johndoe/index_data">>,
    type => babel_hash_partitioned_index,
    config => #{
        sort_ordering => asc,
        number_of_partitions => 8,
        partition_algorithm => jch,
        partition_by => [email],
        index_by => [email, account_id],
        aggregate_by => [email],
        covered_fields => [account_id, user_id]
    }
}.
```

This will produce an index partition that looks like the following

```erlang
#{
    meta => #{},
    data => #{
        "johndoe@example.com" => #{
            <<"mrn:account:..A">> => <<"mrn:user:...X">>,
            <<"mrn:account:..B">> => <<"mrn:user:...Y">>,
        }
    }
}
```

Then:

```erlang
> babel_index:match(<<"johndoe@example.com">>, Index, Opts).
[
    #{
        <<"user_id">>> => <<"mrn:user:..X">>,
        <<"account_id">> =>  <<"mrn:account:...A">>
    },
    #{
        <<"user_id">>> => <<"mrn:user:..Y">>,
        <<"account_id">> =>  <<"mrn:account:...B">>
    }
]
```

## Case - Complex


If we wanted the index to cover the tuple {`account_id`, `email`} then we would do:


```erlang
Index = #{
    id => <<"users_by_location">>,
    bucket_type => <<"map">>,
    bucket => <<"lojack/johndoe/index_data">>,
    type => babel_hash_partitioned_index,
    config => #{
        sort_ordering => asc,
        number_of_partitions => 8,
        partition_algorithm => jch,
        partition_by => [post_code],
        index_by => [post_code, last_name, first_name],
        aggregate_by => [post_code, last_name],
        covered_fields => [account_id, user_id]
    }
}.
```

This will produce an index partition that looks like the following

```erlang
#{
    meta => #{},
    data => #{
        <<"KT122DU", "DOE">> => #{
            <<"JOHN">> => encode({<<"mrn:account:..B">>, <<"mrn:user:...X">>}),
            <<"LUCY">> => encode({<<"mrn:account:..B">>, <<"mrn:user:...Y">>})
        }
    }
}
```

```erlang
1> babel_index:match(<<"KT122DU", "DOE">>, Index, Opts).
[
    #{
        <<"user_id">>> => <<"mrn:user:..X">>,
        <<"account_id">> =>  <<"mrn:account:...B">>
    },
    #{
        <<"user_id">>> => <<"mrn:user:..Y">>,
        <<"account_id">> =>  <<"mrn:account:...B">>
    }
]
2> babel_index:match(<<"KT122DU", "DOE", "LUCY">>, Index, Opts).
[
    #{
        <<"user_id">>> => <<"mrn:user:..Y">>,
        <<"account_id">> =>  <<"mrn:account:...B">>
    }
]
```