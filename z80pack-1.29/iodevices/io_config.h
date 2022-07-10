/*
 * Z80SIM  -  a Z80-CPU simulator
 *
 * Common I/O devices used by various simulated machines
 *
 * Copyright (C) 2008-2016 by Udo Munk
 *
 * This module reads the I/O configuration file and sets
 * global variables for the I/O device emulations, so
 * that functions of I/O devices can be configured.
 *
 * History:
 * 20-OCT-08 first version finished
 * 20-MAR-14 ignore carriage return too, necessary for the Windows port
 * 19-JUN-14 added config parameter for droping nulls after CR/LF
 * 09-OCT-14 modified to support 2 SIO's
 * 09-MAY-16 added path for config file
 * 29-AUG-16 ROM and boot switch configuration for Altair emulation added
 */

extern void io_config(void);
