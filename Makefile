# Configurable options
#   MODE = release | debug (default: debug)
#   SNAPPY = 0 | 1 (default: 1)
#
CSTDFLAG = --std=c99 -pedantic -Wall -Wextra -Wno-unused-parameter
CPPFLAGS += -fPIC -Iinclude -Iexternal/snappy
CPPFLAGS += -D_LARGEFILE_SOURCE -D_FILE_OFFSET_BITS=64
CPPFLAGS += -D_XOPEN_SOURCE=500 -D_DARWIN_C_SOURCE
LDFLAGS += -lpthread

ifeq ($(MODE),release)
	CPPFLAGS += -O3
	DEFINES += -DNDEBUG
else
	CFLAGS += -g
endif

# run make with SNAPPY=0 to turn it off
ifneq ($(SNAPPY),0)
	DEFINES += -DBP_USE_SNAPPY=1
else
	DEFINES += -DBP_USE_SNAPPY=0
endif

all: external/snappy/config.status bplus.a

external/snappy/config.status:
	(git submodule init && git submodule update && cd external/snappy)
	(cd external/snappy && ./autogen.sh && ./configure)

OBJS =

ifneq ($(SNAPPY),0)
	OBJS += external/snappy/snappy-sinksource.o
	OBJS += external/snappy/snappy.o
	OBJS += external/snappy/snappy-c.o
endif

OBJS += src/utils.o
OBJS += src/writer.o
OBJS += src/values.o
OBJS += src/pages.o
OBJS += src/bplus.o

deps := $(OBJS:%.o=%.o.d)

bplus.a: $(OBJS)
	$(AR) rcs bplus.a $(OBJS)

src/%.o: src/%.c
	$(CC) $(CFLAGS) $(CSTDFLAG) $(CPPFLAGS) $(DEFINES) \
		-o $@ -MMD -MF $@.d -c $<

external/snappy/%.o: external/snappy/%.cc
	$(CC) $(CFLAGS) $(CPPFLAGS) -c $< -o $@

TESTS =
TESTS += test/test-api
TESTS += test/test-reopen
TESTS += test/test-range
TESTS += test/test-corruption
TESTS += test/test-bulk
TESTS += test/test-threaded-rw
TESTS += test/bench-basic
TESTS += test/bench-bulk
TESTS += test/bench-multithread-get

check: $(TESTS)
	@test/test-api
	@test/test-reopen
	@test/test-range
	@test/test-bulk
	@test/test-corruption
	@test/test-threaded-rw

test/%: test/%.cc bplus.a
	$(CXX) $(CFLAGS) $(CPPFLAGS) $< -o $@ bplus.a $(LDFLAGS)

clean:
	@rm -f bplus.a
	@rm -f $(OBJS) $(TESTS) $(deps)

.PHONY: all check clean

-include $(deps)
