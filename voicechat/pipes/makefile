# Makefile
# Dynamically determine the BYOND path based on the active version from the tgstation-server setup.
# Assumes the ActiveVersion file is at /home/tgstation-server/SurfShack13/Byond/ActiveVersion
# and the libbyond.so is under /home/tgstation-server/SurfShack13/Byond/<version>/byond/bin/libbyond.so
BYOND_ROOT = $(PWD)/../../Byond
BYOND_VERSION = $(shell cat $(BYOND_ROOT)/ActiveVersion)
BYOND_PATH = $(BYOND_ROOT)/$(BYOND_VERSION)/byond/bin

# Byond api gets downloaded from install.sh
CC = gcc
CPP = g++
CFLAGS = -m32 -pthread -g -Wall -Wno-deprecated -O3 -fno-strict-aliasing
LDFLAGS = -m32 -shared $(BYOND_PATH)/libbyond.so
RM = rm -f
TARGET_LIB = byondsocket.so
OBJS = \
main.o \
byondapi_cpp_wrappers.o
.PHONY: all
all: ${TARGET_LIB}
$(TARGET_LIB): $(OBJS)
$(CC) ${LDFLAGS} -o $@ $^
.cpp.o:
$(CPP) $(CPPFLAGS) $(CFLAGS) -c $*.cpp -o $*.o
.c.o:
$(CC) $(CPPFLAGS) $(CFLAGS) -c $*.c -o $*.o
.PHONY: clean
clean:
-${RM} ${TARGET_LIB} ${OBJS}
