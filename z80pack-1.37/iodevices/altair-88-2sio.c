/*
 * Z80SIM  -  a Z80-CPU simulator
 *
 * Common I/O devices used by various simulated machines
 *
 * Copyright (C) 2008-2020 by Udo Munk
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
 * 24-FEB-17 improved tty reopen
 * 22-MAR-17 connected SIO 2 to UNIX domain socket
 * 23-OCT-17 improved UNIX domain socket connections
 * 03-MAY-18 improved accuracy
 * 03-JUL-18 added baud rate to terminal 2SIO
 * 15-JUL-18 use logging
 * 24-NOV-19 configurable baud rate for second channel
 * 19-JUL-20 avoid problems with some third party terminal emulations
 */

#include <unistd.h>
#include <stdio.h>
#include <ctype.h>
#include <errno.h>
#include <fcntl.h>
#include <sys/time.h>
#include <sys/poll.h>
#include <sys/types.h>
#include <sys/socket.h>
#include "sim.h"
#include "simglb.h"
#include "log.h"
#include "unix_terminal.h"
#include "unix_network.h"

#define BAUDTIME 10000000

extern int time_diff(struct timeval *, struct timeval *);

static const char *TAG = "2SIO";

int sio1_upper_case;
int sio1_strip_parity;
int sio1_drop_nulls;
int sio1_baud_rate = 115200;

static struct timeval sio1_t1, sio1_t2;
static BYTE sio1_stat;

int sio2_upper_case;
int sio2_strip_parity;
int sio2_drop_nulls;
int sio2_baud_rate = 115200;

static struct timeval sio2_t1, sio2_t2;
static BYTE sio2_stat;

/*
 * read status register
 *
 * bit 0 = 1, character available for input from tty
 * bit 1 = 1, transmitter ready to write character to tty
 */
