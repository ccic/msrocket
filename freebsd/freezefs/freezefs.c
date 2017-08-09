#include <string.h>
#include <stdio.h>
#include <sys/ioctl.h>
#include <sys/param.h>
#include <sys/ucred.h>
#include <sys/mount.h>
#include <sys/types.h>
#include <unistd.h>
#include <stdlib.h>
#include <stdint.h>
#include <errno.h>
#include <err.h>
#include <fcntl.h>
#include <ufs/ffs/fs.h>
#include <paths.h>
#include "hv_snapshot.h"

#define UNDEF_FREEZE_THAW	(0)
#define FREEZE			(1)
#define THAW			(2)
#define CHECK			(3)
#define SLEEP_TIME		(10)

static const char *dev = "/dev";

static int
test_write_tmp(const char* p)
{
	int ret = 0;
	char data[] = "abcdefghij";
	char filename[64];
	const char *test_file = "test_freeze";
	if (p != NULL) {
		snprintf(filename, sizeof(filename), "%s/%s", p, test_file);
	} else {
		snprintf(filename, sizeof(filename), "/tmp/%s", test_file);
	}
	FILE *fp = fopen(filename, "rw+");
	if (!fp) {
		ret = 1;
		printf("Fail to open");
		goto error;
	}
	int len = 5;
	int writelen = fwrite(data, sizeof(char), len, fp);
	if (writelen != len) {
		ret = 2;
		printf("Fail to write the %d character\n", len);
		goto error;
	}
	fclose(fp);
	return 0;
error:
	printf("error in test_write_tmp\n");
	return ret;
}

static int
check(void)
{
	struct statfs *mntbuf, *statfsp;
	int mntsize;
	int i;

	mntsize = getmntinfo(&mntbuf, MNT_NOWAIT);
	if (mntsize == 0) {
		printf("There is no mount information\n");
		return (EINVAL);
	}
	for (i = mntsize - 1; i >= 0; --i)
	{
		statfsp = &mntbuf[i];

		if (strncmp(statfsp->f_mntonname, dev, strlen(dev)) == 0) {
			continue; /* skip to freeze '/dev' */
		} else if (statfsp->f_flags & MNT_RDONLY) {
			continue; /* skip to freeze RDONLY partition */
		} else if (strncmp(statfsp->f_fstypename, "ufs", 3) != 0) {
			printf("The freeze/thaw on file system '%s' is not supported\n",
			    statfsp->f_fstypename);
			return (EPERM); /* only UFS can be freezed */
		}
	}

	return (0);
}

static void freeze(const char* partition, int duration)
{
	struct statfs *mntbuf, *statfsp;
	int mntsize;
	int fso;
	int error = 0;
	int i;
	int write_test_rtn = 0;

	fso = open(_PATH_UFSSUSPEND, O_RDWR);
	if (fso == -1)
		err(1, "unable to open %s", _PATH_UFSSUSPEND);	
	/*
	 * First check the mounted filesystems.
	 */
	mntsize = getmntinfo(&mntbuf, MNT_NOWAIT);
	if (mntsize == 0)
		return;

	printf("mnt size: %d\n", mntsize);
	for(i = mntsize - 1; i >= 0; --i)
	{
		statfsp = &mntbuf[i];
		printf("fstype: %s, on '%s' from '%s'\n",
			statfsp->f_fstypename,
			statfsp->f_mntonname, statfsp->f_mntfromname);
		if (strncmp(statfsp->f_mntonname, dev, strlen(dev)) == 0) {
			continue; /* skip to freeze '/dev' */
		} else if (statfsp->f_flags & MNT_RDONLY) {
			continue; /* skip to freeze RDONLY partition */
		} else if (strncmp(statfsp->f_fstypename, "ufs", 3) != 0) {
			continue; /* only UFS can be freezed */
		}

		if ((partition == NULL && strcmp("/", statfsp->f_mntonname) == 0) ||
		    (partition != NULL && strncmp(statfsp->f_mntonname,
		    partition, strlen(partition)) == 0)) {
			if (partition == NULL) {
				partition = statfsp->f_mntonname;
			}
			printf("begin to suspend on '%s'\n", partition);

			error = ioctl(fso, UFSSUSPEND, &statfsp->f_fsid);
			if (error != 0) {
				printf("error: %d\n",errno);
			} else {
				printf("Successfully suspend filesystem\n");
			}
			break;
		}
	}
	if (error == 0) {
		sleep(duration); /* how long time to freeze */
		write_test_rtn = test_write_tmp(partition);
		if (!write_test_rtn) {
			printf("Successfully write something\n");
		}
	}
	close(fso); /* Stop freeze once the file handle is closed */
}
#if 0
static void thaw_allmountpoints()
{
	struct statfs *mntbuf, *statfsp;
	int mntsize;
	int fso;
	int error;
	int i;
	fso = open(_PATH_UFSSUSPEND, O_RDWR);
	if (fso == -1)
		err(1, "unable to open %s", _PATH_UFSSUSPEND);	
	/*
	 * First check the mounted filesystems.
	 */
	mntsize = getmntinfo(&mntbuf, MNT_NOWAIT);
	if (mntsize == 0)
		return;

	for(i = mntsize - 1; i >= 0; --i)
	{
		statfsp = &mntbuf[i];

		if (strcmp("/", statfsp->f_mntonname) == 0 ||
			strcmp("ufs", statfsp->f_fstypename) == 0) {
			printf("begin to resume ufs\n");
			error = ioctl(fso, UFSRESUME);
			if (error != 0) {
				printf("error: %d\n",errno);
			} else {
				printf("Successfully resume filesystem\n");
			}
			break;
		}
	}

	close(fso);

}
#endif

static void usage(const char* cmd) {
	fprintf(stderr, "%s -f : freeze the root filesystem\n"
	    /* " -t : thaw the filesystem\n" */
	    " -c : check whether freeze/thaw is supported\n"
	    " -F <partition> : freeze the specified partition\n"
	    " -d <duration> : specify the duration (s) for freezing."
	    " Default is %ds\n",
		 cmd, SLEEP_TIME);
	exit(1);
}

int main(int argc, char* argv[]) {
	int ch;
	int freeze_thaw = UNDEF_FREEZE_THAW;
	const char* partition = NULL;
	int freeze_dur = SLEEP_TIME;
	int status;
	while ((ch = getopt(argc, argv, "F:d:fc")) != -1) {
		switch (ch) {
		case 'f':
			/* Run as regular process for debugging purpose. */
			freeze_thaw = FREEZE;
			break;
#if 0
		case 't':
			/* Generate debugging output */
			freeze_thaw = THAW;
			break;
#endif
		case 'F':
			freeze_thaw = FREEZE;
			partition = optarg;
			break;
		case 'd':
			freeze_dur = (int)strtol(optarg, NULL, 10);
			break;
		case 'c':
			freeze_thaw = CHECK;
			break;
		default:
			usage(argv[0]);
			break;
		}
	}
	if (freeze_thaw == FREEZE) {
		freeze(partition, freeze_dur);
	} else if (freeze_thaw == CHECK) {
		status = check();
		if (status == 0) {
			printf("Support freeze/thaw\n");
		} else {
			printf("Not Support freeze/thaw\n");
		}
	} else {
		usage(argv[0]);
	}
	return 0;
}
