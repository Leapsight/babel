# Users By Email

## Example 1 - Simple case

```erlang
Index = #{
    id => <<"users_by_email">>,
    bucket_type => <<"map">>,
    bucket => <<"lojack/johndoe/index_data">>,
    type => riak_hash_partitioned_index,
    config => #{
        sort_ordering => asc,
        number_of_partitions => 8,
        partition_algorithm => fnv32a,
        partition_by => [email],
        index_by => [email],
        covered_fields => [user_id]
    }
}.
```

This will produce an index partition equivalent(*) to the following Erlang term.

```erlang
#{
    meta => #{},
    data => [
        {<<"johndoe@example.com">>, <<"mrn:user:...">>}
    ]
}
```

(*) This is not the actual representation as we will use RIAK KV CRDT datatypes, but it would be the case if we implemented a function to represent the CRDT in erlang terms.

## Example 2 - Covering multiple fields

```erlang
Index = #{
    id => <<"users_by_email">>,
    bucket_type => <<"map">>,
    bucket => <<"lojack/johndoe/index_data">>,
    type => riak_hash_partitioned_index,
    config => #{
        sort_ordering => asc,
        number_of_partitions => 8,
        partition_algorithm => fnv32a,
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
    data => [
        {<<"johndoe@example.com">>, {<<"mrn:user:...">>,  <<"mrn:account:...">>}}
    ]
}
```

## Case 3 - Aggregate By

If we wanted to supported multiple users per email i.e. a person can be a usr in multiple accounts using the same email then we need to use the `aggregate_by` option.


```erlang
Index = #{
    id => <<"users_by_email">>,
    bucket_type => <<"map">>,
    bucket => <<"lojack/johndoe/index_data">>,
    type => riak_hash_partitioned_index,
    config => #{
        sort_ordering => asc,
        number_of_partitions => 8,
        partition_algorithm => fnv32a,
        partition_by => [email],
        aggregate_by => [email],
        index_by => [email],
        covered_fields => [user_id]
    }
}.
```

This will produce an index partition that looks like the following

```erlang
#{
    meta => #{},
    data => #{
        "johndoe@example.com" => [
            <<"mrn:user:..X">>,
            <<"mrn:user:..Y">>
        ]
    }
}
```

## Case

If we wanted the index to cover the tuple {`account_id`, `email`} then we would do:


```erlang
Index = #{
    id => <<"users_by_email">>,
    bucket_type => <<"map">>,
    bucket => <<"lojack/johndoe/index_data">>,
    type => riak_hash_partitioned_index,
    config => #{
        sort_ordering => asc,
        number_of_partitions => 8,
        partition_algorithm => fnv32a,
        partition_by => [email],
        aggregate_by => [email],
        index_by => [email],
        covered_fields => [account_id, user_id]
    }
}.
```

This will produce an index partition that looks like the following

```erlang
#{
    meta => #{},
    data => #{
        "johndoe@example.com" => [
            {<<"mrn:account:..A">>, <<"mrn:user:...X">>},
            {<<"mrn:account:..B">>, <<"mrn:user:...Y">>},
        ]
    }
}
```

## Case - Complex


If we wanted the index to cover the tuple {`account_id`, `email`} then we would do:


```erlang
Index = #{
    id => <<"users_by_location">>,
    bucket_type => <<"map">>,
    bucket => <<"lojack/johndoe/index_data">>,
    type => riak_hash_partitioned_index,
    config => #{
        sort_ordering => asc,
        number_of_partitions => 8,
        partition_algorithm => fnv32a,
        partition_by => [post_code],
        aggregate_by => [post_code, last_name],
        index_by => [post_code, last_name, first_name],
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
            <<"JOHN">> => {<<"mrn:account:..B">>, <<"mrn:user:...Y">>}
        }
    }
}
```