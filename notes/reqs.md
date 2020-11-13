# New Requirements

107> {R2, babel_map:changed_key_paths(R2)}.
{#babel_map{
     values =
         #{<<"roles">> =>
               #babel_map{
                   values = #{},updates = [],
                   removes = [<<"mrn:party_role:user">>],
                   context = undefined}},
     updates = [<<"roles">>],
     removes = [],context = <<>>},
 {[],[[<<"roles">>,<<"mrn:party_role:user">>]]}}
108> {R3, babel_map:changed_key_paths(R3)}.
{#babel_map{
     values =
         #{<<"roles">> =>
               #babel_map{
                   values =
                       #{<<"mrn:party_role:user">> =>
                             #babel_map{
                                 values = #{<<"username">> => <<"bar">>},
                                 updates = [<<"username">>],
                                 removes = [],context = undefined}},
                   updates = [<<"mrn:party_role:user">>],
                   removes = [],context = undefined}},
     updates = [<<"roles">>],
     removes = [],context = <<>>},
 {[[<<"roles">>,<<"mrn:party_role:user">>,<<"username">>]],
  []}}
109>


Conf = #{
    name => index_name_users_by_username(),
    bucket_type => bucket_type(),
    bucket_prefix => bucket_prefix(),
    type => babel_hash_partitioned_index,
    config => #{
        sort_ordering => asc,
        number_of_partitions => 512,
        partition_algorithm => jch,
        partition_by => [
            [<<"roles">>, <<"mrn:party_role:user">>, <<"username">>],
        ],
        index_by => [
            [<<"roles">>, <<"mrn:party_role:user">>, <<"username">>],
            <<"account_id">>
        ],
        aggregate_by => [
            [<<"roles">>, <<"mrn:party_role:user">>, <<"username">>]
        ],
        covered_fields => [<<"id">>]
    }
}.

Spec = <<"roles">> => {map, #{
            <<"mrn:party_role:user">> => {map, #{
                <<"username">> => {register, binary}
}}}}.

foo@gmail.com
    [
        {mrn:acc:1, mrn:person:1},
        {mrn:acc:2, mrn:person:3}
    ]


foobar@gmail.com
    [
        {mrn:acc:1, mrn:person:1},
        {mrn:acc:2, mrn:person:3}
    ]

# UPDATE
update_index({delete, Obj}, Idx)
update_index({insert, Obj}, Idx)
update_index({update, undefined, New}, Idx) -> update_index({insert, Obj}, Idx)
update_index({update, Old(foo@gmail.com), New(foobar@gmail.com)}, Idx) ->
    [
        update_index({delete, Old(foo@gmail.com)}, Idx)
        update_index({insert, New(foobar@gmail.com)}, Idx)
    ].


update_index({update, Old(foobar@gmail.com), New(foobar@gmail.com)}, Idx) ->
    [
        update_index({delete, Old(foobar@gmail.com)}, Idx)
        update_index({insert, New(foobar@gmail.com)}, Idx)
    ].


affected_indices({update, Old, New}, Coll) ->
    for each index i do
        i.updated_key_paths
        New.changed_key_paths

    Indices.

    for each index i do
        i.updated_key_paths
         for each kp
            Status = New.status(kp)
            if Status == updated
                [
                    update_index({delete, Old}, Idx)
                    update_index({insert, New}, Idx)
                ].
            else if Status == removed
                [
                    update_index({delete, Old}, Idx)
                ]
            else
                ok

    Indices.


update_indices({update, Old, New}, Indices)


[a] [a]
[a] [a,b] [a,b,c]
[a] [x]

Opts = #{event_payload => #{indices => [1, 4, 5]}}
{scheduled, WorRef, ok} = babel:update_indices(Actions, Collection, Opts),
{ok, #{indices => [1, 4, 5]}} = babel:yield(WorRef, 10000),




-module(person).



update(Data, Person) ->
    ....

 async(babel:update_indices({update, Old, New}, Collec).)
 ok.


