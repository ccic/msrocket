#	@(#)Makefile	8.8 (Berkeley) 6/21/2000
#
# $TSHeader: src/sbin/growfs/Makefile,v 1.4 2000/12/05 19:45:24 tomsoft Exp $
# $FreeBSD$
#

DIRDEPS = lib/libc
.PATH:	${.CURDIR}/../mount

PACKAGE=runtime
PROG=   appvss
SRCS=   appvss.c
CFLAGS+=-I${.CURDIR}/../mount -g

LIBADD=	util

.include <bsd.prog.mk>
