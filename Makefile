.PHONY: docs test

docs:
	rebar3 as docs edoc
	cp README.md doc/README.md

test:
	. test/setup_riak.sh
	rebar3 ct