CC ?= cc
CFLAGS ?= -Wall -Wextra -O2

.PHONY: all clean test

all: bin/zhixu-rt-suppress-run

bin/zhixu-rt-suppress-run: tools/zhixu-rt-suppress-run.c
	mkdir -p bin
	$(CC) $(CFLAGS) -o $@ $<

clean:
	rm -rf bin

test: all
	./tests/static.sh
