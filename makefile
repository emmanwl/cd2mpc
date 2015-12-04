VERSION = 13.0
INSTALL = /usr/bin/install -c

# Installation directories
libdir = ${HOME}/libs4shell
bindir = ${HOME}/bin
cnfdir = ${HOME}

all: install

install:
	$(INSTALL) -d -m 755 $(libdir)
	$(INSTALL) -d -m 755 $(bindir)
	$(INSTALL) -m 644 liblog4shell $(libdir)
	$(INSTALL) -m 644 libopt4shell $(libdir)
	$(INSTALL) -m 644 log4shell.cf $(libdir)/.log4shell.cf
	$(INSTALL) -m 755 cd2mpc $(bindir)
	$(INSTALL) -m 644 cd2mpcrc $(cnfdir)/.cd2mpcrc
	@#$(INSTALL) -d -m 755 $(mandir)
	@#$(INSTALL) -m 644 -o 0 cd2mpc.1 $(mandir)
