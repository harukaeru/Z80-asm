/*
 * Z80SIM  -  a Z80-CPU simulator
 *
 * Common I/O devices used by various simulated machines
 *
 * Copyright (C) 2008-2016 by Udo Munk
 *
 * Partial emulation of an Altair 88-2SIO S100 board
 *
 * History:
 * 20-OCT-08 first version finished
 * 31-JAN-14 use correct name from the manual
 * 19-JUN-14 added config parameter for droping nulls after CR/LF
 * 17-JUL-14 don't block on read from terminal
 * 09-OCT-14 modified to support 2 SIO's
 * 23-MAR-15 drop only null's
 * 02-SEP-16 reopen tty at EOF from input redirection
 */

#include <unistd.h>
#include <stdio.h>
#include <ctype.h>
#include <errno.h>
#include <fcntl.h>
#include <sys/poll.h>
//#include <sys/ioctl.h>
#include "sim.h"
#include "simglb.h"
#include "unix_terminal.h"

int sio1_upper_case;
int sio1_strip_parity;
int sio1_drop_nulls;

int sio2_upper_case;
int sio2_strip_parity;
int sio2_drop_nulls;

/*
 * read status register
 *
 * bit 0 = 1, character available for input from tty
 * bit 1 = 1, transmitter ready to write character to tty
 */
BYTE altair_sio1_status_in(void)
{
	BYTE status = 0;
	struct pollfd p[1];

	p[0].fd = fileno(stdin);
	p[0].events = POLLIN | POLLOUT;
	p[0].revents = 0;
	poll(p, 1, 0);
	if (p[0].revents & POLLIN)
		status |= 1;
	if (p[0].revents & POLLOUT)
		status |= 2;

	return(status);
}

/*
 * write status register
 */
void altair_sio1_status_out(BYTE data)
{
	data = data; /* to avoid compiler warning */
}

/*
 * read data register
 *
 * can be configured to translate to upper case, most of the old software
 * written for tty's won't accept lower case characters
 */
BYTE altair_sio1_data_in(void)
{
	BYTE data;
	struct pollfd p[1];
	//int ldisc = TTYDISC;

	p[0].fd = fileno(stdin);
	p[0].events = POLLIN;
	p[0].revents = 0;
	poll(p, 1, 0);
	if (!(p[0].revents & POLLIN))
		return(0);

again:
	if (read(fileno(stdin), &data, 1) == 0) {
		reset_unix_terminal();
		close(fileno(stdin));
		open("/dev/tty", O_RDWR);
		//ioctl(0, TIOCSETD, &ldisc);	/* tried this for OS X */
		//ioctl(0, TIOCSCTTY);		/* but doesn't help */
		set_unix_terminal();
		goto again;
	}

	if (sio1_upper_case)
		data = toupper(data);
	return(data);
}

/*
 * write data register
 *
 * can be configured to strip parity bit because some old software won't.
 * also can drop nulls usually send after CR/LF for teletypes,
 */
void altair_sio1_data_out(BYTE data)
{
	if (sio1_strip_parity)
		data &= 0x7f;

	if (sio1_drop_nulls)
		if (data == 0)
			return;

again:
	if (write(fileno(stdout), (char *) &data, 1) != 1) {
		if (errno == EINTR) {
			goto again;
		} else {
			perror("write altair sio2 data");
			cpu_error = IOERROR;
			cpu_state = STOPPED;
		}
	}
}