BYTE altair_sio1_status_in(void)
{
	struct pollfd p[1];
	int tdiff;

	gettimeofday(&sio1_t2, NULL);
	tdiff = time_diff(&sio1_t1, &sio1_t2);
	if (sio1_baud_rate > 0)
		if ((tdiff >= 0) && (tdiff < BAUDTIME/sio1_baud_rate))
			return(sio1_stat);

	p[0].fd = fileno(stdin);
	p[0].events = POLLIN;
	p[0].revents = 0;
	poll(p, 1, 0);
	if (p[0].revents & POLLIN)
		sio1_stat |= 1;
	if (p[0].revents & POLLNVAL) {
		LOGE(TAG, "can't use terminal, try 'screen simulation ...'");
		cpu_error = IOERROR;
		cpu_state = STOPPED;
	}
	sio1_stat |= 2;

	gettimeofday(&sio1_t1, NULL);

	return(sio1_stat);
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
 * Can be configured to translate to upper case, most of the old software
 * written for tty's won't accept lower case characters.
 */
BYTE altair_sio1_data_in(void)
{
	BYTE data;
	static BYTE last;
	struct pollfd p[1];

again:
	/* if no input waiting return last */
	p[0].fd = fileno(stdin);
	p[0].events = POLLIN;
	p[0].revents = 0;
	poll(p, 1, 0);
	if (!(p[0].revents & POLLIN))
		return(last);

	if (read(fileno(stdin), &data, 1) == 0) {
		/* try to reopen tty, input redirection exhausted */
		freopen("/dev/tty", "r", stdin);
		set_unix_terminal();
		goto again;
	}

	gettimeofday(&sio1_t1, NULL);
	sio1_stat &= 0b11111110;

	/* process read data */
	if (sio1_upper_case)
		data = toupper(data);
	last = data;
	return(data);
}

/*
 * write data register
 *
 * Can be configured to strip parity bit because some old software won't.
 * Also can drop nulls usually send after CR/LF for teletypes.
 */
void altair_sio1_data_out(BYTE data)
{
	if (sio1_drop_nulls)
		if (data == 0)
			return;

	if (sio1_strip_parity)
		data &= 0x7f;

again:
	if (write(fileno(stdout), &data, 1) != 1) {
		if (errno == EINTR) {
			goto again;
		} else {
			LOGE(TAG, "can't write data sio1");
			cpu_error = IOERROR;
			cpu_state = STOPPED;
		}
	}

	gettimeofday(&sio1_t1, NULL);
	sio1_stat &= 0b11111101;
}

/*
 * read status register
 *
 * bit 0 = 1, character available for input from tty
 * bit 1 = 1, transmitter ready to write character to tty
 */
BYTE altair_sio2_status_in(void)
{
	struct pollfd p[1];
	int tdiff;

	/* if socket not connected check for a new connection */
	if (ucons[1].ssc == 0) {
		p[0].fd = ucons[1].ss;
		p[0].events = POLLIN;
		p[0].revents = 0;
		poll(p, 1, 0);
		/* accept a new connection */
		if (p[0].revents) {
			if ((ucons[1].ssc = accept(ucons[1].ss, NULL,
			     NULL)) == -1) {
				LOGW(TAG, "can't accept server socket");
				ucons[1].ssc = 0;
			}
		}
	}

	gettimeofday(&sio2_t2, NULL);
	tdiff = time_diff(&sio2_t1, &sio2_t2);
	if (sio2_baud_rate > 0)
		if ((tdiff >= 0) && (tdiff < BAUDTIME/sio2_baud_rate))
			return(sio2_stat);

	/* if socket is connected check for I/O */
	if (ucons[1].ssc != 0) {
		p[0].fd = ucons[1].ssc;
		p[0].events = POLLIN | POLLOUT;
		p[0].revents = 0;
		poll(p, 1, 0);
		if (p[0].revents & POLLIN)
			sio2_stat |= 1;
		if (p[0].revents & POLLOUT)
			sio2_stat |= 2;
	}

	gettimeofday(&sio2_t1, NULL);

	return(sio2_stat);
}

/*
 * write status register
 */
void altair_sio2_status_out(BYTE data)
{
	data = data; /* to avoid compiler warning */
}

/*
 * read data register
 *
 * Can be configured to translate to upper case, most of the old software
 * written for tty's won't accept lower case characters.
 */
BYTE altair_sio2_data_in(void)
{
	BYTE data;
	static BYTE last;
	struct pollfd p[1];

	/* if not connected return last */
	if (ucons[1].ssc == 0)
		return(last);

	/* if no input waiting return last */
	p[0].fd = ucons[1].ssc;
	p[0].events = POLLIN;
	p[0].revents = 0;
	poll(p, 1, 0);
	if (!(p[0].revents & POLLIN))
		return(last);

	if (read(ucons[1].ssc, &data, 1) != 1) {
		/* EOF, close socket and return last */
		close(ucons[1].ssc);
		ucons[1].ssc = 0;
		return(last);
	}

	gettimeofday(&sio2_t1, NULL);
	sio2_stat &= 0b11111110;

	/* process read data */
	if (sio2_upper_case)
		data = toupper(data);
	last = data;
	return(data);
}

/*
 * write data register
 *
 * Can be configured to strip parity bit because some old software won't.
 * Also can drop nulls usually send after CR/LF for teletypes.
 */
void altair_sio2_data_out(BYTE data)
{
	struct pollfd p[1];

	/* return if socket not connected */
	if (ucons[1].ssc == 0)
		return;

	/* if output not possible close socket and return */
	p[0].fd = ucons[1].ssc;
	p[0].events = POLLOUT;
	p[0].revents = 0;
	poll(p, 1, 0);
	if (!(p[0].revents & POLLOUT)) {
		close(ucons[1].ssc);
		ucons[1].ssc = 0;
		return;
	}

	if (sio2_drop_nulls)
		if (data == 0)
			return;

	if (sio2_strip_parity)
		data &= 0x7f;

again:
	if (write(ucons[1].ssc, &data, 1) != 1) {
		if (errno == EINTR) {
			goto again;
		} else {
			close(ucons[1].ssc);
			ucons[1].ssc = 0;
		}
	}

	gettimeofday(&sio2_t1, NULL);
	sio2_stat &= 0b11111101;
}
