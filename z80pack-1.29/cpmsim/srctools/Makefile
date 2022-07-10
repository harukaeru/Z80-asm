#
# some places where the tools usually are installed
#
#INSTALLDIR=/usr/local/bin
INSTALLDIR=${HOME}/bin
#INSTALLDIR=..

#CC = cc
CC = gcc

CFLAGS= -O3 -Wall

all: test mkdskimg bin2hex send receive ptp2bin
	@echo
	@echo "Done."
	@echo

test:
	@test -d ${INSTALLDIR} || (echo "${INSTALLDIR} doesn't exist, fix INSTALLDIR"; exit 1)

mkdskimg: mkdskimg.c
	$(CC) $(CFLAGS) -o mkdskimg mkdskimg.c
	cp mkdskimg ${INSTALLDIR}

bin2hex: bin2hex.c
	$(CC) $(CFLAGS) -o bin2hex bin2hex.c
	cp bin2hex ${INSTALLDIR}

send: send.c
	$(CC) $(CFLAGS) -o send send.c
	cp send ${INSTALLDIR}

receive: receive.c
	$(CC) $(CFLAGS) -o receive receive.c
	cp receive ${INSTALLDIR}

ptp2bin: ptp2bin.c
	$(CC) $(CFLAGS) -o ptp2bin ptp2bin.c
	cp ptp2bin ${INSTALLDIR}

clean:
	rm -f mkdskimg mkdskimg.exe bin2hex bin2hex.exe receive receive.exe \
	send send.exe ptp2bin ptp2bin.exe
