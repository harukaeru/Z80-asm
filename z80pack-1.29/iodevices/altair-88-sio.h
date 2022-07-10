/*
 * Z80SIM  -  a Z80-CPU simulator
 *
 * Common I/O devices used by various simulated machines
 *
 * Copyright (C) 2016 by Udo Munk
 *
 * Partial emulation of an Altair 88-SIO S100 board
 *
 * History:
 * 12-JUL-16 first version
 * 02-SEP-16 reopen tty at EOF from input redirection
 */

extern BYTE altair_sio0_status_in(void);
extern void altair_sio0_status_out(BYTE);
extern BYTE altair_sio0_data_in(void);
extern void altair_sio0_data_out(BYTE);
