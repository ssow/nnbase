include erlang.mk

PROJECT = nnbase
ERLC_OPTS := $(filter-out -Werror,$(ERLC_OPTS))
