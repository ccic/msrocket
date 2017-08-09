#include <string.h>
#include <stdio.h>
#include <sys/ioctl.h>
#include <sys/param.h>
#include <sys/ucred.h>
#include <sys/mount.h>
#include <sys/types.h>
#include <unistd.h>
#include <stdlib.h>
#include <poll.h>
#include <stdint.h>
#include <syslog.h>
#include <errno.h>
#include <err.h>
#include <fcntl.h>
#include <ufs/ffs/fs.h>
#include <paths.h>
#include <sys/ioccom.h>
#include <dev/hyperv/hv_snapshot.h>

#define UNDEF_FREEZE_THAW	(0)
#define FREEZE			(1)
#define THAW			(2)
#define CHECK			(3)

#define	VSS_LOG(priority, format, args...) do	{				\
		if (is_debugging == 1) {					\
			if (is_daemon == 1)					\
				syslog(priority, format, ## args);		\
			else							\
				printf(format, ## args);			\
		} else {							\
			if (priority < LOG_DEBUG) {				\
				if (is_daemon == 1)				\
					syslog(priority, format, ## args);	\
				else						\
					printf(format, ## args);		\
			}							\
		}								\
	} while(0)

#define CHECK_TIMEOUT		1
#define CHECK_FAIL		2
#define FREEZE_TIMEOUT		1
#define FREEZE_FAIL		2
#define THAW_TIMEOUT		1
#define THAW_FAIL		2

static int is_daemon        = 1;
static int is_debugging     = 0;
static int simu_opt_waiting = 2; // seconds

#define GENERIC_OPT(TIMEOUT, FAIL)						\
	do {									\
		sleep(simu_opt_waiting);					\
		if (opt == CHECK_TIMEOUT) {					\
			sleep(simu_opt_waiting * 10);				\
			VSS_LOG(LOG_INFO, "%s timeout simulation\n", __func__);	\
			return (0);						\
		} else if (opt == CHECK_FAIL) {					\
			VSS_LOG(LOG_INFO, "%s failure simulation\n", __func__);	\
			return (CHECK_FAIL);					\
		} else {							\
			VSS_LOG(LOG_INFO, "%s success simulation\n", __func__);	\
			return (0);						\
		}								\
	} while (0)

static int
check(int opt)
{
	GENERIC_OPT(CHECK_TIMEOUT, CHECK_FAIL);
}

static int
freeze(int opt)
{
	GENERIC_OPT(FREEZE_TIMEOUT, FREEZE_FAIL);
}

static int
thaw(int opt)
{
	GENERIC_OPT(THAW_TIMEOUT, THAW_FAIL);
}

static void usage(const char* cmd) {
	fprintf(stderr,
	    "%s -f <0|1|2>: simulate app freeze."
	    " 0: successful, 1: freeze timeout, 2: freeze failed\n"
	    " -c <0|1|2>: simulate vss feature check"
	    " 0: supported, 1: check timeout, 2: not supported\n"
	    " -t <0|1|2>: simulate app thaw."
	    " 0: successful, 1: thaw timeout, 2: thaw failed\n"
	    " -d : enable debug mode\n"
	    " -n : run this tool under non-daemon mode\n", cmd);
}

int
main(int argc, char* argv[]) {
	int ch, freezesimuop = 0, thawsimuop = 0, checksimuop = 0, fd, r, error;
	uint32_t op;
	struct pollfd app_vss_fd[1];
	struct hv_vss_opt_msg  userdata;

	while ((ch = getopt(argc, argv, "f:c:t:dnh")) != -1) {
		switch (ch) {
		case 'f':
			/* Run as regular process for debugging purpose. */
			freezesimuop = (int)strtol(optarg, NULL, 10);
			break;
		case 't':
			thawsimuop = (int)strtol(optarg, NULL, 10);
			break;
		case 'c':
			checksimuop = (int)strtol(optarg, NULL, 10);
			break;
		case 'd':
			is_debugging = 1;
			break;
		case 'n':
			is_daemon = 0;
			break;
		case 'h':
		default:
			usage(argv[0]);
			exit(0);
		}
	}

	openlog("APPVSS", 0, LOG_USER);
	/* Become daemon first. */
	if (is_daemon == 1)
		daemon(1, 0);
	else
		VSS_LOG(LOG_DEBUG, "Run as regular process.\n");

	VSS_LOG(LOG_INFO, "HV_VSS starting; pid is: %d\n", getpid());

	fd = open(VSS_DEV(APP_VSS_DEV_NAME), O_RDWR);
	if (fd < 0) {
		VSS_LOG(LOG_ERR, "Fail to open %s, error: %d %s\n",
		    VSS_DEV(APP_VSS_DEV_NAME), errno, strerror(errno));
		exit(EXIT_FAILURE);
	}
	app_vss_fd[0].fd     = fd;
	app_vss_fd[0].events = POLLIN | POLLRDNORM;

	while (1) {
		r = poll(app_vss_fd, 1, INFTIM);

		VSS_LOG(LOG_DEBUG, "poll returned r = %d, revent = 0x%x\n",
		    r, app_vss_fd[0].revents);

		if (r == 0 || (r < 0 && errno == EAGAIN) ||
		    (r < 0 && errno == EINTR)) {
			/* Nothing to read */
			continue;
		}

		if (r < 0) {
			/*
			 * For poll return failure other than EAGAIN,
			 * we want to exit.
			 */
			VSS_LOG(LOG_ERR, "Poll failed.\n");
			perror("poll");
			exit(EIO);
		}

		/* Read from character device */
		error = ioctl(fd, IOCHVVSSREAD, &userdata);
		if (error < 0) {
			VSS_LOG(LOG_ERR, "Read failed.\n");
			perror("pread");
			exit(EIO);
		}

		if (userdata.status != 0) {
			VSS_LOG(LOG_ERR, "data read error\n");
			continue;
		}

		op = userdata.opt;

		switch (op) {
		case HV_VSS_CHECK:
			error = check(checksimuop);
			break;
		case HV_VSS_FREEZE:
			error = freeze(freezesimuop);
			break;
		case HV_VSS_THAW:
			error = thaw(thawsimuop);
			break;
		default:
			VSS_LOG(LOG_ERR, "Illegal operation: %d\n", op);
			error = VSS_FAIL;
		}
		if (error)
			userdata.status = VSS_FAIL;
		else
			userdata.status = VSS_SUCCESS;
		error = ioctl(fd, IOCHVVSSWRITE, &userdata);
		if (error != 0) {
			VSS_LOG(LOG_ERR, "Fail to write to device\n");
			exit(EXIT_FAILURE);
		} else {
			VSS_LOG(LOG_INFO, "Send response %d for %s to kernel\n",
			    userdata.status, op == HV_VSS_FREEZE ? "Freeze" :
			    (op == HV_VSS_THAW ? "Thaw" : "Check"));
		}
	}
	return 0;
}
