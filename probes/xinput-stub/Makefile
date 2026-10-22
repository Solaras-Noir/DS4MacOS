CC      = x86_64-w64-mingw32-gcc
CFLAGS  = -O2 -Wall -Wextra -ffreestanding -fno-builtin -fno-stack-protector
LDFLAGS = -shared -s -nostdlib -nostartfiles -Wl,-e,DllMain
LIBS    = -lkernel32

all: bin/xinput1_3.dll bin/xinput1_4.dll

xinput_stub.o: xinput_stub.c
	$(CC) $(CFLAGS) -c -o $@ $<

bin/xinput1_3.dll: xinput_stub.o xinput1_3.def
	mkdir -p bin
	$(CC) $(LDFLAGS) -o $@ xinput_stub.o xinput1_3.def $(LIBS)

bin/xinput1_4.dll: xinput_stub.o xinput1_4.def
	mkdir -p bin
	$(CC) $(LDFLAGS) -o $@ xinput_stub.o xinput1_4.def $(LIBS)

clean:
	rm -f xinput_stub.o bin/xinput1_3.dll bin/xinput1_4.dll

.PHONY: all clean
