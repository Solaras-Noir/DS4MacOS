CC      = x86_64-w64-mingw32-gcc
CFLAGS  = -O2 -Wall -Wextra
LDFLAGS = -shared -s

all: bin/xinput1_3.dll bin/xinput1_4.dll

xinput_stub.o: xinput_stub.c
	$(CC) $(CFLAGS) -c -o $@ $<

bin/xinput1_3.dll: xinput_stub.o xinput_stub.def
	mkdir -p bin
	$(CC) $(LDFLAGS) -o $@ xinput_stub.o xinput_stub.def

bin/xinput1_4.dll: bin/xinput1_3.dll
	cp $< $@

clean:
	rm -f xinput_stub.o bin/xinput1_3.dll bin/xinput1_4.dll

.PHONY: all clean
