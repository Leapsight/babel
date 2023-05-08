.PHONY: docs test

docs:
	rebar3 ex_doc skip_deps=true

test:
	. test/setup_riak.sh
	rebar3 ct


check: eqwalize

eqwalize:
	elp eqwalize-all