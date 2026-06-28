// SPDX-License-Identifier: GPL-2.0-or-later
/*
 * Keep ZhiXu xpad RT suppression enabled only while this process is running.
 */

#include <errno.h>
#include <fcntl.h>
#include <signal.h>
#include <stdbool.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>

static const char *param_path = "/sys/module/xpad/parameters/zhixu_suppress_rt";
static volatile sig_atomic_t stop_requested;

static void die(const char *message)
{
	perror(message);
	exit(1);
}

static void request_stop(int signal)
{
	(void)signal;
	stop_requested = 1;
}

static void install_signal_handlers(void)
{
	struct sigaction action;

	memset(&action, 0, sizeof(action));
	action.sa_handler = request_stop;
	sigemptyset(&action.sa_mask);

	if (sigaction(SIGINT, &action, NULL) < 0)
		die("sigaction SIGINT");
	if (sigaction(SIGTERM, &action, NULL) < 0)
		die("sigaction SIGTERM");
	if (sigaction(SIGHUP, &action, NULL) < 0)
		die("sigaction SIGHUP");
}

static char read_param(void)
{
	char value;
	int fd;

	fd = open(param_path, O_RDONLY);
	if (fd < 0)
		die("open zhixu_suppress_rt");

	if (read(fd, &value, 1) != 1)
		die("read zhixu_suppress_rt");

	close(fd);
	return value;
}

static void write_param(char value)
{
	char buffer[2] = { value, '\n' };
	int fd;

	fd = open(param_path, O_WRONLY);
	if (fd < 0)
		die("open zhixu_suppress_rt for write");

	if (write(fd, buffer, sizeof(buffer)) != (ssize_t)sizeof(buffer))
		die("write zhixu_suppress_rt");

	close(fd);
}

int main(void)
{
	char previous;

	install_signal_handlers();

	previous = read_param();
	if (previous != 'Y' && previous != 'N') {
		fprintf(stderr, "Unexpected zhixu_suppress_rt value: %c\n", previous);
		return 1;
	}

	write_param('Y');
	fprintf(stderr, "ZhiXu RT suppression enabled. Press Ctrl+C to disable it.\n");

	while (!stop_requested)
		pause();

	write_param(previous);
	fprintf(stderr, "ZhiXu RT suppression restored to %c.\n", previous);

	return 0;
}
