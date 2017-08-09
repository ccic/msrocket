#	@(#)Makefile	8.8 (Berkeley) 6/21/2000
#
# $TSHeader: src/sbin/growfs/Makefile,v 1.4 2000/12/05 19:45:24 tomsoft Exp $
# $FreeBSD$
#

.include <src.opts.mk>

.PATH:	${.CURDIR}/../mount

PACKAGE=runtime
PROG=   freezefs
SRCS=   freezefs.c getmntopts.c
CFLAGS+=-I${.CURDIR}/../mount -g -DFS_DEBUG

LIBADD=	util

.if ${MK_TESTS} != "no"
SUBDIR+= 
.endif

.include <bsd.prog.mk>
