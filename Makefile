# escrowc with TinyCC (PLAN.md). make builds build/escrowc and
# build/parsetool, make check-clang checks every C file with clang, and
# make test runs test/parse.sh.
TCC = tcc
CLANG = cc
TCCFLAGS = -std=c99 -Wall -Werror
CLANGFLAGS = -std=c99 -Wall -Wextra -Wswitch-enum -Werror -fsyntax-only

FRONT = src/arena.c src/diag.c src/lexer.c src/parser.c src/printer.c
ESCROWC = $(FRONT) src/evm.c src/keccak.c src/main.c
HEADERS = src/arena.h src/evm.h src/keccak.h src/prelude.h src/syntax.h
PRELUDE = prelude/Prelude.esc

all: build/escrowc build/parsetool

build/prelude.c: tools/embed.c src/prelude.h $(PRELUDE)
	mkdir -p build
	$(TCC) $(TCCFLAGS) -run tools/embed.c $(PRELUDE) $@

build/escrowc: $(ESCROWC) $(HEADERS) build/prelude.c
	$(TCC) $(TCCFLAGS) -o $@ $(ESCROWC) build/prelude.c

build/parsetool: $(FRONT) test/parsetool.c $(HEADERS) build/prelude.c
	$(TCC) $(TCCFLAGS) -o $@ $(FRONT) test/parsetool.c build/prelude.c

check-clang: build/prelude.c
	$(CLANG) $(CLANGFLAGS) src/*.c test/*.c tools/*.c build/prelude.c

test: build/escrowc build/parsetool
	sh test/parse.sh

clean:
	rm -rf build

.PHONY: all check-clang test clean
