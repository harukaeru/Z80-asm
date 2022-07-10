/*
 * Z80SIM  -  a Z80-CPU simulator
 *
 * Common I/O devices used by various simulated machines
 *
 * Copyright (C) 2016 by Udo Munk
 *
 * Partial emulation of an Altair 88-SIO Rev. 0 S100 board
 *
 * History:
 * 12-JUL-16 first version
 * 02-SEP-16 reopen tty at EOF from input redirection
 */

#include <unistd.h>
#include <stdio.h>
#include <ctype.h>
#include <errno.h>
#include <fcntl.h>
#include <sys/poll.h>
#include "sim.h"
#include "simglb.h"
#include "unix_terminal.h"

/*
 * read status register
 *
 * bit 5 = 1, character available for input from tty
 *            unmodified Rev. 0, later ones used bit 0
 * bit 1 = 1, transmitter ready to write character to tty
 */
BYTE altair_sio0_status_in(void)
{
	BYTE status = 0;
	struct pollfd p[1];

	p[0].fd = fileno(stdin);
	p[0].events = POLLIN | POLLOUT;
	p[0].revents = 0;
	poll(p, 1, 0);
	if (p[0].revents & POLLIN)
		status |= 32;
	if (p[0].revents & POLLOUT)
		status |= 2;

	return(status);
}

/*
 * write status register
 */
void altair_sio0_status_out(BYTE data)
{
	data = data; /* to avoid compiler warning */
}

/*
 * read data register
 */
BYTE altair_sio0_data_in(void)
{
	BYTE data;
	struct pollfd p[1];

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
		set_unix_terminal();
		goto again;
	}
	return(data);
}

/*
 * write data register
 */
void altair_sio0_data_out(BYTE data)
{
	data &= 0x7f;	/* strip parity */

again:
	if (write(fileno(stdout), (char *) &data, 1) != 1) {
		if (errno == EINTR) {
			goto again;
		} else {
			perror("write altair sio0 data");
			cpu_error = IOERROR;
			cpu_state = STOPPED;
		}
	}
}
