prefix=/usr/local

all: nothingToCompile

nothingToCompile:
	/bin/true

install: rrd2csv.pl rrdmulti.pl
	install -m 755 rrd2csv.pl $(prefix)/bin
	install -m 755 rrdmulti.pl $(prefix)/bin

uninstall:
	$(RM) $(prefix)/bin/rrd2csv.pl
	$(RM) $(prefix)/bin/rrdmulti.pl
