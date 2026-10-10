# Makefile - entry points for building and testing the ledger batch
# system.  Each target is a thin wrapper round a script in scripts/
# or tests/, so the scripts can also be run directly on systems that
# have bash but not make.
#
#   make            same as `make build`
#   make build      compile bin/ledger-batch, bin/ledger-reconcile
#                   and the unit-test executables
#   make lint       check COBOL source format (column 72, tabs, ...)
#   make test       lint, build, then run every test suite
#   make unit       build, then run only the unit tests
#   make integration, make regression
#                   build, then run only that suite
#   make example    build, then run the example batch into
#                   build/example/
#   make coverage   measure line coverage (needs GnuCOBOL 3.2+, gcov)
#   make loc        report source lines by language
#   make clean      remove everything that was built or generated

SHELL := bash

.PHONY: all build lint test unit integration regression example \
        coverage loc clean

all: build

build:
	bash scripts/build.sh

lint:
	bash scripts/lint-cobol.sh

test:
	bash scripts/test.sh

unit: build
	bash tests/run-tests.sh unit

integration: build
	bash tests/run-tests.sh integration

regression: build
	bash tests/run-tests.sh regression

example: build
	@bash scripts/run-batch.sh testdata/control/standard.ctl \
	    testdata/accounts/standard.dat \
	    testdata/transactions/mixed-batch.dat \
	    build/example testdata/history/empty.dat; \
	status=$$?; \
	if [ $$status -gt 4 ]; then exit $$status; fi; \
	echo "example: return code $$status; reports are in build/example/"

coverage:
	bash scripts/coverage.sh

loc:
	bash scripts/count-source-lines.sh

clean:
	rm -rf bin build
