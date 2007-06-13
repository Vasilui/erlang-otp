/* ``The contents of this file are subject to the Erlang Public License,
 * Version 1.1, (the "License"); you may not use this file except in
 * compliance with the License. You should have received a copy of the
 * Erlang Public License along with this software. If not, it can be
 * retrieved via the world wide web at http://www.erlang.org/.
 * 
 * Software distributed under the License is distributed on an "AS IS"
 * basis, WITHOUT WARRANTY OF ANY KIND, either express or implied. See
 * the License for the specific language governing rights and limitations
 * under the License.
 * 
 * The Initial Developer of the Original Code is Ericsson Utvecklings AB.
 * Portions created by Ericsson are Copyright 1999, Ericsson Utvecklings
 * AB. All Rights Reserved.''
 *
 * The SCTP protocol was added 2006
 * by Leonid Timochouk <l.timochouk@gmail.com>
 * and Serge Aleynikov  <serge@hq.idt.net>
 * at IDT Corp. Adapted by the OTP team at Ericsson AB.
 * 
 *     $Id$
 */

#ifdef HAVE_CONFIG_H
#include "config.h"
#endif

/* If we HAVE_SCTP_H and Solaris, we need to define the following in
   order to get SCTP working:
*/
#if (defined(HAVE_SCTP_H) && defined(__sun) && defined(__SVR4))
#define  SOLARIS10    1
/* WARNING: This is not quite correct, it may also be Solaris 11! */
#define  _XPG4_2
#define  __EXTENSIONS__
#endif

#include <stdio.h>
#include <stdlib.h>
#include <ctype.h>
#include <sys/types.h>
#include <errno.h>

#ifndef _OSE_
#ifdef HAVE_UNISTD_H
#include <unistd.h>
#endif
#ifdef HAVE_SYS_UIO_H
#include <sys/uio.h>
#endif
#endif

/* use http processing */
#define USE_HTTP 
/* All platforms fail on malloc errors. */
#define FATAL_MALLOC


#include "erl_driver.h"

#ifdef __WIN32__
#define  STRNCASECMP strncasecmp

#define INCL_WINSOCK_API_TYPEDEFS 1

#ifndef WINDOWS_H_INCLUDES_WINSOCK2_H
#include <winsock2.h>
#endif
#include <windows.h>

#include <Ws2tcpip.h>   /* NEED VC 6.0 !!! */

#undef WANT_NONBLOCKING
#include "sys.h"

#undef EWOULDBLOCK
#undef ETIMEDOUT

#define HAVE_MULTICAST_SUPPORT

#define ERRNO_BLOCK             WSAEWOULDBLOCK

#define EWOULDBLOCK             WSAEWOULDBLOCK
#define EINPROGRESS             WSAEINPROGRESS
#define EALREADY                WSAEALREADY
#define ENOTSOCK                WSAENOTSOCK
#define EDESTADDRREQ            WSAEDESTADDRREQ
#define EMSGSIZE                WSAEMSGSIZE
#define EPROTOTYPE              WSAEPROTOTYPE
#define ENOPROTOOPT             WSAENOPROTOOPT
#define EPROTONOSUPPORT         WSAEPROTONOSUPPORT
#define ESOCKTNOSUPPORT         WSAESOCKTNOSUPPORT
#define EOPNOTSUPP              WSAEOPNOTSUPP
#define EPFNOSUPPORT            WSAEPFNOSUPPORT
#define EAFNOSUPPORT            WSAEAFNOSUPPORT
#define EADDRINUSE              WSAEADDRINUSE
#define EADDRNOTAVAIL           WSAEADDRNOTAVAIL
#define ENETDOWN                WSAENETDOWN
#define ENETUNREACH             WSAENETUNREACH
#define ENETRESET               WSAENETRESET
#define ECONNABORTED            WSAECONNABORTED
#define ECONNRESET              WSAECONNRESET
#define ENOBUFS                 WSAENOBUFS
#define EISCONN                 WSAEISCONN
#define ENOTCONN                WSAENOTCONN
#define ESHUTDOWN               WSAESHUTDOWN
#define ETOOMANYREFS            WSAETOOMANYREFS
#define ETIMEDOUT               WSAETIMEDOUT
#define ECONNREFUSED            WSAECONNREFUSED
#define ELOOP                   WSAELOOP
#undef ENAMETOOLONG
#define ENAMETOOLONG            WSAENAMETOOLONG
#define EHOSTDOWN               WSAEHOSTDOWN
#define EHOSTUNREACH            WSAEHOSTUNREACH
#undef ENOTEMPTY
#define ENOTEMPTY               WSAENOTEMPTY
#define EPROCLIM                WSAEPROCLIM
#define EUSERS                  WSAEUSERS
#define EDQUOT                  WSAEDQUOT
#define ESTALE                  WSAESTALE
#define EREMOTE                 WSAEREMOTE

#define INVALID_EVENT           WSA_INVALID_EVENT

static BOOL (WINAPI *fpSetHandleInformation)(HANDLE,DWORD,DWORD);

#define sock_open(af, type, proto) \
    make_noninheritable_handle(socket((af), (type), (proto)))
#define sock_close(s)              closesocket((s))
#define sock_shutdown(s, how)      shutdown((s), (how))

#define sock_accept(s, addr, len) \
    make_noninheritable_handle(accept((s), (addr), (len)))
#define sock_connect(s, addr, len) connect((s), (addr), (len))
#define sock_listen(s, b)          listen((s), (b))
#define sock_bind(s, addr, len)    bind((s), (addr), (len))
#define sock_getopt(s,t,n,v,l)     getsockopt((s),(t),(n),(v),(l))
#define sock_setopt(s,t,n,v,l)     setsockopt((s),(t),(n),(v),(l))
#define sock_name(s, addr, len)    getsockname((s), (addr), (len))
#define sock_peer(s, addr, len)    getpeername((s), (addr), (len))
#define sock_ntohs(x)              ntohs((x))
#define sock_ntohl(x)              ntohl((x))
#define sock_htons(x)              htons((x))
#define sock_htonl(x)              htonl((x))
#define sock_send(s,buf,len,flag)  send((s),(buf),(len),(flag))
#define sock_sendv(s, vec, size, np, flag) \
                WSASend((s),(WSABUF*)(vec),\
				   (size),(np),(flag),NULL,NULL)
#define sock_recv(s,buf,len,flag)  recv((s),(buf),(len),(flag))

#define sock_recvfrom(s,buf,blen,flag,addr,alen) \
                recvfrom((s),(buf),(blen),(flag),(addr),(alen))
#define sock_sendto(s,buf,blen,flag,addr,alen) \
                sendto((s),(buf),(blen),(flag),(addr),(alen))
#define sock_hostname(buf, len)    gethostname((buf), (len))

#define sock_getservbyname(name,proto) getservbyname((name),(proto))
#define sock_getservbyport(port,proto) getservbyport((port),(proto))

#define sock_errno() WSAGetLastError()
#define sock_create_event(d)       WSACreateEvent()
#define sock_close_event(e)        WSACloseEvent(e)

#define sock_select(D, Flags, OnOff) winsock_event_select(D, Flags, OnOff)

#define SET_BLOCKING(s)           ioctlsocket(s, FIONBIO, &zero_value)
#define SET_NONBLOCKING(s)        ioctlsocket(s, FIONBIO, &one_value)


static unsigned long zero_value = 0;
static unsigned long one_value = 1;

#else

#ifdef VXWORKS
#include <sockLib.h>
#include <sys/times.h>
#include <iosLib.h>
#include <taskLib.h>
#include <selectLib.h>
#include <ioLib.h>
#else
#include <sys/time.h>
#ifdef NETDB_H_NEEDS_IN_H
#include <netinet/in.h>
#endif
#include <netdb.h>
#endif

#ifndef _OSE_
#include <sys/socket.h>
#include <netinet/in.h>
#else
/* datatypes and macros from Solaris socket.h */
struct  linger {
        int     l_onoff;                /* option on/off */
        int     l_linger;               /* linger time */
};
#define SO_OOBINLINE    0x0100          /* leave received OOB data in line */
#define SO_LINGER       0x0080          /* linger on close if data present */
#endif

#ifdef VXWORKS
#include <rpc/rpctypes.h>
#endif
#ifdef DEF_INADDR_LOOPBACK_IN_RPC_TYPES_H
#include <rpc/types.h>
#endif

#ifndef _OSE_
#include <netinet/tcp.h>
#include <arpa/inet.h>
#endif

#if (!defined(VXWORKS) && !defined(_OSE_))
#include <sys/param.h>
#ifdef HAVE_ARPA_NAMESER_H
#include <arpa/nameser.h>
#endif
#endif

#ifdef HAVE_SYS_SOCKIO_H
#include <sys/sockio.h>
#endif

#ifdef HAVE_SYS_IOCTL_H
#include <sys/ioctl.h>
#endif

#ifndef _OSE_
#include <net/if.h>
#else
#define IFF_MULTICAST 0x00000800
#endif

#ifdef _OSE_
#include "inet.h"
#include "ineterr.h"
#include "ose_inet_drv.h"
#include "nameser.h" 
#include "resolv.h"
#define SET_ASYNC(s) setsockopt((s), SOL_SOCKET, SO_OSEEVENT, (&(s)), sizeof(int))

extern void select_release(void);

#endif /* _OSE_ */

/* Solaris headers, only to be used with SFK */
#ifdef _OSE_SFK_
#include <ctype.h>
#include <string.h>
#endif

/* SCTP support -- currently for UNIX platforms only: */
#undef HAVE_SCTP
#if (!defined(VXWORKS) && !defined(_OSE_) && !defined(__WIN32__) && defined(HAVE_SCTP_H))

#include <netinet/sctp.h>

/* SCTP Socket API Draft from version 11 on specifies that netinet/sctp.h must
   explicitly define HAVE_SCTP in case when SCTP is supported,  but Solaris 10
   still apparently uses Draft 10, and does not define that symbol, so we have
   to define it explicitly:
*/
#ifndef     HAVE_SCTP
#    define HAVE_SCTP
#endif

/* These changed in draft 11, so SOLARIS10 uses the old MSG_* */
#if ! HAVE_DECL_SCTP_UNORDERED
#     define    SCTP_UNORDERED  MSG_UNORDERED
#endif
#if ! HAVE_DECL_SCTP_ADDR_OVER
#     define    SCTP_ADDR_OVER  MSG_ADDR_OVER
#endif
#if ! HAVE_DECL_SCTP_ABORT
#     define    SCTP_ABORT      MSG_ABORT
#endif
#if ! HAVE_DECL_SCTP_EOF
#     define    SCTP_EOF        MSG_EOF
#endif

#endif /* SCTP supported */

#ifndef WANT_NONBLOCKING
#define WANT_NONBLOCKING
#endif
#include "sys.h"

/* #define INET_DRV_DEBUG 1 */
#ifdef INET_DRV_DEBUG
#define DEBUG 1
#undef DEBUGF
#define DEBUGF(X) printf X
#endif

#if !defined(__WIN32__) && !defined(HAVE_STRNCASECMP)
#define STRNCASECMP my_strncasecmp

static int my_strncasecmp(const char *s1, const char *s2, size_t n)
{
    int i;

    for (i=0;i<n-1 && s1[i] && s2[i] && toupper(s1[i]) == toupper(s2[i]);++i)
	;
    return (toupper(s1[i]) - toupper(s2[i]));
}
	

#else
#define  STRNCASECMP strncasecmp
#endif

#define INVALID_SOCKET -1
#define INVALID_EVENT  -1
#define SOCKET_ERROR   -1
#define SOCKET int
#define HANDLE long int
#define FD_READ    DO_READ
#define FD_WRITE   DO_WRITE
#define FD_CLOSE   0
#define FD_CONNECT DO_WRITE
#define FD_ACCEPT  DO_READ

#define sock_connect(s, addr, len)  connect((s), (addr), (len))
#define sock_listen(s, b)           listen((s), (b))
#define sock_bind(s, addr, len)     bind((s), (addr), (len))
#ifdef VXWORKS
#define sock_getopt(s,t,n,v,l)      wrap_sockopt(&getsockopt,\
                                                 s,t,n,v,(unsigned int)(l))
#define sock_setopt(s,t,n,v,l)      wrap_sockopt(&setsockopt,\
                                                 s,t,n,v,(unsigned int)(l))
#else
#define sock_getopt(s,t,n,v,l)      getsockopt((s),(t),(n),(v),(l))
#define sock_setopt(s,t,n,v,l)      setsockopt((s),(t),(n),(v),(l))
#endif
#define sock_name(s, addr, len)     getsockname((s), (addr), (len))
#define sock_peer(s, addr, len)     getpeername((s), (addr), (len))
#define sock_ntohs(x)               ntohs((x))
#define sock_ntohl(x)               ntohl((x))
#define sock_htons(x)               htons((x))
#define sock_htonl(x)               htonl((x))

#ifdef _OSE_
#define sock_accept(s, addr, len)   ose_inet_accept((s), (addr), (len))
#define sock_send(s,buf,len,flag)   ose_inet_send((s),(buf),(len),(flag))
#define sock_sendto(s,buf,blen,flag,addr,alen) \
                ose_inet_sendto((s),(buf),(blen),(flag),(addr),(alen))
#define sock_sendv(s, vec, size, np, flag) \
		(*(np) = ose_inet_sendv((s), (SysIOVec*)(vec), (size)))
#define sock_open(af, type, proto)  ose_inet_socket((af), (type), (proto))
#define sock_close(s)               ose_inet_close((s))
#define sock_hostname(buf, len)     ose_gethostname((buf), (len))
#define sock_getservbyname(name,proto) ose_getservbyname((name), (proto))
#define sock_getservbyport(port,proto) ose_getservbyport((port), (proto))

#else
#define sock_accept(s, addr, len)   accept((s), (addr), (len))
#define sock_send(s,buf,len,flag)   send((s),(buf),(len),(flag))
#define sock_sendto(s,buf,blen,flag,addr,alen) \
                sendto((s),(buf),(blen),(flag),(addr),(alen))
#define sock_sendv(s, vec, size, np, flag) \
		(*(np) = writev((s), (struct iovec*)(vec), (size)))
#define sock_sendmsg(s,msghdr,flag) sendmsg((s),(msghdr),(flag))

#define sock_open(af, type, proto)  socket((af), (type), (proto))
#define sock_close(s)               close((s))
#define sock_shutdown(s, how)       shutdown((s), (how))

#define sock_hostname(buf, len)     gethostname((buf), (len))
#define sock_getservbyname(name,proto) getservbyname((name), (proto))
#define sock_getservbyport(port,proto) getservbyport((port), (proto))
#endif /* _OSE_ */

#define sock_recv(s,buf,len,flag)   recv((s),(buf),(len),(flag))
#define sock_recvfrom(s,buf,blen,flag,addr,alen) \
                recvfrom((s),(buf),(blen),(flag),(addr),(alen))
#define sock_recvmsg(s,msghdr,flag) recvmsg((s),(msghdr),(flag))

#define sock_errno()                errno
#define sock_create_event(d)        ((d)->s) /* return file descriptor */
#define sock_close_event(e)                  /* do nothing */

#ifdef _OSE_
#define inet_driver_select(port, e, mode, on) \
                                    ose_inet_select(port, e, mode, on)
#else
#define inet_driver_select(port, e, mode, on) \
                                    driver_select(port, e, mode, on)
#endif /* _OSE_ */

#define sock_select(d, flags, onoff) do { \
        (d)->event_mask = (onoff) ? \
                 ((d)->event_mask | (flags)) : \
                 ((d)->event_mask & ~(flags)); \
        DEBUGF(("sock_select(%ld): flags=%02X, onoff=%d, event_mask=%02lX\r\n", 		(long) (d)->port, (flags), (onoff), (unsigned long) (d)->event_mask)); \
        inet_driver_select((d)->port, (ErlDrvEvent)(long)(d)->event, (flags), (onoff)); \
   } while(0)


#endif /* __WIN32__ */

#define get_int24(s) ((((unsigned char*) (s))[0] << 16) | \
                      (((unsigned char*) (s))[1] << 8)  | \
                      (((unsigned char*) (s))[2]))

#define get_little_int32(s) ((((unsigned char*) (s))[3] << 24) | \
			     (((unsigned char*) (s))[2] << 16)  | \
			     (((unsigned char*) (s))[1] << 8) | \
			     (((unsigned char*) (s))[0]))

/*----------------------------------------------------------------------------
** Interface constants.
** 
** This section must be "identical" to the corresponding inet_int.hrl
*/

/* general address encode/decode tag */
#define INET_AF_INET        1
#define INET_AF_INET6       2
#define INET_AF_ANY         3 /* INADDR_ANY or IN6ADDR_ANY_INIT */
#define INET_AF_LOOPBACK    4 /* INADDR_LOOPBACK or IN6ADDR_LOOPBACK_INIT */

/* INET_REQ_GETTYPE enumeration */
#define INET_TYPE_STREAM    1
#define INET_TYPE_DGRAM     2
#define INET_TYPE_SEQPACKET 3

/* INET_LOPT_MODE options */
#define INET_MODE_LIST      0
#define INET_MODE_BINARY    1

/* INET_LOPT_DELIVER options */
#define INET_DELIVER_PORT   0
#define INET_DELIVER_TERM   1

/* INET_LOPT_ACTIVE options */
#define INET_PASSIVE        0  /* false */
#define INET_ACTIVE         1  /* true */
#define INET_ONCE           2  /* true; active once then passive */

/* INET_REQ_GETSTATUS enumeration */
#define INET_F_OPEN         0x0001
#define INET_F_BOUND        0x0002
#define INET_F_ACTIVE       0x0004
#define INET_F_LISTEN       0x0008
#define INET_F_CON          0x0010
#define INET_F_ACC          0x0020
#define INET_F_LST          0x0040
#define INET_F_BUSY         0x0080 
#define INET_F_MULTI_CLIENT 0x0100 /* Multiple clients for one descriptor, i.e. multi-accept */

/* One numberspace for *_REC_* so if an e.g UDP request is issued
** for a TCP socket, the driver can protest.
*/
#define INET_REQ_OPEN          1
#define INET_REQ_CLOSE         2
#define INET_REQ_CONNECT       3
#define INET_REQ_PEER          4
#define INET_REQ_NAME          5
#define INET_REQ_BIND          6
#define INET_REQ_SETOPTS       7
#define INET_REQ_GETOPTS       8
/* #define INET_REQ_GETIX         9  NOT USED ANY MORE */
/* #define INET_REQ_GETIF         10 REPLACE BY NEW STUFF */
#define INET_REQ_GETSTAT       11
#define INET_REQ_GETHOSTNAME   12
#define INET_REQ_FDOPEN        13
#define INET_REQ_GETFD         14
#define INET_REQ_GETTYPE       15
#define INET_REQ_GETSTATUS     16
#define INET_REQ_GETSERVBYNAME 17
#define INET_REQ_GETSERVBYPORT 18
#define INET_REQ_SETNAME       19
#define INET_REQ_SETPEER       20
#define INET_REQ_GETIFLIST     21
#define INET_REQ_IFGET         22
#define INET_REQ_IFSET         23
#define INET_REQ_SUBSCRIBE     24
/* TCP requests */
#define TCP_REQ_ACCEPT         40
#define TCP_REQ_LISTEN         41
#define TCP_REQ_RECV           42
#define TCP_REQ_UNRECV         43
#define TCP_REQ_SHUTDOWN       44
#define TCP_REQ_MULTI_OP       45
/* UDP and SCTP requests */
#define PACKET_REQ_RECV        60 /* Common for UDP and SCTP         */
#define SCTP_REQ_LISTEN	       61 /* Different from TCP; not for UDP */
#define SCTP_REQ_BINDX	       62 /* Multi-home SCTP bind            */

/* INET_REQ_SUBSCRIBE sub-requests */
#define INET_SUBS_EMPTY_OUT_Q  1

/* TCP additional flags */
#define TCP_ADDF_DELAY_SEND    1
#define TCP_ADDF_CLOSE_SENT    2

/* *_REQ_* replies */
#define INET_REP_ERROR       0
#define INET_REP_OK          1
#define INET_REP_SCTP        2

/* INET_REQ_SETOPTS and INET_REQ_GETOPTS options */
#define INET_OPT_REUSEADDR  0   /* enable/disable local address reuse */
#define INET_OPT_KEEPALIVE  1   /* enable/disable keep connections alive */
#define INET_OPT_DONTROUTE  2   /* enable/disable routing for messages */
#define INET_OPT_LINGER     3   /* linger on close if data is present */
#define INET_OPT_BROADCAST  4   /* enable/disable transmission of broadcast */
#define INET_OPT_OOBINLINE  5   /* enable/disable out-of-band data in band */
#define INET_OPT_SNDBUF     6   /* set send buffer size */
#define INET_OPT_RCVBUF     7   /* set receive buffer size */
#define INET_OPT_PRIORITY   8   /* set priority */
#define INET_OPT_TOS        9   /* Set type of service */
#define TCP_OPT_NODELAY     10  /* don't delay send to coalesce packets */
#define UDP_OPT_MULTICAST_IF 11  /* set/get IP multicast interface */
#define UDP_OPT_MULTICAST_TTL 12 /* set/get IP multicast timetolive */
#define UDP_OPT_MULTICAST_LOOP 13 /* set/get IP multicast loopback */
#define UDP_OPT_ADD_MEMBERSHIP 14 /* add an IP group membership */
#define UDP_OPT_DROP_MEMBERSHIP 15 /* drop an IP group membership */
/* LOPT is local options */
#define INET_LOPT_BUFFER      20  /* min buffer size hint */
#define INET_LOPT_HEADER      21  /* list header size */
#define INET_LOPT_ACTIVE      22  /* enable/disable active receive */
#define INET_LOPT_PACKET      23  /* packet header type (TCP) */
#define INET_LOPT_MODE        24  /* list or binary mode */
#define INET_LOPT_DELIVER     25  /* port or term delivery */
#define INET_LOPT_EXITONCLOSE 26  /* exit port on active close or not ! */
#define INET_LOPT_TCP_HIWTRMRK     27  /* set local high watermark */
#define INET_LOPT_TCP_LOWTRMRK     28  /* set local low watermark */
#define INET_LOPT_BIT8             29  /* set 8 bit detection */
#define INET_LOPT_TCP_SEND_TIMEOUT 30  /* set send timeout */
#define INET_LOPT_TCP_DELAY_SEND   31  /* Delay sends until next poll */
#define INET_LOPT_PACKET_SIZE      32  /* Max packet size */
#define INET_LOPT_UDP_READ_PACKETS 33  /* Number of packets to read */
#define INET_OPT_RAW               34  /* Raw socket options */
/* SCTP options: a separate range, from 100: */
#define SCTP_OPT_RTOINFO		100
#define SCTP_OPT_ASSOCINFO		101
#define SCTP_OPT_INITMSG		102
#define SCTP_OPT_AUTOCLOSE		103
#define SCTP_OPT_NODELAY		104
#define SCTP_OPT_DISABLE_FRAGMENTS	105
#define SCTP_OPT_I_WANT_MAPPED_V4_ADDR	106
#define SCTP_OPT_MAXSEG			107
#define SCTP_OPT_SET_PEER_PRIMARY_ADDR  108
#define SCTP_OPT_PRIMARY_ADDR		109
#define SCTP_OPT_ADAPTION_LAYER 	110
#define SCTP_OPT_PEER_ADDR_PARAMS	111
#define SCTP_OPT_DEFAULT_SEND_PARAM	112
#define SCTP_OPT_EVENTS			113
#define SCTP_OPT_DELAYED_ACK_TIME	114
#define SCTP_OPT_STATUS			115
#define SCTP_OPT_GET_PEER_ADDR_INFO	116

/* INET_REQ_IFGET and INET_REQ_IFSET options */
#define INET_IFOPT_ADDR       1
#define INET_IFOPT_BROADADDR  2
#define INET_IFOPT_DSTADDR    3
#define INET_IFOPT_MTU        4
#define INET_IFOPT_NETMASK    5
#define INET_IFOPT_FLAGS      6
#define INET_IFOPT_HWADDR     7

/* INET_LOPT_PACKET options */
#define TCP_PB_RAW     0
#define TCP_PB_1       1
#define TCP_PB_2       2
#define TCP_PB_4       3
#define TCP_PB_ASN1    4
#define TCP_PB_RM      5
#define TCP_PB_CDR     6
#define TCP_PB_FCGI    7
#define TCP_PB_LINE_LF 8
#define TCP_PB_TPKT    9
#define TCP_PB_HTTP    10
#define TCP_PB_HTTPH   11

/* INET_LOPT_BIT8 options */
#define INET_BIT8_CLEAR 0
#define INET_BIT8_SET   1
#define INET_BIT8_ON    2
#define INET_BIT8_OFF   3

/* INET_REQ_GETSTAT enumeration */
#define INET_STAT_RECV_CNT   1
#define INET_STAT_RECV_MAX   2
#define INET_STAT_RECV_AVG   3
#define INET_STAT_RECV_DVI   4
#define INET_STAT_SEND_CNT   5
#define INET_STAT_SEND_MAX   6
#define INET_STAT_SEND_AVG   7
#define INET_STAT_SEND_PND   8
#define INET_STAT_RECV_OCT   9      /* received octets */ 
#define INET_STAT_SEND_OCT   10     /* sent octets */

/* INET_IFOPT_FLAGS enumeration */
#define INET_IFF_UP            0x0001
#define INET_IFF_BROADCAST     0x0002
#define INET_IFF_LOOPBACK      0x0004
#define INET_IFF_POINTTOPOINT  0x0008
#define INET_IFF_RUNNING       0x0010
#define INET_IFF_MULTICAST     0x0020
/* Complement flags for turning them off */
#define INET_IFF_DOWN            0x0100
#define INET_IFF_NBROADCAST      0x0200
/* #define INET_IFF_NLOOPBACK    0x0400 */
#define INET_IFF_NPOINTTOPOINT   0x0800
/* #define INET_IFF_NRUNNING     0x1000 */
/* #define INET_IFF_NMULTICAST   0x2000 */

/* Flags for "sctp_sndrcvinfo". Used in a bitmask -- must be powers of 2:
** INET_REQ_SETOPTS:SCTP_OPT_DEFAULT_SEND_PARAM
*/
#define SCTP_FLAG_UNORDERED (1 /* am_unordered */)
#define SCTP_FLAG_ADDR_OVER (2 /* am_addr_over */)
#define SCTP_FLAG_ABORT     (4 /* am_abort */)
#define SCTP_FLAG_EOF       (8 /* am_eof */)
#define SCTP_FLAG_SNDALL   (16 /* am_sndall, NOT YET IMPLEMENTED */)

/* Flags for "sctp_set_opts" (actually for SCTP_OPT_PEER_ADDR_PARAMS).
** These flags are also used in a bitmask, so they must be powers of 2:
*/
#define SCTP_FLAG_HB_ENABLE	    (1 /* am_hb_enable */)
#define SCTP_FLAG_HB_DISABLE	    (2 /* am_hb_disable */)
#define SCTP_FLAG_HB_DEMAND	    (4 /* am_hb_demand */)
#define	SCTP_FLAG_PMTUD_ENABLE	    (8 /* am_pmtud_enable */)
#define	SCTP_FLAG_PMTUD_DISABLE    (16 /* am_pmtud_disable */)
#define SCTP_FLAG_SACDELAY_ENABLE  (32 /* am_sackdelay_enable */)
#define SCTP_FLAG_SACDELAY_DISABLE (64 /* am_sackdelay_disable */)

/*
** End of interface constants.
**--------------------------------------------------------------------------*/

#define INET_STATE_CLOSED    0
#define INET_STATE_OPEN      (INET_F_OPEN)
#define INET_STATE_BOUND     (INET_STATE_OPEN | INET_F_BOUND)
#define INET_STATE_CONNECTED (INET_STATE_BOUND | INET_F_ACTIVE)

#define IS_OPEN(d) \
 (((d)->state & INET_F_OPEN) == INET_F_OPEN)

#define IS_BOUND(d) \
 (((d)->state & INET_F_BOUND) == INET_F_BOUND)

#define IS_CONNECTED(d) \
  (((d)->state & INET_STATE_CONNECTED) == INET_STATE_CONNECTED)

#define IS_CONNECTING(d) \
  (((d)->state & INET_F_CON) == INET_F_CON)

#define IS_BUSY(d) \
  (((d)->state & INET_F_BUSY) == INET_F_BUSY)

#define INET_DEF_BUFFER     1460        /* default buffer size */
#define INET_MIN_BUFFER     1           /* internal min buffer */
#define INET_MAX_BUFFER     (1024*64)   /* internal max buffer */

/* Note: INET_HIGH_WATERMARK MUST be less than 2*INET_MAX_BUFFER */
#define INET_HIGH_WATERMARK (1024*8) /* 8k pending high => busy  */
/* Note: INET_LOW_WATERMARK MUST be less than INET_MAX_BUFFER and
** less than INET_HIGH_WATERMARK
*/
#define INET_LOW_WATERMARK  (1024*4) /* 4k pending => allow more */

#define INET_INFINITY  0xffffffff  /* infinity value */

#define INET_MAX_ASYNC 1           /* max number of async queue ops */

/* INET_LOPT_UDP_PACKETS */
#define INET_PACKET_POLL     5   /* maximum number of packets to poll */

/* Max interface name */
#define INET_IFNAMSIZ          16

/* Max length of Erlang Term Buffer (for outputting structured terms):  */
#ifdef  HAVE_SCTP
#define PACKET_ERL_DRV_TERM_DATA_LEN  512
#else
#define PACKET_ERL_DRV_TERM_DATA_LEN  32
#endif


#define BIN_REALLOC_LIMIT(x)  (((x)*3)/4)  /* 75% */

/* The general purpose sockaddr */
typedef union {
    struct sockaddr sa;
    struct sockaddr_in sai;
#ifdef HAVE_IN6
    struct sockaddr_in6 sai6;
#endif
} inet_address;


/* for AF_INET & AF_INET6 */
#define inet_address_port(x) ((x)->sai.sin_port)

#if defined(HAVE_IN6) && defined(AF_INET6)
#define addrlen(family) \
   ((family == AF_INET) ? sizeof(struct in_addr) : \
    ((family == AF_INET6) ? sizeof(struct in6_addr) : 0))
#else
#define addrlen(family) \
   ((family == AF_INET) ? sizeof(struct in_addr) : 0)
#endif

typedef struct _multi_timer_data {
    ErlDrvNowData when;
    ErlDrvTermData caller;
    void (*timeout_function)(ErlDrvData drv_data, ErlDrvTermData caller);
    struct _multi_timer_data *next;
    struct _multi_timer_data *prev;
} MultiTimerData;

static MultiTimerData *add_multi_timer(MultiTimerData **first, ErlDrvPort port, 
			    ErlDrvTermData caller, unsigned timeout,
			    void (*timeout_fun)(ErlDrvData drv_data,
						ErlDrvTermData caller));
static void fire_multi_timers(MultiTimerData **first, ErlDrvPort port,
			      ErlDrvData data);
static void remove_multi_timer(MultiTimerData **first, ErlDrvPort port, MultiTimerData *p);

static void tcp_inet_multi_timeout(ErlDrvData e, ErlDrvTermData caller);
static void clean_multi_timers(MultiTimerData **first, ErlDrvPort port);

typedef struct {
    int            id;      /* id used to identify reply */
    ErlDrvTermData caller;  /* recipient of async reply */
    int            req;     /* Request id (CONNECT/ACCEPT/RECV) */
    union {
	unsigned       value; /* Request timeout (since op issued,not started) */
	MultiTimerData *mtd;
    } tmo;
    ErlDrvMonitor monitor;
} inet_async_op;

typedef struct inet_async_multi_op_ {
    inet_async_op op;
    struct inet_async_multi_op_ *next;
} inet_async_multi_op;


typedef struct subs_list_ {
  ErlDrvTermData subscriber;
  struct subs_list_ *next;
} subs_list;

#define NO_PROCESS 0
#define NO_SUBSCRIBERS(SLP) ((SLP)->subscriber == NO_PROCESS)
static void send_to_subscribers(ErlDrvPort, subs_list *, int,
				ErlDrvTermData [], int);
static void free_subscribers(subs_list*);
static int save_subscriber(subs_list *, ErlDrvTermData);

typedef struct {
    SOCKET s;                   /* the socket or INVALID_SOCKET if not open */
    HANDLE event;               /* Event handle (same as s in unix) */
    long  event_mask;           /* current FD events */
#ifdef __WIN32__
    long forced_events;           /* Mask of events that are forcefully signalled 
				   on windows see winsock_event_select 
				   for details */

#endif
    ErlDrvPort  port;           /* the port identifier */
    ErlDrvTermData dport;       /* the port identifier as DriverTermData */
    int   state;                /* status */
    int   prebound;             /* only set when opened with inet_fdopen */
    int   mode;                 /* BINARY | LIST
				   (affect how to interpret hsz) */
    int   exitf;                /* exit port on close or not */
    int   bit8f;                /* check if data has bit number 7 set */
    int   deliver;              /* Delivery mode, TERM or PORT */

    ErlDrvTermData caller;      /* recipient of sync reply */
    ErlDrvTermData busy_caller; /* recipient of sync reply when caller busy.
				 * Only valid while INET_F_BUSY. */

    inet_async_op* oph;          /* queue head or NULL */
    inet_async_op* opt;          /* queue tail or NULL */
    inet_async_op  op_queue[INET_MAX_ASYNC];  /* call queue */

    int   active;               /* 0 = passive, 1 = active, 2 = active once */
    int   stype;                /* socket type:
				    SOCK_STREAM/SOCK_DGRAM/SOCK_SEQPACKET   */
    int   sprotocol;            /* socket protocol:
				   IPPROTO_TCP|IPPROTO_UDP|IPPROTO_SCTP     */
    int   sfamily;              /* address family */
    int   htype;                /* header type (TCP only?) */
    unsigned int psize;         /* max packet size (TCP only?) */
    int   bit8;                 /* set if bit8f==true and data some data
				   seen had the 7th bit set */
    inet_address remote;        /* remote address for connected sockets */
    inet_address peer_addr;     /* fake peer address */
    inet_address name_addr;     /* fake local address */

    inet_address* peer_ptr;    /* fake peername or NULL */
    inet_address* name_ptr;    /* fake sockname or NULL */

    int   bufsz;                /* minimum buffer constraint */
    unsigned int hsz;           /* the list header size, -1 is large !!! */
    /* statistics */
    unsigned long recv_oct[2];  /* number of received octets >= 64 bits */
    unsigned long recv_cnt;     /* number of packets received */
    unsigned long recv_max;     /* maximum packet size received */
    double recv_avg;            /* average packet size received */
    double recv_dvi;            /* avarage deviation from avg_size */
    unsigned long send_oct[2];  /* number of octets sent >= 64 bits */
    unsigned long send_cnt;     /* number of packets sent */
    unsigned long send_max;     /* maximum packet send */
    double send_avg;            /* average packet size sent */

    subs_list empty_out_q_subs; /* Empty out queue subscribers */
} inet_descriptor;



#define TCP_STATE_CLOSED     INET_STATE_CLOSED
#define TCP_STATE_OPEN       (INET_F_OPEN)
#define TCP_STATE_BOUND      (TCP_STATE_OPEN | INET_F_BOUND)
#define TCP_STATE_CONNECTED  (TCP_STATE_BOUND | INET_F_ACTIVE)
#define TCP_STATE_LISTEN     (TCP_STATE_BOUND | INET_F_LISTEN)
#define TCP_STATE_CONNECTING (TCP_STATE_BOUND | INET_F_CON)
#define TCP_STATE_ACCEPTING  (TCP_STATE_LISTEN | INET_F_ACC)
#define TCP_STATE_MULTI_ACCEPTING (TCP_STATE_ACCEPTING | INET_F_MULTI_CLIENT)


#define TCP_MAX_PACKET_SIZE 0x4000000  /* 64 M */

#define MAX_VSIZE 16		/* Max number of entries allowed in an I/O
				 * vector sock_sendv().
				 */

static int tcp_inet_init(void);
static void tcp_inet_stop(ErlDrvData);
static void tcp_inet_command(ErlDrvData, char*, int);
static void tcp_inet_commandv(ErlDrvData, ErlIOVec*);
static void tcp_inet_drv_input(ErlDrvData, ErlDrvEvent);
static void tcp_inet_drv_output(ErlDrvData data, ErlDrvEvent event);
static ErlDrvData tcp_inet_start(ErlDrvPort, char* command);
static int tcp_inet_ctl(ErlDrvData, unsigned int, char*, int, char**, int);
static void tcp_inet_timeout(ErlDrvData);
static void tcp_inet_process_exit(ErlDrvData, ErlDrvMonitor *); 
#ifdef __WIN32__
static void tcp_inet_event(ErlDrvData, ErlDrvEvent);
static void find_dynamic_functions(void);
#endif

static struct erl_drv_entry tcp_inet_driver_entry = 
{
    tcp_inet_init,  /* inet_init will add this driver !! */
    tcp_inet_start, 
    tcp_inet_stop, 
    tcp_inet_command,
#ifdef __WIN32__
    tcp_inet_event,
    NULL,
#else
    tcp_inet_drv_input,
    tcp_inet_drv_output,
#endif
    "tcp_inet",
    NULL,
    NULL,
    tcp_inet_ctl,
    tcp_inet_timeout,
    tcp_inet_commandv,
    NULL,
    NULL,
    NULL,
    NULL,
    ERL_DRV_EXTENDED_MARKER,
    ERL_DRV_EXTENDED_MAJOR_VERSION,
    ERL_DRV_EXTENDED_MINOR_VERSION,
    ERL_DRV_FLAG_USE_PORT_LOCKING,
    NULL,
    tcp_inet_process_exit
};

#define PACKET_STATE_CLOSED     INET_STATE_CLOSED
#define PACKET_STATE_OPEN       (INET_F_OPEN)
#define PACKET_STATE_BOUND      (PACKET_STATE_OPEN  | INET_F_BOUND)
#define SCTP_STATE_LISTEN	(PACKET_STATE_BOUND | INET_F_LISTEN)
#define SCTP_STATE_CONNECTING   (PACKET_STATE_BOUND | INET_F_CON)
#define PACKET_STATE_CONNECTED  (PACKET_STATE_BOUND | INET_F_ACTIVE)


static int        packet_inet_init(void);
static void       packet_inet_stop(ErlDrvData);
static void       packet_inet_command(ErlDrvData, char*, int);
static void       packet_inet_drv_input(ErlDrvData data, ErlDrvEvent event);
static void	  packet_inet_drv_output(ErlDrvData data, ErlDrvEvent event);
static ErlDrvData udp_inet_start(ErlDrvPort, char* command);
#ifdef HAVE_SCTP
static ErlDrvData sctp_inet_start(ErlDrvPort, char* command);
#endif
static int        packet_inet_ctl(ErlDrvData, unsigned int, char*, 
				  int, char**, int);
static void       packet_inet_timeout(ErlDrvData);
#ifdef __WIN32__
static void       packet_inet_event(ErlDrvData, ErlDrvEvent);
static SOCKET     make_noninheritable_handle(SOCKET s);
static int        winsock_event_select(inet_descriptor *, int, int);
#endif

static struct erl_drv_entry udp_inet_driver_entry = 
{
    packet_inet_init,  /* inet_init will add this driver !! */
    udp_inet_start,
    packet_inet_stop,
    packet_inet_command,
#ifdef __WIN32__
    packet_inet_event,
    NULL, 
#else
    packet_inet_drv_input,
    packet_inet_drv_output,
#endif
    "udp_inet",
    NULL,
    NULL,
    packet_inet_ctl,
    packet_inet_timeout,
    NULL,
    NULL,
    NULL,
    NULL,
    NULL,
    ERL_DRV_EXTENDED_MARKER,
    ERL_DRV_EXTENDED_MAJOR_VERSION,
    ERL_DRV_EXTENDED_MINOR_VERSION,
    ERL_DRV_FLAG_USE_PORT_LOCKING
};

#ifdef HAVE_SCTP
static struct erl_drv_entry sctp_inet_driver_entry = 
{
    packet_inet_init,  /* inet_init will add this driver !! */
    sctp_inet_start,
    packet_inet_stop,
    packet_inet_command,
#ifdef __WIN32__
    packet_inet_event,
    NULL, 
#else
    packet_inet_drv_input,
    packet_inet_drv_output,
#endif
    "sctp_inet",
    NULL,
    NULL,
    packet_inet_ctl,
    packet_inet_timeout,
    NULL,
    NULL,
    NULL,
    NULL,
    NULL,
    ERL_DRV_EXTENDED_MARKER,
    ERL_DRV_EXTENDED_MAJOR_VERSION,
    ERL_DRV_EXTENDED_MINOR_VERSION,
    ERL_DRV_FLAG_USE_PORT_LOCKING
};
#endif

typedef struct {
    inet_descriptor inet;       /* common data structure (DON'T MOVE) */
    int   high;                 /* high watermark */
    int   low;                  /* low watermark */
    int   send_timeout;         /* timeout to use in send */
    int   busy_on_send;         /* busy on send with timeout! */
    int   i_bufsz;              /* current input buffer size (<= bufsz) */
    ErlDrvBinary* i_buf;        /* current binary buffer */
    char*         i_ptr;        /* current pos in buf */
    char*         i_ptr_start;  /* packet start pos in buf */
    int           i_remain;     /* remaining chars to read */
    int           tcp_add_flags;/* Additional TCP descriptor flags */
#ifdef USE_HTTP
    int           http_state;   /* 0 = response|request  1=headers fields */
#endif
    inet_async_multi_op *multi_first;/* NULL == no multi-accept-queue, op is in ordinary queue */
    inet_async_multi_op *multi_last;
    MultiTimerData *mtd;        /* Timer structures for multiple accept */
} tcp_descriptor;

/* send function */
static int tcp_send(tcp_descriptor* desc, char* ptr, int len);
static int tcp_sendv(tcp_descriptor* desc, ErlIOVec* ev);
static int tcp_recv(tcp_descriptor* desc, int request_len);
static int tcp_deliver(tcp_descriptor* desc, int len);

static int tcp_inet_output(tcp_descriptor* desc, HANDLE event);
static int tcp_inet_input(tcp_descriptor* desc, HANDLE event);

typedef struct {
    inet_descriptor inet;   /* common data structure (DON'T MOVE) */
    int read_packets;       /* Number of packets to read per invocation */
} udp_descriptor;


static int packet_inet_input(udp_descriptor* udesc, HANDLE event);
static int packet_inet_output(udp_descriptor* udesc, HANDLE event);

/* convert descriptor poiner to inet_descriptor pointer */
#define INETP(d) (&(d)->inet)

static int async_ref = 0;          /* async reference id generator */
#define NEW_ASYNC_ID() ((async_ref++) & 0xffff)


static ErlDrvTermData am_ok;
static ErlDrvTermData am_tcp;
static ErlDrvTermData am_udp;
static ErlDrvTermData am_error;
static ErlDrvTermData am_inet_async;
static ErlDrvTermData am_inet_reply;
static ErlDrvTermData am_timeout;
static ErlDrvTermData am_closed;
static ErlDrvTermData am_tcp_closed;
static ErlDrvTermData am_tcp_error;
static ErlDrvTermData am_udp_error;
static ErlDrvTermData am_empty_out_q;
#ifdef HAVE_SCTP
static ErlDrvTermData am_sctp;
static ErlDrvTermData am_sctp_error;
static ErlDrvTermData am_true;
static ErlDrvTermData am_false;
static ErlDrvTermData am_buffer;
static ErlDrvTermData am_mode;
static ErlDrvTermData am_list;
static ErlDrvTermData am_binary;
static ErlDrvTermData am_active;
static ErlDrvTermData am_once;
static ErlDrvTermData am_buffer;
static ErlDrvTermData am_linger;
static ErlDrvTermData am_recbuf;
static ErlDrvTermData am_sndbuf;
static ErlDrvTermData am_reuseaddr;
static ErlDrvTermData am_dontroute;
static ErlDrvTermData am_priority;
static ErlDrvTermData am_tos;
#endif

/* speical errors for bad ports and sequences */
#define EXBADPORT "exbadport"
#define EXBADSEQ  "exbadseq"


static int inet_init(void);
static int ctl_reply(int, char*, int, char**, int);

struct erl_drv_entry inet_driver_entry = 
{
    inet_init,  /* inet_init will add TCP, UDP and SCTP drivers */
    NULL, /* start */
    NULL, /* stop */
    NULL, /* output */
    NULL, /* ready_input */
    NULL, /* ready_output */
    "inet"
};

/* XXX: is this a driver interface function ??? */
extern void erl_exit(int n, char*, _DOTS_);

/*
 * Malloc wrapper,
 * we would like to change the behaviour for different 
 * systems here.
 */

#ifdef FATAL_MALLOC

static void *alloc_wrapper(size_t size){
    void *ret = driver_alloc(size);
    if(ret == NULL) 
	erl_exit(1,"Out of virtual memory in malloc (%s)", __FILE__);
    return ret;
}
#define ALLOC(X) alloc_wrapper(X)

static void *realloc_wrapper(void *current, size_t size){
    void *ret = driver_realloc(current,size);
    if(ret == NULL) 
	erl_exit(1,"Out of virtual memory in realloc (%s)", __FILE__);
    return ret;
}
#define REALLOC(X,Y) realloc_wrapper(X,Y)
#define FREE(P) driver_free((P))
#else /* FATAL_MALLOC */

#define ALLOC(X) driver_alloc((X))
#define REALLOC(X,Y) driver_realloc((X), (Y))
#define FREE(P) driver_free((P))

#endif /* FATAL_MALLOC */

#define INIT_ATOM(NAME) am_ ## NAME = driver_mk_atom(#NAME)

#define LOAD_ATOM_CNT 2
#define LOAD_ATOM(vec, i, atom) \
  (((vec)[(i)] = ERL_DRV_ATOM), \
  ((vec)[(i)+1] = (atom)), \
  ((i)+LOAD_ATOM_CNT))

#define LOAD_INT_CNT 2
#define LOAD_INT(vec, i, val) \
  (((vec)[(i)] = ERL_DRV_INT), \
  ((vec)[(i)+1] = (ErlDrvTermData)(val)), \
  ((i)+LOAD_INT_CNT))

#define LOAD_PORT_CNT 2
#define LOAD_PORT(vec, i, port) \
  (((vec)[(i)] = ERL_DRV_PORT), \
  ((vec)[(i)+1] = (port)), \
  ((i)+LOAD_PORT_CNT))

#define LOAD_PID_CNT 2
#define LOAD_PID(vec, i, pid) \
  (((vec)[(i)] = ERL_DRV_PID), \
  ((vec)[(i)+1] = (pid)), \
  ((i)+LOAD_PID_CNT))

#define LOAD_BINARY_CNT 4
#define LOAD_BINARY(vec, i, bin, offs, len) \
  (((vec)[(i)] = ERL_DRV_BINARY), \
  ((vec)[(i)+1] = (ErlDrvTermData)(bin)), \
  ((vec)[(i)+2] = (len)), \
  ((vec)[(i)+3] = (offs)), \
  ((i)+LOAD_BINARY_CNT))

#define LOAD_STRING_CNT 3
#define LOAD_STRING(vec, i, str, len) \
  (((vec)[(i)] = ERL_DRV_STRING), \
  ((vec)[(i)+1] = (ErlDrvTermData)(str)), \
  ((vec)[(i)+2] = (len)), \
  ((i)+LOAD_STRING_CNT))

#define LOAD_STRING_CONS_CNT 3
#define LOAD_STRING_CONS(vec, i, str, len) \
  (((vec)[(i)] = ERL_DRV_STRING_CONS), \
  ((vec)[(i)+1] = (ErlDrvTermData)(str)), \
  ((vec)[(i)+2] = (len)), \
  ((i)+LOAD_STRING_CONS_CNT))

#define LOAD_TUPLE_CNT 2
#define LOAD_TUPLE(vec, i, size) \
  (((vec)[(i)] = ERL_DRV_TUPLE), \
  ((vec)[(i)+1] = (size)), \
  ((i)+LOAD_TUPLE_CNT))

#define LOAD_NIL_CNT 1
#define LOAD_NIL(vec, i) \
  (((vec)[(i)] = ERL_DRV_NIL), \
  ((i)+LOAD_NIL_CNT))

#define LOAD_LIST_CNT 2
#define LOAD_LIST(vec, i, size) \
  (((vec)[(i)] = ERL_DRV_LIST), \
  ((vec)[(i)+1] = (size)), \
  ((i)+LOAD_LIST_CNT))

#ifdef HAVE_SCTP
    /* "IS_SCTP": tells the difference between a UDP and an SCTP socket: */
#   define IS_SCTP(desc)((desc)->sprotocol==IPPROTO_SCTP)

    /* For AssocID, 4 bytes should be enough -- checked by "init": */
#   define GET_ASSOC_ID		get_int32
#   define ASSOC_ID_LEN		4
#   define LOAD_ASSOC_ID	LOAD_INT
#   define LOAD_ASSOC_ID_CNT	LOAD_INT_CNT
#   define SCTP_ANC_BUFF_SIZE   INET_DEF_BUFFER/2 /* XXX: not very good... */
#endif

static int load_ip_port(ErlDrvTermData* spec, int i, char* buf)
{
    spec[i++] = ERL_DRV_INT;
    spec[i++] = (ErlDrvTermData) get_int16(buf);
    return i;
}

static int load_ip_address(ErlDrvTermData* spec, int i, int family, char* buf)
{
    int n;
    if (family == AF_INET) {
	for (n = 0;  n < 4;  n++) {
	    spec[i++] = ERL_DRV_INT;
	    spec[i++] = (ErlDrvTermData) ((unsigned char)buf[n]);
	}
	spec[i++] = ERL_DRV_TUPLE;
	spec[i++] = 4;
    }
#if defined(HAVE_IN6) && defined(AF_INET6)
    else if (family == AF_INET6) {
	for (n = 0;  n < 16;  n += 2) {
	    spec[i++] = ERL_DRV_INT;
	    spec[i++] = (ErlDrvTermData) get_int16(buf+n);
	}
	spec[i++] = ERL_DRV_TUPLE;
	spec[i++] = 8;
    }
#endif
    else {
	spec[i++] = ERL_DRV_TUPLE;
	spec[i++] = 0;
    }
    return i;
}

#ifdef HAVE_SCTP
/* For SCTP, we often need to return {IP, Port} tuples: */
static int inet_get_address
      (int family, char* dst, inet_address* src, unsigned int* len);

#define LOAD_IP_AND_PORT_CNT                                              \
        (8*LOAD_INT_CNT + LOAD_TUPLE_CNT + LOAD_INT_CNT + LOAD_TUPLE_CNT)
                           
static int load_ip_and_port
           (ErlDrvTermData* spec,    int i, inet_descriptor* desc,
	    struct sockaddr_storage* addr)
{
    /* The size of the buffer  used to stringify the addr  is the same as
       that of "sockaddr_storage" itself: only their layout is different:
    */
    unsigned int len  = sizeof(struct sockaddr_storage);
    unsigned int alen = len;
    char         abuf  [len];
    int res =
	inet_get_address(desc->sfamily, abuf, (inet_address*) addr, &alen);
    ASSERT(res==0);
    res = 0;
    /* Now "abuf" contains: Family(1b), Port(2b), IP(4|16b) */

    /* NB: the following functions are safe to use, as they create tuples
       of copied Ints on the "spec", and do not install any String pts --
       a ptr to "abuf" would be dangling upon exiting this function:   */
    i = load_ip_address(spec, i, desc->sfamily, abuf+3);
    i = load_ip_port   (spec, i, abuf+1);
    i = LOAD_TUPLE     (spec, i, 2);
    return i;
}

/* Loading Boolean flags as Atoms: */
#define LOAD_BOOL_CNT LOAD_ATOM_CNT
#define LOAD_BOOL(spec,   i,   flag)                          \
	LOAD_ATOM((spec), (i), (flag) ? am_true : am_false);
#endif /* HAVE_SCTP */

/*
** Binary Buffer Managment
** We keep a stack of usable buffers 
*/
#define BUFFER_STACK_SIZE 16

static erts_smp_spinlock_t inet_buffer_stack_lock;
static ErlDrvBinary* buffer_stack[BUFFER_STACK_SIZE];
static int buffer_stack_pos = 0;


/*
 * XXX
 * The erts_smp_spin_* functions should not be used by drivers (but this
 * driver is special). Replace when driver locking api has been implemented.
 * /rickard
 */
#define BUFSTK_LOCK	erts_smp_spin_lock(&inet_buffer_stack_lock);
#define BUFSTK_UNLOCK	erts_smp_spin_unlock(&inet_buffer_stack_lock);

#ifdef DEBUG
static int tot_buf_allocated = 0;  /* memory in use for i_buf */
static int tot_buf_stacked = 0;   /* memory on stack */
static int max_buf_allocated = 0; /* max allocated */

#define COUNT_BUF_ALLOC(sz) do { \
  BUFSTK_LOCK; \
  tot_buf_allocated += (sz); \
  if (tot_buf_allocated > max_buf_allocated) \
    max_buf_allocated = tot_buf_allocated; \
  BUFSTK_UNLOCK; \
} while(0)

#define COUNT_BUF_FREE(sz) do { \
 BUFSTK_LOCK; \
 tot_buf_allocated -= (sz); \
 BUFSTK_UNLOCK; \
 } while(0)

#define COUNT_BUF_STACK(sz) do { \
 BUFSTK_LOCK; \
 tot_buf_stacked += (sz); \
 BUFSTK_UNLOCK; \
 } while(0)

#else

#define COUNT_BUF_ALLOC(sz)
#define COUNT_BUF_FREE(sz)
#define COUNT_BUF_STACK(sz)

#endif

static ErlDrvBinary* alloc_buffer(long minsz)
{
    ErlDrvBinary* buf = NULL;

    BUFSTK_LOCK;

    DEBUGF(("alloc_buffer: sz = %ld, tot = %d, max = %d\r\n", 
	    minsz, tot_buf_allocated, max_buf_allocated));

    if (buffer_stack_pos > 0) {
	int origsz;

	buf = buffer_stack[--buffer_stack_pos];
	origsz = buf->orig_size;
	BUFSTK_UNLOCK;
	COUNT_BUF_STACK(-origsz);
	if (origsz < minsz) {
	    if ((buf = driver_realloc_binary(buf, minsz)) == NULL)
		return NULL;
	    COUNT_BUF_ALLOC(buf->orig_size - origsz);
	}
    }
    else {
	BUFSTK_UNLOCK;
	if ((buf = driver_alloc_binary(minsz)) == NULL)
	    return NULL;
	COUNT_BUF_ALLOC(buf->orig_size);
    }
    return buf;
}

/*
** Max buffer memory "cached" BUFFER_STACK_SIZE * INET_MAX_BUFFER
** (16 * 64k ~ 1M)
*/
/*#define CHECK_DOUBLE_RELEASE 1*/
static void release_buffer(ErlDrvBinary* buf)
{
    DEBUGF(("release_buffer: %ld\r\n", (buf==NULL) ? 0 : buf->orig_size));
    if (buf == NULL)
	return;
    BUFSTK_LOCK;
    if ((buf->orig_size > INET_MAX_BUFFER) || 
	(buffer_stack_pos >= BUFFER_STACK_SIZE)) {
	BUFSTK_UNLOCK;
	COUNT_BUF_FREE(buf->orig_size);
	driver_free_binary(buf);
    }
    else {
#ifdef CHECK_DOUBLE_RELEASE
#ifdef __GNUC__
#warning CHECK_DOUBLE_RELEASE is enabled, this is a custom build emulator
#endif
	int i;
	for (i = 0; i < buffer_stack_pos; ++i) {
	    if (buffer_stack[i] == buf) {
		erl_exit(1,"Multiple buffer release in inet_drv, this is a "
			 "bug, save the core and send it to "
			 "support@erlang.ericsson.se!");
	    }
	}
#endif
	buffer_stack[buffer_stack_pos++] = buf;
	BUFSTK_UNLOCK;
	COUNT_BUF_STACK(buf->orig_size);
    }
}

static ErlDrvBinary* realloc_buffer(ErlDrvBinary* buf, long newsz)
{
    ErlDrvBinary* bin;
#ifdef DEBUG
    long orig_size =  buf->orig_size;
#endif

    if ((bin = driver_realloc_binary(buf,newsz)) != NULL) {
	COUNT_BUF_ALLOC(newsz - orig_size);
	;
    }
    return bin;
}

/* use a TRICK, access the refc field to see if any one else has
 * a ref to this buffer then call driver_free_binary else 
 * release_buffer instead
 */
static void free_buffer(ErlDrvBinary* buf)
{
    DEBUGF(("free_buffer: %ld\r\n", (buf==NULL) ? 0 : buf->orig_size));

    if (buf != NULL) {
	if (driver_binary_get_refc(buf) == 1)
	    release_buffer(buf);
	else {
	    COUNT_BUF_FREE(buf->orig_size);
	    driver_free_binary(buf);
	}
    }
}


#ifdef __WIN32__

static ErlDrvData dummy_start(ErlDrvPort port, char* command)
{
    return (ErlDrvData)port;
}

static int dummy_ctl(ErlDrvData data, unsigned int cmd, char* buf, int len,
		     char** rbuf, int rsize)
{
    static char error[] = "no_winsock2";

    driver_failure_atom((ErlDrvPort)data, error);
    return ctl_reply(INET_REP_ERROR, error, sizeof(error), rbuf, rsize);
}

static void dummy_command(ErlDrvData data, char* buf, int len)
{
}

static struct erl_drv_entry dummy_tcp_driver_entry = 
{
    NULL,			/* init */
    dummy_start,		/* start */
    NULL,			/* stop */
    dummy_command,		/* command */
    NULL,			/* input */
    NULL,			/* output */
    "tcp_inet",			/* name */
    NULL,
    NULL,
    dummy_ctl,
    NULL,
    NULL
};

static struct erl_drv_entry dummy_udp_driver_entry = 
{
    NULL,			/* init */
    dummy_start,		/* start */
    NULL,			/* stop */
    dummy_command,		/* command */
    NULL,			/* input */
    NULL,			/* output */
    "udp_inet",			/* name */
    NULL,
    NULL,
    dummy_ctl,
    NULL,
    NULL
};

#ifdef HAVE_SCTP
static struct erl_drv_entry dummy_sctp_driver_entry = 
{				/* Though there is no SCTP for Win32 yet... */
    NULL,			/* init */
    dummy_start,		/* start */
    NULL,			/* stop */
    dummy_command,		/* command */
    NULL,			/* input */
    NULL,			/* output */
    "sctp_inet",		/* name */
    NULL,
    NULL,
    dummy_ctl,
    NULL,
    NULL
};
#endif

#endif

/* general control reply function */
static int ctl_reply(int rep, char* buf, int len, char** rbuf, int rsize)
{
    char* ptr;

    if ((len+1) > rsize) {
	ptr = ALLOC(len+1);
	*rbuf = ptr;
    }
    else
	ptr = *rbuf;
    *ptr++ = rep;
    memcpy(ptr, buf, len);
    return len+1;
}

/* general control error reply function */
static int ctl_error(int err, char** rbuf, int rsize)
{
    char response[256];		/* Response buffer. */
    char* s;
    char* t;

    for (s = erl_errno_id(err), t = response; *s; s++, t++)
	*t = tolower(*s);
    return ctl_reply(INET_REP_ERROR, response, t-response, rbuf, rsize);
}

static int ctl_xerror(char* xerr, char** rbuf, int rsize)
{
    int n = strlen(xerr);
    return ctl_reply(INET_REP_ERROR, xerr, n, rbuf, rsize);
}


static ErlDrvTermData error_atom(int err)
{
    char errstr[256];
    char* s;
    char* t;

    for (s = erl_errno_id(err), t = errstr; *s; s++, t++)
	*t = tolower(*s);
    *t = '\0';
    return driver_mk_atom(errstr);
}


static void enq_old_multi_op(tcp_descriptor *desc, int id, int req, 
			     ErlDrvTermData caller, MultiTimerData *timeout,
			     ErlDrvMonitor *monitorp)
{
    inet_async_multi_op *opp;

    opp = ALLOC(sizeof(inet_async_multi_op));

    opp->op.id = id;
    opp->op.caller = caller;
    opp->op.req = req;
    opp->op.tmo.mtd = timeout;
    memcpy(&(opp->op.monitor), monitorp, sizeof(ErlDrvMonitor));
    opp->next = NULL;

    if (desc->multi_first == NULL) {
	desc->multi_first = opp;
    } else {
	desc->multi_last->next = opp;
    }
    desc->multi_last = opp;
}   

static void enq_multi_op(tcp_descriptor *desc, char *buf, int req, 
			 ErlDrvTermData caller, MultiTimerData *timeout,
			 ErlDrvMonitor *monitorp)
{
    int id = NEW_ASYNC_ID();
    enq_old_multi_op(desc,id,req,caller,timeout,monitorp);
    if (buf != NULL)
	put_int16(id, buf);
}

static int deq_multi_op(tcp_descriptor *desc, int *id_p, int *req_p, 
			ErlDrvTermData *caller_p, MultiTimerData **timeout_p,
			ErlDrvMonitor *monitorp)
{
    inet_async_multi_op *opp;
    opp = desc->multi_first;
    if (!opp) {
	return -1;
    }
    desc->multi_first = opp->next;
    if (desc->multi_first == NULL) {
	desc->multi_last = NULL;
    }
    *id_p = opp->op.id;
    *req_p = opp->op.req;
    *caller_p = opp->op.caller;
    if (timeout_p != NULL) {
	*timeout_p = opp->op.tmo.mtd;
    }
    if (monitorp != NULL) {
	memcpy(monitorp,&(opp->op.monitor),sizeof(ErlDrvMonitor));
    }
    FREE(opp);
    return 0;
}

static int remove_multi_op(tcp_descriptor *desc, int *id_p, int *req_p, 
			   ErlDrvTermData caller, MultiTimerData **timeout_p,
			   ErlDrvMonitor *monitorp)
{
    inet_async_multi_op *opp, *slap;
    for (opp = desc->multi_first, slap = NULL; 
	 opp != NULL && opp->op.caller != caller; 
	 slap = opp, opp = opp->next)
	;
    if (!opp) {
	return -1;
    }
    if (slap == NULL) {
	desc->multi_first = opp->next;
    } else {
	slap->next = opp->next;
    }
    if (desc->multi_last == opp) {
	desc->multi_last = slap;
    }
    *id_p = opp->op.id;
    *req_p = opp->op.req;
    if (timeout_p != NULL) {
	*timeout_p = opp->op.tmo.mtd;
    }
    if (monitorp != NULL) {
	memcpy(monitorp,&(opp->op.monitor),sizeof(ErlDrvMonitor));
    }
    FREE(opp);
    return 0;
}

/* setup a new async id + caller (format async_id into buf) */

static int enq_async_w_tmo(inet_descriptor* desc, char* buf, int req, unsigned timeout,
			   ErlDrvMonitor *monitorp)
{
    int id = NEW_ASYNC_ID();
    inet_async_op* opp;

    if ((opp = desc->oph) == NULL)            /* queue empty */
	opp = desc->oph = desc->opt = desc->op_queue;
    else if (desc->oph == desc->opt) { /* queue full */ 
	DEBUGF(("enq(%ld): queue full\r\n", (long)desc->port));
	return -1;
    }

    opp->id = id;
    opp->caller = driver_caller(desc->port);
    opp->req = req;
    opp->tmo.value = timeout;
    if (monitorp != NULL) {
	memcpy(&(opp->monitor),monitorp,sizeof(ErlDrvMonitor));
    }

    DEBUGF(("enq(%ld): %d %ld %d\r\n", 
	    (long) desc->port, opp->id, opp->caller, opp->req));

    opp++;
    if (opp >= desc->op_queue + INET_MAX_ASYNC)
	desc->oph = desc->op_queue;
    else
	desc->oph = opp;

    if (buf != NULL)
	put_int16(id, buf);
    return 0;
}

static int enq_async(inet_descriptor* desc, char* buf, int req) 
{
    return enq_async_w_tmo(desc,buf,req,INET_INFINITY, NULL);
}

static int deq_async_w_tmo(inet_descriptor* desc, int* ap, ErlDrvTermData* cp, 
			   int* rp, unsigned *tp, ErlDrvMonitor *monitorp)
{
    inet_async_op* opp;

    if ((opp = desc->opt) == NULL) {  /* queue empty */
	DEBUGF(("deq(%ld): queue empty\r\n", (long)desc->port));
	return -1;
    }
    *ap = opp->id;
    *cp = opp->caller;
    *rp = opp->req;
    if (tp != NULL) {
	*tp = opp->tmo.value;
    }
    if (monitorp != NULL) {
	memcpy(monitorp,&(opp->monitor),sizeof(ErlDrvMonitor));
    }
    
    DEBUGF(("deq(%ld): %d %ld %d\r\n", 
	    (long)desc->port, opp->id, opp->caller, opp->req));
    
    opp++;
    if (opp >= desc->op_queue + INET_MAX_ASYNC)
	desc->opt = desc->op_queue;
    else
	desc->opt = opp;

    if (desc->opt == desc->oph)
	desc->opt = desc->oph = NULL;
    return 0;
}

static int deq_async(inet_descriptor* desc, int* ap, ErlDrvTermData* cp, int* rp)
{
    return deq_async_w_tmo(desc,ap,cp,rp,NULL,NULL);
}
/* send message:
**     {inet_async, Port, Ref, ok} 
*/
static int 
send_async_ok(ErlDrvPort port, ErlDrvTermData Port, int Ref, 
	      ErlDrvTermData recipient)
{
    ErlDrvTermData spec[2*LOAD_ATOM_CNT + LOAD_PORT_CNT + 
			LOAD_INT_CNT + LOAD_TUPLE_CNT];
    int i = 0;
    
    i = LOAD_ATOM(spec, i, am_inet_async);
    i = LOAD_PORT(spec, i, Port);
    i = LOAD_INT(spec, i, Ref);
    i = LOAD_ATOM(spec, i, am_ok);
    i = LOAD_TUPLE(spec, i, 4);
    
    ASSERT(i == sizeof(spec)/sizeof(*spec));
    
    return driver_send_term(port, recipient, spec, i);
}

/* send message:
**     {inet_async, Port, Ref, {ok,Port2}} 
*/
static int 
send_async_ok_port(ErlDrvPort port, ErlDrvTermData Port, int Ref, 
		   ErlDrvTermData recipient, ErlDrvTermData Port2)
{
    ErlDrvTermData spec[2*LOAD_ATOM_CNT + 2*LOAD_PORT_CNT + 
			LOAD_INT_CNT + 2*LOAD_TUPLE_CNT];
    int i = 0;
    
    i = LOAD_ATOM(spec, i, am_inet_async);
    i = LOAD_PORT(spec, i, Port);
    i = LOAD_INT(spec, i, Ref);
    {
	i = LOAD_ATOM(spec, i, am_ok);
	i = LOAD_PORT(spec, i, Port2);
	i = LOAD_TUPLE(spec, i, 2);
    }
    i = LOAD_TUPLE(spec, i, 4);
    
    ASSERT(i == sizeof(spec)/sizeof(*spec));
    
    return driver_send_term(port, recipient, spec, i);
}

/* send message:
**      {inet_async, Port, Ref, {error,Reason}}
*/
static int
send_async_error(ErlDrvPort port, ErlDrvTermData Port, int Ref,
		 ErlDrvTermData recipient, ErlDrvTermData Reason)
{
    ErlDrvTermData spec[3*LOAD_ATOM_CNT + LOAD_PORT_CNT + 
			LOAD_INT_CNT + 2*LOAD_TUPLE_CNT];
    int i = 0;
    
    i = 0;
    i = LOAD_ATOM(spec, i, am_inet_async);
    i = LOAD_PORT(spec, i, Port);
    i = LOAD_INT(spec, i, Ref);
    {
	i = LOAD_ATOM(spec, i, am_error);
	i = LOAD_ATOM(spec, i, Reason);
	i = LOAD_TUPLE(spec, i, 2);
    }
    i = LOAD_TUPLE(spec, i, 4);
    ASSERT(i == sizeof(spec)/sizeof(*spec));
    DEBUGF(("send_async_error %ld %ld\r\n", recipient, Reason));
    return driver_send_term(port, recipient, spec, i);
}


static int async_ok(inet_descriptor* desc)
{
    int req;
    int aid;
    ErlDrvTermData caller;

    if (deq_async(desc, &aid, &caller, &req) < 0)
	return -1;
    return send_async_ok(desc->port, desc->dport, aid, caller);
}

static int async_ok_port(inet_descriptor* desc, ErlDrvTermData Port2)
{
    int req;
    int aid;
    ErlDrvTermData caller;

    if (deq_async(desc, &aid, &caller, &req) < 0)
	return -1;
    return send_async_ok_port(desc->port, desc->dport, aid, caller, Port2);
}

static int async_error_am(inet_descriptor* desc, ErlDrvTermData reason)
{
    int req;
    int aid;
    ErlDrvTermData caller;

    if (deq_async(desc, &aid, &caller, &req) < 0)
	return -1;
    return send_async_error(desc->port, desc->dport, aid, caller,
			    reason);
}

/* dequeue all operations */
static int async_error_am_all(inet_descriptor* desc, ErlDrvTermData reason)
{
    int req;
    int aid;
    ErlDrvTermData caller;

    while (deq_async(desc, &aid, &caller, &req) == 0) {
	send_async_error(desc->port, desc->dport, aid, caller,
			 reason);
    }
    return 0;
}


static int async_error(inet_descriptor* desc, int err)
{
    return async_error_am(desc, error_atom(err));
}

/* send:
**   {inet_reply, S, ok} 
*/

static int inet_reply_ok(inet_descriptor* desc)
{
    ErlDrvTermData spec[2*LOAD_ATOM_CNT + LOAD_PORT_CNT + LOAD_TUPLE_CNT];
    ErlDrvTermData caller = desc->caller;
    int i = 0;
    
    i = LOAD_ATOM(spec, i, am_inet_reply);
    i = LOAD_PORT(spec, i, desc->dport);
    i = LOAD_ATOM(spec, i, am_ok);
    i = LOAD_TUPLE(spec, i, 3);
    ASSERT(i == sizeof(spec)/sizeof(*spec));
    
    desc->caller = 0;
    return driver_send_term(desc->port, caller, spec, i);    
}

/* send:
**   {inet_reply, S, {error, Reason}} 
*/
static int inet_reply_error_am(inet_descriptor* desc, ErlDrvTermData reason)
{
    ErlDrvTermData spec[3*LOAD_ATOM_CNT + LOAD_PORT_CNT + 2*LOAD_TUPLE_CNT];
    ErlDrvTermData caller = desc->caller;
    int i = 0;
    
    i = LOAD_ATOM(spec, i, am_inet_reply);
    i = LOAD_PORT(spec, i, desc->dport);
    i = LOAD_ATOM(spec, i, am_error);
    i = LOAD_ATOM(spec, i, reason);
    i = LOAD_TUPLE(spec, i, 2);
    i = LOAD_TUPLE(spec, i, 3);
    ASSERT(i == sizeof(spec)/sizeof(*spec));
    desc->caller = 0;
    
    DEBUGF(("inet_reply_error_am %ld %ld\r\n", caller, reason));
    return driver_send_term(desc->port, caller, spec, i);
}

/* send:
**   {inet_reply, S, {error, Reason}} 
*/
static int inet_reply_error(inet_descriptor* desc, int err)
{
    return inet_reply_error_am(desc, error_atom(err));
}

/* 
** Deliver port data from buffer 
*/
static int inet_port_data(inet_descriptor* desc, char* buf, int len)
{
    unsigned int hsz = desc->hsz;

    DEBUGF(("inet_port_data(%ld): len = %d\r\n", (long)desc->port, len));

    if ((desc->mode == INET_MODE_LIST) || (hsz > len))
	return driver_output2(desc->port, buf, len, NULL, 0);
    else if (hsz > 0)
	return driver_output2(desc->port, buf, hsz, buf+hsz, len-hsz);
    else
	return driver_output(desc->port, buf, len);
}

/* 
** Deliver port data from binary (for an active mode socket)
*/
static int
inet_port_binary_data(inet_descriptor* desc, ErlDrvBinary* bin, int offs, int len)
{
    unsigned int hsz = desc->hsz;

    DEBUGF(("inet_port_binary_data(%ld): offs=%d, len = %d\r\n", 
	    (long)desc->port, offs, len));

    if ((desc->mode == INET_MODE_LIST) || (hsz > len)) 
	return driver_output2(desc->port, bin->orig_bytes+offs, len, NULL, 0);
    else 
	return driver_output_binary(desc->port, bin->orig_bytes+offs, hsz,
				    bin, offs+hsz, len-hsz);
}

#ifdef USE_HTTP

#define HTTP_HDR_HASH_SIZE  53
#define HTTP_METH_HASH_SIZE 13

static char tspecial[128];

static char* http_hdr_strings[] = {
  "Cache-Control",
  "Connection",
  "Date",
  "Pragma",
  "Transfer-Encoding",
  "Upgrade",
  "Via",
  "Accept",
  "Accept-Charset",
  "Accept-Encoding",
  "Accept-Language",
  "Authorization",
  "From",
  "Host",
  "If-Modified-Since",
  "If-Match",
  "If-None-Match",
  "If-Range",
  "If-Unmodified-Since",
  "Max-Forwards",
  "Proxy-Authorization",
  "Range",
  "Referer",
  "User-Agent",
  "Age",
  "Location",
  "Proxy-Authenticate",
  "Public",
  "Retry-After",
  "Server",
  "Vary",
  "Warning",
  "Www-Authenticate",
  "Allow",
  "Content-Base",
  "Content-Encoding",
  "Content-Language",
  "Content-Length",
  "Content-Location",
  "Content-Md5",
  "Content-Range",
  "Content-Type",
  "Etag",
  "Expires",
  "Last-Modified",
  "Accept-Ranges",
  "Set-Cookie",
  "Set-Cookie2",
  "X-Forwarded-For",
  "Cookie",
  "Keep-Alive",
  "Proxy-Connection",
    NULL
};


static char* http_meth_strings[] = {
  "OPTIONS",
  "GET",
  "HEAD",
  "POST",
  "PUT",
  "DELETE",
  "TRACE",
    NULL
};

typedef struct http_atom {
  struct http_atom* next;   /* next in bucket */
  unsigned long h;          /* stored hash value */
  char* name;
  int   len;
  int index;                /* index in table + bit-pos */
  ErlDrvTermData atom;      /* erlang atom rep */
} http_atom_t;

static http_atom_t http_hdr_table[sizeof(http_hdr_strings)/sizeof(char*)];
static http_atom_t http_meth_table[sizeof(http_meth_strings)/sizeof(char*)];

static http_atom_t* http_hdr_hash[HTTP_HDR_HASH_SIZE];
static http_atom_t* http_meth_hash[HTTP_METH_HASH_SIZE];

static ErlDrvTermData am_http_eoh;
static ErlDrvTermData am_http_header;
static ErlDrvTermData am_http_request;
static ErlDrvTermData am_http_response;
static ErlDrvTermData am_http_error;
static ErlDrvTermData am_abs_path;
static ErlDrvTermData am_absoluteURI;
static ErlDrvTermData am_star;
static ErlDrvTermData am_undefined;
static ErlDrvTermData am_http;
static ErlDrvTermData am_https;
static ErlDrvTermData am_scheme;



#define CRNL(ptr) (((ptr)[0] == '\r') && ((ptr)[1] == '\n'))
#define NL(ptr)   ((ptr)[0] == '\n')
#define SP(ptr)   (((ptr)[0] == ' ') || ((ptr)[0] == '\t'))
#define is_tspecial(x) ((((x) > 32) && ((x) < 128)) ? tspecial[(x)] : 1)

#define hash_update(h,c) do { \
    unsigned long __g; \
    (h) = ((h) << 4) + (c); \
    if ((__g = (h) & 0xf0000000)) { \
       (h) ^= (__g >> 24); \
       (h) ^= __g; \
    } \
 } while(0)

static void http_hash(char* name, http_atom_t* entry,
		      http_atom_t** hash, int hsize)
{
  unsigned long h = 0;
  unsigned char* ptr = (unsigned char*) name;
  int ix;
  int len = 0;

  while(*ptr != '\0') {
    hash_update(h, *ptr);
    ptr++;
    len++;
  }
  ix = h % hsize;

  entry->next = hash[ix];
  entry->h    = h;
  entry->name = name;
  entry->len  = len;
  entry->atom = driver_mk_atom(name);
    
  hash[ix] = entry;
}

static http_atom_t* http_hash_lookup(char* name, int len,
				     unsigned long h,
				     http_atom_t** hash, int hsize)
{
  int ix = h % hsize;
  http_atom_t* ap = hash[ix];

  while (ap != NULL) {
    if ((ap->h == h) && (ap->len == len) && 
	(strncmp(ap->name, name, len) == 0))
      return ap;
    ap = ap->next;
  }
  return NULL;
}
     


static int http_init(void)
{
  int i;
  unsigned char* ptr;

  for (i = 0; i < 33; i++)
    tspecial[i] = 1;
  for (i = 33; i < 127; i++)
    tspecial[i] = 0;
  for (ptr = (unsigned char*)"()<>@,;:\\\"/[]?={} \t"; *ptr != '\0'; ptr++)
    tspecial[*ptr] = 1;

  INIT_ATOM(http_eoh);
  INIT_ATOM(http_header);
  INIT_ATOM(http_request);
  INIT_ATOM(http_response);
  INIT_ATOM(http_error);
  INIT_ATOM(abs_path);
  INIT_ATOM(absoluteURI);
  am_star = driver_mk_atom("*");
  INIT_ATOM(undefined);
  INIT_ATOM(http);
  INIT_ATOM(https);
  INIT_ATOM(scheme);

  for (i = 0; i < HTTP_HDR_HASH_SIZE; i++)
    http_hdr_hash[i] = NULL;
  for (i = 0; http_hdr_strings[i] != NULL; i++) {
    http_hdr_table[i].index = i;
    http_hash(http_hdr_strings[i], 
	      &http_hdr_table[i], 
	      http_hdr_hash, HTTP_HDR_HASH_SIZE);
  }

  for (i = 0; i < HTTP_METH_HASH_SIZE; i++)
    http_meth_hash[i] = NULL;
  for (i = 0; http_meth_strings[i] != NULL; i++) {
    http_meth_table[i].index = i;
    http_hash(http_meth_strings[i],
	      &http_meth_table[i], 
	      http_meth_hash, HTTP_METH_HASH_SIZE);
  }
  return 0;
}

static int
http_response_message(tcp_descriptor* desc, int major, int minor, int status,
		      char* phrase, int phrase_len)
{
  int i = 0;
  ErlDrvTermData spec[27];

  if (desc->inet.active == INET_PASSIVE) {
    /* {inet_async,S,Ref,{ok,{http_response,Version,Status,Phrase}}} */
    int req;
    int aid;
    ErlDrvTermData caller;

    if (deq_async(INETP(desc), &aid, &caller, &req) < 0)
      return -1;
    i = LOAD_ATOM(spec, i,  am_inet_async);
    i = LOAD_PORT(spec, i,  desc->inet.dport);
    i = LOAD_INT(spec, i,   aid);
    i = LOAD_ATOM(spec, i,  am_ok);
    i = LOAD_ATOM(spec, i,  am_http_response);
    i = LOAD_INT(spec, i, major);
    i = LOAD_INT(spec, i, minor);
    i = LOAD_TUPLE(spec, i, 2);
    i = LOAD_INT(spec, i, status);
    i = LOAD_STRING(spec, i, phrase, phrase_len);
    i = LOAD_TUPLE(spec, i, 4);
    i = LOAD_TUPLE(spec, i, 2);
    i = LOAD_TUPLE(spec, i, 4);
    return driver_send_term(desc->inet.port, caller, spec, i);
  }
  else {
    /* {http_response, S, Version, Status, Phrase} */
    i = LOAD_ATOM(spec, i,  am_http_response);
    i = LOAD_PORT(spec, i,  desc->inet.dport);
    i = LOAD_INT(spec, i, major);
    i = LOAD_INT(spec, i, minor);
    i = LOAD_TUPLE(spec, i, 2);
    i = LOAD_INT(spec, i, status);
    i = LOAD_STRING(spec, i, phrase, phrase_len);
    i = LOAD_TUPLE(spec, i, 5);
    return driver_output_term(desc->inet.port, spec, i);
  }
}

/*
** Handle URI syntax:
**
**  Request-URI    = "*" | absoluteURI | abs_path
**  absoluteURI    = scheme ":" *( uchar | reserved )
**  net_path       = "//" net_loc [ abs_path ]
**  abs_path       = "/" rel_path
**  rel_path       = [ path ] [ ";" params ] [ "?" query ]
**  path           = fsegment *( "/" segment )
**  fsegment       = 1*pchar
**  segment        = *pchar
**  params         = param *( ";" param )
**  param          = *( pchar | "/" )
**  query          = *( uchar | reserved )
**
**  http_URL       = "http:" "//" host [ ":" port ] [ abs_path ]
**
**  host           = <A legal Internet host domain name
**                   or IP address (in dotted-decimal form),
**                   as defined by Section 2.1 of RFC 1123>
**  port           = *DIGIT
**
**  {absoluteURI, <scheme>, <host>, <port>, <path+params+query>}
**       when <scheme> = http | https
**  {scheme, <scheme>, <chars>}
**       wheb <scheme> is something else then http or https
**  {abs_path,  <path>}
**
**  <string>  (unknown form)
**
*/

/* host [ ":" port ] [ abs_path ] */
static int
http_load_absoluteURI(ErlDrvTermData* spec, int i, ErlDrvTermData scheme,
		      char* uri_ptr, int uri_len)
{
  char* p;
  char* abs_path_ptr;
  int   abs_path_len;

  if ((p = memchr(uri_ptr, '/', uri_len)) == NULL) {
    /* host [":" port] */
    abs_path_ptr = "/";
    abs_path_len = 1;
  }
  else {
    int n = (p - uri_ptr);

    abs_path_ptr = p;
    abs_path_len = uri_len - n;
    uri_len = n;
  }
  i = LOAD_ATOM(spec, i, am_absoluteURI);
  i = LOAD_ATOM(spec, i, scheme);

  /* host[:port]  */
  if ((p = memchr(uri_ptr, ':', uri_len)) == NULL) {
    i = LOAD_STRING(spec, i, uri_ptr, uri_len);
    i = LOAD_ATOM(spec, i, am_undefined);
  }
  else {
    int n = (p - uri_ptr);
    int port = 0;

    i = LOAD_STRING(spec, i, uri_ptr, n);
    n = uri_len - (n+1);
    p++;
    while(n && isdigit((int) *p)) {
      port = port*10 + (*p - '0');
      n--;
      p++;
    }
    if ((n != 0) || (port == 0))
      i = LOAD_ATOM(spec, i, am_undefined);
    else
      i = LOAD_INT(spec, i, port);
  }
  i = LOAD_STRING(spec, i, abs_path_ptr, abs_path_len);
  i = LOAD_TUPLE(spec, i, 5);
  return i;
}

static int http_load_uri(ErlDrvTermData* spec, int i, char* uri_ptr, int uri_len)
{
  if ((uri_len == 1) && (uri_ptr[0] == '*'))
    i = LOAD_ATOM(spec, i, am_star);
  else if ((uri_len <= 1) || (uri_ptr[0] == '/')) {
    i = LOAD_ATOM(spec, i, am_abs_path);
    i = LOAD_STRING(spec, i, uri_ptr, uri_len);
    i = LOAD_TUPLE(spec, i, 2);
  }
  else {
    if ((uri_len>=7) && (STRNCASECMP(uri_ptr, "http://", 7) == 0)) {
      uri_len -= 7;
      uri_ptr += 7;
      return http_load_absoluteURI(spec, i, am_http, uri_ptr, uri_len);
    }
    else if ((uri_len>=8) && (STRNCASECMP(uri_ptr, "https://", 8) == 0)) {
      uri_len -= 8;
      uri_ptr += 8;    
      return http_load_absoluteURI(spec, i, am_https, uri_ptr,uri_len);
    }
    else {
      char* ptr;
      if ((ptr = memchr(uri_ptr, ':', uri_len)) == NULL)
	i = LOAD_STRING(spec, i, uri_ptr, uri_len);
      else {
	int slen = ptr - uri_ptr;
	i = LOAD_ATOM(spec, i, am_scheme);
	i = LOAD_STRING(spec, i, uri_ptr, slen);
	i = LOAD_STRING(spec, i, uri_ptr+(slen+1), uri_len-(slen+1));
	i = LOAD_TUPLE(spec, i, 3);
      }
    }
  }
  return i;
}

static int
http_request_message(tcp_descriptor* desc, http_atom_t* meth, char* meth_ptr,
		     int meth_len, char* uri_ptr, int uri_len,
		     int major, int minor)
{
  int i = 0;
  ErlDrvTermData spec[43];

  if (desc->inet.active == INET_PASSIVE) {
    /* {inet_async, S, Ref, {ok,{http_request,Meth,Uri,Version}}} */
    int req;
    int aid;
    ErlDrvTermData caller;

    if (deq_async(INETP(desc), &aid, &caller, &req) < 0)
      return -1;
    i = LOAD_ATOM(spec, i,  am_inet_async);
    i = LOAD_PORT(spec, i,  desc->inet.dport);
    i = LOAD_INT(spec, i,   aid);
    i = LOAD_ATOM(spec, i,  am_ok);
    i = LOAD_ATOM(spec, i,  am_http_request);
    if (meth != NULL)
      i = LOAD_ATOM(spec, i, meth->atom);
    else
      i = LOAD_STRING(spec, i, meth_ptr, meth_len);
    i = http_load_uri(spec, i, uri_ptr, uri_len);
    i = LOAD_INT(spec, i, major);
    i = LOAD_INT(spec, i, minor);
    i = LOAD_TUPLE(spec, i, 2);
    i = LOAD_TUPLE(spec, i, 4);
    i = LOAD_TUPLE(spec, i, 2);
    i = LOAD_TUPLE(spec, i, 4);
    ASSERT(i <= 43);
    return driver_send_term(desc->inet.port, caller, spec, i);
  }
  else {
    /* {http_request, S, Meth, Uri, Version} */
    i = LOAD_ATOM(spec, i,  am_http_request);
    i = LOAD_PORT(spec, i,  desc->inet.dport);
    if (meth != NULL)
      i = LOAD_ATOM(spec, i, meth->atom);
    else
      i = LOAD_STRING(spec, i, meth_ptr, meth_len);
    i = http_load_uri(spec, i, uri_ptr, uri_len);
    i = LOAD_INT(spec, i, major);
    i = LOAD_INT(spec, i, minor);
    i = LOAD_TUPLE(spec, i, 2);
    i = LOAD_TUPLE(spec, i, 5);
    ASSERT(i <= 43);
    return driver_output_term(desc->inet.port, spec, i);
  }
}

static int
http_header_message(tcp_descriptor* desc, http_atom_t* name, char* name_ptr,
		    int name_len, char* value_ptr, int value_len)
{
  int i = 0;
  ErlDrvTermData spec[26];

  if (desc->inet.active == INET_PASSIVE) {
    /* {inet_async,S,Ref,{ok,{http_header,Bit,Name,IValue,Value}} */
    int req;
    int aid;
    ErlDrvTermData caller;

    if (deq_async(INETP(desc), &aid, &caller, &req) < 0)
      return -1;
    i = LOAD_ATOM(spec, i,  am_inet_async);
    i = LOAD_PORT(spec, i,  desc->inet.dport);
    i = LOAD_INT(spec, i,   aid);
    i = LOAD_ATOM(spec, i,  am_ok);
    i = LOAD_ATOM(spec, i,  am_http_header);
    if (name != NULL) {
      i = LOAD_INT(spec, i,  name->index+1);
      i = LOAD_ATOM(spec, i, name->atom);
    }
    else {
      i = LOAD_INT(spec, i,  0);
      i = LOAD_STRING(spec, i, name_ptr, name_len);
    }
    i = LOAD_ATOM(spec, i, am_undefined);
    i = LOAD_STRING(spec, i, value_ptr, value_len);
    i = LOAD_TUPLE(spec, i, 5);
    i = LOAD_TUPLE(spec, i, 2);
    i = LOAD_TUPLE(spec, i, 4);
    ASSERT(i <= 26);
    return driver_send_term(desc->inet.port, caller, spec, i);
  }
  else {
    /* {http_header,S,Bit,Name,Code,Value} */
    i = LOAD_ATOM(spec, i,  am_http_header);
    i = LOAD_PORT(spec, i,  desc->inet.dport);
    if (name != NULL) {
      i = LOAD_INT(spec, i,  name->index+1);
      i = LOAD_ATOM(spec, i, name->atom);
    }
    else {
      i = LOAD_INT(spec, i,  0);
      i = LOAD_STRING(spec, i, name_ptr, name_len);
    }
    i = LOAD_ATOM(spec, i, am_undefined);
    i = LOAD_STRING(spec, i, value_ptr, value_len);
    i = LOAD_TUPLE(spec, i, 6);
    ASSERT(i <= 26);
    return driver_output_term(desc->inet.port, spec, i);
  }
}

static int http_eoh_message(tcp_descriptor* desc)
{
  int i = 0;
  ErlDrvTermData spec[14];

  if (desc->inet.active == INET_PASSIVE) {
    /* {inet_async,S,Ref,{ok,http_eoh}} */
    int req;
    int aid;
    ErlDrvTermData caller;

    if (deq_async(INETP(desc), &aid, &caller, &req) < 0)
      return -1;
    i = LOAD_ATOM(spec, i,  am_inet_async);
    i = LOAD_PORT(spec, i,  desc->inet.dport);
    i = LOAD_INT(spec, i,   aid);
    i = LOAD_ATOM(spec, i,  am_ok);
    i = LOAD_ATOM(spec, i,  am_http_eoh);
    i = LOAD_TUPLE(spec, i, 2);
    i = LOAD_TUPLE(spec, i, 4);
    ASSERT(i <= 14);
    return driver_send_term(desc->inet.port, caller, spec, i);
  }
  else {
    /* {http_eoh,S} */
    i = LOAD_ATOM(spec, i,  am_http_eoh);
    i = LOAD_PORT(spec, i,  desc->inet.dport);
    i = LOAD_TUPLE(spec, i, 2);
    ASSERT(i <= 14);
    return driver_output_term(desc->inet.port, spec, i);
  }
}

static int http_error_message(tcp_descriptor* desc, char* buf, int len)
{
  int i = 0;
  ErlDrvTermData spec[19];

  if (desc->inet.active == INET_PASSIVE) {
    /* {inet_async,S,Ref,{error,{http_error,Line}}} */
    int req;
    int aid;
    ErlDrvTermData caller;

    if (deq_async(INETP(desc), &aid, &caller, &req) < 0)
      return -1;
    i = LOAD_ATOM(spec, i,  am_inet_async);
    i = LOAD_PORT(spec, i,  desc->inet.dport);
    i = LOAD_INT(spec, i,   aid);
    i = LOAD_ATOM(spec, i,  am_error);
    i = LOAD_ATOM(spec, i,  am_http_error);
    i = LOAD_STRING(spec, i, buf, len);
    i = LOAD_TUPLE(spec, i, 2);
    i = LOAD_TUPLE(spec, i, 2);
    i = LOAD_TUPLE(spec, i, 4);
    ASSERT(i <= 19);
    return driver_send_term(desc->inet.port, caller, spec, i);
  }
  else {
    /* {http_error,S,Line} */
    i = LOAD_ATOM(spec, i,  am_http_error);
    i = LOAD_PORT(spec, i,  desc->inet.dport);
    i = LOAD_STRING(spec, i, buf, len);
    i = LOAD_TUPLE(spec, i, 3);
    ASSERT(i <= 19);
    return driver_output_term(desc->inet.port, spec, i);
  }
}

/*
** load http message:
**  {http_eoh, S}                          - end of headers
**  {http_header,   S, Key, Value}         - Key = atom() | string()
**  {http_request,  S, Method,Url,Version}
**  {http_response, S, Version, Status, Message}
**  {http_error,    S, Error-Line}
*/
static int http_message(tcp_descriptor* desc, char* buf, int len)
{
  char* ptr = buf;
  int n = len;

  /* remove trailing CRNL (accept NL as well) */
  if ((n >= 2) && (buf[n-2] == '\r'))
    n -= 2;
  else if ((n >= 1) && (buf[n-1] == '\n'))
    n -= 1;

  if (desc->http_state == 0) {
    unsigned long h;
    http_atom_t* meth;
    char* meth_ptr;
    int   meth_len;
    int c;
    /* start-line = Request-Line | Status-Line */
    if (n == 0)
	return -1;
    h = 0;
    meth_ptr = ptr;
    while (n && !is_tspecial((unsigned char)*ptr)) {
      c = *ptr;
      hash_update(h, c);
      ptr++;
      n--;
    }
    if ((meth_len = (ptr - meth_ptr)) == 0)
      return -1;
    meth = http_hash_lookup(meth_ptr, meth_len, h,
			    http_meth_hash, HTTP_METH_HASH_SIZE);
    if (n) {
      if ((*ptr == '/') && (strncmp(buf, "HTTP", 4) == 0)) {
	int major  = 0;
	int minor  = 0;
	int status = 0;
	/* Status-Line = HTTP-Version SP 
	 *              Status-Code SP Reason-Phrase 
	 *              CRNL
	 * HTTP-Version   = "HTTP" "/" 1*DIGIT "." 1*DIGIT
	 */
	ptr++;
	n--;
	if (!n || !isdigit((int) *ptr)) return -1;
	while(n && isdigit((int) *ptr)) {
	  major = 10*major + (*ptr - '0');
	  ptr++;
	  n--;
	}
	if (!n || (*ptr != '.'))
	  return -1;
	ptr++;
	n--;
	if (!n || !isdigit((int) *ptr)) return -1;
	while(n && isdigit((int) *ptr)) {
	  minor = 10*minor + (*ptr - '0');
	  ptr++;
	  n--;
	}
	if (!n || !SP(ptr))
	  return -1;

	while(n && SP(ptr)) { ptr++; n--; }

	while(n && isdigit((int) *ptr)) {
	  status = 10*status + (*ptr - '0');
	  ptr++;
	  n--;
	}
	if (!n || !SP(ptr))
	  return -1;

	while(n && SP(ptr)) { ptr++; n--; }

	/* NOTE: the syntax allows empty reason phrases */
	desc->http_state++;

	return http_response_message(desc, major, minor, status,
				     (char*)ptr, n);
      }
      else if (SP(ptr)) {
	/* Request-Line = Method SP Request-URI SP HTTP-Version CRLF */
	char* uri_ptr;
	int   uri_len;
	int major  = 0;
	int minor  = 0;
	
	while(n && SP(ptr)) { ptr++; n--; }
	uri_ptr = ptr;
	while(n && !SP(ptr)) { ptr++; n--; }
	if ((uri_len = (ptr - uri_ptr)) == 0)
	  return -1;
	while(n && SP(ptr)) { ptr++; n--; }
	if (n == 0) {
	  desc->http_state++;
	  return http_request_message(desc, meth,
				      meth_ptr, meth_len,
				      uri_ptr, uri_len,
				      0, 9);
	}
	if (n < 8)
	  return -1;
	if (strncmp(ptr, "HTTP/", 5) != 0)
	  return -1;
	ptr += 5;
	n   -= 5;

	if (!n || !isdigit((int) *ptr)) return -1;
	while(n && isdigit((int) *ptr)) {
	  major = 10*major + (*ptr - '0');
	  ptr++;
	  n--;
	}

	if (!n || (*ptr != '.'))
	  return -1;
	ptr++;
	n--;

	if (!n || !isdigit((int) *ptr)) return -1;
	while(n && isdigit((int) *ptr)) {
	  minor = 10*minor + (*ptr - '0');
	  ptr++;
	  n--;
	}
	desc->http_state++;
	return http_request_message(desc, meth,
				    meth_ptr, meth_len,
				    uri_ptr, uri_len,
				    major, minor);
      }
    }
    return -1;
  }
  else {
    int up = 1;      /* make next char uppercase */
    http_atom_t* name;
    char* name_ptr;
    int   name_len;
    unsigned long h;

    if (n == 0) {
      /* end of headers */
      desc->http_state = 0;  /* reset state (for next request) */
      return http_eoh_message(desc);
    }
    h = 0;
    while(n && !is_tspecial((unsigned char)*ptr)) {
      int c = *ptr;
      if (up) {
	if (islower(c)) {
	  c = toupper(c);
	}
	up = 0;
      }
      else {
	if (isupper(c))
	  c = tolower(c);
	else if (c == '-')
	  up = 1;
      }
      *ptr = c;
      hash_update(h, c);
      ptr++;
      n--;
    }
    if (*ptr != ':') {
      /* Error case */
      return -1;
    }
    name_ptr = buf;
    name_len = (ptr - buf);
    name = http_hash_lookup(name_ptr, name_len, h,
			    http_hdr_hash, HTTP_HDR_HASH_SIZE);
    ptr++;
    n--;
    /* Skip white space */
    while(n && SP(ptr)) { ptr++; n--; }

    return http_header_message(desc, name, name_ptr, name_len,
			       ptr, n);
  }
}
#endif

/* 
** passive mode reply:
**        {inet_async, S, Ref, {ok,[H1,...Hsz | Data]}}
** NB: this is for TCP only;
** UDP and SCTP use inet_async_binary_data .
*/
static int inet_async_data(inet_descriptor* desc, char* buf, int len)
{
    unsigned int hsz = desc->hsz;
    ErlDrvTermData spec[20];
    ErlDrvTermData caller;
    int req;
    int aid;
    int i = 0;

    DEBUGF(("inet_async_data(%ld): len = %d\r\n", (long)desc->port, len));

    if (deq_async(desc, &aid, &caller, &req) < 0)
	return -1;

    i = LOAD_ATOM(spec, i, am_inet_async);
    i = LOAD_PORT(spec, i, desc->dport);
    i = LOAD_INT(spec, i, aid);

    i = LOAD_ATOM(spec, i, am_ok);
    if ((desc->mode == INET_MODE_LIST) || (hsz > len)) {
	i = LOAD_STRING(spec, i, buf, len); /* => [H1,H2,...Hn] */ 
	i = LOAD_TUPLE(spec, i, 2);
	i = LOAD_TUPLE(spec, i, 4);
	ASSERT(i == 15);
	desc->caller = 0;
	return driver_send_term(desc->port, caller, spec, i);
    }
    else {
	/* INET_MODE_BINARY => [H1,H2,...HSz | Binary] */
	ErlDrvBinary* bin;
	int sz = len - hsz;
	int code;

	if ((bin = driver_alloc_binary(sz)) == NULL)
	    return async_error(desc, ENOMEM);
	memcpy(bin->orig_bytes, buf+hsz, sz);
	i = LOAD_BINARY(spec, i, bin, 0, sz);
	if (hsz > 0)
	    i = LOAD_STRING_CONS(spec, i, buf, hsz);
	i = LOAD_TUPLE(spec, i, 2);
	i = LOAD_TUPLE(spec, i, 4);
	ASSERT(i <= 20);
	desc->caller = 0;
	code = driver_send_term(desc->port, caller, spec, i);
	driver_free_binary(bin);  /* must release binary */
	return code;
    }
}

#ifdef HAVE_SCTP
/*
** SCTP-related atoms:
*/
static ErlDrvTermData   am_sctp_rtoinfo, /* Option names */
    am_sctp_associnfo,                 am_sctp_initmsg,
    am_sctp_autoclose,                 am_sctp_nodelay,
    am_sctp_disable_fragments,         am_sctp_i_want_mapped_v4_addr,
    am_sctp_maxseg,                    am_sctp_set_peer_primary_addr,
    am_sctp_primary_addr,              am_sctp_adaption_layer,
    am_sctp_peer_addr_params,          am_sctp_default_send_param,
    am_sctp_events,                    am_sctp_delayed_ack_time,
    am_sctp_status,                    am_sctp_get_peer_addr_info,
    
    /* Record names */
    am_sctp_sndrcvinfo,                am_sctp_assoc_change,
    am_sctp_paddr_change,              am_sctp_remote_error,
    am_sctp_send_failed,               am_sctp_shutdown_event,
    am_sctp_adaption_event,            am_sctp_pdapi_event,
    am_sctp_assocparams,               am_sctp_prim,
    am_sctp_setpeerprim,               am_sctp_setadaption,
    am_sctp_paddrparams,               am_sctp_event_subscribe,
    am_sctp_assoc_value,               am_sctp_paddrinfo,

    /* For #sctp_sndrcvinfo{}: */
    am_unordered,                      am_addr_over,
    am_abort,                          am_eof,
    
    /* For #sctp_assoc_change{}: */
    am_comm_up,                        am_comm_lost,
    am_restart,                        am_shutdown_comp,
    am_cant_assoc,
    
    /* For #sctp_paddr_change{}: */
    am_addr_available,                 am_addr_unreachable, 
    am_addr_removed,                   am_addr_added,
    am_addr_made_prim,
    
    /* For #sctp_remote_error{}: */
    am_short_recv,                     am_wrong_anc_data,
    
    /* For #sctp_pdap_event{}: */
    am_partial_delivery_aborted,
    
    /* For #sctp_paddrparams{}: */
    am_hb_enable,                      am_hb_disable,
    am_hb_demand,                      am_pmtud_enable,
    am_pmtud_disable,                  am_sackdelay_enable,
    am_sackdelay_disable,
    
    /* For #sctp_paddrinfo{}: */
    am_active,                         am_inactive,
    
    /* For #sctp_status{}: */
    am_empty,                          am_closed,
    am_cookie_wait,                    am_cookie_echoed,
    am_established,                    am_shutdown_pending,
    am_shutdown_sent,                  am_shutdown_received,
    am_shutdown_ack_sent;
    /* Not yet implemented in the Linux kernel:
    ** am_bound,                          am_listen;
    */

/*
** Parsing of "sctp_sndrcvinfo": ancillary data coming with received msgs.
** This function is mainly used by "sctp_parse_ancillary_data",  but also
** by "sctp_parse_async_event" in case of SCTP_SEND_FAILED:
*/
#define SCTP_PARSE_SNDRCVINFO_CNT                            \
        (5*LOAD_ATOM_CNT + 7*LOAD_INT_CNT + LOAD_NIL_CNT +   \
	 LOAD_LIST_CNT + LOAD_ASSOC_ID_CNT + LOAD_TUPLE_CNT)
static int sctp_parse_sndrcvinfo
	   (ErlDrvTermData * spec, int i, struct sctp_sndrcvinfo * sri)
{
    i = LOAD_ATOM	(spec, i, am_sctp_sndrcvinfo);
    i = LOAD_INT	(spec, i, sri->sinfo_stream);
    i = LOAD_INT	(spec, i, sri->sinfo_ssn);
    /* Now Flags, as a list: */
    int n = 0;
    if (sri->sinfo_flags & SCTP_UNORDERED)
	{ i = LOAD_ATOM (spec, i, am_unordered);     n++; }

    if (sri->sinfo_flags & SCTP_ADDR_OVER)
	{ i = LOAD_ATOM (spec, i, am_addr_over);     n++; }

    if (sri->sinfo_flags & SCTP_ABORT)
	{ i = LOAD_ATOM (spec, i, am_abort);	     n++; }

    if (sri->sinfo_flags & SCTP_EOF)
	{ i = LOAD_ATOM (spec, i, am_eof);	     n++; }

    /* SCTP_SENDALL is not yet supported by the Linux kernel     */
    i = LOAD_NIL	(spec, i);
    i = LOAD_LIST	(spec, i, n+1);

    /* Continue with other top-level fields: */
    i = LOAD_INT	(spec, i, sock_ntohl(sri->sinfo_ppid));
    i = LOAD_INT	(spec, i, sri->sinfo_context);
    i = LOAD_INT	(spec, i, sri->sinfo_timetolive);
    i = LOAD_INT	(spec, i, sri->sinfo_tsn);
    i = LOAD_INT	(spec, i, sri->sinfo_cumtsn);
    i = LOAD_ASSOC_ID	(spec, i, sri->sinfo_assoc_id);

    /* Close up the record: */
    i = LOAD_TUPLE	(spec, i, 10);
    return i;
}

/*
** This function skips non-SCTP ancillary data, returns SCTP-specific anc.data
** (currently "sctp_sndrcvinfo" only) as a list of records:
*/
static int sctp_parse_ancillary_data
	   (ErlDrvTermData * spec, int i, struct msghdr * mptr)
{
    /* First of all, check for ancillary data: */
    struct cmsghdr * cmsg, * frst_msg = CMSG_FIRSTHDR(mptr);
    int    s = 0;
    for (cmsg = frst_msg; cmsg != NULL; cmsg = CMSG_NXTHDR(mptr,cmsg))
    {
	/* Skip other possible ancillary data, e.g. from IPv6: */
	if (cmsg->cmsg_level != IPPROTO_SCTP ||
	    cmsg->cmsg_type  != SCTP_SNDRCV)
	continue;

	if (((char*)cmsg + cmsg->cmsg_len) - (char*)frst_msg >
	    mptr->msg_controllen)
	    /* MUST check this in Linux --  the returned "cmsg" may actually
	       go too far! */
	    break;

	/* The ONLY kind of ancillary SCTP data which can occur on receiving
	   is "sctp_sndrcvinfo" (on sending, "sctp_initmsg" can be specified
	   by the user). So parse this type:
	*/
	struct sctp_sndrcvinfo * sri =
	    (struct sctp_sndrcvinfo*) CMSG_DATA(cmsg);

	i = sctp_parse_sndrcvinfo (spec, i, sri);
	s ++;
    }
    /* Now make the list of tuples created above. Normally, it will be [] or
       a singleton list.   The list must first be closed with NIL, otherwise
       traversing it in Erlang would be problematic:
    */
    i = LOAD_NIL (spec, i);
    i = LOAD_LIST(spec, i, s+1);
    return i;
}

/*
** Parsing of ERROR and ABORT SCTP chunks. The function returns a list of error
** causes (as atoms).  The chunks also contain some extended cause info, but it
** is not very detailed anyway, and of no interest at the user level   (it only
** concerns the protocol implementation), so we omit it:
*/
static int sctp_parse_error_chunk
       (ErlDrvTermData * spec, int i, char * chunk, int chlen)
{
    /* The "chunk" itself contains its length, which must not be greater than
       the "chlen" derived from the over-all msg size:
    */
    int len = sock_ntohs (*((uint16_t*)(chunk+2)));
    ASSERT(len >= 4 && len <= chlen);

    char * causes = chunk + 4;
    int    coff   = 0;  /* Cause offset */
    len -= 4;	    	/* Total length of the "causes" fields */

    int    ccode;	/* Cause code   */
    int    clen;	/* Cause length */
    char * cause  = causes;
    int    s      = 0;

    while (coff < len)
    {
	ccode = sock_ntohs (*((uint16_t*)(cause)));
	clen  = sock_ntohs (*((uint16_t*)(cause + 2)));
	if (clen <= 0)
	    /* Strange, but must guard against that!  */
	    break;

	/* Install the corresp atom for this "ccode": */
	i = LOAD_INT (spec, i, ccode);
	cause += clen;
	coff  += clen;
	s ++;
    }
    i = LOAD_NIL (spec, i);
    i = LOAD_LIST(spec, i, s+1);
    return i;
}

/*
** Parsing of SCTP notification events. NB: they are NOT ancillary data: they
** are sent IN PLACE OF, not in conjunction with, the normal data:
*/
static int sctp_parse_async_event
      (ErlDrvTermData * spec, int i,    int ok_pos,
       ErlDrvTermData   error_atom,     inet_descriptor* desc,
       ErlDrvBinary   * bin,  int offs, int sz)
{
    char* body			   = bin->orig_bytes + offs;
    union sctp_notification * nptr = (union sctp_notification *) body;

    switch (nptr->sn_header.sn_type)
    {    
	case SCTP_ASSOC_CHANGE:
	{   /* {sctp_assoc_change,
		State		: Atom(),
		Error		: Atom(),
		OutBoundStreams : Int(),
		InBoundStreams  : Int(),
		AssocID		: Int(),
		// AbortCauses	: [Atom()]   // NOT YET IMPLEMENTED
	       }
	    */
	    struct sctp_assoc_change* sptr = &(nptr->sn_assoc_change);
	    ASSERT(sptr->sac_length <= sz);  /* No buffer overrun */

	    i = LOAD_ATOM (spec, i, am_sctp_assoc_change);

	    switch (sptr->sac_state)
	    {
	    case SCTP_COMM_UP:
		i = LOAD_ATOM (spec, i, am_comm_up);
		break;
	    case SCTP_COMM_LOST:
		i = LOAD_ATOM (spec, i, am_comm_lost);
		break;
	    case SCTP_RESTART:
		i = LOAD_ATOM (spec, i, am_restart);
		break;
	    case SCTP_SHUTDOWN_COMP:
		i = LOAD_ATOM (spec, i, am_shutdown_comp);
		break;
	    case SCTP_CANT_STR_ASSOC:
		i = LOAD_ATOM (spec, i, am_cant_assoc);
		break;
	    default:
		ASSERT(0);
	    }
	    i = LOAD_INT (spec, i, sptr->sac_error);
	    i = LOAD_INT (spec, i, sptr->sac_outbound_streams);
	    i = LOAD_INT (spec, i, sptr->sac_inbound_streams);
	    i = LOAD_INT (spec, i, sptr->sac_assoc_id);

	    /* The ABORT chunk may or may not be present at the end, depending
	       on whether there was really an ABORT.  In the Linux Kernel SCTP
	       implementation, this chunk is not delivered anyway, so we leave
	       it out. Just close up the tuple:
	    */
	    i = LOAD_TUPLE (spec, i, 6);
	    break;
	}

	case SCTP_PEER_ADDR_CHANGE:
	{   /* {sctp_paddr_change,
		AffectedAddr	: String(),
		State		: Atom(),
		Error		: Atom(),
		AssocID		: Int()
	       }
	    */
	    struct sctp_paddr_change* sptr = &(nptr->sn_paddr_change);
	    ASSERT(sptr->spc_length <= sz);  /* No buffer overrun */

	    i = LOAD_ATOM	(spec, i, am_sctp_paddr_change);
	    i = load_ip_and_port(spec, i, desc, &sptr->spc_aaddr);

	    switch (sptr->spc_state)
	    {
	    case SCTP_ADDR_AVAILABLE:
		i = LOAD_ATOM (spec, i, am_addr_available);
		break;
	    case SCTP_ADDR_UNREACHABLE:
		i = LOAD_ATOM (spec, i, am_addr_unreachable);
		break;
	    case SCTP_ADDR_REMOVED:
		i = LOAD_ATOM (spec, i, am_addr_removed);
		break;
	    case SCTP_ADDR_ADDED:
		i = LOAD_ATOM (spec, i, am_addr_added);
		break;
	    case SCTP_ADDR_MADE_PRIM:
		i = LOAD_ATOM (spec, i, am_addr_made_prim);
		break;
	    default:
		ASSERT(0);
	    }
	    i = LOAD_INT   (spec, i, sptr->spc_error);
	    i = LOAD_INT   (spec, i, sptr->spc_assoc_id);
	    i = LOAD_TUPLE (spec, i, 5);
	    break;
	}

	case SCTP_REMOTE_ERROR:
	{   /* This is an error condition, so we return an error term
	       {sctp_remote_error,
		Error		: Int(),
		AssocID		: Int(),
		RemoteCauses	: [Atom()] // Remote Error flags
	       }
	    */
	    struct sctp_remote_error * sptr = &(nptr->sn_remote_error);
	    ASSERT(sptr->sre_length <= sz);   /* No buffer overrun */

	    /* Over-write the prev part of the response with an error: */
	    (void)LOAD_ATOM(spec, ok_pos, error_atom);

	    /* Continue from the curr pos: */
	    i = LOAD_ATOM  (spec, i, am_sctp_remote_error);

	    i = LOAD_INT   (spec, i, sock_ntohs(sptr->sre_error));
	    i = LOAD_INT   (spec, i, sptr->sre_assoc_id);

#	    ifdef HAVE_SCTP_REMOTE_ERROR_SRE_DATA
	    char * chunk = (char*) (&(sptr->sre_data));
#	    else
	    char * chunk = ((char*)sptr) + sizeof(*sptr);
#	    endif
	    int    chlen = sptr->sre_length  - (chunk - (char *)sptr);
	    i = sctp_parse_error_chunk(spec, i, chunk, chlen);

	    i = LOAD_TUPLE (spec, i, 4);
	    /* The {error, {...}} will be closed by the caller */
	    break;
	}

	case SCTP_SEND_FAILED:
	{   /* {sctp_send_failed,
		DataSent	: Atom()	// true or false
		Error		: Atom(),
		OrigInfo	: Tuple(),
		AssocID		: Int(),
		OrigData	: Binary()
	       }
	       This is also an ERROR condition -- overwrite the 'ok':
	    */
	    struct sctp_send_failed * sptr = &(nptr->sn_send_failed);
	    ASSERT(sptr->ssf_length <= sz);	/* No buffer overrun */

	    /* Over-write 'ok' with 'error', continue from curr "i": */
	    (void)LOAD_ATOM(spec, ok_pos, error_atom);

	    i = LOAD_ATOM  (spec, i, am_sctp_send_failed);
	    switch (sptr->ssf_flags) {
	    case SCTP_DATA_SENT:
		i = LOAD_ATOM (spec, i, am_true);
		break;
	    case SCTP_DATA_UNSENT:
		i = LOAD_ATOM (spec, i, am_false);
		break;
	    default:
		ASSERT(0);
	    }
	    i = LOAD_INT      (spec, i, sptr->ssf_error);
	    /* Now parse the orig SCTP_SNDRCV info */
	    i = sctp_parse_sndrcvinfo (spec, i, &sptr->ssf_info);
	    i = LOAD_ASSOC_ID (spec, i, sptr->ssf_assoc_id);

	    /* Load the orig data chunk, as an unparsed binary. Note that
	       in LOAD_BINARY below, we must specify the offset wrt bin->
	       orig_bytes. In Solaris 10, we don't have ssf_data:
	    */
#	    ifdef HAVE_SCTP_SEND_FAILED_SSF_DATA
	    char * chunk = (char*) (&(sptr->ssf_data));
#	    else
	    char * chunk = ((char*)sptr) + sizeof(*sptr);
#	    endif
	    int    chlen = sptr->ssf_length - (chunk - (char*) sptr);
	    int    choff = chunk - bin->orig_bytes;

	    i = LOAD_BINARY(spec, i, bin, choff, chlen);
	    i = LOAD_TUPLE (spec, i, 6);
	    /* The {error, {...}} tuple is not yet closed */
	    break;
	}

	case SCTP_SHUTDOWN_EVENT:
	{   /* {sctp_shutdown_event,
		AssocID		: Int()
	       }
	    */
	    struct sctp_shutdown_event * sptr = &(nptr->sn_shutdown_event);

	    ASSERT (sptr->sse_length == sizeof(struct sctp_shutdown_event) &&
		    sptr->sse_length <= sz);	/* No buffer overrun */

	    i = LOAD_ATOM  (spec, i, am_sctp_shutdown_event);
	    i = LOAD_INT   (spec, i, sptr->sse_assoc_id);
	    i = LOAD_TUPLE (spec, i, 2);
	    break;
	}

	case SCTP_ADAPTION_INDICATION:
	{   /* {sctp_adaption_event,
		Indication	: Atom(),
		AssocID		: Int()
	       }
	    */
	    struct sctp_adaption_event * sptr = &(nptr->sn_adaption_event);
	    ASSERT (sptr->sai_length == sizeof(struct sctp_adaption_event) &&
		    sptr->sai_length <= sz);	/* No buffer overrun */

	    i = LOAD_ATOM  (spec, i, am_sctp_adaption_event);
	    i = LOAD_INT   (spec, i, sock_ntohl(sptr->sai_adaption_ind));
	    i = LOAD_INT   (spec, i, sptr->sai_assoc_id);
	    i = LOAD_TUPLE (spec, i, 3);
	    break;
	}

	case SCTP_PARTIAL_DELIVERY_EVENT:
	{   /* It is not clear  whether this event  is sent  to the sender
		(when the receiver gets only a part of a message),   or to
		the receiver itself.  In any case, we do not support partial
		delivery of msgs in this implementation, so this is an error
		condition:
		{sctp_pdapi_event, sctp_partial_delivery_aborted, AssocID}:
	    */
	    (void) LOAD_ATOM  (spec, ok_pos, error_atom);

	    struct sctp_pdapi_event * sptr = &(nptr->sn_pdapi_event);
	    ASSERT (sptr->pdapi_length == sizeof(struct sctp_pdapi_event) &&
		    sptr->pdapi_length <= sz);  /* No buffer overrun */

	    i = LOAD_ATOM  (spec, i, am_sctp_pdapi_event);

	    /* Currently, there is only one indication possible: */
	    ASSERT (sptr->pdapi_indication == SCTP_PARTIAL_DELIVERY_ABORTED);

	    i = LOAD_ATOM  (spec, i, am_partial_delivery_aborted);
	    i = LOAD_INT   (spec, i, sptr->pdapi_assoc_id);
	    i = LOAD_TUPLE (spec, i, 3);
	    /* The {error, {...}} tuple is not yet closed */
	    break;
	}

	/* XXX: No more supported SCTP Event types. The standard also provides
	   SCTP_AUTHENTICATION_EVENT, but it is not implemented in the Linux
	   kernel, hence not supported here either. It is not possible to
	   request delivery of such events in this implementation, so they
	   cannot occur:
	*/
	default:   ASSERT(0);
    }
    return i;
}
#endif  /* HAVE_SCTP */

/* 
** passive mode reply:
** for UDP:
**        {inet_async, S, Ref, {ok, Data=[H1,...,Hsz | BinData]}}
** or (in the list mode)
**	  {inet_async, S, Ref, {ok, Data=[H1,...,Hsz]}}
**
** for SCTP:
**	  {inet_async, S, Ref, {ok, {[H1,...,HSz], [AncilData], Data_OR_Event}}}
** where  each AncilDatum:Tuple();
**	  Data:List() or Binary(), but if List(), then without the Addr part,
**				   which is moved in front;
**	  Event:Tuple();
** or
** 	  {inet_async, S, Ref, {error, {[H1,...,HSz], [AncilData], ErrorTerm}}}
**
** Cf: the output of send_async_error() is
**	  {inet_async, S, Ref, {error, Cause:Atom()}}
*/
static int
inet_async_binary_data
	(inet_descriptor* desc, unsigned  int phsz,
	 ErlDrvBinary   * bin,  int offs, int len, void * extra)
{
    unsigned int hsz = desc->hsz + phsz;
    ErlDrvTermData spec [PACKET_ERL_DRV_TERM_DATA_LEN];
    ErlDrvTermData caller = desc->caller;
    int aid;
    int req;
    int i = 0;

    DEBUGF(("inet_async_binary_data(%ld): offs=%d, len=%d\r\n", 
	    (long)desc->port, offs, len));

    if (deq_async(desc, &aid, &caller, &req) < 0)
	return -1;

    i = LOAD_ATOM(spec, i, am_inet_async);	/* 'inet_async' */
    i = LOAD_PORT(spec, i, desc->dport);	/* S		*/
    i = LOAD_INT (spec, i, aid);		/* Ref		*/

#ifdef HAVE_SCTP
    /* Need to memoise the position of the 'ok' atom written, as it may
       later be overridden by an 'error': */
    int ok_pos = i;
#endif
    i = LOAD_ATOM(spec, i, am_ok);

#ifdef HAVE_SCTP
    if (IS_SCTP(desc))
    {	/* For SCTP we always have desc->hsz==0 (i.e., no application-level
	   headers are used), so hsz==phsz (see above): */
	ASSERT (hsz == phsz && hsz != 0);
	int sz = len - hsz;  /* Size of the msg data proper, w/o the addr */

	/* We always put the Addr as a list in front */
	i = LOAD_STRING(spec, i, bin->orig_bytes+offs, hsz);

	/* Put in the list (possibly empty) of Ancillary Data: */
	struct msghdr* mptr = (struct msghdr *) extra;
	i = sctp_parse_ancillary_data (spec, i, mptr);

	/* Then: Data or Event (Notification)? */
	if (mptr->msg_flags & MSG_NOTIFICATION)
	    /* This is an Event, parse it. It may indicate a normal or an error
	       condition; in the latter case,   the 'ok' above is overridden by
	       an 'error', and the Event we receive contains the error term: */
	    i = sctp_parse_async_event
		(spec, i, ok_pos, am_error, desc, bin, offs+hsz, sz);
        else
    	    /* This is SCTP data, not a notification event.   The data can be
	       returned as a List or as a Binary, similar to the generic case:
	    */
	    if (desc->mode == INET_MODE_LIST)
		/* INET_MODE_LIST   => [H1,H2,...Hn], addr and data together,
		   butthe Addr has already been parsed, so start at offs+hsz:
		*/
		i = LOAD_STRING(spec, i, bin->orig_bytes+offs+hsz, sz);
	    else
	    	/* INET_MODE_BINARY => Binary */
		i = LOAD_BINARY(spec, i, bin, offs+hsz, sz);

	/* Close up the {[H1,...,HSz], [AncilData], Event_OR_Data} tuple. This
	   is valid even in the case when Event is a error notification:  */
	i = LOAD_TUPLE (spec, i, 3);
    }
    else
#endif  /* HAVE_SCTP */
    /* Generic case. Both Addr and Data (or a single list of them together) are
       returned: */

    if ((desc->mode == INET_MODE_LIST) || (hsz > len)) {
	/* INET_MODE_LIST => [H1,H2,...Hn] */
	i = LOAD_STRING(spec, i, bin->orig_bytes+offs, len);
    }
    else {
	/* INET_MODE_BINARY => [H1,H2,...HSz | Binary] or [Binary]: */
	int sz = len - hsz;
	i = LOAD_BINARY(spec, i, bin, offs+hsz, sz);
	if (hsz > 0)
	    i = LOAD_STRING_CONS(spec, i, bin->orig_bytes+offs, hsz);
    }
    /* Close up the {ok, ...} or {error, ...} tuple: */
    i = LOAD_TUPLE(spec, i, 2);

    /* Close up the outer {inet_async, S, Ref, {ok|error, ...}} tuple: */
    i = LOAD_TUPLE(spec, i, 4);

    ASSERT(i <= PACKET_ERL_DRV_TERM_DATA_LEN);    
    desc->caller = 0;
    return driver_send_term(desc->port, caller, spec, i);
}

/* 
** active mode message:
**        {tcp, S, [H1,...Hsz | Data]}
*/
static int tcp_message(inet_descriptor* desc, char* buf, int len)
{
    unsigned int hsz = desc->hsz;
    ErlDrvTermData spec[20];
    int i = 0;

    DEBUGF(("tcp_message(%ld): len = %d\r\n", (long)desc->port, len));    

    i = LOAD_ATOM(spec, i, am_tcp);
    i = LOAD_PORT(spec, i, desc->dport);

    if ((desc->mode == INET_MODE_LIST) || (hsz > len)) {
	i = LOAD_STRING(spec, i, buf, len); /* => [H1,H2,...Hn] */ 
	i = LOAD_TUPLE(spec, i, 3);
	ASSERT(i <= 20);
	return driver_output_term(desc->port, spec, i);
    }
    else {
	/* INET_MODE_BINARY => [H1,H2,...HSz | Binary] */
	ErlDrvBinary* bin;
	int sz = len - hsz;
	int code;

	if ((bin = driver_alloc_binary(sz)) == NULL)
	    return async_error(desc, ENOMEM);
	memcpy(bin->orig_bytes, buf+hsz, sz);
	i = LOAD_BINARY(spec, i, bin, 0, sz);
	if (hsz > 0)
	    i = LOAD_STRING_CONS(spec, i, buf, hsz);
	i = LOAD_TUPLE(spec, i, 3);
	ASSERT(i <= 20);
	code = driver_output_term(desc->port, spec, i);
	driver_free_binary(bin);  /* must release binary */
	return code;
    }
}

/* 
** active mode message:
**        {tcp, S, [H1,...Hsz | Data]}
*/
static int
tcp_binary_message(inet_descriptor* desc, ErlDrvBinary* bin, int offs, int len)
{
    unsigned int hsz = desc->hsz;
    ErlDrvTermData spec[20];
    int i = 0;

    DEBUGF(("tcp_binary_message(%ld): len = %d\r\n", (long)desc->port, len)); 

    i = LOAD_ATOM(spec, i, am_tcp);
    i = LOAD_PORT(spec, i, desc->dport);

    if ((desc->mode == INET_MODE_LIST) || (hsz > len)) {
	/* INET_MODE_LIST => [H1,H2,...Hn] */
	i = LOAD_STRING(spec, i, bin->orig_bytes+offs, len);
    }
    else {
	/* INET_MODE_BINARY => [H1,H2,...HSz | Binary] */
	int sz = len - hsz;

	i = LOAD_BINARY(spec, i, bin, offs+hsz, sz);
	if (hsz > 0)
	    i = LOAD_STRING_CONS(spec, i, bin->orig_bytes+offs, hsz);
    }
    i = LOAD_TUPLE(spec, i, 3);
    ASSERT(i <= 20);
    return driver_output_term(desc->port, spec, i);
}

/*
** send:  active mode  {tcp_closed, S}
*/
static int tcp_closed_message(tcp_descriptor* desc)
{
    ErlDrvTermData spec[6];
    int i = 0;

    DEBUGF(("tcp_closed_message(%ld):\r\n", (long)desc->inet.port)); 
    if (!(desc->tcp_add_flags & TCP_ADDF_CLOSE_SENT)) {
	desc->tcp_add_flags |= TCP_ADDF_CLOSE_SENT;

	i = LOAD_ATOM(spec, i, am_tcp_closed);
	i = LOAD_PORT(spec, i, desc->inet.dport);
	i = LOAD_TUPLE(spec, i, 2);
	ASSERT(i <= 6);
	return driver_output_term(desc->inet.port, spec, i);
    } 
    return 0;
}

/*
** send active message {tcp_error, S, Error}
*/
static int tcp_error_message(tcp_descriptor* desc, int err)
{
    ErlDrvTermData spec[8];
    ErlDrvTermData am_err = error_atom(err);
    int i = 0;

    DEBUGF(("tcp_error_message(%ld): %d\r\n", (long)desc->inet.port, err)); 

    i = LOAD_ATOM(spec, i, am_tcp_error);
    i = LOAD_PORT(spec, i, desc->inet.dport);
    i = LOAD_ATOM(spec, i, am_err);
    i = LOAD_TUPLE(spec, i, 3);
    ASSERT(i <= 8);
    return driver_output_term(desc->inet.port, spec, i);
}

/* 
** active mode message:
**        {udp,  S, IP, Port, [H1,...Hsz | Data]} or
**	  {sctp, S, IP, Port, {[AncilData],  Event_or_Data}}
** where
** 	  [H1,...,HSz] are msg headers (without IP/Port, UDP only),
**	  Data  : List() | Binary()
*/
static int packet_binary_message
    (inet_descriptor* desc, ErlDrvBinary* bin, int offs, int len, void* extra)
{
    unsigned int hsz = desc->hsz;
    ErlDrvTermData spec [PACKET_ERL_DRV_TERM_DATA_LEN];
    int i = 0;
    int alen;

    DEBUGF(("packet_binary_message(%ld): len = %d\r\n",
	   (long)desc->port, len));
#   ifdef HAVE_SCTP
    i = LOAD_ATOM(spec, i, IS_SCTP(desc) ? am_sctp : am_udp); /* UDP|SCTP */
#   else
    i = LOAD_ATOM(spec, i, am_udp );			      /* UDP only */
#   endif
    i = LOAD_PORT(spec, i, desc->dport);   		      /* S	  */
    
    alen = addrlen(desc->sfamily);
    i = load_ip_address(spec, i, desc->sfamily, bin->orig_bytes+offs+3);
    i = load_ip_port(spec, i, bin->orig_bytes+offs+1);	      /* IP, Port */
    
    offs += (alen + 3);
    len  -= (alen + 3);

#   ifdef HAVE_SCTP
    if (!IS_SCTP(desc))
    {
#   endif
	if ((desc->mode == INET_MODE_LIST) || (hsz > len))
	    /* INET_MODE_LIST, or only headers => [H1,H2,...Hn] */
	    i = LOAD_STRING(spec, i, bin->orig_bytes+offs, len);
	else {
	    /* INET_MODE_BINARY => [H1,H2,...HSz | Binary]	*/
	    int sz = len - hsz;

	    i = LOAD_BINARY(spec, i, bin, offs+hsz, sz);
	    if (hsz > 0)
		i = LOAD_STRING_CONS(spec, i, bin->orig_bytes+offs, hsz);
	}
#   ifdef HAVE_SCTP
    }
    else
    {	/* For SCTP we always have desc->hsz==0 (i.e., no application-level
	   headers are used): */
	ASSERT(hsz == 0);

	/* Put in the list (possibly empty) of Ancillary Data: */
	struct msghdr* mptr = (struct msghdr *) extra;
	i = sctp_parse_ancillary_data (spec, i, mptr);

	/* Then: Data or Event (Notification)? */
	if (mptr->msg_flags & MSG_NOTIFICATION)
	    /* This is an Event, parse it. It may indicate a normal or an error
	       condition; in the latter case,  the initial 'sctp' atom is over-
	       ridden by 'sctp_error',   and the Event we receive contains the
	       error term: */
	    i = sctp_parse_async_event
		(spec, i, 0, am_sctp_error, desc, bin, offs, len);
        else
    	    /* This is SCTP data, not a notification event.   The data can be
	       returned as a List or as a Binary, similar to the generic case:
	    */
	    if (desc->mode == INET_MODE_LIST)
		/* INET_MODE_LIST   => [H1,H2,...Hn], addr and data together,
		   but the Addr has already been parsed, so start at offs:
		*/
		i = LOAD_STRING(spec, i, bin->orig_bytes+offs, len);
	    else
	    	/* INET_MODE_BINARY => Binary */
		i = LOAD_BINARY(spec, i, bin, offs, len);

	/* Close up the {[AncilData], Event_OR_Data} tuple: */
	i = LOAD_TUPLE (spec, i, 2);
    }
#   endif /* HAVE_SCTP */

    /* Close up the outer 5-tuple: */
    i = LOAD_TUPLE(spec, i, 5);
    ASSERT(i <= PACKET_ERL_DRV_TERM_DATA_LEN);
    return driver_output_term(desc->port, spec, i);
}

/*
** send active message {udp_error|sctp_error, S, Error}
*/
static int packet_error_message(udp_descriptor* udesc, int err)
{
    inet_descriptor* desc = INETP(udesc);
    ErlDrvTermData spec[2*LOAD_ATOM_CNT + LOAD_PORT_CNT + LOAD_TUPLE_CNT];
    ErlDrvTermData am_err = error_atom(err);
    int i = 0;

    DEBUGF(("packet_error_message(%ld): %d\r\n",
	   (long)desc->port, err)); 

#   ifdef HAVE_SCTP
    if (IS_SCTP(desc) )
    	i = LOAD_ATOM(spec, i, am_sctp_error);
    else
#   endif
	i = LOAD_ATOM(spec, i, am_udp_error);

    i = LOAD_PORT(spec, i, desc->dport);
    i = LOAD_ATOM(spec, i, am_err);
    i = LOAD_TUPLE(spec, i, 3);
    ASSERT(i == sizeof(spec)/sizeof(*spec));
    return driver_output_term(desc->port, spec, i);
}

/*
** The fcgi header is 8 bytes. After that comes the data and
** possibly some padding.
** return length of the header (and total length int plen)
** return -1 when not enough bytes
** return -2 when error
*/
#define FCGI_VERSION_1		1

struct fcgi_head {
  unsigned char version;
  unsigned char type;
  unsigned char requestIdB1;
  unsigned char requestIdB0;
  unsigned char contentLengthB1;
  unsigned char contentLengthB0;
  unsigned char paddingLength;
  unsigned char reserved;
};


#define CDR_MAGIC "GIOP"

struct cdr_head {
    unsigned char magic[4];        /* 4 bytes must be 'GIOP' */
    unsigned char major;           /* major version */ 
    unsigned char minor;           /* minor version */
    unsigned char flags;           /* bit 0: 0 == big endian, 1 == little endian 
				      bit 1: 1 == more fragments follow
				   */
    unsigned char message_type;    /* message type ... */
    unsigned char message_size[4]; /* size in (flags bit 0 byte order) */
};


#define TPKT_VRSN 3

struct tpkt_head {
    unsigned char vrsn;             /* contains TPKT_VRSN */
    unsigned char reserved;
    unsigned char packet_length[2]; /* size incl header, big-endian (?) */
};


/* scan buffer for bit 7 */
static void scanbit8(inet_descriptor* desc, char* buf, int len)
{
    int c;

    if (!desc->bit8f || desc->bit8) return;
    c = 0;
    while(len--) c |= *buf++;
    desc->bit8 = ((c & 0x80) != 0);
}

/* 
** active=TRUE:
**  (NOTE! distribution MUST use active=TRUE, deliver=PORT)
**       deliver=PORT  {S, {data, [H1,..Hsz | Data]}}
**       deliver=TERM  {tcp, S, [H1..Hsz | Data]}
**
** active=FALSE:
**       {async, S, Ref, {ok,[H1,...Hsz | Data]}}
*/
static int tcp_reply_data(tcp_descriptor* desc, char* buf, int len)
{
    int code;

    /* adjust according to packet type */
    switch(desc->inet.htype) {
    case TCP_PB_1:  buf += 1; len -= 1; break;
    case TCP_PB_2:  buf += 2; len -= 2; break;
    case TCP_PB_4:  buf += 4; len -= 4; break;
    case TCP_PB_FCGI:
	len -= ((struct fcgi_head*)buf)->paddingLength;
	break;
    }

    scanbit8(INETP(desc), buf, len);

    if (desc->inet.deliver == INET_DELIVER_PORT)
        code = inet_port_data(INETP(desc), buf, len);
#ifdef USE_HTTP
    else if ((desc->inet.htype == TCP_PB_HTTP) ||
	     (desc->inet.htype == TCP_PB_HTTPH)) {
        if ((code = http_message(desc, buf, len)) < 0)
	    http_error_message(desc, buf, len);
	code = 0;
    }
#endif    
    else if (desc->inet.active == INET_PASSIVE)
        return inet_async_data(INETP(desc), buf, len);
    else
        code = tcp_message(INETP(desc), buf, len);

    if (code < 0)
	return code;
    if (desc->inet.active == INET_ONCE)
	desc->inet.active = INET_PASSIVE;
    return code;
}

static int
tcp_reply_binary_data(tcp_descriptor* desc, ErlDrvBinary* bin, int offs, int len)
{
    int code;

    /* adjust according to packet type */
    switch(desc->inet.htype) {
    case TCP_PB_1:  offs += 1; len -= 1; break;
    case TCP_PB_2:  offs += 2; len -= 2; break;
    case TCP_PB_4:  offs += 4; len -= 4; break;
    case TCP_PB_FCGI:
	len -= ((struct fcgi_head*)(bin->orig_bytes+offs))->paddingLength;
	break;
    }

    scanbit8(INETP(desc), bin->orig_bytes+offs, len);

    if (desc->inet.deliver == INET_DELIVER_PORT)
        code = inet_port_binary_data(INETP(desc), bin, offs, len);
#ifdef USE_HTTP
    else if ((desc->inet.htype == TCP_PB_HTTP) ||
	     (desc->inet.htype == TCP_PB_HTTPH)) {
        if ((code = http_message(desc, bin->orig_bytes+offs, len)) < 0)
	    http_error_message(desc, bin->orig_bytes+offs, len);
	code = 0;
    }
#endif
    else if (desc->inet.active == INET_PASSIVE)
	return inet_async_binary_data(INETP(desc), 0, bin, offs, len, NULL);
    else
	code = tcp_binary_message(INETP(desc), bin, offs, len);
    if (code < 0)
	return code;
    if (desc->inet.active == INET_ONCE)
	desc->inet.active = INET_PASSIVE;
    return code;
}


static int
packet_reply_binary_data(inet_descriptor* desc, unsigned  int hsz,
			 ErlDrvBinary   * bin,  int offs, int len,
			 void * extra)
{
    int code;

    scanbit8(desc, bin->orig_bytes+offs, len);

    if (desc->active == INET_PASSIVE)
	/* "inet" is actually for both UDP and SCTP, as well as TCP! */
	return inet_async_binary_data(desc, hsz, bin, offs, len, extra);
    else
    {	/* INET_ACTIVE or INET_ONCE: */
	if (desc->deliver == INET_DELIVER_PORT)
	    code = inet_port_binary_data(desc, bin, offs, len);
	else
	    code = packet_binary_message(desc, bin, offs, len, extra);
	if (code < 0)
	    return code;
	if (desc->active == INET_ONCE)
	    desc->active = INET_PASSIVE;
	return code;
    }
}

/* ----------------------------------------------------------------------------

   INET

---------------------------------------------------------------------------- */

static int
sock_init(void) /* May be called multiple times. */
{
#ifdef __WIN32__
    WORD wVersionRequested;
    WSADATA wsaData;
    static int res = -1; /* res < 0 == initialization never attempted */

    if (res >= 0)
	return res;

    wVersionRequested = MAKEWORD(2,0);
    if (WSAStartup(wVersionRequested, &wsaData) != 0)
	goto error;

    if ((LOBYTE(wsaData.wVersion) != 2) || (HIBYTE(wsaData.wVersion) != 0))
	goto error;

    find_dynamic_functions();

    return res = 1;

 error:

    WSACleanup();
    return res = 0;
#else
    return 1;
#endif
}

static int inet_init()
{
    if (!sock_init())
	goto error;

    buffer_stack_pos = 0;

    erts_smp_spinlock_init(&inet_buffer_stack_lock, "inet_buffer_stack_lock");

    ASSERT(sizeof(struct in_addr) == 4);
#   if defined(HAVE_IN6) && defined(AF_INET6)
    ASSERT(sizeof(struct in6_addr) == 16);
#   endif

#ifdef DEBUG
    tot_buf_allocated = 0;
    max_buf_allocated = 0;
    tot_buf_stacked = 0;
#endif
    INIT_ATOM(ok);
    INIT_ATOM(tcp);
    INIT_ATOM(udp);
    INIT_ATOM(error);
    INIT_ATOM(inet_async);
    INIT_ATOM(inet_reply);
    INIT_ATOM(timeout);
    INIT_ATOM(closed);
    INIT_ATOM(tcp_closed);
    INIT_ATOM(tcp_error);
    INIT_ATOM(udp_error);
    INIT_ATOM(empty_out_q);
#ifdef HAVE_SCTP
    /* Check the size of SCTP AssocID -- currently both this driver and the
       Erlang part require 32 bit: */
    ASSERT(sizeof(sctp_assoc_t)==ASSOC_ID_LEN);
    
    INIT_ATOM(sctp);
    INIT_ATOM(sctp_error);
    INIT_ATOM(true);
    INIT_ATOM(false);
    INIT_ATOM(buffer);
    INIT_ATOM(mode);
    INIT_ATOM(list);
    INIT_ATOM(binary);
    INIT_ATOM(active);
    INIT_ATOM(once);
    INIT_ATOM(buffer);
    INIT_ATOM(linger);
    INIT_ATOM(recbuf);
    INIT_ATOM(sndbuf);
    INIT_ATOM(reuseaddr);
    INIT_ATOM(dontroute);
    INIT_ATOM(priority);
    INIT_ATOM(tos);
    
    /* Option names */
    INIT_ATOM(sctp_rtoinfo);
    INIT_ATOM(sctp_associnfo);
    INIT_ATOM(sctp_initmsg);
    INIT_ATOM(sctp_autoclose);
    INIT_ATOM(sctp_nodelay);
    INIT_ATOM(sctp_disable_fragments);
    INIT_ATOM(sctp_i_want_mapped_v4_addr);
    INIT_ATOM(sctp_maxseg);
    INIT_ATOM(sctp_set_peer_primary_addr);
    INIT_ATOM(sctp_primary_addr);
    INIT_ATOM(sctp_adaption_layer);
    INIT_ATOM(sctp_peer_addr_params);
    INIT_ATOM(sctp_default_send_param);
    INIT_ATOM(sctp_events);
    INIT_ATOM(sctp_delayed_ack_time);
    INIT_ATOM(sctp_status);
    INIT_ATOM(sctp_get_peer_addr_info);
    
    /* Record names */
    INIT_ATOM(sctp_sndrcvinfo);
    INIT_ATOM(sctp_assoc_change);
    INIT_ATOM(sctp_paddr_change);
    INIT_ATOM(sctp_remote_error);
    INIT_ATOM(sctp_send_failed);
    INIT_ATOM(sctp_shutdown_event);
    INIT_ATOM(sctp_adaption_event);
    INIT_ATOM(sctp_pdapi_event);
    INIT_ATOM(sctp_assocparams);
    INIT_ATOM(sctp_prim);
    INIT_ATOM(sctp_setpeerprim);
    INIT_ATOM(sctp_setadaption);
    INIT_ATOM(sctp_paddrparams);
    INIT_ATOM(sctp_event_subscribe);
    INIT_ATOM(sctp_assoc_value);
    INIT_ATOM(sctp_paddrinfo);
    
    /* For #sctp_sndrcvinfo{}: */
    INIT_ATOM(unordered);
    INIT_ATOM(addr_over);
    INIT_ATOM(abort);
    INIT_ATOM(eof);
    
    /* For #sctp_assoc_change{}: */
    INIT_ATOM(comm_up);
    INIT_ATOM(comm_lost);
    INIT_ATOM(restart);
    INIT_ATOM(shutdown_comp);
    INIT_ATOM(cant_assoc);
    
    /* For #sctp_paddr_change{}: */
    INIT_ATOM(addr_available);
    INIT_ATOM(addr_unreachable); 
    INIT_ATOM(addr_removed);
    INIT_ATOM(addr_added);
    INIT_ATOM(addr_made_prim);
    
    INIT_ATOM(short_recv);
    INIT_ATOM(wrong_anc_data);
    
    /* For #sctp_pdap_event{}: */
    INIT_ATOM(partial_delivery_aborted);
    
    /* For #sctp_paddrparams{}: */
    INIT_ATOM(hb_enable);
    INIT_ATOM(hb_disable);
    INIT_ATOM(hb_demand);
    INIT_ATOM(pmtud_enable);
    INIT_ATOM(pmtud_disable);
    INIT_ATOM(sackdelay_enable);
    INIT_ATOM(sackdelay_disable);
    
    /* For #sctp_paddrinfo{}: */
    INIT_ATOM(active);
    INIT_ATOM(inactive);
    
    /* For #sctp_status{}: */
    INIT_ATOM(empty);
    INIT_ATOM(closed);
    INIT_ATOM(cookie_wait);
    INIT_ATOM(cookie_echoed);
    INIT_ATOM(established);
    INIT_ATOM(shutdown_pending);
    INIT_ATOM(shutdown_sent);
    INIT_ATOM(shutdown_received);
    INIT_ATOM(shutdown_ack_sent);
    /* Not yet implemented in the Linux kernel:
    ** INIT_ATOM(bound);
    ** INIT_ATOM(listen);
    */
#endif
    
    /* add TCP, UDP and SCTP drivers */
#ifdef _OSE_
    add_ose_tcp_drv_entry(&tcp_inet_driver_entry);
    add_ose_udp_drv_entry(&udp_inet_driver_entry);
#else
    add_driver_entry(&tcp_inet_driver_entry);
    add_driver_entry(&udp_inet_driver_entry);
#  ifdef HAVE_SCTP
    add_driver_entry(&sctp_inet_driver_entry);
#  endif
#endif /* _OSE_ */
    /* remove the dummy inet driver */
    remove_driver_entry(&inet_driver_entry);
#ifdef USE_HTTP
    http_init();
#endif
    return 0;

 error:
    remove_driver_entry(&inet_driver_entry);
    return -1;
}


/*
** Set a inaddr structure:
**  src = [P1,P0,X1,X2,.....]
**  dst points to a structure large enugh to keep any kind
**  of inaddr.
** *len is set to length of src on call
** and is set to actual length of dst on return
** return NULL on error and ptr after port address on success
*/
static char* inet_set_address(int family, inet_address* dst, char* src, int* len)
{
    short port;

    if ((family == AF_INET) && (*len >= 2+4)) {
	sys_memzero((char*)dst, sizeof(struct sockaddr_in));
	port = get_int16(src);
	dst->sai.sin_family = family;
	dst->sai.sin_port   = sock_htons(port);
	sys_memcpy(&dst->sai.sin_addr, src+2, 4);
	*len = sizeof(struct sockaddr_in);
	return src + 2+4;
    }
#if defined(HAVE_IN6) && defined(AF_INET6)
    else if ((family == AF_INET6) && (*len >= 2+16)) {
	sys_memzero((char*)dst, sizeof(struct sockaddr_in6));
	port = get_int16(src);
	dst->sai6.sin6_family = family;
	dst->sai6.sin6_port   = sock_htons(port);
	dst->sai6.sin6_flowinfo = 0;   /* XXX this may be set as well ?? */
	sys_memcpy(&dst->sai6.sin6_addr, src+2, 16);
	*len = sizeof(struct sockaddr_in6); 
	return src + 2+16;
    }
#endif
    return NULL;
}
#ifdef HAVE_SCTP
/*
** Set an inaddr structure, address family comes from source data,
** or from argument if source data specifies constant address.
** 
** src = [TAG,P1,P0]           when TAG = INET_AF_ANY  | INET_AF_LOOPBACK
** src = [TAG,P1,P0,X1,X2,...] when TAG = INET_AF_INET | INET_AF_INET6
*/
static char *inet_set_faddress(int family, inet_address* dst,
			       char *src, int* len) {
    int tag;
    
    if (*len < 1) return NULL;
    (*len) --;
    tag = *(src ++);
    switch (tag) {
    case INET_AF_INET:
	family = AF_INET;
	break;
#   if defined(HAVE_IN6) && defined(AF_INET6)
    case INET_AF_INET6:
	family = AF_INET6;
	break;
#   endif
    case INET_AF_ANY:
    case INET_AF_LOOPBACK: {
	int port;
	
	if (*len < 2) return NULL;
	port = get_int16(src);
	switch (family) {
	case AF_INET: {
	    struct in_addr addr;
	    switch (tag) {
	    case INET_AF_ANY: 
		addr.s_addr = sock_htonl(INADDR_ANY);
		break;
	    case INET_AF_LOOPBACK:
		addr.s_addr = sock_htonl(INADDR_LOOPBACK);
		break;
	    default:
		return NULL;
	    }
	    sys_memzero((char*)dst, sizeof(struct sockaddr_in));
	    dst->sai.sin_family      = family;
	    dst->sai.sin_port        = sock_htons(port);
	    dst->sai.sin_addr.s_addr = addr.s_addr;
	    *len = sizeof(struct sockaddr_in);
	}   break;
#       if defined(HAVE_IN6) && defined(AF_INET6)
	case AF_INET6: {
	    const struct in6_addr* paddr;
	    switch (tag) {
	    case INET_AF_ANY: 
		paddr = &in6addr_any;
		break;
	    case INET_AF_LOOPBACK:
		paddr = &in6addr_loopback;
		break;
	    default:
		return NULL;
	    }
	    sys_memzero((char*)dst, sizeof(struct sockaddr_in6));
	    dst->sai6.sin6_family = family;
	    dst->sai6.sin6_port   = sock_htons(port);
	    dst->sai6.sin6_flowinfo = 0;   /* XXX this may be set as well ?? */
	    dst->sai6.sin6_addr = *paddr;
	    *len = sizeof(struct sockaddr_in6);
	}   break;
#       endif
	default:
	    return NULL;
	}
	return src + 2;
    }   break;
    default:
	return NULL;
    }
    return inet_set_address(family, dst, src, len);
}
#endif /* HAVE_SCTP */

/* Get a inaddr structure
** src = inaddr structure
** *len is the lenght of structure
** dst is filled with [F,P1,P0,X1,....] 
** where F is the family code (coded)
** and *len is the length of dst on return 
** (suitable to deliver to erlang)
*/
static int inet_get_address(int family, char* dst, inet_address* src, unsigned int* len)
{
    short port;

    if ((family == AF_INET) && (*len >= sizeof(struct sockaddr_in))) {
	dst[0] = INET_AF_INET;
	port = sock_ntohs(src->sai.sin_port);
	put_int16(port, dst+1);
	sys_memcpy(dst+3, (char*)&src->sai.sin_addr, sizeof(struct in_addr));
	*len = 3 + sizeof(struct in_addr);
	return 0;
    }
#if defined(HAVE_IN6) && defined(AF_INET6)
    else if ((family == AF_INET6) && (*len >= sizeof(struct sockaddr_in6))) {
	dst[0] = INET_AF_INET6;
	port = sock_ntohs(src->sai6.sin6_port);
	put_int16(port, dst+1);
	sys_memcpy(dst+3, (char*)&src->sai6.sin6_addr,sizeof(struct in6_addr));
	*len = 3 + sizeof(struct in6_addr);
	return 0;
    }
#endif
    return -1;
}

static void desc_close(inet_descriptor* desc)
{
    if (desc->s != INVALID_SOCKET) {
#ifdef __WIN32__
	driver_select(desc->port, desc->event, DO_READ, 0);
#endif
	sock_select(desc, FD_READ | FD_WRITE | FD_CLOSE, 0);
	sock_close(desc->s);
	desc->s = INVALID_SOCKET;
	sock_close_event(desc->event);
	desc->event = INVALID_EVENT;
	desc->event_mask = 0;
#ifdef __WIN32__
	desc->forced_events = 0;
#endif
    }
}

static void desc_close_read(inet_descriptor* desc)
{
    if (desc->s != INVALID_SOCKET) {
#ifdef __WIN32__
	driver_select(desc->port, desc->event, DO_READ, 0);
#endif
	sock_select(desc, FD_READ | FD_CLOSE, 0);
    }
}


static int erl_inet_close(inet_descriptor* desc)
{
    free_subscribers(&desc->empty_out_q_subs);
    if ((desc->prebound == 0) && (desc->state & INET_F_OPEN)) {
	desc_close(desc);
	desc->state = INET_STATE_CLOSED;
    } else if (desc->prebound && (desc->s != INVALID_SOCKET)) {
	sock_select(desc, FD_READ | FD_WRITE | FD_CLOSE, 0);
	desc->event_mask = 0;
#ifdef __WIN32__
	desc->forced_events = 0;
#endif
    }
    return 0;
}


static int inet_ctl_open(inet_descriptor* desc, int domain, int type, 
			 char** rbuf, int rsize)
{
    if (desc->state != INET_STATE_CLOSED)
	return ctl_xerror(EXBADSEQ, rbuf, rsize);
    if ((desc->s = sock_open(domain, type, desc->sprotocol)) == INVALID_SOCKET)
	return ctl_error(sock_errno(), rbuf, rsize);
    if ((desc->event = sock_create_event(desc)) == INVALID_EVENT)
	return ctl_error(sock_errno(), rbuf, rsize);
    SET_NONBLOCKING(desc->s);
#ifdef __WIN32__
	driver_select(desc->port, desc->event, DO_READ, 1);
#endif
    desc->state = INET_STATE_OPEN;
    desc->stype = type;
    desc->sfamily = domain;
    return ctl_reply(INET_REP_OK, NULL, 0, rbuf, rsize);
}


/* as inet_open but pass in an open socket (MUST BE OF RIGHT TYPE) */
static int inet_ctl_fdopen(inet_descriptor* desc, int domain, int type,
			   SOCKET s, char** rbuf, int rsize)
{
    inet_address name;
    unsigned int sz = sizeof(name);

    /* check that it is a socket and that the socket is bound */
    if (sock_name(s, (struct sockaddr*) &name, &sz) == SOCKET_ERROR)
	return ctl_error(sock_errno(), rbuf, rsize);
    desc->s = s;
    if ((desc->event = sock_create_event(desc)) == INVALID_EVENT)
	return ctl_error(sock_errno(), rbuf, rsize);
    SET_NONBLOCKING(desc->s);
#ifdef __WIN32__
	driver_select(desc->port, desc->event, DO_READ, 1);
#endif
    desc->state = INET_STATE_BOUND; /* assume bound */
    if (type == SOCK_STREAM) { /* check if connected */
	sz = sizeof(name);
	if (sock_peer(s, (struct sockaddr*) &name, &sz) != SOCKET_ERROR)
	    desc->state = INET_STATE_CONNECTED;
    }

    desc->prebound = 1; /* used to prevent a real close since
			 * the fd probably comes from an 
			 * external wrapper program, so it is
			 * not certain that we can open it again */
    desc->stype = type;
    desc->sfamily = domain;
    return ctl_reply(INET_REP_OK, NULL, 0, rbuf, rsize);
}

/*
**  store interface info as: (bytes)
**  [Len] Name(Len) Flags(1) addr(4) baddr(4) mask(4) bw(4)
*/
struct addr_if {
    char name[INET_IFNAMSIZ];
    long           flags;        /* coded flags */
    struct in_addr addr;         /* interface address */
    struct in_addr baddr;        /* broadcast address */
    struct in_addr mask;         /* netmask */
};


#ifndef SIOCGIFNETMASK
static struct in_addr net_mask(in)
struct in_addr in;
{
    register u_long i = sock_ntohl(in.s_addr);

    if (IN_CLASSA(i))
	in.s_addr = sock_htonl(IN_CLASSA_NET);
    else if (IN_CLASSB(i))
	in.s_addr = sock_htonl(IN_CLASSB_NET);
    else
	in.s_addr = sock_htonl(IN_CLASSC_NET);
    return in;
}
#endif

#if defined(__WIN32__) && defined(SIO_GET_INTERFACE_LIST)

/* format address in dot notation */
static char* fmt_addr(unsigned long x, char* ptr)
{
    int i;
    for (i = 0; i < 4; i++) {
	int nb[3];
	int y = (x >> 24) & 0xff;
	x <<= 8;
	nb[0] = y % 10; y /= 10;
	nb[1] = y % 10; y /= 10;
	nb[2] = y % 10; y /= 10;
	switch((nb[2] ? 3 : (nb[1] ? 2 : 1))) {
	case 3:  *ptr++ = nb[2] + '0';
	case 2:  *ptr++ = nb[1] + '0';
	case 1:  *ptr++ = nb[0] + '0';
	}
	*ptr++ = '.';
    }
    *(ptr-1) = '\0';
    return ptr;
}

static int parse_addr(char* ptr, int n, long* x)
{
    long addr = 0;
    int  dots = 0;
    int  digs = 0;
    int  v  = 0;

    while(n--) {
	switch(*ptr) {
	case '0': case '1': case '2':case '3':case '4':case '5':
	case '6': case '7': case '8':case '9':
	    v = v*10 + *ptr - '0';
	    if (++digs > 3) return -1;
	    break;
	case '.':
	    if ((dots>2) || (digs==0) || (digs > 3) || (v > 0xff)) return -1;
	    dots++;
	    digs = 0;
	    addr = (addr << 8) | v;
	    v = 0;
	    break;
	default:
	    return -1;
	}
	ptr++;
    }
    if ((dots!=3) || (digs==0) || (digs > 3) || (v > 0xff)) return -1;
    addr = (addr << 8) | v;
    *x = addr;
    return 0;
}

#endif

#define buf_check(ptr, end, n) \
do { if ((end)-(ptr) < (n)) goto error; } while(0)

static char* sockaddr_to_buf(struct sockaddr* addr, char* ptr, char* end)
{
    if (addr->sa_family == AF_INET || addr->sa_family == 0) {
	struct in_addr a;
	buf_check(ptr,end,sizeof(struct in_addr));
	a = ((struct sockaddr_in*) addr)->sin_addr;
	sys_memcpy(ptr, (char*)&a, sizeof(struct in_addr));
	return ptr + sizeof(struct in_addr);
    }
#if defined(HAVE_IN6) && defined(AF_INET6)
    else if (addr->sa_family == AF_INET6) {
	struct in6_addr a;
	buf_check(ptr,end,sizeof(struct in6_addr));
	a = ((struct sockaddr_in6*) addr)->sin6_addr;
	sys_memcpy(ptr, (char*)&a, sizeof(struct in6_addr));
	return ptr + sizeof(struct in6_addr);
    }
#endif
 error:
    return NULL;

}

static char* buf_to_sockaddr(char* ptr, char* end, struct sockaddr* addr)
{
    buf_check(ptr,end,sizeof(struct in_addr));
    sys_memcpy((char*) &((struct sockaddr_in*)addr)->sin_addr, ptr,
	       sizeof(struct in_addr));
    addr->sa_family = AF_INET;
    return ptr +  sizeof(struct in_addr);

 error:
    return NULL;
}



#if defined(__WIN32__) && defined(SIO_GET_INTERFACE_LIST)

static int inet_ctl_getiflist(inet_descriptor* desc, char** rbuf, int rsize)
{
    char ifbuf[BUFSIZ];
    char sbuf[BUFSIZ];
    char* sptr;
    INTERFACE_INFO* ifp;
    DWORD len;
    int n;
    int err;

    ifp = (INTERFACE_INFO*) ifbuf;
    len = 0;
    err = WSAIoctl(desc->s, SIO_GET_INTERFACE_LIST, NULL, 0,
		   (LPVOID) ifp, BUFSIZ, (LPDWORD) &len,
		   NULL, NULL);

    if (err == SOCKET_ERROR)
	return ctl_error(sock_errno(), rbuf, rsize);

    n = (len + sizeof(INTERFACE_INFO) - 1) / sizeof(INTERFACE_INFO);
    sptr = sbuf;

    while(n--) {
	if (((struct sockaddr*)&ifp->iiAddress)->sa_family == desc->sfamily) {
	    struct in_addr sina = ((struct sockaddr_in*)&ifp->iiAddress)->sin_addr;
	    /* discard INADDR_ANY interface address */
	    if (sina.s_addr != INADDR_ANY)
		sptr = fmt_addr(sock_ntohl(sina.s_addr), sptr);
	}
	ifp++;
    }
    return ctl_reply(INET_REP_OK, sbuf, sptr - sbuf, rbuf, rsize);
}


/* input is an ip-address in string format i.e A.B.C.D 
** scan the INTERFACE_LIST to get the options 
*/
static int inet_ctl_ifget(inet_descriptor* desc, char* buf, int len,
			  char** rbuf, int rsize)
{
    char ifbuf[BUFSIZ];
    int  n;
    char sbuf[BUFSIZ];
    char* sptr;
    char* s_end = sbuf + BUFSIZ;
    int namlen;
    int   err;
    INTERFACE_INFO* ifp;
    long namaddr;

    if ((len == 0) || ((namlen = buf[0]) > len))
	goto error;
    if (parse_addr(buf+1, namlen, &namaddr) < 0)
	goto error;
    namaddr = sock_ntohl(namaddr);
    buf += (namlen+1);
    len -= (namlen+1);

    ifp = (INTERFACE_INFO*) ifbuf;
    err = WSAIoctl(desc->s, SIO_GET_INTERFACE_LIST, NULL, 0,
			      (LPVOID) ifp, BUFSIZ, (LPDWORD) &n, 
			      NULL, NULL);
    if (err == SOCKET_ERROR) {
	return ctl_error(sock_errno(), rbuf, rsize);
    }

    n = (n + sizeof(INTERFACE_INFO) - 1) / sizeof(INTERFACE_INFO);

    /* find interface */
    while(n) {
	if (((struct sockaddr_in*)&ifp->iiAddress)->sin_addr.s_addr == namaddr)
	    break;
	ifp++;
	n--;
    }
    if (n == 0)
	goto error;

    sptr = sbuf;

    while (len--) {
	switch(*buf++) {
	case INET_IFOPT_ADDR:
	    buf_check(sptr, s_end, 1);
	    *sptr++ = INET_IFOPT_ADDR;
	    if ((sptr = sockaddr_to_buf((struct sockaddr *)&ifp->iiAddress,
					sptr, s_end)) == NULL)
		goto error;
	    break;

	case INET_IFOPT_HWADDR:
	    break;

	case INET_IFOPT_BROADADDR:
#ifdef SIOCGIFBRDADDR
	    buf_check(sptr, s_end, 1);
	    *sptr++ = INET_IFOPT_BROADADDR;
	    if ((sptr=sockaddr_to_buf((struct sockaddr *)
				      &ifp->iiBroadcastAddress,sptr,s_end))
		== NULL)
		goto error;
#endif
	    break;
	    
	case INET_IFOPT_DSTADDR:
	    break;

	case INET_IFOPT_NETMASK:
	    buf_check(sptr, s_end, 1);
	    *sptr++ = INET_IFOPT_NETMASK;
	    if ((sptr = sockaddr_to_buf((struct sockaddr *)
					&ifp->iiNetmask,sptr,s_end)) == NULL)
		goto error;
	    break;

	case INET_IFOPT_MTU:
	    break;

	case INET_IFOPT_FLAGS: {
	    long eflags = 0;
	    int flags = ifp->iiFlags;
	    /* just enumerate the interfaces (no names) */

	    /* translate flags */
	    if (flags & IFF_UP)
		eflags |= INET_IFF_UP;
	    if (flags & IFF_BROADCAST)
		eflags |= INET_IFF_BROADCAST;
	    if (flags & IFF_LOOPBACK)
		eflags |= INET_IFF_LOOPBACK;
	    if (flags & IFF_POINTTOPOINT)
		eflags |= INET_IFF_POINTTOPOINT;
	    if (flags & IFF_UP) /* emulate runnign ? */
		eflags |= INET_IFF_RUNNING;
	    if (flags & IFF_MULTICAST)
		eflags |= INET_IFF_MULTICAST;

	    buf_check(sptr, s_end, 5);
	    *sptr++ = INET_IFOPT_FLAGS;
	    put_int32(eflags, sptr);
	    sptr += 4;
	    break;
	}
	default:
	    goto error;
	}
    }
    return ctl_reply(INET_REP_OK, sbuf, sptr - sbuf, rbuf, rsize);

 error:
    return ctl_error(EINVAL, rbuf, rsize);
}

/* not supported */
static int inet_ctl_ifset(inet_descriptor* desc, char* buf, int len,
			  char** rbuf, int rsize)
{
    return ctl_reply(INET_REP_OK, NULL, 0, rbuf, rsize);
}


#elif defined(SIOCGIFCONF) && defined(SIOCSIFFLAGS)
/* cygwin has SIOCGIFCONF but not SIOCSIFFLAGS (Nov 2002) */

#define VOIDP(x) ((void*)(x))
#if defined(AF_LINK) && !defined(NO_SA_LEN)
#define SIZEA(p) (((p).sa_len > sizeof(p)) ? (p).sa_len : sizeof(p))
#else
#define SIZEA(p) (sizeof (p))
#endif


static int inet_ctl_getiflist(inet_descriptor* desc, char** rbuf, int rsize)
{
    struct ifconf ifc;
    struct ifreq *ifr;
    char *buf;
    int buflen, ifc_len, i;
    char *sbuf, *sp;
    
    /* Courtesy of Per Bergqvist and W. Richard Stevens */
    
    ifc_len = 0;
    buflen = 100 * sizeof(struct ifreq);
    buf = ALLOC(buflen);

    for (;;) {
	ifc.ifc_len = buflen;
	ifc.ifc_buf = buf;
	if (ioctl(desc->s, SIOCGIFCONF, (char *)&ifc) < 0) {
	    int res = sock_errno();
	    if (res != EINVAL || ifc_len) {
		FREE(buf);
		return ctl_error(res, rbuf, rsize);
	    }
	} else {
	    if (ifc.ifc_len == ifc_len) break; /* buf large enough */
	    ifc_len = ifc.ifc_len;
	}
	buflen += 10 * sizeof(struct ifreq);
	buf = (char *)REALLOC(buf, buflen);
    }
    
    sp = sbuf = ALLOC(ifc_len+1);
    *sp++ = INET_REP_OK;
    i = 0;
    for (;;) {
	int n;
	
	ifr = (struct ifreq *) VOIDP(buf + i);
	n = sizeof(ifr->ifr_name) + SIZEA(ifr->ifr_addr);
	if (n < sizeof(*ifr)) n = sizeof(*ifr);
	if (i+n > ifc_len) break;
	i += n;
	
	switch (ifr->ifr_addr.sa_family) {
#if defined(HAVE_IN6) && defined(AF_INET6)
	case AF_INET6:
#endif
	case AF_INET:
	    ASSERT(sp+IFNAMSIZ+1 < sbuf+buflen+1)
	    strncpy(sp, ifr->ifr_name, IFNAMSIZ);
	    sp[IFNAMSIZ] = '\0';
	    sp += strlen(sp), ++sp;
	}
	
	if (i >= ifc_len) break;
    }
    FREE(buf);
    *rbuf = sbuf;
    return sp - sbuf;
}



static int inet_ctl_ifget(inet_descriptor* desc, char* buf, int len,
			  char** rbuf, int rsize)
{
    char sbuf[BUFSIZ];
    char* sptr;
    char* s_end = sbuf + BUFSIZ;
    struct ifreq ifreq;
    int namlen;

    if ((len == 0) || ((namlen = buf[0]) > len))
	goto error;
    sys_memset(ifreq.ifr_name, '\0', IFNAMSIZ);
    sys_memcpy(ifreq.ifr_name, buf+1, 
	       (namlen > IFNAMSIZ) ? IFNAMSIZ : namlen);
    buf += (namlen+1);
    len -= (namlen+1);
    sptr = sbuf;

    while (len--) {
	switch(*buf++) {
	case INET_IFOPT_ADDR:
	    if (ioctl(desc->s, SIOCGIFADDR, (char *)&ifreq) < 0)
		break;
	    buf_check(sptr, s_end, 1);
	    *sptr++ = INET_IFOPT_ADDR;
	    if ((sptr = sockaddr_to_buf(&ifreq.ifr_addr, sptr, s_end)) == NULL)
		goto error;
	    break;

	case INET_IFOPT_HWADDR: {
#ifdef SIOCGIFHWADDR
	    if (ioctl(desc->s, SIOCGIFHWADDR, (char *)&ifreq) < 0)
		break;
	    buf_check(sptr, s_end, 1+IFHWADDRLEN);
	    *sptr++ = INET_IFOPT_HWADDR;
	    /* raw memcpy (fix include autoconf later) */
	    sys_memcpy(sptr, (char*)(&ifreq.ifr_hwaddr.sa_data), IFHWADDRLEN);
	    sptr += IFHWADDRLEN;
#endif
	    break;
	}


	case INET_IFOPT_BROADADDR:
#ifdef SIOCGIFBRDADDR
	    if (ioctl(desc->s, SIOCGIFBRDADDR, (char *)&ifreq) < 0)
		break;
	    buf_check(sptr, s_end, 1);
	    *sptr++ = INET_IFOPT_BROADADDR;
	    if ((sptr=sockaddr_to_buf(&ifreq.ifr_broadaddr,sptr,s_end)) == NULL)
		goto error;
#endif
	    break;
	    
	case INET_IFOPT_DSTADDR:
#ifdef SIOCGIFDSTADDR	    
	    if (ioctl(desc->s, SIOCGIFDSTADDR, (char *)&ifreq) < 0)
		break;
	    buf_check(sptr, s_end, 1);
	    *sptr++ = INET_IFOPT_DSTADDR;
	    if ((sptr = sockaddr_to_buf(&ifreq.ifr_dstaddr,sptr,s_end)) == NULL)
		goto error;
#endif
	    break;

	case INET_IFOPT_NETMASK:
#if defined(SIOCGIFNETMASK)
	    if (ioctl(desc->s, SIOCGIFNETMASK, (char *)&ifreq) < 0)
		break;
	    buf_check(sptr, s_end, 1);
	    *sptr++ = INET_IFOPT_NETMASK;
#if defined(ifr_netmask)
	    sptr = sockaddr_to_buf(&ifreq.ifr_netmask,sptr,s_end);
#else
	    /* SIOCGNETMASK exist but not macro ??? */
	    sptr = sockaddr_to_buf(&ifreq.ifr_addr,sptr,s_end);
#endif
	    if (sptr == NULL)
		goto error;
#else
	    if (ioctl(desc->s, SIOCGIFADDR, (char *)&ifreq) < 0)
		break;
	    else {
		struct sockadd_in* ap;
		/* emulate netmask,
		 * (wasted stuff since noone uses classes)
		 */
		buf_check(sptr, s_end, 1);
		*sptr++ = INET_IFOPT_NETMASK;
		ap = (struct sockaddr_in*) VOIDP(&ifreq.ifr_addr);
		ap->sin_addr = net_mask(ap->sin_addr);
		if ((sptr = sockaddr_to_buf(&ifreq.ifr_addr,sptr,s_end)) == NULL)
		    goto error;
	    }
#endif
	    break;

	case INET_IFOPT_MTU: {
#if defined(SIOCGIFMTU) && defined(ifr_mtu)
	    int n;

	    if (ioctl(desc->s, SIOCGIFMTU, (char *)&ifreq) < 0)
		break;
	    buf_check(sptr, s_end, 5);
	    *sptr++ = INET_IFOPT_MTU;
	    n = ifreq.ifr_mtu;
	    put_int32(n, sptr);
	    sptr += 4;
#endif
	    break;
	}

	case INET_IFOPT_FLAGS: {
	    int flags;
	    int eflags = 0;

	    if (ioctl(desc->s, SIOCGIFFLAGS, (char*)&ifreq) < 0)
		flags = 0;
	    else
		flags = ifreq.ifr_flags;
	    /* translate flags */
	    if (flags & IFF_UP)
		eflags |= INET_IFF_UP;
	    if (flags & IFF_BROADCAST)
		eflags |= INET_IFF_BROADCAST;
	    if (flags & IFF_LOOPBACK)
		eflags |= INET_IFF_LOOPBACK;	
	    if (flags & IFF_POINTOPOINT)
		eflags |= INET_IFF_POINTTOPOINT;
	    if (flags & IFF_RUNNING)
		eflags |= INET_IFF_RUNNING;
	    if (flags & IFF_MULTICAST)
		eflags |= INET_IFF_MULTICAST;

	    buf_check(sptr, s_end, 5);
	    *sptr++ = INET_IFOPT_FLAGS;
	    put_int32(eflags, sptr);
	    sptr += 4;
	    break;
	}
	default:
	    goto error;
	}
    }
    return ctl_reply(INET_REP_OK, sbuf, sptr - sbuf, rbuf, rsize);

 error:
    return ctl_error(EINVAL, rbuf, rsize);
}

/* FIXME: temporary hack */
#ifndef IFHWADDRLEN
#define IFHWADDRLEN 6
#endif

static int inet_ctl_ifset(inet_descriptor* desc, char* buf, int len,
			  char** rbuf, int rsize)
{
    struct ifreq ifreq;
    int namlen;
    char* b_end = buf + len;

    if ((len == 0) || ((namlen = buf[0]) > len))
	goto error;
    sys_memset(ifreq.ifr_name, '\0', IFNAMSIZ);
    sys_memcpy(ifreq.ifr_name, buf+1, 
	       (namlen > IFNAMSIZ) ? IFNAMSIZ : namlen);
    buf += (namlen+1);
    len -= (namlen+1);

    while(buf < b_end) {
	switch(*buf++) {
	case INET_IFOPT_ADDR:
	    if ((buf = buf_to_sockaddr(buf, b_end, &ifreq.ifr_addr)) == NULL)
		goto error;
	    (void) ioctl(desc->s, SIOCSIFADDR, (char*)&ifreq);
	    break;

	case INET_IFOPT_HWADDR: 
	    buf_check(buf, b_end, IFHWADDRLEN);
#ifdef SIOCSIFHWADDR
	    /* raw memcpy (fix include autoconf later) */
	    sys_memcpy((char*)(&ifreq.ifr_hwaddr.sa_data), buf, IFHWADDRLEN);

	    (void) ioctl(desc->s, SIOCSIFHWADDR, (char *)&ifreq);
#endif
	    buf += IFHWADDRLEN;
	    break;


	case INET_IFOPT_BROADADDR:
#ifdef SIOCSIFBRDADDR
	    if ((buf = buf_to_sockaddr(buf, b_end, &ifreq.ifr_broadaddr)) == NULL)
		goto error;
	    (void) ioctl(desc->s, SIOCSIFBRDADDR, (char *)&ifreq); 
#endif
	    break;

	case INET_IFOPT_DSTADDR:
#ifdef SIOCSIFDSTADDR
	    if ((buf = buf_to_sockaddr(buf, b_end, &ifreq.ifr_dstaddr)) == NULL)
		goto error;
	    (void) ioctl(desc->s, SIOCSIFDSTADDR, (char *)&ifreq);
#endif
	    break;

	case INET_IFOPT_NETMASK:
#ifdef SIOCSIFNETMASK

#if defined(ifr_netmask)
	    buf = buf_to_sockaddr(buf,b_end, &ifreq.ifr_netmask);
#else
	    buf = buf_to_sockaddr(buf,b_end, &ifreq.ifr_addr);
#endif
	    if (buf == NULL)
		goto error;
	    (void) ioctl(desc->s, SIOCSIFNETMASK, (char *)&ifreq);
#endif
	    break;

	case INET_IFOPT_MTU:
	    buf_check(buf, b_end, 4);
#if defined(SIOCSIFMTU) && defined(ifr_mtu)
	    ifreq.ifr_mtu = get_int32(buf);
	    (void) ioctl(desc->s, SIOCSIFMTU, (char *)&ifreq);
#endif
	    buf += 4;
	    break;

	case INET_IFOPT_FLAGS: {
	    int flags0;
	    int flags;
	    int eflags;

	    buf_check(buf, b_end, 4);
	    eflags = get_int32(buf);

	    /* read current flags */
	    if (ioctl(desc->s, SIOCGIFFLAGS, (char*)&ifreq) < 0)
		flags0 = flags = 0;
	    else
		flags0 = flags = ifreq.ifr_flags;

	    /* update flags */
	    if (eflags & INET_IFF_UP)            flags |= IFF_UP;
	    if (eflags & INET_IFF_DOWN)          flags &= ~IFF_UP;
	    if (eflags & INET_IFF_BROADCAST)     flags |= IFF_BROADCAST;
	    if (eflags & INET_IFF_NBROADCAST)    flags &= ~IFF_BROADCAST;
	    if (eflags & INET_IFF_POINTTOPOINT)  flags |= IFF_POINTOPOINT;
	    if (eflags & INET_IFF_NPOINTTOPOINT) flags &= ~IFF_POINTOPOINT;

	    if (flags != flags0) {
		ifreq.ifr_flags = flags;
		(void) ioctl(desc->s, SIOCSIFFLAGS, (char*)&ifreq);
	    }
	    buf += 4;
	    break;
	}

	default:
	    goto error;
	}
    }
    return ctl_reply(INET_REP_OK, NULL, 0, rbuf, rsize);

 error:
    return ctl_error(EINVAL, rbuf, rsize);
}

#else


static int inet_ctl_getiflist(inet_descriptor* desc, char** rbuf, int rsize)
{
    return ctl_reply(INET_REP_OK, NULL, 0, rbuf, rsize);
}


static int inet_ctl_ifget(inet_descriptor* desc, char* buf, int len,
			  char** rbuf, int rsize)
{
    return ctl_reply(INET_REP_OK, NULL, 0, rbuf, rsize);
}


static int inet_ctl_ifset(inet_descriptor* desc, char* buf, int len,
			  char** rbuf, int rsize)
{
    return ctl_reply(INET_REP_OK, NULL, 0, rbuf, rsize);
}

#endif

#ifdef VXWORKS
/*
** THIS is a terrible creature, a bug in the TCP part
** of the old VxWorks stack (non SENS) created a race.
** If (and only if?) a socket got closed from the other
** end and we tried a set/getsockopt on the TCP level,
** the task would generate a bus error...
*/
static STATUS wrap_sockopt(STATUS (*function)() /* Yep, no parameter
                                                   check */,
                           int s, int level, int optname,
                           char *optval, unsigned int optlen 
                           /* optlen is a pointer if function 
                              is getsockopt... */)
{
    fd_set rs;
    struct timeval timeout;
    int to_read;
    int ret;

    FD_ZERO(&rs);
    FD_SET(s,&rs);
    memset(&timeout,0,sizeof(timeout));
    if (level == IPPROTO_TCP) {
        taskLock();
        if (select(s+1,&rs,NULL,NULL,&timeout)) {
            if (ioctl(s,FIONREAD,(int)&to_read) == ERROR ||
                to_read == 0) { /* End of file, other end closed? */
                sock_errno() = EBADF;
                taskUnlock();
                return ERROR;
            }
        }
        ret = (*function)(s,level,optname,optval,optlen);
        taskUnlock();
    } else {
        ret = (*function)(s,level,optname,optval,optlen);
    }
    return ret;
}
#endif

#if  defined(IP_TOS) && defined(SOL_IP) && defined(SO_PRIORITY)
static int setopt_prio_tos_trick
	   (int fd, int proto, int type, char* arg_ptr, int arg_sz)
{
    /* The relations between SO_PRIORITY, TOS and other options
       is not what you (or at least I) would expect...:
       If TOS is set after priority, priority is zeroed.
       If any other option is set after tos, tos might be zeroed.
       Therefore, save tos and priority. If something else is set, 
       restore both after setting, if  tos is set, restore only 
       prio and if prio is set restore none... All to keep the
       user feeling socket options are independent. /PaN */
    int          tmp_ival_prio;
    int          tmp_ival_tos;
    int          res;
#ifdef HAVE_SOCKLEN_T
	    socklen_t
#else
		int
#endif
		tmp_arg_sz_prio = sizeof(tmp_ival_prio),
		tmp_arg_sz_tos  = sizeof(tmp_ival_tos);

    res = sock_getopt(fd, SOL_SOCKET, SO_PRIORITY,
		      (char *) &tmp_ival_prio, &tmp_arg_sz_prio);
    if (res == 0) {
	res = sock_getopt(fd, SOL_IP, IP_TOS, 
		      (char *) &tmp_ival_tos, &tmp_arg_sz_tos);
	if (res == 0) {
	    res = sock_setopt(fd, proto, type, arg_ptr, arg_sz);
	    if (res == 0) {
		if (type != SO_PRIORITY) {
		    if (type != IP_TOS) {
			res = sock_setopt(fd, 
					  SOL_IP, 
					  IP_TOS,
					  (char *) &tmp_ival_tos, 
					  tmp_arg_sz_tos);
		    }
		    if (res == 0) {
			res =  sock_setopt(fd, 
					   SOL_SOCKET, 
					   SO_PRIORITY,
					   (char *) &tmp_ival_prio, 
					   tmp_arg_sz_prio);
		    }
		}
	    }
	}
    }
    return (res);
}
#endif

/* set socket options:
** return -1 on error
**         0 if ok
**         1 if ok force deliver of queued data
*/
#ifdef HAVE_SCTP
static int sctp_set_opts(inet_descriptor* desc, char* ptr, int len);
#endif

static int inet_set_opts(inet_descriptor* desc, char* ptr, int len)
{
    int type;
    int proto;
    int opt;
    struct linger li_val;
#ifdef HAVE_MULTICAST_SUPPORT
    struct ip_mreq mreq_val;
#endif
    int ival;
    char* arg_ptr;
    int arg_sz;
    int old_htype = desc->htype;
    int old_active = desc->active;
    int propagate = 0; /* Set to 1 if failure to set this option
			  should be propagated to erlang (not all 
			  errors can be propagated for BC reasons) */
    int res;
#ifdef HAVE_SCTP
    /* SCTP sockets are treated completely separately: */
    if (IS_SCTP(desc))
	return sctp_set_opts(desc, ptr, len);
#endif

    while(len >= 5) {
	opt = *ptr++;
	ival = get_int32(ptr);
	ptr += 4;
	len -= 5;
	arg_ptr = (char*) &ival;
	arg_sz = sizeof(ival);
	proto = SOL_SOCKET;

	switch(opt) {
	case INET_LOPT_HEADER:
	    DEBUGF(("inet_set_opts(%ld): s=%d, HEADER=%d\r\n",
		    (long)desc->port, desc->s,ival));
	    desc->hsz = ival;
	    continue;

	case INET_LOPT_MODE:
	    /* List or Binary: */
	    DEBUGF(("inet_set_opts(%ld): s=%d, MODE=%d\r\n",
		    (long)desc->port, desc->s, ival));
	    desc->mode = ival;
	    continue;

	case INET_LOPT_DELIVER:
	    DEBUGF(("inet_set_opts(%ld): s=%d, DELIVER=%d\r\n",
		    (long)desc->port, desc->s, ival));
	    desc->deliver = ival;
	    continue;
	    
	case INET_LOPT_BUFFER:
	    DEBUGF(("inet_set_opts(%ld): s=%d, BUFFER=%d\r\n",
		    (long)desc->port, desc->s, ival));
	    if (ival > INET_MAX_BUFFER)  ival = INET_MAX_BUFFER;
	    else if (ival < INET_MIN_BUFFER) ival = INET_MIN_BUFFER;
	    desc->bufsz = ival;
	    continue;

	case INET_LOPT_ACTIVE:
	    DEBUGF(("inet_set_opts(%ld): s=%d, ACTIVE=%d\r\n",
		    (long)desc->port, desc->s,ival));
	    desc->active = ival;
	    if ((desc->stype == SOCK_STREAM) && (desc->active != INET_PASSIVE) && 
		(desc->state == INET_STATE_CLOSED)) {
		tcp_closed_message((tcp_descriptor *) desc);
		if (desc->exitf) {
		    driver_exit(desc->port, 0);
		} else {
		    desc_close_read(desc);
		}
	    }
	    continue;

	case INET_LOPT_PACKET:
	    DEBUGF(("inet_set_opts(%ld): s=%d, PACKET=%d\r\n",
		    (long)desc->port, desc->s, ival));
	    desc->htype = ival;
	    continue;

	case INET_LOPT_PACKET_SIZE:
	    DEBUGF(("inet_set_opts(%ld): s=%d, PACKET_SIZE=%d\r\n",
		    (long)desc->port, desc->s, ival));
	    desc->psize = (unsigned int)ival;
	    continue;

	case INET_LOPT_EXITONCLOSE:
	    DEBUGF(("inet_set_opts(%ld): s=%d, EXITONCLOSE=%d\r\n",
		    (long)desc->port, desc->s, ival));
	    desc->exitf = ival;
	    continue;

	case INET_LOPT_BIT8:
	    DEBUGF(("inet_set_opts(%ld): s=%d, BIT8=%d\r\n",
		    (long)desc->port, desc->s, ival));
	    switch(ival) {
	    case INET_BIT8_ON:
		desc->bit8f = 1;
		desc->bit8  = 0;
		break;
	    case INET_BIT8_OFF:
		desc->bit8f = 0;
		desc->bit8  = 0;
		break;
	    case INET_BIT8_CLEAR:
		desc->bit8f = 1;
		desc->bit8  = 0;
		break;
	    case INET_BIT8_SET:
		desc->bit8f = 1;
		desc->bit8  = 1;
		break;
	    }
	    continue;

	case INET_LOPT_TCP_HIWTRMRK:
	    if (desc->stype == SOCK_STREAM) {
		tcp_descriptor* tdesc = (tcp_descriptor*) desc;
		if (ival < 0) ival = 0;
		else if (ival > INET_MAX_BUFFER*2) ival = INET_MAX_BUFFER*2;
		if (tdesc->low > ival)
		    tdesc->low = ival;
		tdesc->high = ival;
	    }
	    continue;

	case INET_LOPT_TCP_LOWTRMRK:
	    if (desc->stype == SOCK_STREAM) {
		tcp_descriptor* tdesc = (tcp_descriptor*) desc;
		if (ival < 0) ival = 0;
		else if (ival > INET_MAX_BUFFER) ival = INET_MAX_BUFFER;
		if (tdesc->high < ival)
		    tdesc->high = ival;
		tdesc->high = ival;
	    }
	    continue;

	case INET_LOPT_TCP_SEND_TIMEOUT:
	    if (desc->stype == SOCK_STREAM) {
		tcp_descriptor* tdesc = (tcp_descriptor*) desc;
		tdesc->send_timeout = ival;
	    }
	    continue;

	case INET_LOPT_TCP_DELAY_SEND:
	    if (desc->stype == SOCK_STREAM) {
		tcp_descriptor* tdesc = (tcp_descriptor*) desc;
		if (ival)
		    tdesc->tcp_add_flags |= TCP_ADDF_DELAY_SEND;
		else
		    tdesc->tcp_add_flags &= ~TCP_ADDF_DELAY_SEND;
	    }
	    continue;

	case INET_LOPT_UDP_READ_PACKETS:
	    if (desc->stype == SOCK_DGRAM) {
		udp_descriptor* udesc = (udp_descriptor*) desc;
		if (ival <= 0) return -1;
		udesc->read_packets = ival;
	    }
	    continue;

	case INET_OPT_REUSEADDR: 
#ifdef __WIN32__
	    continue;  /* Bjorn says */
#else
	    type = SO_REUSEADDR;
	    DEBUGF(("inet_set_opts(%ld): s=%d, SO_REUSEADDR=%d\r\n",
		    (long)desc->port, desc->s,ival));
	    break;
#endif
	case INET_OPT_KEEPALIVE: type = SO_KEEPALIVE;
	    DEBUGF(("inet_set_opts(%ld): s=%d, SO_KEEPALIVE=%d\r\n",
		    (long)desc->port, desc->s, ival));
	    break;
	case INET_OPT_DONTROUTE: type = SO_DONTROUTE;
	    DEBUGF(("inet_set_opts(%ld): s=%d, SO_DONTROUTE=%d\r\n",
		    (long)desc->port, desc->s, ival));
	    break;
	case INET_OPT_BROADCAST: type = SO_BROADCAST;
	    DEBUGF(("inet_set_opts(%ld): s=%d, SO_BROADCAST=%d\r\n",
		    (long)desc->port, desc->s,ival));
	    break;
	case INET_OPT_OOBINLINE: type = SO_OOBINLINE; 
	    DEBUGF(("inet_set_opts(%ld): s=%d, SO_OOBINLINE=%d\r\n",
		    (long)desc->port, desc->s, ival));
	    break;
	case INET_OPT_SNDBUF:    type = SO_SNDBUF; 
	    DEBUGF(("inet_set_opts(%ld): s=%d, SO_SNDBUF=%d\r\n",
		    (long)desc->port, desc->s, ival));
	    /* 
	     * Setting buffer sizes in VxWorks gives unexpected results
	     * our workaround is to leave it at default.
	     */
#ifdef VXWORKS
	    goto skip_os_setopt;
#else
	    break;
#endif
	case INET_OPT_RCVBUF:    type = SO_RCVBUF; 
	    DEBUGF(("inet_set_opts(%ld): s=%d, SO_RCVBUF=%d\r\n",
		    (long)desc->port, desc->s, ival));
#ifdef VXWORKS
	    goto skip_os_setopt;
#else
	    break;
#endif
	case INET_OPT_LINGER:    type = SO_LINGER; 
	    if (len < 4)
		return -1;
	    li_val.l_onoff = ival;
	    li_val.l_linger = get_int32(ptr);
	    ptr += 4;
	    len -= 4;
	    arg_ptr = (char*) &li_val;
	    arg_sz = sizeof(li_val);
	    DEBUGF(("inet_set_opts(%ld): s=%d, SO_LINGER=%d,%d",
		    (long)desc->port, desc->s, li_val.l_onoff,li_val.l_linger));
	    break;

	case INET_OPT_PRIORITY: 
#ifdef SO_PRIORITY
	    type = SO_PRIORITY;
	    propagate = 1; /* We do want to know if this fails */
	    DEBUGF(("inet_set_opts(%ld): s=%d, SO_PRIORITY=%d\r\n",
		    (long)desc->port, desc->s, ival));
	    break;
#else
	    continue;
#endif
	case INET_OPT_TOS:
#if defined(IP_TOS) && defined(SOL_IP)
	    proto = SOL_IP;
	    type = IP_TOS;
	    propagate = 1;
	    DEBUGF(("inet_set_opts(%ld): s=%d, IP_TOS=%d\r\n",
		    (long)desc->port, desc->s, ival));
	    break;
#else
	    continue;
#endif

	case TCP_OPT_NODELAY:
	    proto = IPPROTO_TCP; 
	    type = TCP_NODELAY; 
	    DEBUGF(("inet_set_opts(%ld): s=%d, TCP_NODELAY=%d\r\n",
		    (long)desc->port, desc->s, ival));
	    break;

#ifdef HAVE_MULTICAST_SUPPORT

	case UDP_OPT_MULTICAST_TTL:
	    proto = IPPROTO_IP;
	    type = IP_MULTICAST_TTL;
	    DEBUGF(("inet_set_opts(%ld): s=%d, IP_MULTICAST_TTL=%d\r\n",
		    (long)desc->port,desc->s,ival));
	    break;

	case UDP_OPT_MULTICAST_LOOP:
	    proto = IPPROTO_IP;
	    type = IP_MULTICAST_LOOP;
	    DEBUGF(("inet_set_opts(%ld): s=%d, IP_MULTICAST_LOOP=%d\r\n",
		    (long)desc->port,desc->s,ival));
	    break;

	case UDP_OPT_MULTICAST_IF:
	    proto = IPPROTO_IP;
	    type = IP_MULTICAST_IF;
	    DEBUGF(("inet_set_opts(%ld): s=%d, IP_MULTICAST_IF=%x\r\n",
		    (long)desc->port, desc->s, ival));
	    ival = sock_htonl(ival);
	    break;

	case UDP_OPT_ADD_MEMBERSHIP:
	    proto = IPPROTO_IP;
	    type = IP_ADD_MEMBERSHIP;
	    DEBUGF(("inet_set_opts(%ld): s=%d, IP_ADD_MEMBERSHIP=%d\r\n",
		    (long)desc->port, desc->s,ival));
	    goto L_set_mreq;
	    
	case UDP_OPT_DROP_MEMBERSHIP:
	    proto = IPPROTO_IP;
	    type = IP_DROP_MEMBERSHIP;
	    DEBUGF(("inet_set_opts(%ld): s=%d, IP_DROP_MEMBERSHIP=%x\r\n",
		    (long)desc->port, desc->s, ival));
	L_set_mreq:
	    mreq_val.imr_multiaddr.s_addr = sock_htonl(ival);
	    ival = get_int32(ptr);
	    mreq_val.imr_interface.s_addr = sock_htonl(ival);
	    ptr += 4;
	    len -= 4;
	    arg_ptr = (char*)&mreq_val;
	    arg_sz = sizeof(mreq_val);
	    break;

#endif /* HAVE_MULTICAST_SUPPORT */

	case INET_OPT_RAW:
	    if (len < 8) {
		return -1;
	    }
	    proto = ival;
	    type = get_int32(ptr);
	    ptr += 4;
	    arg_sz = get_int32(ptr);
	    ptr += 4;
	    len -= 8;
	    if (len < arg_sz) {
		return -1;
	    }
	    arg_ptr = ptr;
	    ptr += arg_sz;
	    len -= arg_sz;
	    break;

	default:
	    return -1;
	}
#if  defined(IP_TOS) && defined(SOL_IP) && defined(SO_PRIORITY)
	res = setopt_prio_tos_trick (desc->s, proto, type, arg_ptr, arg_sz);
#else
	res = sock_setopt	    (desc->s, proto, type, arg_ptr, arg_sz);
#endif
	if (propagate && res != 0) {
	    return -1;
	}
	DEBUGF(("inet_set_opts(%ld): s=%d returned %d\r\n",
		(long)desc->port, desc->s, res));
#ifdef VXWORKS
skip_os_setopt:
#endif
	if (type == SO_RCVBUF) {
	    /* make sure we have desc->bufsz >= SO_RCVBUF */
	    if (ival > desc->bufsz)
		desc->bufsz = ival;
	}
    }

    if ( ((desc->stype == SOCK_STREAM) && IS_CONNECTED(desc)) ||
	((desc->stype == SOCK_DGRAM) && IS_OPEN(desc))) {

	if (desc->active != old_active)
	    sock_select(desc, (FD_READ|FD_CLOSE), (desc->active>0));

	if ((desc->stype==SOCK_STREAM) && desc->active) {
	    if (!old_active || (desc->htype != old_htype)) {
		/* passive => active change OR header type change in active mode */
		return 1;
	    }
	    return 0;
	}
    }
    return 0;
}

#ifdef HAVE_SCTP

/*  "sctp_get_initmsg":
**  Used by both "send*" and "setsockopt". Gets the 4 fields of "sctp_initmsg"
**  from the input buffer:
*/
#define SCTP_GET_INITMSG_LEN (4*2)
static char* sctp_get_initmsg(struct sctp_initmsg* ini, char* curr)
{
    ini->sinit_num_ostreams   = get_int16 (curr);	curr += 2;
    ini->sinit_max_instreams  = get_int16 (curr);	curr += 2;
    ini->sinit_max_attempts   = get_int16 (curr);	curr += 2;
    ini->sinit_max_init_timeo = get_int16 (curr);	curr += 2;
    return curr;
}

/*  "sctp_get_sendparams":
**  Parses (from the command buffer) the 6 user-sprcified parms of
**  "sctp_sndrcvinfo":
**	stream(u16),      flags(u16), ppid(u32), context(u32),
**	timetoleave(u32), assoc_id
**  Is used by both "send*" and "setsockopt":
*/
#define SCTP_GET_SENDPARAMS_LEN (2*2 + 3*4 + ASSOC_ID_LEN)
static char* sctp_get_sendparams (struct sctp_sndrcvinfo* sri, char* curr)
{
    sri->sinfo_stream       = get_int16(curr);		curr += 2;
    sri->sinfo_ssn	    = 0;

    /* The "flags" are already ORed at the Erlang side, here we
       reconstruct the real SCTP flags:
    */
    int eflags		    = get_int16(curr);		curr += 2;
    int cflags		    = 0;
    if (eflags & SCTP_FLAG_UNORDERED) cflags |= SCTP_UNORDERED;
    if (eflags & SCTP_FLAG_ADDR_OVER) cflags |= SCTP_ADDR_OVER;
    if (eflags & SCTP_FLAG_ABORT)     cflags |= SCTP_ABORT;
    if (eflags & SCTP_FLAG_EOF)	      cflags |= SCTP_EOF;

    sri->sinfo_flags	    = cflags;
    sri->sinfo_ppid         = sock_htonl(get_int32(curr));
							curr += 4;
    sri->sinfo_context      = get_int32(curr);		curr += 4;
    sri->sinfo_timetolive   = get_int32(curr);		curr += 4;
    sri->sinfo_tsn	    = 0;
    sri->sinfo_cumtsn	    = 0;
    sri->sinfo_assoc_id	    = GET_ASSOC_ID  (curr);	curr += ASSOC_ID_LEN;

    return curr;
}

/* Set SCTP options:
** return -1 on error
**         0 if ok
** NB: unlike inet_set_opts(), we don't have an active mode here, so there is no
** mode change which could force data delivery on setting an option.
** Arg: "ptr": [(erlang_encoded_opt(u8), value(...)), ...];  thus, multiple opts
** can be set at a time.
*/
static int sctp_set_opts(inet_descriptor* desc, char* ptr, int len)
{
#   define CHKLEN(Ptr, Len)                        \
    do {                                           \
	if ((Ptr) + (Len) > ptr + len) return -1; \
    } while (0)
    
    char * curr = ptr;
    int    proto, type, res;

    /* The following union is used to hold any arg to "setsockopt": */
    union  opts_union
    {
	int			    ival;
	struct sctp_rtoinfo	    rtoi;
	struct sctp_assocparams	    ap;
	struct sctp_initmsg	    im;
	struct linger		    lin;
	struct sctp_setpeerprim	    prim;
	struct sctp_setadaption	    ad;
	struct sctp_paddrparams	    pap;
	struct sctp_sndrcvinfo	    sri;
	struct sctp_event_subscribe es;
#	ifdef SCTP_DELAYED_ACK_TIME
	struct sctp_assoc_value     av; /* Not in SOLARIS10 */
#	endif
    }
    arg;

    char * arg_ptr = NULL;
    int    arg_sz  = 0;

    while (curr < ptr + len)
    {
	/* Get the Erlang-encoded option type -- always 1 byte: */
	int eopt = *curr;
	curr++;

	/* Get the option value.  XXX: The condition  (curr < ptr + len)
	   does not preclude us from reading from beyond the buffer end,
	   if the Erlang part of the driver specifies its input wrongly!
	*/
	CHKLEN(curr, 4); /* All options need at least 4 bytes */
	switch(eopt)
	{
	/* Local INET options: */

	case INET_LOPT_BUFFER:
	    desc->bufsz  = get_int32(curr);		curr += 4;

            if (desc->bufsz > INET_MAX_BUFFER)
		desc->bufsz = INET_MAX_BUFFER;
            else
	    if (desc->bufsz < INET_MIN_BUFFER)
		desc->bufsz = INET_MIN_BUFFER;
	    res = 0;	  /* This does not affect the kernel buffer size */
	    continue;

	case INET_LOPT_MODE:
	    desc->mode   = get_int32(curr);		curr += 4;
	    res = 0;
	    continue;

	case INET_LOPT_ACTIVE:
	    desc->active = get_int32(curr);		curr += 4;
	    res = 0;
	    continue;

	/* SCTP options and applicable generic INET options: */

	case SCTP_OPT_RTOINFO:
	{
	    CHKLEN(curr, ASSOC_ID_LEN + 3*4);
	    arg.rtoi.srto_assoc_id = GET_ASSOC_ID(curr);  curr += ASSOC_ID_LEN;
	    arg.rtoi.srto_initial  = get_int32   (curr);  curr += 4;
	    arg.rtoi.srto_max      = get_int32   (curr);  curr += 4;
	    arg.rtoi.srto_min      = get_int32   (curr);  curr += 4;

	    proto   = IPPROTO_SCTP;
	    type    = SCTP_RTOINFO;
	    arg_ptr = (char*) (&arg.rtoi);
	    arg_sz  = sizeof  ( arg.rtoi);
	    break;
	}
	case SCTP_OPT_ASSOCINFO:
	{
	    CHKLEN(curr, ASSOC_ID_LEN + 2*2 + 3*4);

	    arg.ap.sasoc_assoc_id    = GET_ASSOC_ID(curr); curr += ASSOC_ID_LEN;
	    arg.ap.sasoc_asocmaxrxt  = get_int16   (curr); curr += 2;
	    arg.ap.sasoc_number_peer_destinations =
				       get_int16   (curr); curr += 2;
	    arg.ap.sasoc_peer_rwnd   = get_int32   (curr); curr += 4;
	    arg.ap.sasoc_local_rwnd  = get_int32   (curr); curr += 4;
	    arg.ap.sasoc_cookie_life = get_int32   (curr); curr += 4;

	    proto   = IPPROTO_SCTP;
	    type    = SCTP_ASSOCINFO;
	    arg_ptr = (char*) (&arg.ap);
	    arg_sz  = sizeof  ( arg.ap);
	    break;
	}
	case SCTP_OPT_INITMSG:
	{
	    CHKLEN(curr, SCTP_GET_INITMSG_LEN);
	    curr  = sctp_get_initmsg (&arg.im, curr);

	    proto   = IPPROTO_SCTP;
	    type    = SCTP_INITMSG;
	    arg_ptr = (char*) (&arg.im);
	    arg_sz  = sizeof  ( arg.im);
	    break;
	}
	case INET_OPT_LINGER:
	{
	    CHKLEN(curr, ASSOC_ID_LEN + 2 + 4);
	    arg.lin.l_onoff  = get_int16 (curr);  curr += 2;
	    arg.lin.l_linger = get_int32 (curr);  curr += 4;

	    proto   = SOL_SOCKET;
	    type    = SO_LINGER;
	    arg_ptr = (char*) (&arg.lin);
	    arg_sz  = sizeof  ( arg.lin);
	    break;
	}
	case SCTP_OPT_NODELAY:
	{
	    arg.ival= get_int32 (curr);	  curr += 4;
	    proto   = IPPROTO_SCTP;
	    type    = SCTP_NODELAY;
	    arg_ptr = (char*) (&arg.ival);
	    arg_sz  = sizeof  ( arg.ival);
	    break;
	}
	case INET_OPT_RCVBUF:
	{
	    arg.ival= get_int32 (curr);	  curr += 4;
	    proto   = SOL_SOCKET;
	    type    = SO_RCVBUF;
	    arg_ptr = (char*) (&arg.ival);
	    arg_sz  = sizeof  ( arg.ival);

	    /* Adjust the size of the user-level recv buffer, so it's not
	       smaller than the kernel one: */
	    if (desc->bufsz <= arg.ival)
		desc->bufsz  = arg.ival;
	    break;
	}
	case INET_OPT_SNDBUF:
	{
	    arg.ival= get_int32 (curr);	  curr += 4;
	    proto   = SOL_SOCKET;
	    type    = SO_SNDBUF;
	    arg_ptr = (char*) (&arg.ival);
	    arg_sz  = sizeof  ( arg.ival);

	    /* Adjust the size of the user-level recv buffer, so it's not
	       smaller than the kernel one: */
	    if (desc->bufsz <= arg.ival)
		desc->bufsz  = arg.ival;
	    break;
	}
	case INET_OPT_REUSEADDR:
	{
	    arg.ival= get_int32 (curr);	  curr += 4;
	    proto   = SOL_SOCKET;
	    type    = SO_REUSEADDR;
	    arg_ptr = (char*) (&arg.ival);
	    arg_sz  = sizeof  ( arg.ival);
	    break;
	}
	case INET_OPT_DONTROUTE:
	{
	    arg.ival= get_int32 (curr);	  curr += 4;
	    proto   = SOL_SOCKET;
	    type    = SO_DONTROUTE;
	    arg_ptr = (char*) (&arg.ival);
	    arg_sz  = sizeof  ( arg.ival);
	    break;
	}
	case INET_OPT_PRIORITY:
#	ifdef SO_PRIORITY
	{
	    arg.ival= get_int32 (curr);	  curr += 4;
	    proto   = SOL_SOCKET;
	    type    = SO_PRIORITY;
	    arg_ptr = (char*) (&arg.ival);
	    arg_sz  = sizeof  ( arg.ival);
	    break;
	}
#	else
	    continue; /* Option not supported -- ignore it */
#	endif

	case INET_OPT_TOS:
#	if defined(IP_TOS) && defined(SOL_IP)
	{
	    arg.ival= get_int32 (curr);	  curr += 4;
	    proto   = SOL_IP;
	    type    = IP_TOS;
	    arg_ptr = (char*) (&arg.ival);
	    arg_sz  = sizeof  ( arg.ival);
	    break;
	}
#	else
	    continue; /* Option not supported -- ignore it */
#	endif

	case SCTP_OPT_AUTOCLOSE:
	{
	    arg.ival= get_int32 (curr);	  curr += 4;
	    proto   = IPPROTO_SCTP;
	    type    = SCTP_AUTOCLOSE;
	    arg_ptr = (char*) (&arg.ival);
	    arg_sz  = sizeof  ( arg.ival);
	    break;
	}
	case SCTP_OPT_DISABLE_FRAGMENTS:
	{
	    arg.ival= get_int32 (curr);	  curr += 4;
	    proto   = IPPROTO_SCTP;
	    type    = SCTP_DISABLE_FRAGMENTS;
	    arg_ptr = (char*) (&arg.ival);
	    arg_sz  = sizeof  ( arg.ival);
	    break;
	}
	case SCTP_OPT_I_WANT_MAPPED_V4_ADDR:
	{
	    arg.ival= get_int32 (curr);	  curr += 4;
	    proto   = IPPROTO_SCTP;
	    type    = SCTP_I_WANT_MAPPED_V4_ADDR;
	    arg_ptr = (char*) (&arg.ival);
	    arg_sz  = sizeof  ( arg.ival);
	    break;
	}
	case SCTP_OPT_MAXSEG:
	{
	    arg.ival= get_int32 (curr);	  curr += 4;
	    proto   = IPPROTO_SCTP;
	    type    = SCTP_MAXSEG;
	    arg_ptr = (char*) (&arg.ival);
	    arg_sz  = sizeof  ( arg.ival);
	    break;
	}
	case SCTP_OPT_PRIMARY_ADDR:
	case SCTP_OPT_SET_PEER_PRIMARY_ADDR:
	{
	    CHKLEN(curr, ASSOC_ID_LEN);
	    /* XXX: These 2 opts have isomorphic value data structures,
	       "sctp_setpeerprim" and "sctp_prim" (in Solaris 10, the latter
	       is called "sctp_setprim"),  so we grouped them together:
	    */
	    arg.prim.sspp_assoc_id = GET_ASSOC_ID(curr); curr += ASSOC_ID_LEN;

	    /* Fill in "arg.prim.sspp_addr": */
	    int    alen  = ptr + len - curr;
	    char * after =
		   inet_set_address
		   	(desc->sfamily, (inet_address*) (&arg.prim.sspp_addr),
			curr,  &alen);
	    if (after == NULL)
		return -1;
	    curr  = after;

	    proto = IPPROTO_SCTP;
	    if (eopt == SCTP_OPT_PRIMARY_ADDR)
		type =  SCTP_PRIMARY_ADDR;
	    else
		type =  SCTP_SET_PEER_PRIMARY_ADDR;

	    arg_ptr  =  (char*) (&arg.prim);
	    arg_sz   =  sizeof  ( arg.prim);
	    break;
	}
	case SCTP_OPT_ADAPTION_LAYER:
	{
	    /* XXX: do we need to convert the Ind into network byte order??? */
	    arg.ad.ssb_adaption_ind = sock_htonl (get_int32(curr));  curr += 4;

	    proto   = IPPROTO_SCTP;
	    type    = SCTP_ADAPTION_LAYER;
	    arg_ptr = (char*) (&arg.ad);
	    arg_sz  = sizeof  ( arg.ad);
	    break;
	}
	case SCTP_OPT_PEER_ADDR_PARAMS:
	{
	    CHKLEN(curr, ASSOC_ID_LEN);
	    arg.pap.spp_assoc_id = GET_ASSOC_ID(curr);	curr += ASSOC_ID_LEN;

	    /* Fill in "pap.spp_address": */
	    int    alen  = ptr + len - curr;
	    char * after =
		   inet_set_address
			(desc->sfamily, (inet_address*) (&arg.pap.spp_address),
			curr,  &alen);
	    if (after == NULL)
		return -1;
	    curr = after;

	    CHKLEN(curr, 4 + 2 + 3*4);
	    
	    arg.pap.spp_hbinterval = get_int32(curr);	curr += 4;
	    arg.pap.spp_pathmaxrxt = get_int16(curr);	curr += 2;

	    /* The following are missing in Solaris 10: */
#	    ifdef HAVE_SCTP_PADDRPARAMS_SPP_PATHMTU
	    arg.pap.spp_pathmtu    = get_int32(curr);
#           endif
	    curr += 4;
#	    ifdef HAVE_SCTP_PADDRPARAMS_SPP_SACKDELAY
	    arg.pap.spp_sackdelay  = get_int32(curr);
#           endif
	    curr += 4;

#	    ifdef HAVE_SCTP_PADDRPARAMS_SPP_FLAGS
	    /* Now re-construct the flags: */
	    int eflags	       = get_int32(curr);
	    int cflags	       = 0;

	    int hb_enable      = eflags & SCTP_FLAG_HB_ENABLE;
	    int hb_disable     = eflags & SCTP_FLAG_HB_DISABLE;
	    if (hb_enable && hb_disable)
		return -1;
	    if (hb_enable)	 		cflags |= SPP_HB_ENABLE;
	    if (hb_disable)	 		cflags |= SPP_HB_DISABLE;
	    if (eflags & SCTP_FLAG_HB_DEMAND)	cflags |= SPP_HB_DEMAND;

	    int pmtud_enable   = eflags & SCTP_FLAG_PMTUD_ENABLE;
	    int pmtud_disable  = eflags & SCTP_FLAG_PMTUD_DISABLE;
	    if (pmtud_enable && pmtud_disable)
		return -1;
	    if (pmtud_enable)			cflags |= SPP_PMTUD_ENABLE;
	    if (pmtud_disable)			cflags |= SPP_PMTUD_DISABLE;

	    int sackdelay_enable =eflags& SCTP_FLAG_SACDELAY_ENABLE;
	    int sackdelay_disable=eflags& SCTP_FLAG_SACDELAY_DISABLE;
	    if (sackdelay_enable && sackdelay_disable)
		return -1;
	    if (sackdelay_enable)		cflags |= SPP_SACKDELAY_ENABLE;
	    if (sackdelay_disable)		cflags |= SPP_SACKDELAY_DISABLE;

	    arg.pap.spp_flags  = cflags;
#	    endif
	    curr += 4;

	    proto   = IPPROTO_SCTP;
	    type    = SCTP_PEER_ADDR_PARAMS;
	    arg_ptr = (char*) (&arg.pap);
	    arg_sz  = sizeof  ( arg.pap);
	    break;
	}
	case SCTP_OPT_DEFAULT_SEND_PARAM:
	{
	    CHKLEN(curr, SCTP_GET_SENDPARAMS_LEN);
	    curr = sctp_get_sendparams (&arg.sri, curr);

	    proto   = IPPROTO_SCTP;
	    type    = SCTP_DEFAULT_SEND_PARAM;
	    arg_ptr = (char*) (&arg.sri);
	    arg_sz  = sizeof  ( arg.sri);
	    break;
	}
	case SCTP_OPT_EVENTS:
	{
	    CHKLEN(curr, 8);
	    /* We do not support "sctp_authentication_event" -- it is not
	       implemented in Linux Kernel SCTP anyway.   Just in case if
	       the above structure has more fields than we support,  zero
	       it out -- the extraneous events will NOT be used:
	    */
	    memset (&arg.es, 0, sizeof(arg.es));

	    /* The input "buf" must contain the full definition of all the
	       supported event fields, 1 byte per each,   as each event is
	       either explicitly subscribed or cleared:
	    */
	    arg.es.sctp_data_io_event          = get_int8(curr);   curr++;
	    arg.es.sctp_association_event      = get_int8(curr);   curr++;
	    arg.es.sctp_address_event	       = get_int8(curr);   curr++;
	    arg.es.sctp_send_failure_event     = get_int8(curr);   curr++;
	    arg.es.sctp_peer_error_event       = get_int8(curr);   curr++;
	    arg.es.sctp_shutdown_event	       = get_int8(curr);   curr++;
	    arg.es.sctp_partial_delivery_event = get_int8(curr);   curr++;
	    arg.es.sctp_adaption_layer_event   = get_int8(curr);   curr++;

	    proto   = IPPROTO_SCTP;
	    type    = SCTP_EVENTS;
	    arg_ptr = (char*) (&arg.es);
	    arg_sz  = sizeof  ( arg.es);
	    break;
	}
	/* The following is not available on Solaris 10: */
#	ifdef SCTP_DELAYED_ACK_TIME
	case SCTP_OPT_DELAYED_ACK_TIME:
	{
	    CHKLEN(curr, ASSOC_ID_LEN + 4);
	    arg.av.assoc_id    = GET_ASSOC_ID(curr);	curr += ASSOC_ID_LEN;
	    arg.av.assoc_value = get_int32(curr);	curr += 4;

	    proto   = IPPROTO_SCTP;
	    type    = SCTP_DELAYED_ACK_TIME;
	    arg_ptr = (char*) (&arg.av);
	    arg_sz  = sizeof  ( arg.es);
	    break;
	}
#	endif
	default:
	    /* XXX: No more supported SCTP options. In particular, authentica-
	       tion options (SCTP_AUTH_CHUNK, SCTP_AUTH_KEY, SCTP_PEER_AUTH_
               CHUNKS, SCTP_LOCAL_AUTH_CHUNKS, SCTP_AUTH_SETKEY_ACTIVE)  are
	       not yet implemented in the Linux kernel,  hence not supported
	       here.  Also not supported are SCTP_HMAC_IDENT, as well as any
	       "generic" options except "INET_LOPT_MODE".    Raise an error:
	    */
	    return -1;
	}
#if  defined(IP_TOS) && defined(SOL_IP) && defined(SO_PRIORITY)
	res = setopt_prio_tos_trick (desc->s, proto, type, arg_ptr, arg_sz);
#else
	res = sock_setopt	    (desc->s, proto, type, arg_ptr, arg_sz);
#endif
	/* The return values of "sock_setopt" can only be 0 or -1: */
	ASSERT(res == 0 || res == -1);
	if (res == -1)
	{  /* Got an error, DO NOT continue with other options. However, on
	      Solaris 10, we DO allow SO_SNDBUF and SO_RCVBUF to fail, assu-
	      min that the default kernel versions are good enough:
	   */
#	   ifdef SOLARIS10
	   if (type != SO_SNDBUF && type != SO_RCVBUF)
#	   endif
	   return res;
	}
    }
    /* If we got here, all "sock_setopt"s above were successful:   */
    return 0;
#   undef CHKLEN
}
#endif /* HAVE_SCTP */

/* load all option values into the buf and reply 
** return total length of reply filled into ptr
** ptr should point to a buffer with 9*len +1 to be safe!!
*/

static int inet_fill_opts(inet_descriptor* desc,
			  char* buf, int len, char** dest, int destlen)
{
    int type;
    int proto;
    int opt;
    struct linger li_val;
    int ival;
    char* arg_ptr;
    unsigned int arg_sz;
    char *ptr = NULL;
    int dest_used = 0;
    int dest_allocated = destlen;
    char *orig_dest = *dest;

    /* Ptr is a name parameter */ 
#define RETURN_ERROR()				\
    do {					\
	if (dest_allocated > destlen) {		\
	    FREE(*dest);			\
	    *dest = orig_dest;			\
	}					\
	return -1;				\
    } while(0)

#define PLACE_FOR(Size,Ptr)						   \
    do {								   \
	int need = dest_used + (Size);					   \
	if (need > INET_MAX_BUFFER) {					   \
	    RETURN_ERROR();						   \
	}								   \
	if (need > dest_allocated) {					   \
	    char *new_buffer;						   \
	    if (dest_allocated == destlen) {				   \
		new_buffer = ALLOC((dest_allocated = need + 10));	   \
		memcpy(new_buffer,*dest,dest_used);			   \
	    } else {							   \
		new_buffer = REALLOC(*dest, (dest_allocated = need + 10)); \
	    }								   \
	    *dest = new_buffer;						   \
	}								   \
	(Ptr) = (*dest) + dest_used;					   \
	dest_used = need;						   \
    } while (0)

    /* Ptr is a name parameter */ 
#define TRUNCATE_TO(Size,Ptr)				\
    do {						\
	int new_need = ((Ptr) - (*dest)) + (Size);	\
	if (new_need > dest_used) {			\
	    erl_exit(1,"Internal error in inet_drv, "	\
		     "miscalculated buffer size");	\
	}						\
	dest_used = new_need;				\
    } while(0)

    
    PLACE_FOR(1,ptr);
    *ptr = INET_REP_OK;

    while(len--) {
	opt = *buf++;
	proto = SOL_SOCKET;
	arg_sz = sizeof(ival);
	arg_ptr = (char*) &ival;

	PLACE_FOR(5,ptr);

	switch(opt) {
	case INET_LOPT_BUFFER:
	    *ptr++ = opt;
	    put_int32(desc->bufsz, ptr);
	    continue;
	case INET_LOPT_HEADER:
	    *ptr++ = opt;
	    put_int32(desc->hsz, ptr);
	    continue;
	case INET_LOPT_MODE:
	    *ptr++ = opt;
	    put_int32(desc->mode, ptr);
	    continue;
	case INET_LOPT_DELIVER:
	    *ptr++ = opt;
	    put_int32(desc->deliver, ptr);
	    continue;
	case INET_LOPT_ACTIVE:
	    *ptr++ = opt;
	    put_int32(desc->active, ptr);
	    continue;
	case INET_LOPT_PACKET:
	    *ptr++ = opt;
	    put_int32(desc->htype, ptr);
	    continue;
	case INET_LOPT_PACKET_SIZE:
	    *ptr++ = opt;
	    put_int32(desc->psize, ptr);
	    continue;
	case INET_LOPT_EXITONCLOSE:
	    *ptr++ = opt;
	    put_int32(desc->exitf, ptr);
	    continue;

	case INET_LOPT_BIT8:
	    *ptr++ = opt;
	    if (desc->bit8f) {
		put_int32(desc->bit8, ptr);
	    } else {
		put_int32(INET_BIT8_OFF, ptr);
	    }
	    continue;

	case INET_LOPT_TCP_HIWTRMRK:
	    if (desc->stype == SOCK_STREAM) {
		*ptr++ = opt;
		ival = ((tcp_descriptor*)desc)->high;
		put_int32(ival, ptr);
	    } else {
		TRUNCATE_TO(0,ptr);
	    }
	    continue;

	case INET_LOPT_TCP_LOWTRMRK:
	    if (desc->stype == SOCK_STREAM) {
		*ptr++ = opt;
		ival = ((tcp_descriptor*)desc)->low;
		put_int32(ival, ptr);
	    } else {
		TRUNCATE_TO(0,ptr);
	    }
	    continue;

	case INET_LOPT_TCP_SEND_TIMEOUT:
	    if (desc->stype == SOCK_STREAM) {
		*ptr++ = opt;
		ival = ((tcp_descriptor*)desc)->send_timeout;
		put_int32(ival, ptr);
	    } else {
		TRUNCATE_TO(0,ptr);
	    }
	    continue;

	case INET_LOPT_TCP_DELAY_SEND:
	    if (desc->stype == SOCK_STREAM) {
		*ptr++ = opt;
		ival = !!(((tcp_descriptor*)desc)->tcp_add_flags & TCP_ADDF_DELAY_SEND);
		put_int32(ival, ptr);
	    } else {
		TRUNCATE_TO(0,ptr);
	    }
	    continue;

	case INET_LOPT_UDP_READ_PACKETS:
	    if (desc->stype == SOCK_DGRAM) {
		*ptr++ = opt;
		ival = ((udp_descriptor*)desc)->read_packets;
		put_int32(ival, ptr);
	    } else {
		TRUNCATE_TO(0,ptr);
	    }
	    continue;

	case INET_OPT_PRIORITY:
#ifdef SO_PRIORITY
	    type = SO_PRIORITY;
	    break;
#else
	    *ptr++ = opt;
	    put_int32(0, ptr);
	    continue;
#endif
	case INET_OPT_TOS:
#if defined(IP_TOS) && defined(SOL_IP)
	    proto = SOL_IP;
	    type = IP_TOS;
	    break;
#else
	    *ptr++ = opt;
	    put_int32(0, ptr);
	    continue;
#endif
	case INET_OPT_REUSEADDR: 
	    type = SO_REUSEADDR; 
	    break;
	case INET_OPT_KEEPALIVE: 
	    type = SO_KEEPALIVE; 
	    break;
	case INET_OPT_DONTROUTE: 
	    type = SO_DONTROUTE; 
	    break;
	case INET_OPT_BROADCAST: 
	    type = SO_BROADCAST;
	    break;
	case INET_OPT_OOBINLINE: 
	    type = SO_OOBINLINE; 
	    break;
	case INET_OPT_SNDBUF:    
	    type = SO_SNDBUF; 
	    break;
	case INET_OPT_RCVBUF:    
	    type = SO_RCVBUF; 
	    break;
	case TCP_OPT_NODELAY:
	    proto = IPPROTO_TCP;
	    type = TCP_NODELAY;
	    break;

#ifdef HAVE_MULTICAST_SUPPORT
	case UDP_OPT_MULTICAST_TTL:
	    proto = IPPROTO_IP;
	    type = IP_MULTICAST_TTL;
	    break;
	case UDP_OPT_MULTICAST_LOOP:
	    proto = IPPROTO_IP;
	    type = IP_MULTICAST_LOOP;
	    break;
	case UDP_OPT_MULTICAST_IF:
	    proto = IPPROTO_IP;
	    type = IP_MULTICAST_IF;
	    break;
	case INET_OPT_LINGER:
	    arg_sz = sizeof(li_val);
	    arg_ptr = (char*) &li_val;	    
	    type = SO_LINGER; 
	    break;
#endif /* HAVE_MULTICAST_SUPPORT */

	case INET_OPT_RAW:
	    {
		int data_provided;
		/* Raw options are icky, handle directly... */
		if (len < 13) {
		    RETURN_ERROR();
		}
		len -= 13;
		proto = get_int32(buf);
		buf += 4;
		type = get_int32(buf);
		buf += 4;
		data_provided = (int) *buf++;
		arg_sz = get_int32(buf);
		if (arg_sz > INET_MAX_BUFFER) {	
		    RETURN_ERROR();
		}
		buf += 4;
		TRUNCATE_TO(0,ptr);
		PLACE_FOR(13 + arg_sz,ptr);
		arg_ptr = ptr + 13;
		if (data_provided) {
		    if (len < arg_sz) {
			RETURN_ERROR();
		    }
		    memcpy(arg_ptr,buf,arg_sz);
		    buf += arg_sz;
		    len -= arg_sz;
		}
		if (sock_getopt(desc->s,proto,type,arg_ptr,&arg_sz) == 
		    SOCKET_ERROR) {
		    TRUNCATE_TO(0,ptr); 
		    continue;
		}
		TRUNCATE_TO(arg_sz + 13,ptr);
		*ptr++ = opt;
		put_int32(proto,ptr);
		ptr += 4;
		put_int32(type,ptr);
		ptr += 4;
		put_int32(arg_sz,ptr);
		continue;
	    }
	default:
	    RETURN_ERROR();
	}
	/* We have 5 bytes allocated to ptr */
	if (sock_getopt(desc->s,proto,type,arg_ptr,&arg_sz) == SOCKET_ERROR) {
	    TRUNCATE_TO(0,ptr);
	    continue;
	}
	*ptr++ = opt;
	if (arg_ptr == (char*)&ival) {
	    put_int32(ival, ptr);
	}
	else {
	    put_int32(li_val.l_onoff, ptr);
	    PLACE_FOR(4,ptr);
	    put_int32(li_val.l_linger, ptr);
	}
    }
    return (dest_used);
#undef PLACE_FOR
#undef TRUNCATE_TO
#undef RETURN_ERROR
}

#ifdef HAVE_SCTP
#define LOAD_PADDRINFO_CNT                                            \
        (2*LOAD_ATOM_CNT + LOAD_ASSOC_ID_CNT + LOAD_IP_AND_PORT_CNT + \
	 4*LOAD_INT_CNT + LOAD_TUPLE_CNT)
static int load_paddrinfo (ErlDrvTermData * spec, int i,
			   inet_descriptor* desc, struct sctp_paddrinfo* pai)
{
    i = LOAD_ATOM	(spec, i, am_sctp_paddrinfo);
    i = LOAD_ASSOC_ID	(spec, i, pai->spinfo_assoc_id);
    i = load_ip_and_port(spec, i, desc, &pai->spinfo_address);
    switch(pai->spinfo_state)
    {
    case SCTP_ACTIVE:
	i = LOAD_ATOM	(spec, i, am_active);
	break;
    case SCTP_INACTIVE:
	i = LOAD_ATOM	(spec, i, am_inactive);
	break;
    default:
	ASSERT(0);	/* NB: SCTP_UNCONFIRMED modifier not yet supported */
    }
    i = LOAD_INT	(spec, i, pai->spinfo_cwnd);
    i = LOAD_INT	(spec, i, pai->spinfo_srtt);
    i = LOAD_INT	(spec, i, pai->spinfo_rto );
    i = LOAD_INT	(spec, i, pai->spinfo_mtu );
    /* Close up the record: */
    i = LOAD_TUPLE	(spec, i, 8);
    return i;
}

/*
**  "sctp_fill_opts":   Returns {ok, Results}, or an error:
*/
static int sctp_fill_opts(inet_descriptor* desc, char* buf, int buflen,
			  char** dest, int destlen)
{
    /* In contrast to the generic "inet_fill_opts", the output here is
       represented by tuples/records, which are formed in the "spec":
    */
    ErlDrvTermData *spec;
    int i      = 0;
    int length = 0; /* Number of result list entries */
    
    int spec_allocated = PACKET_ERL_DRV_TERM_DATA_LEN;
    spec = ALLOC(sizeof(* spec) * spec_allocated);
    
#   define RETURN_ERROR(Spec, Errno) \
    do {                    \
	FREE(Spec);        \
	return (Errno);     \
    } while(0)
    
    /* Spec is a name parmeter */
#   define PLACE_FOR(Spec, Index, N)                            \
    do {                                                        \
	int need;                                               \
	if ((Index) > spec_allocated) {                         \
	    erl_exit(1,"Internal error in inet_drv, "           \
		     "miscalculated buffer size");              \
	}                                                       \
	need = (Index) + (N);                                   \
	if (need > INET_MAX_BUFFER/sizeof(ErlDrvTermData)) {    \
	    RETURN_ERROR((Spec), -ENOMEM);                      \
	}                                                       \
	if (need > spec_allocated) {                            \
	    (Spec) = REALLOC((Spec),                            \
			     sizeof(* (Spec))                   \
			     * (spec_allocated = need + 20));   \
	}                                                       \
    } while (0)
    
    PLACE_FOR(spec, i, 2*LOAD_ATOM_CNT + LOAD_PORT_CNT);
    i = LOAD_ATOM (spec, i, am_inet_reply);
    i = LOAD_PORT (spec, i, desc->dport);
    i = LOAD_ATOM (spec, i, am_ok);
    
    while (buflen > 0) {
	int eopt = *buf;   /* "eopt" is 1-byte encoded */
	buf ++; buflen --;
	
	switch(eopt)
	{
	/* Local options allowed for SCTP. For TCP and UDP, the values of
	   these options are returned via "res" using integer encoding,
	   but here, we encode them as proper terms the same way as we do
	   it for all other SCTP options:
	*/
	case INET_LOPT_BUFFER:
	{
	    PLACE_FOR(spec, i, LOAD_ATOM_CNT + LOAD_INT_CNT + LOAD_TUPLE_CNT);
	    i = LOAD_ATOM (spec, i, am_buffer);
	    i = LOAD_INT  (spec, i, desc->bufsz);
	    i = LOAD_TUPLE(spec, i, 2);
	    break;
	}
	case INET_LOPT_MODE:
	{
	    PLACE_FOR(spec, i, 2*LOAD_ATOM_CNT + LOAD_TUPLE_CNT);
	    i = LOAD_ATOM (spec, i, am_mode);
	    switch (desc->mode)
	    {
	    	case INET_MODE_LIST  :
		{ i = LOAD_ATOM (spec, i, am_list);   break; }

		case INET_MODE_BINARY:
		{ i = LOAD_ATOM (spec, i, am_binary); break; }

		default: ASSERT (0);
	    }
	    i = LOAD_TUPLE (spec, i, 2);
	    break;
	}
	case INET_LOPT_ACTIVE:
	{
	    PLACE_FOR(spec, i, 2*LOAD_ATOM_CNT + LOAD_TUPLE_CNT);
	    i = LOAD_ATOM (spec, i, am_active);
	    switch (desc->active)
	    {
		case INET_ACTIVE :
		{ i = LOAD_ATOM (spec, i, am_true);  break; }

		case INET_PASSIVE:
		{ i = LOAD_ATOM (spec, i, am_false); break; }

		case INET_ONCE   :
		{ i = LOAD_ATOM (spec, i, am_once);  break; }

		default: ASSERT (0);
	    }
	    i = LOAD_TUPLE (spec, i, 2);
	    break;
	}

	/* SCTP and generic INET options: */

	case SCTP_OPT_RTOINFO:
	{
	    struct       sctp_rtoinfo rti;
	    unsigned int sz  = sizeof(rti);
	    
	    if (buflen < ASSOC_ID_LEN) RETURN_ERROR(spec, -EINVAL);
	    rti.srto_assoc_id = GET_ASSOC_ID(buf);
	    buf    += ASSOC_ID_LEN;
	    buflen -= ASSOC_ID_LEN;
	    
	    if (sock_getopt(desc->s, IPPROTO_SCTP, SCTP_RTOINFO, 
			    &rti, &sz) < 0) continue;
	    /* Fill in the response: */
	    PLACE_FOR(spec, i, 
		      2*LOAD_ATOM_CNT + LOAD_ASSOC_ID_CNT + 
		      3*LOAD_INT_CNT + 2*LOAD_TUPLE_CNT);
	    i = LOAD_ATOM	(spec, i, am_sctp_rtoinfo);
	    i = LOAD_ATOM	(spec, i, am_sctp_rtoinfo);
	    i = LOAD_ASSOC_ID	(spec, i, rti.srto_assoc_id);
	    i = LOAD_INT	(spec, i, rti.srto_initial);
	    i = LOAD_INT	(spec, i, rti.srto_max);
	    i = LOAD_INT	(spec, i, rti.srto_min);
	    i = LOAD_TUPLE	(spec, i, 5);
	    i = LOAD_TUPLE (spec, i, 2);
	    break;
	}
	case SCTP_OPT_ASSOCINFO:
	{
	    struct       sctp_assocparams ap;
	    unsigned int sz  = sizeof(ap);
	    
	    if (buflen < ASSOC_ID_LEN) RETURN_ERROR(spec, -EINVAL);
	    ap.sasoc_assoc_id = GET_ASSOC_ID(buf);
	    buf    += ASSOC_ID_LEN;
	    buflen -= ASSOC_ID_LEN;
	    
	    if (sock_getopt(desc->s, IPPROTO_SCTP, SCTP_ASSOCINFO, 
			    &ap, &sz) < 0) continue;
	    /* Fill in the response: */
	    PLACE_FOR(spec, i, 
		      2*LOAD_ATOM_CNT + LOAD_ASSOC_ID_CNT + 
		      5*LOAD_INT_CNT + 2*LOAD_TUPLE_CNT);
	    i = LOAD_ATOM	(spec, i, am_sctp_associnfo);
	    i = LOAD_ATOM	(spec, i, am_sctp_assocparams);
	    i = LOAD_ASSOC_ID	(spec, i, ap.sasoc_assoc_id);
	    i = LOAD_INT	(spec, i, ap.sasoc_asocmaxrxt);
	    i = LOAD_INT	(spec, i, ap.sasoc_number_peer_destinations);
	    i = LOAD_INT	(spec, i, ap.sasoc_peer_rwnd);
	    i = LOAD_INT	(spec, i, ap.sasoc_local_rwnd);
	    i = LOAD_INT	(spec, i, ap.sasoc_cookie_life);
	    i = LOAD_TUPLE	(spec, i, 7);
	    i = LOAD_TUPLE	(spec, i, 2);
	    break;
	}
	case SCTP_OPT_INITMSG:
	{
	    struct       sctp_initmsg im;
	    unsigned int sz = sizeof(im);
	    
	    if (sock_getopt(desc->s, IPPROTO_SCTP, SCTP_INITMSG, 
			    &im, &sz) < 0) continue;
	    /* Fill in the response: */
	    PLACE_FOR(spec, i, 
		      2*LOAD_ATOM_CNT + 
		      4*LOAD_INT_CNT + 2*LOAD_TUPLE_CNT);
	    i = LOAD_ATOM	(spec, i, am_sctp_initmsg);
	    i = LOAD_ATOM	(spec, i, am_sctp_initmsg);
	    i = LOAD_INT	(spec, i, im.sinit_num_ostreams);
	    i = LOAD_INT	(spec, i, im.sinit_max_instreams);
	    i = LOAD_INT	(spec, i, im.sinit_max_attempts);
	    i = LOAD_INT	(spec, i, im.sinit_max_init_timeo);
	    i = LOAD_TUPLE	(spec, i, 5);
	    i = LOAD_TUPLE	(spec, i, 2);
	    break;
	}
	/* The following option returns a tuple {bool, int}:   */
	case INET_OPT_LINGER:
	{
	    struct linger lg;
	    unsigned int  sz = sizeof(lg);
	    
	    if (sock_getopt(desc->s, IPPROTO_SCTP, SO_LINGER,
			    &lg, &sz) < 0) continue;
	    /* Fill in the response: */
	    PLACE_FOR(spec, i, 
		      LOAD_ATOM_CNT + LOAD_BOOL_CNT + 
		      LOAD_INT_CNT + 2*LOAD_TUPLE_CNT);
	    i = LOAD_ATOM	(spec, i, am_linger);
	    i = LOAD_BOOL	(spec, i, lg.l_onoff);
	    i = LOAD_INT	(spec, i, lg.l_linger);
	    i = LOAD_TUPLE	(spec, i, 2);
	    i = LOAD_TUPLE	(spec, i, 2);
	    break;
	}
	/* The following options just return an integer value: */
	case INET_OPT_RCVBUF   :
	case INET_OPT_SNDBUF   :
	case INET_OPT_REUSEADDR:
	case INET_OPT_DONTROUTE:
	case INET_OPT_PRIORITY :
	case INET_OPT_TOS      :
	case SCTP_OPT_AUTOCLOSE:
	case SCTP_OPT_MAXSEG   :
	/* The following options return true or false:	       */
	case SCTP_OPT_NODELAY  :
	case SCTP_OPT_DISABLE_FRAGMENTS:
	case SCTP_OPT_I_WANT_MAPPED_V4_ADDR:
	{
	    int res   = 0;
	    unsigned int sz = sizeof(res);
	    int proto = 0, type = 0, is_int = 0;
	    ErlDrvTermData tag = am_sctp_error;

	    switch(eopt)
	    {
	    case INET_OPT_RCVBUF   :
	    {
		proto  = IPPROTO_SCTP;
		type   = SO_RCVBUF;
		is_int = 1;
		tag    = am_recbuf;
		break;
	    }
	    case INET_OPT_SNDBUF   :
	    {
		proto  = IPPROTO_SCTP;
		type   = SO_SNDBUF;
		is_int = 1;
		tag    = am_sndbuf;
		break;
	    }
	    case INET_OPT_REUSEADDR:
	    {
		proto  = SOL_SOCKET;
		type   = SO_REUSEADDR;
		is_int = 0;
		tag    = am_reuseaddr;
		break;
	    }
	    case INET_OPT_DONTROUTE:
	    {
		proto  = SOL_SOCKET;
		type   = SO_DONTROUTE;
		is_int = 0;
		tag    = am_dontroute;
		break;
	    }
	    case INET_OPT_PRIORITY:
	    {
#	    if defined(SO_PRIORITY)
		proto  = SOL_SOCKET;
		type   = SO_PRIORITY;
		is_int = 1;
		tag    = am_priority;
		break;
#	    else
		/* Not supported -- ignore */
		continue;
#	    endif
	    }
	    case INET_OPT_TOS:
	    {
#	    if defined(IP_TOS) && defined(SOL_IP)
		proto  = SOL_IP;
		type   = IP_TOS;
		is_int = 1;
		tag    = am_tos;
		break;
#	    else
		/* Not supported -- ignore */
		continue;
#	    endif
	    }
	    case SCTP_OPT_AUTOCLOSE:
	    {
		proto  = IPPROTO_SCTP;
		type   = SCTP_AUTOCLOSE;
		is_int = 1;
		tag    = am_sctp_autoclose;
		break;
	    }
	    case SCTP_OPT_MAXSEG   :
	   {
		proto  = IPPROTO_SCTP;
		type   = SCTP_MAXSEG;
		is_int = 1;
		tag    = am_sctp_maxseg;
		break;
	    }
	    case SCTP_OPT_NODELAY  :
	   {
		proto  = IPPROTO_SCTP;
		type   = SCTP_NODELAY;
		is_int = 0;
		tag    = am_sctp_nodelay;
		break;
	    }
	    case SCTP_OPT_DISABLE_FRAGMENTS:
	    {
		proto  = IPPROTO_SCTP;
		type   = SCTP_DISABLE_FRAGMENTS;
		is_int = 0;
		tag    = am_sctp_disable_fragments;
		break;
	    }
	    case SCTP_OPT_I_WANT_MAPPED_V4_ADDR:
	    {
		proto  = IPPROTO_SCTP;
		type   = SCTP_I_WANT_MAPPED_V4_ADDR;
		is_int = 0;
		tag    = am_sctp_i_want_mapped_v4_addr;
		break;
	    }
	    default:	 ASSERT(0);
	    }
	    if (sock_getopt (desc->s, proto, type, &res, &sz) < 0) continue;
	    /* Form the result: */
	    PLACE_FOR(spec, i, LOAD_ATOM_CNT + 
		      (is_int ? LOAD_INT_CNT : LOAD_BOOL_CNT) +
		      LOAD_TUPLE_CNT);
	    i = LOAD_ATOM	(spec, i, tag);
	    if (is_int)
	    	i = LOAD_INT	(spec, i, res);
	    else
	    	i = LOAD_BOOL	(spec, i, res);
	    i = LOAD_TUPLE	(spec, i, 2);
	    break;
	}
	case SCTP_OPT_PRIMARY_ADDR:
	case SCTP_OPT_SET_PEER_PRIMARY_ADDR:
	{
	    /* These 2 options use completely isomorphic data structures: */
	    struct       sctp_setpeerprim sp;
	    unsigned int sz = sizeof(sp);
	    
	    if (buflen < ASSOC_ID_LEN) RETURN_ERROR(spec, -EINVAL);
	    sp.sspp_assoc_id = GET_ASSOC_ID(buf);
	    buf    += ASSOC_ID_LEN;
	    buflen -= ASSOC_ID_LEN;
	    
	    if (sock_getopt(desc->s, IPPROTO_SCTP,
			    (eopt == SCTP_OPT_PRIMARY_ADDR) ?
			    SCTP_PRIMARY_ADDR : SCTP_SET_PEER_PRIMARY_ADDR,
			    &sp, &sz) < 0) continue;
	    /* Fill in the response: */
	    PLACE_FOR(spec, i, 
		      2*LOAD_ATOM_CNT + LOAD_ASSOC_ID_CNT + 
		      LOAD_IP_AND_PORT_CNT + 2*LOAD_TUPLE_CNT);
	    switch (eopt) {
	    case SCTP_OPT_PRIMARY_ADDR:
		i = LOAD_ATOM(spec, i, am_sctp_primary_addr);
		i = LOAD_ATOM(spec, i, am_sctp_prim);
		break;
	    case SCTP_OPT_SET_PEER_PRIMARY_ADDR:
		i = LOAD_ATOM(spec, i, am_sctp_set_peer_primary_addr);
		i = LOAD_ATOM(spec, i, am_sctp_setpeerprim);
		break;
	    default:
		ASSERT(0);
	    }
	    i = LOAD_ASSOC_ID	(spec, i, sp.sspp_assoc_id);
	    i = load_ip_and_port(spec, i, desc, &sp.sspp_addr);
	    i = LOAD_TUPLE	(spec, i, 3);
	    i = LOAD_TUPLE	(spec, i, 2);
	    break;
	}
	case SCTP_OPT_ADAPTION_LAYER:
	{
	    struct       sctp_setadaption ad;
	    unsigned int sz  = sizeof (ad);
	    
	    if (sock_getopt(desc->s, IPPROTO_SCTP, SCTP_ADAPTION_LAYER, 
			    &ad, &sz) < 0) continue;
	    /* Fill in the response: */
	    PLACE_FOR(spec, i, 
		      2*LOAD_ATOM_CNT + LOAD_INT_CNT + 2*LOAD_TUPLE_CNT);
	    i = LOAD_ATOM	(spec, i, am_sctp_adaption_layer);
	    i = LOAD_ATOM	(spec, i, am_sctp_setadaption);
	    i = LOAD_INT	(spec, i, ad.ssb_adaption_ind);
	    i = LOAD_TUPLE	(spec, i, 2);
	    i = LOAD_TUPLE	(spec, i, 2);
	    break;
	}
	case SCTP_OPT_PEER_ADDR_PARAMS:
	{
	    struct sctp_paddrparams  ap;
	    unsigned int             sz = sizeof(ap);
	    int                      n;
	    char                    *after;
	    int                      alen;
	    
	    if (buflen < ASSOC_ID_LEN) RETURN_ERROR(spec, -EINVAL);
	    ap.spp_assoc_id = GET_ASSOC_ID(buf);
	    buf += ASSOC_ID_LEN;
	    buflen -= ASSOC_ID_LEN;
	    alen = buflen;
	    after = inet_set_faddress(desc->sfamily,
				      (inet_address*) (&ap.spp_address),
				      buf, &alen);
	    if (after == NULL) RETURN_ERROR(spec, -EINVAL);
	    buflen -= after - buf;
	    buf     = after;
	    
	    if (sock_getopt(desc->s, IPPROTO_SCTP, SCTP_PEER_ADDR_PARAMS, 
			    &ap, &sz) < 0) continue;
	    /* Fill in the response: */
	    PLACE_FOR(spec, i, 
		      2*LOAD_ATOM_CNT + LOAD_ASSOC_ID_CNT + 
		      LOAD_IP_AND_PORT_CNT + 4*LOAD_INT_CNT);
	    i = LOAD_ATOM	(spec, i, am_sctp_peer_addr_params);
	    i = LOAD_ATOM	(spec, i, am_sctp_paddrparams);
	    i = LOAD_ASSOC_ID	(spec, i, ap.spp_assoc_id);
	    i = load_ip_and_port(spec, i, desc, &ap.spp_address);
	    i = LOAD_INT	(spec, i, ap.spp_hbinterval);
	    i = LOAD_INT	(spec, i, ap.spp_pathmaxrxt);
	    
	    /* The following fields are not suported in SOLARIS10,
	    ** so put 0s for "spp_pathmtu", "spp_sackdelay",
	    ** and empty list for "spp_flags":
	    */

#	    ifdef HAVE_SCTP_PADDRPARAMS_SPP_PATHMTU
	    i = LOAD_INT	(spec, i, ap.spp_pathmtu);
#           else
	    i = LOAD_INT	(spec, i, 0);
#           endif
	    
#	    ifdef HAVE_SCTP_PADDRPARAMS_SPP_SACKDELAY
	    i = LOAD_INT	(spec, i, ap.spp_sackdelay);
#           else
	    i = LOAD_INT	(spec, i, 0);
#           endif
	    
	    n = 0;
#	    ifdef HAVE_SCTP_PADDRPARAMS_SPP_FLAGS
	    PLACE_FOR(spec, i, 7*LOAD_ATOM_CNT);
	    /* Now Flags, as a list: */
	    if (ap.spp_flags & SPP_HB_ENABLE)
	    	{ i = LOAD_ATOM	(spec, i, am_hb_enable); 	     n++; }
	    
	    if (ap.spp_flags & SPP_HB_DISABLE)
		{ i = LOAD_ATOM (spec, i, am_hb_disable); 	     n++; }
	    
	    if (ap.spp_flags & SPP_HB_DEMAND)
		{ i = LOAD_ATOM (spec, i, am_hb_demand);	     n++; }
	    
	    if (ap.spp_flags & SPP_PMTUD_ENABLE)
		{ i = LOAD_ATOM (spec, i, am_pmtud_enable);          n++; }
	    
	    if (ap.spp_flags & SPP_PMTUD_DISABLE)
		{ i = LOAD_ATOM (spec, i, am_pmtud_disable);         n++; }
	    
	    if (ap.spp_flags & SPP_SACKDELAY_ENABLE)
		{ i = LOAD_ATOM (spec, i, am_sackdelay_enable);      n++; }
	    
	    if (ap.spp_flags & SPP_SACKDELAY_DISABLE)
		{ i = LOAD_ATOM (spec, i, am_sackdelay_disable);     n++; }
#	    endif
	    
	    PLACE_FOR(spec, i,
		      LOAD_NIL_CNT + LOAD_LIST_CNT + 2*LOAD_TUPLE_CNT);
	    
	    /* Close up the Flags list: */
	    i = LOAD_NIL	(spec, i);
	    i = LOAD_LIST	(spec, i, n+1);

	    /* Close up the record: */
	    i = LOAD_TUPLE	(spec, i, 8);
	    /* Close up the result tuple: */
	    i = LOAD_TUPLE	(spec, i, 2);
	    break;
	}
	case SCTP_OPT_DEFAULT_SEND_PARAM:
	{
	    struct       sctp_sndrcvinfo sri;
	    unsigned int sz  = sizeof(sri);
	    
	    if (sock_getopt(desc->s, IPPROTO_SCTP, SCTP_DEFAULT_SEND_PARAM,
			    &sri, &sz) < 0) continue;
	    /* Fill in the response: */
	    PLACE_FOR(spec, i, LOAD_ATOM_CNT +
		      SCTP_PARSE_SNDRCVINFO_CNT + LOAD_TUPLE_CNT);
	    i = LOAD_ATOM(spec, i, am_sctp_default_send_param);
	    i = sctp_parse_sndrcvinfo(spec, i, &sri);
	    i = LOAD_TUPLE(spec, i, 2);
	    break;
	}
	case SCTP_OPT_EVENTS:
	{
	    struct       sctp_event_subscribe evs;
	    unsigned int sz  = sizeof(evs);
	    
	    if (sock_getopt(desc->s, IPPROTO_SCTP, SCTP_EVENTS,
			    &evs, &sz) < 0) continue;
	    /* Fill in the response: */
	    PLACE_FOR(spec, i, 
		      2*LOAD_ATOM_CNT + 8*LOAD_BOOL_CNT + 2*LOAD_TUPLE_CNT);
	    i = LOAD_ATOM	(spec, i, am_sctp_events);
	    i = LOAD_ATOM	(spec, i, am_sctp_event_subscribe);
	    i = LOAD_BOOL	(spec, i, evs.sctp_data_io_event);
	    i = LOAD_BOOL	(spec, i, evs.sctp_association_event);
	    i = LOAD_BOOL	(spec, i, evs.sctp_address_event);
	    i = LOAD_BOOL	(spec, i, evs.sctp_send_failure_event);
	    i = LOAD_BOOL	(spec, i, evs.sctp_peer_error_event);
	    i = LOAD_BOOL	(spec, i, evs.sctp_shutdown_event);
	    i = LOAD_BOOL	(spec, i, evs.sctp_partial_delivery_event);
	    i = LOAD_BOOL	(spec, i, evs.sctp_adaption_layer_event);
	    /* NB: sctp_authentication_event is not yet supported in Linux */
	    i = LOAD_TUPLE	(spec, i, 9);
	    i = LOAD_TUPLE	(spec, i, 2);
	    break;
	}
	/* The following option is not available in Solaris 10: */
#	ifdef SCTP_DELAYED_ACK_TIME
	case SCTP_OPT_DELAYED_ACK_TIME:
	{
	    struct       sctp_assoc_value av;
	    unsigned int sz  = sizeof(av);
	    
	    if (buflen < ASSOC_ID_LEN) RETURN_ERROR(spec, -EINVAL);
	    av.assoc_id = GET_ASSOC_ID(buf);
	    buf    += ASSOC_ID_LEN;
	    buflen -= ASSOC_ID_LEN;
	    
	    if (sock_getopt(desc->s, IPPROTO_SCTP, SCTP_DELAYED_ACK_TIME,
			    &av, &sz) < 0) continue;
	    /* Fill in the response: */
	    PLACE_FOR(spec, i, 2*LOAD_ATOM_CNT + LOAD_ASSOC_ID_CNT +
		      LOAD_INT_CNT + 2*LOAD_TUPLE_CNT);
	    i = LOAD_ATOM	(spec, i, am_sctp_delayed_ack_time);
	    i = LOAD_ATOM	(spec, i, am_sctp_assoc_value);
	    i = LOAD_ASSOC_ID	(spec, i, av.assoc_id);
	    i = LOAD_INT	(spec, i, av.assoc_value);
	    i = LOAD_TUPLE	(spec, i, 3);
	    i = LOAD_TUPLE	(spec, i, 2);
	    break;
	}
#	endif
	case SCTP_OPT_STATUS:
	{
	    struct       sctp_status  st;
	    unsigned int sz  = sizeof(st);
	    
	    if (buflen < ASSOC_ID_LEN) RETURN_ERROR(spec, -EINVAL);
	    st.sstat_assoc_id = GET_ASSOC_ID(buf);
	    buf    += ASSOC_ID_LEN;
	    buflen -= ASSOC_ID_LEN;
	    
	    if (sock_getopt(desc->s, IPPROTO_SCTP, SCTP_STATUS,
			    &st, &sz) < 0) continue;
	    /* Fill in the response: */
	    PLACE_FOR(spec, i, 3*LOAD_ATOM_CNT + LOAD_ASSOC_ID_CNT +
		      6*LOAD_INT_CNT + LOAD_PADDRINFO_CNT +
		      2*LOAD_TUPLE_CNT);
	    i = LOAD_ATOM	(spec, i, am_sctp_status);
	    i = LOAD_ATOM	(spec, i, am_sctp_status);
	    i = LOAD_ASSOC_ID   (spec, i, st.sstat_assoc_id);
	    switch(st.sstat_state)
	    {
            /*  SCTP_EMPTY is not supported on SOLARIS10: */
#	    ifdef SCTP_EMPTY
	    case SCTP_EMPTY:
		i = LOAD_ATOM	(spec, i, am_empty);
		break;
#	    endif
	    case SCTP_CLOSED:
		i = LOAD_ATOM   (spec, i, am_closed);
		break;
	    /* The following states are not supported by Linux Kernel SCTP yet:
	    case SCTP_BOUND:
		i = LOAD_ATOM	(spec, i, am_bound);
		break;
	    case SCTP_LISTEN:
		i = LOAD_ATOM	(spec, i, am_listen);
		break;
	    */
	    case SCTP_COOKIE_WAIT:
		i = LOAD_ATOM	(spec, i, am_cookie_wait);
		break;
	    case SCTP_COOKIE_ECHOED:
		i = LOAD_ATOM	(spec, i, am_cookie_echoed);
		break;
	    case SCTP_ESTABLISHED:
		i = LOAD_ATOM	(spec, i, am_established);
		break;
	    case SCTP_SHUTDOWN_PENDING:
		i = LOAD_ATOM	(spec, i, am_shutdown_pending);
		break;
	    case SCTP_SHUTDOWN_SENT:
		i = LOAD_ATOM	(spec, i, am_shutdown_sent);
		break;
	    case SCTP_SHUTDOWN_RECEIVED:
		i = LOAD_ATOM	(spec, i, am_shutdown_received);
		break;
	    case SCTP_SHUTDOWN_ACK_SENT:
		i = LOAD_ATOM	(spec, i, am_shutdown_ack_sent);
		break;
	    default:
		i = LOAD_ATOM	(spec, i, am_undefined);
		break;
	    }
	    i = LOAD_INT	(spec, i, st.sstat_rwnd);
	    i = LOAD_INT	(spec, i, st.sstat_unackdata);
	    i = LOAD_INT	(spec, i, st.sstat_penddata);
	    i = LOAD_INT	(spec, i, st.sstat_instrms);
	    i = LOAD_INT	(spec, i, st.sstat_outstrms);
	    i = LOAD_INT	(spec, i, st.sstat_fragmentation_point);
	    i = load_paddrinfo	(spec, i, desc, &st.sstat_primary);
	    /* Close up the record: */
	    i = LOAD_TUPLE	(spec, i, 10);
	    /* Close up the result tuple: */
	    i = LOAD_TUPLE	(spec, i, 2);
	    break;
	}
	case SCTP_OPT_GET_PEER_ADDR_INFO:
	{
	    struct sctp_paddrinfo  pai;
	    unsigned int           sz = sizeof(pai);
	    char                  *after;
	    int                    alen;
	    
	    if (buflen < ASSOC_ID_LEN) RETURN_ERROR(spec, -EINVAL);
	    pai.spinfo_assoc_id = GET_ASSOC_ID(buf);
	    buf    += ASSOC_ID_LEN;
	    buflen -= ASSOC_ID_LEN;
	    alen = buflen;
	    after = inet_set_faddress(desc->sfamily,
				      (inet_address*) (&pai.spinfo_address),
				      buf, &alen);
	    if (after == NULL) RETURN_ERROR(spec, -EINVAL);
	    buflen -= after - buf;
	    buf     = after;
	    
	    if (sock_getopt(desc->s, IPPROTO_SCTP, SCTP_GET_PEER_ADDR_INFO,
			    &pai, &sz) < 0) continue;
	    /* Fill in the response: */
	    PLACE_FOR(spec, i, 
		      LOAD_ATOM_CNT + LOAD_PADDRINFO_CNT + LOAD_TUPLE_CNT);
	    i = LOAD_ATOM       (spec, i, am_sctp_get_peer_addr_info);
	    i = load_paddrinfo	(spec, i, desc, &pai);
	    i = LOAD_TUPLE	(spec, i, 2);
	    break;
	}
	default:
	    RETURN_ERROR(spec, -EINVAL); /* No more valid options */
	}
	/* If we get here one result has been succesfully loaded */
	length ++;
    }
    if (buflen != 0) RETURN_ERROR(spec, -EINVAL); /* Optparam mismatch */
    
    PLACE_FOR(spec, i, LOAD_NIL_CNT + LOAD_LIST_CNT + 2*LOAD_TUPLE_CNT);
    
    /* If we get here, we have "length" options: */
    i = LOAD_NIL  (spec, i);
    i = LOAD_LIST (spec, i, length+1);

    /* Close up the {ok, List} response: */
    i = LOAD_TUPLE(spec, i, 2);
    /* Close up the {inet_reply, S, {ok, List}} response:    */
    i = LOAD_TUPLE(spec, i, 3);

    /* Now, convert "spec" into the returnable term: */
    /* desc->caller = 0;	  What does it mean? */
    driver_output_term(desc->port, spec, i);
    FREE(spec);

    (*dest)[0] = INET_REP_SCTP;
    return 1;   /* Response length */
#   undef PLACE_FOR
#   undef RETURN_ERROR
}
#endif

/* fill statistics reply, op codes from src and result in dest
** dst area must be a least 5*len + 1 bytes
*/
static int inet_fill_stat(inet_descriptor* desc, char* src, int len, char* dst)
{
    unsigned long val;
    int op;
    char* dst_start = dst;

    *dst++ = INET_REP_OK;     /* put reply code */
    while (len--) {
	op = *src++;
	*dst++ = op;  /* copy op code */
	switch(op) {
	case INET_STAT_RECV_CNT:  
	    val = desc->recv_cnt;    
	    break;
	case INET_STAT_RECV_MAX:  
	    val = (unsigned long) desc->recv_max;    
	    break;
	case INET_STAT_RECV_AVG:  
	    val = (unsigned long) desc->recv_avg;    
	    break;
	case INET_STAT_RECV_DVI:  
	    val = (unsigned long) fabs(desc->recv_dvi); 
	    break;
	case INET_STAT_SEND_CNT:  
	    val = desc->send_cnt; 
	    break;
	case INET_STAT_SEND_MAX:  
	    val = desc->send_max; 
	    break;
	case INET_STAT_SEND_AVG: 
	    val = (unsigned long) desc->send_avg;
	    break;
	case INET_STAT_SEND_PND:  
	    val = driver_sizeq(desc->port); 
	    break;
	case INET_STAT_RECV_OCT:
	    put_int32(desc->recv_oct[1], dst);   /* write high 32bit */
	    put_int32(desc->recv_oct[0], dst+4); /* write low 32bit */
	    dst += 8;
	    continue;
	case INET_STAT_SEND_OCT:
	    put_int32(desc->send_oct[1], dst);   /* write high 32bit */
	    put_int32(desc->send_oct[0], dst+4); /* write low 32bit */
	    dst += 8;
	    continue;
	default: return -1; /* invalid argument */
	}
	put_int32(val, dst);  /* write 32bit value */
	dst += 4;
    }
    return dst - dst_start;  /* actual length */
}

static void
send_empty_out_q_msgs(inet_descriptor* desc)
{
  ErlDrvTermData msg[6];
  int msg_len = 0;

  if(NO_SUBSCRIBERS(&desc->empty_out_q_subs))
    return;

  msg_len = LOAD_ATOM(msg, msg_len, am_empty_out_q);
  msg_len = LOAD_PORT(msg, msg_len, desc->dport);
  msg_len = LOAD_TUPLE(msg, msg_len, 2);

  ASSERT(msg_len == sizeof(msg)/sizeof(*msg));

  send_to_subscribers(desc->port,
		      &desc->empty_out_q_subs,
		      1,
		      msg,
		      msg_len);
}

/* subscribe and fill subscription reply, op codes from src and
** result in dest dst area must be a least 5*len + 1 bytes
*/
static int inet_subscribe(inet_descriptor* desc, char* src, int len, char* dst)
{
    unsigned long val;
    int op;
    char* dst_start = dst;

    *dst++ = INET_REP_OK;     /* put reply code */
    while (len--) {
	op = *src++;
	*dst++ = op;  /* copy op code */
	switch(op) {
	case INET_SUBS_EMPTY_OUT_Q:  
	  val = driver_sizeq(desc->port);
	  if(val > 0)
	    if(!save_subscriber(&desc->empty_out_q_subs,
				driver_caller(desc->port)))
	      return 0;
	  break;
	default: return -1; /* invalid argument */
	}
	put_int32(val, dst);  /* write 32bit value */
	dst += 4;
    }
    return dst - dst_start;  /* actual length */
}

/* Terminate socket */
static void inet_stop(inet_descriptor* desc)
{
    erl_inet_close(desc);
    FREE(desc);
}


/* Allocate descriptor */
static ErlDrvData inet_start(ErlDrvPort port, int size, int protocol)
{
    inet_descriptor* desc;

    if ((desc = (inet_descriptor*) ALLOC(size)) == NULL)
	return NULL;

    desc->s = INVALID_SOCKET;
    desc->event = INVALID_EVENT;
    desc->event_mask = 0;
#ifdef __WIN32__
    desc->forced_events = 0;
#endif
    desc->port = port;
    desc->dport = driver_mk_port(port);
    desc->state = INET_STATE_CLOSED;
    desc->prebound = 0;
    desc->bufsz = INET_DEF_BUFFER; 
    desc->hsz = 0;                     /* list header size */
    desc->htype = TCP_PB_RAW;          /* default packet type */
    desc->psize = 0;                   /* no size check */
    desc->stype = -1;                  /* bad stype */
    desc->sfamily = -1;
    desc->sprotocol = protocol;
    desc->mode    = INET_MODE_LIST;    /* list mode */
    desc->exitf   = 1;                 /* exit port when close on active 
					  socket */
    desc->bit8f   = 0;
    desc->bit8    = 0;
    desc->deliver = INET_DELIVER_TERM; /* standard term format */
    desc->active  = INET_PASSIVE;      /* start passive */
    desc->oph = NULL;
    desc->opt = NULL;

    desc->peer_ptr = NULL;
    desc->name_ptr = NULL;

    desc->recv_oct[0] = desc->recv_oct[1] = 0;
    desc->recv_cnt = 0;
    desc->recv_max = 0;    
    desc->recv_avg = 0.0;
    desc->recv_dvi = 0.0;
    desc->send_oct[0] = desc->send_oct[1] = 0;
    desc->send_cnt = 0;
    desc->send_max = 0;
    desc->send_avg = 0.0;
    desc->empty_out_q_subs.subscriber = NO_PROCESS;
    desc->empty_out_q_subs.next = NULL;

    sys_memzero((char *)&desc->remote,sizeof(desc->remote));

    return (ErlDrvData)desc;
}


#ifndef MAXHOSTNAMELEN
#define MAXHOSTNAMELEN 256
#endif

/*
** common TCP/UDP/SCTP control command
*/
static int inet_ctl(inet_descriptor* desc, int cmd, char* buf, int len,
		    char** rbuf, int rsize)
{
    switch (cmd) {

    case INET_REQ_GETSTAT: {
	  char* dst;
	  int i;
	  int dstlen = 1;  /* Reply code */

	  for (i = 0; i < len; i++) {
	      switch(buf[i]) {
	      case INET_STAT_SEND_OCT: dstlen += 9; break;
	      case INET_STAT_RECV_OCT: dstlen += 9; break;
	      default: dstlen += 5; break;
	      }
	  }
	  DEBUGF(("inet_ctl(%ld): GETSTAT\r\n", (long) desc->port)); 
	  if (dstlen > INET_MAX_BUFFER) /* sanity check */
	      return 0;
	  if (dstlen > rsize) {
	      if ((dst = (char*) ALLOC(dstlen)) == NULL)
		  return 0;
	      *rbuf = dst;  /* call will free this buffer */
	  }
	  else
	      dst = *rbuf;  /* ok we fit in buffer given */
	  return inet_fill_stat(desc, buf, len, dst);
      }

    case INET_REQ_SUBSCRIBE: {
	  char* dst;
	  int dstlen = 1 /* Reply code */ + len*5;
	  DEBUGF(("inet_ctl(%ld): INET_REQ_SUBSCRIBE\r\n", (long) desc->port)); 
	  if (dstlen > INET_MAX_BUFFER) /* sanity check */
	      return 0;
	  if (dstlen > rsize) {
	      if ((dst = (char*) ALLOC(dstlen)) == NULL)
		  return 0;
	      *rbuf = dst;  /* call will free this buffer */
	  }
	  else
	      dst = *rbuf;  /* ok we fit in buffer given */
	  return inet_subscribe(desc, buf, len, dst);
      }

    case INET_REQ_GETOPTS: {    /* get options */
	int replen;
	DEBUGF(("inet_ctl(%ld): GETOPTS\r\n", (long)desc->port)); 
#ifdef HAVE_SCTP
        if (IS_SCTP(desc))
        {
            if ((replen = sctp_fill_opts(desc, buf, len, rbuf, rsize)) < 0)
                return ctl_error(-replen, rbuf, rsize);
        } else
#endif
	if ((replen = inet_fill_opts(desc, buf, len, rbuf, rsize)) < 0) {
	    return ctl_error(EINVAL, rbuf, rsize);
	}
	return replen;
    }

    case INET_REQ_GETIFLIST: {
	DEBUGF(("inet_ctl(%ld): GETIFLIST\r\n", (long)desc->port)); 
	if (!IS_OPEN(desc))
	    return ctl_xerror(EXBADPORT, rbuf, rsize);
	return inet_ctl_getiflist(desc, rbuf, rsize);
    }

    case INET_REQ_IFGET: {
	DEBUGF(("inet_ctl(%ld): IFGET\r\n", (long)desc->port)); 	
	if (!IS_OPEN(desc))
	    return ctl_xerror(EXBADPORT, rbuf, rsize);
	return inet_ctl_ifget(desc, buf, len, rbuf, rsize);
    }

    case INET_REQ_IFSET: {
	DEBUGF(("inet_ctl(%ld): IFSET\r\n", (long)desc->port));
	if (!IS_OPEN(desc))
	    return ctl_xerror(EXBADPORT, rbuf, rsize);
	return inet_ctl_ifset(desc, buf, len, rbuf, rsize);
    }

    case INET_REQ_SETOPTS:  {   /* set options */
	DEBUGF(("inet_ctl(%ld): SETOPTS\r\n", (long)desc->port)); 
	switch(inet_set_opts(desc, buf, len)) {
	case -1: 
	    return ctl_error(EINVAL, rbuf, rsize);
	case 0: 
	    return ctl_reply(INET_REP_OK, NULL, 0, rbuf, rsize);
	default:  /* active/passive change!! */
	    /*
	     * Let's hope that the descriptor really is a tcp_descriptor here.
	     */
	    tcp_deliver((tcp_descriptor *) desc, 0);
	    return ctl_reply(INET_REP_OK, NULL, 0, rbuf, rsize);
	}
    }

    case INET_REQ_GETSTATUS: {
	char tbuf[4];

	DEBUGF(("inet_ctl(%ld): GETSTATUS\r\n", (long)desc->port)); 
	put_int32(desc->state, tbuf);
	return ctl_reply(INET_REP_OK, tbuf, 4, rbuf, rsize);
    }

    case INET_REQ_GETTYPE: {
	char tbuf[8];

	DEBUGF(("inet_ctl(%ld): GETTYPE\r\n", (long)desc->port)); 
	if (desc->sfamily == AF_INET) {
	    put_int32(INET_AF_INET, &tbuf[0]);
	}
#if defined(HAVE_IN6) && defined(AF_INET6)
        else if (desc->sfamily == AF_INET6) {
	    put_int32(INET_AF_INET6, &tbuf[0]);
	}
#endif
	else
	    return ctl_error(EINVAL, rbuf, rsize);

	if (desc->stype == SOCK_STREAM) {
	    put_int32(INET_TYPE_STREAM, &tbuf[4]);
	}
	else if (desc->stype == SOCK_DGRAM) {
	    put_int32(INET_TYPE_DGRAM, &tbuf[4]);
	}
#ifdef HAVE_SCTP
	else if (desc->stype == SOCK_SEQPACKET) {
	    put_int32(INET_TYPE_SEQPACKET, &tbuf[4]);
	}
#endif	   
	else
	    return ctl_error(EINVAL, rbuf, rsize);
	return ctl_reply(INET_REP_OK, tbuf, 8, rbuf, rsize);
    }


    case INET_REQ_GETFD: {
	char tbuf[4];

	DEBUGF(("inet_ctl(%ld): GETFD\r\n", (long)desc->port)); 
	if (!IS_OPEN(desc))
	    return ctl_error(EINVAL, rbuf, rsize);
	put_int32((long)desc->s, tbuf);
	return ctl_reply(INET_REP_OK, tbuf, 4, rbuf, rsize);
    }
	
    case INET_REQ_GETHOSTNAME: { /* get host name */
	char tbuf[MAXHOSTNAMELEN];

	DEBUGF(("inet_ctl(%ld): GETHOSTNAME\r\n", (long)desc->port)); 
	if (len != 0)
	    return ctl_error(EINVAL, rbuf, rsize);

	if (sock_hostname(tbuf, MAXHOSTNAMELEN) == SOCKET_ERROR)
	    return ctl_error(sock_errno(), rbuf, rsize);
	return ctl_reply(INET_REP_OK, tbuf, strlen(tbuf), rbuf, rsize);
    }

    case INET_REQ_PEER:  {      /* get peername */
	char tbuf[sizeof(inet_address)];
	inet_address peer;
	inet_address* ptr;
	unsigned int sz = sizeof(peer);

	DEBUGF(("inet_ctl(%ld): PEER\r\n", (long)desc->port)); 

	if (!(desc->state & INET_F_ACTIVE))
	    return ctl_error(ENOTCONN, rbuf, rsize);
	if ((ptr = desc->peer_ptr) == NULL) {
	    ptr = &peer;
	    if (sock_peer(desc->s, (struct sockaddr*)ptr,&sz) == SOCKET_ERROR)
		return ctl_error(sock_errno(), rbuf, rsize);
	}
	if (inet_get_address(desc->sfamily, tbuf, ptr, &sz) < 0)
	    return ctl_error(EINVAL, rbuf, rsize);
	return ctl_reply(INET_REP_OK, tbuf, sz, rbuf, rsize);
    }

    case INET_REQ_SETPEER: { /* set fake peername Port Address */
	if (len == 0) {
	    desc->peer_ptr = NULL;
	    return ctl_reply(INET_REP_OK, NULL, 0, rbuf, rsize);
	}
	else if (len < 2)
	    return ctl_error(EINVAL, rbuf, rsize);	    
	else if (inet_set_address(desc->sfamily, &desc->peer_addr,
				  buf, &len) == NULL)
	    return ctl_error(EINVAL, rbuf, rsize);
	else {
	    desc->peer_ptr = &desc->peer_addr;
	    return ctl_reply(INET_REP_OK, NULL, 0, rbuf, rsize);	    
	}
    }

    case INET_REQ_NAME:  {      /* get sockname */
	char tbuf[sizeof(inet_address)];
	inet_address name;
	inet_address* ptr;
	unsigned int sz = sizeof(name);

	DEBUGF(("inet_ctl(%ld): NAME\r\n", (long)desc->port)); 

	if (!IS_BOUND(desc))
	    return ctl_error(EINVAL, rbuf, rsize); /* address is not valid */

	if ((ptr = desc->name_ptr) == NULL) {
	    ptr = &name;
	    if (sock_name(desc->s, (struct sockaddr*)ptr, &sz) == SOCKET_ERROR)
		return ctl_error(sock_errno(), rbuf, rsize);
	}
	if (inet_get_address(desc->sfamily, tbuf, ptr, &sz) < 0)
	    return ctl_error(EINVAL, rbuf, rsize);
	return ctl_reply(INET_REP_OK, tbuf, sz, rbuf, rsize);
    }

    case INET_REQ_SETNAME: { /* set fake peername Port Address */
	if (len == 0) {
	    desc->name_ptr = NULL;
	    return ctl_reply(INET_REP_OK, NULL, 0, rbuf, rsize);
	}
	else if (len < 2)
	    return ctl_error(EINVAL, rbuf, rsize);	    
	else if (inet_set_address(desc->sfamily, &desc->name_addr,
				  buf, &len) == NULL)
	    return ctl_error(EINVAL, rbuf, rsize);
	else {
	    desc->name_ptr = &desc->name_addr;
	    return ctl_reply(INET_REP_OK, NULL, 0, rbuf, rsize);	    
	}
    }

    case INET_REQ_BIND:  {      /* bind socket */
	char tbuf[2];
	inet_address local;
	short port;

	DEBUGF(("inet_ctl(%ld): BIND\r\n", (long)desc->port)); 

	if (len < 2)
	    return ctl_error(EINVAL, rbuf, rsize);
	if (desc->state != INET_STATE_OPEN)
	    return ctl_xerror(EXBADPORT, rbuf, rsize);

	if (inet_set_address(desc->sfamily, &local, buf, &len) == NULL)
	    return ctl_error(EINVAL, rbuf, rsize);

	if (sock_bind(desc->s,(struct sockaddr*) &local, len) == SOCKET_ERROR)
	    return ctl_error(sock_errno(), rbuf, rsize);

	desc->state = INET_STATE_BOUND;

	if ((port = inet_address_port(&local)) == 0) {
	    len = sizeof(local);
	    sock_name(desc->s, (struct sockaddr*) &local, (unsigned int*)&len);
	    port = inet_address_port(&local);
	}
	port = sock_ntohs(port);
	put_int16(port, tbuf);
	return ctl_reply(INET_REP_OK, tbuf, 2, rbuf, rsize);
    }

#ifndef VXWORKS

    case INET_REQ_GETSERVBYNAME: { /* L1 Name-String L2 Proto-String */
	char namebuf[256];
	char protobuf[256];
	char tbuf[2];
	struct servent* srv;
	short port;
	int n;

	if (len < 2)
	    return ctl_error(EINVAL, rbuf, rsize);
	n = buf[0]; buf++; len--;
	if (n >= len) /* the = sign makes the test inklude next length byte */
	    return ctl_error(EINVAL, rbuf, rsize);
	memcpy(namebuf, buf, n);
	namebuf[n] = '\0';
	len -= n; buf += n;
	n = buf[0]; buf++; len--;
	if (n > len)
	    return ctl_error(EINVAL, rbuf, rsize);
	memcpy(protobuf, buf, n);
	protobuf[n] = '\0';
	if ((srv = sock_getservbyname(namebuf, protobuf)) == NULL)
	    return ctl_error(EINVAL, rbuf, rsize);
	port = sock_ntohs(srv->s_port);
	put_int16(port, tbuf);
	return ctl_reply(INET_REP_OK, tbuf, 2, rbuf, rsize);
    }

    case INET_REQ_GETSERVBYPORT: { /* P1 P0 L1 Proto-String */
	char protobuf[256];
	unsigned short port;
	int n;
	struct servent* srv;

	if (len < 3)
	    return ctl_error(EINVAL, rbuf, rsize);
	port = get_int16(buf);
	port = sock_htons(port);
	buf += 2;
	n = buf[0]; buf++; len -= 3;
	if (n > len)
	    return ctl_error(EINVAL, rbuf, rsize);
	memcpy(protobuf, buf, n);
	protobuf[n] = '\0';
	if ((srv = sock_getservbyport(port, protobuf)) == NULL)
	    return ctl_error(EINVAL, rbuf, rsize);
	len = strlen(srv->s_name);
	return ctl_reply(INET_REP_OK, srv->s_name, len, rbuf, rsize);
    }
	
#endif /* !VXWORKS */	

    default:
	return ctl_xerror(EXBADPORT, rbuf, rsize);
    }
}

/* update statistics on output packets */
static void inet_output_count(inet_descriptor* desc, int len)
{
    unsigned long n = desc->send_cnt + 1;
    unsigned long t = desc->send_oct[0] + len;
    int c = (t < desc->send_oct[0]);
    double avg = desc->send_avg;

    /* at least 64 bit octet count */
    desc->send_oct[0] = t;
    desc->send_oct[1] += c;

    if (n == 0) /* WRAP, use old avg as input to a new sequence */
	n = 1;
    desc->send_avg += (len - avg) / n;
    if (len > desc->send_max)
	desc->send_max = len;
    desc->send_cnt = n;
}

/* update statistics on input packets */
static void inet_input_count(inet_descriptor* desc, int len)
{
    unsigned long n = desc->recv_cnt + 1;
    unsigned long t = desc->recv_oct[0] + len;
    int c = (t < desc->recv_oct[0]);
    double avg = desc->recv_avg;
    double dvi;

    /* at least 64 bit octet count */
    desc->recv_oct[0] = t;
    desc->recv_oct[1] += c;

    if (n == 0) /* WRAP */
	n = 1;

    /* average packet length */
    avg = avg + (len - avg) / n;
    desc->recv_avg = avg;

    if (len > desc->recv_max)
	desc->recv_max = len;

    /* average deviation from average packet length */
    dvi = desc->recv_dvi;
    desc->recv_dvi = dvi + ((len - avg) - dvi) / n;
    desc->recv_cnt = n;
}

/*----------------------------------------------------------------------------

   TCP

-----------------------------------------------------------------------------*/

/*
** Set new size on buffer, used when packet size is determined
** and the buffer is to small.
** buffer must have a size of at least len bytes (counting from ptr_start!)
*/
static int tcp_expand_buffer(tcp_descriptor* desc, int len)
{
    ErlDrvBinary* bin;
    int offs1;
    int offs2;
    int used = desc->i_ptr_start - desc->i_buf->orig_bytes;
    int ulen = used + len;

    if (desc->i_bufsz >= ulen) /* packet will fit */
	return 0;
    else if (desc->i_buf->orig_size >= ulen) { /* buffer is large enough */
	desc->i_bufsz = ulen;  /* set "virtual" size */
	return 0;
    }

    DEBUGF(("tcp_expand_buffer(%ld): s=%d, from %ld to %d\r\n",
	    (long)desc->inet.port, desc->inet.s, desc->i_buf->orig_size, ulen));

    offs1 = desc->i_ptr_start - desc->i_buf->orig_bytes;
    offs2 = desc->i_ptr - desc->i_ptr_start;

    if ((bin = driver_realloc_binary(desc->i_buf, ulen)) == NULL)
	return -1;

    desc->i_buf = bin;
    desc->i_ptr_start = bin->orig_bytes + offs1;
    desc->i_ptr       = desc->i_ptr_start + offs2;
    desc->i_bufsz     = ulen;
    return 0;
}

/* push data into i_buf  */
static int tcp_push_buffer(tcp_descriptor* desc, char* buf, int len)
{
    ErlDrvBinary* bin;

    if (desc->i_buf == NULL) {
	bin = alloc_buffer(len);
	sys_memcpy(bin->orig_bytes, buf, len);
	desc->i_buf = bin;
	desc->i_bufsz = len;
	desc->i_ptr_start = desc->i_buf->orig_bytes;
	desc->i_ptr = desc->i_ptr_start + len;
    }
    else {
	char* start =  desc->i_buf->orig_bytes;
	int sz_before = desc->i_ptr_start - start;
	int sz_filled = desc->i_ptr - desc->i_ptr_start;
	
	if (len <= sz_before) {
	    sys_memcpy(desc->i_ptr_start - len, buf, len);
	    desc->i_ptr_start -= len;
	}
	else {
	    bin = alloc_buffer(desc->i_bufsz+len);
	    sys_memcpy(bin->orig_bytes, buf, len);
	    sys_memcpy(bin->orig_bytes+len, desc->i_ptr_start, sz_filled);
	    free_buffer(desc->i_buf);
	    desc->i_bufsz += len;
	    desc->i_buf = bin;
	    desc->i_ptr_start = bin->orig_bytes;
	    desc->i_ptr = desc->i_ptr_start + sz_filled + len;
	}
    }
    desc->i_remain = 0;	
    return 0;
}

/* clear CURRENT input buffer */
static void tcp_clear_input(tcp_descriptor* desc)
{
    if (desc->i_buf != NULL)
	free_buffer(desc->i_buf);
    desc->i_buf = NULL;
    desc->i_remain    = 0;
    desc->i_ptr       = NULL;
    desc->i_ptr_start = NULL;
    desc->i_bufsz     = 0;
}

/* clear QUEUED output */
static void tcp_clear_output(tcp_descriptor* desc)
{
    ErlDrvPort ix  = desc->inet.port;
    int qsz = driver_sizeq(ix);

    driver_deq(ix, qsz);
    send_empty_out_q_msgs(INETP(desc));
}


/* Move data so that ptr_start point at buf->orig_bytes */
static void tcp_restart_input(tcp_descriptor* desc)
{
    if (desc->i_ptr_start != desc->i_buf->orig_bytes) {
	int n = desc->i_ptr - desc->i_ptr_start;

	DEBUGF(("tcp_restart_input: move %d bytes\r\n", n));
	sys_memmove(desc->i_buf->orig_bytes, desc->i_ptr_start, n);
	desc->i_ptr_start = desc->i_buf->orig_bytes;
	desc->i_ptr = desc->i_ptr_start + n;
    }
}


static int tcp_inet_init(void)
{
    DEBUGF(("tcp_inet_init() {}\r\n"));
    return 0;
}

/* initialize the TCP descriptor */

static ErlDrvData tcp_inet_start(ErlDrvPort port, char* args)
{
    tcp_descriptor* desc;
    DEBUGF(("tcp_inet_start(%ld) {\r\n", (long)port));

    desc = (tcp_descriptor*)
	inet_start(port, sizeof(tcp_descriptor), IPPROTO_TCP);
    if (desc == NULL)
	return ERL_DRV_ERROR_ERRNO;
    desc->high = INET_HIGH_WATERMARK;
    desc->low  = INET_LOW_WATERMARK;
    desc->send_timeout = INET_INFINITY;
    desc->busy_on_send = 0;
    desc->i_buf = NULL;
    desc->i_ptr = NULL;
    desc->i_ptr_start = NULL;
    desc->i_remain = 0;
    desc->i_bufsz = 0;
    desc->tcp_add_flags = 0;
#ifdef USE_HTTP
    desc->http_state = 0;
#endif
    desc->mtd = NULL;
    desc->multi_first = desc->multi_last = NULL;
    DEBUGF(("tcp_inet_start(%ld) }\r\n", (long)port));
    return (ErlDrvData) desc;
}

/* Copy a descriptor, by creating a new port with same settings
 * as the descriptor desc.
 * return NULL on error (ENFILE no ports avail)
 */
static tcp_descriptor* tcp_inet_copy(tcp_descriptor* desc,SOCKET s,
				     ErlDrvTermData owner, int* err)
{
    ErlDrvPort port = desc->inet.port;
    tcp_descriptor* copy_desc;

    copy_desc = (tcp_descriptor*) tcp_inet_start(port, NULL);

    /* Setup event if needed */
    if ((copy_desc->inet.s = s) != INVALID_SOCKET) {
	if ((copy_desc->inet.event = sock_create_event(INETP(copy_desc))) ==
	    INVALID_EVENT) {
	    *err = sock_errno();
	    FREE(copy_desc);
	    return NULL;
	}
    }

    /* Some flags must be inherited at this point */
    copy_desc->inet.mode     = desc->inet.mode;
    copy_desc->inet.exitf    = desc->inet.exitf;
    copy_desc->inet.bit8f    = desc->inet.bit8f;
    copy_desc->inet.deliver  = desc->inet.deliver;
    copy_desc->inet.htype    = desc->inet.htype; 
    copy_desc->inet.psize    = desc->inet.psize; 
    copy_desc->inet.stype    = desc->inet.stype;
    copy_desc->inet.sfamily  = desc->inet.sfamily;
    copy_desc->inet.hsz      = desc->inet.hsz;
    copy_desc->inet.bufsz    = desc->inet.bufsz;
    copy_desc->high          = desc->high;
    copy_desc->low           = desc->low;
    copy_desc->send_timeout  = desc->send_timeout;
    
    /* The new port will be linked and connected to the original caller */
    port = driver_create_port(port, owner, "tcp_inet", (ErlDrvData) copy_desc);
    if ((long)port == -1) {
	*err = ENFILE;
	FREE(copy_desc);
	return NULL;
    }
    copy_desc->inet.port = port;
    copy_desc->inet.dport = driver_mk_port(port);
    *err = 0;
    return copy_desc;
}

/*
** Check Special cases:
** 1. we are a listener doing nb accept -> report error on accept !
** 2. we are doing accept -> restore listener state
*/
static void tcp_close_check(tcp_descriptor* desc)
{
    /* XXX:PaN - multiple clients to handle! */
    if (desc->inet.state == TCP_STATE_ACCEPTING) {
	inet_async_op *this_op = desc->inet.opt;
	sock_select(INETP(desc), FD_ACCEPT, 0);
	desc->inet.state = TCP_STATE_LISTEN;
	if (this_op != NULL) {
	    driver_demonitor_process(desc->inet.port, &(this_op->monitor));
	}
	async_error_am(INETP(desc), am_closed);
    } 
    else if (desc->inet.state == TCP_STATE_MULTI_ACCEPTING) {
	int id,req;
	ErlDrvTermData caller;
	ErlDrvMonitor monitor;

	sock_select(INETP(desc), FD_ACCEPT, 0);
	desc->inet.state = TCP_STATE_LISTEN;
	while (deq_multi_op(desc,&id,&req,&caller,NULL,&monitor) == 0) {
	    driver_demonitor_process(desc->inet.port, &monitor);
	    send_async_error(desc->inet.port, desc->inet.dport, id, caller, am_closed);
	}
	clean_multi_timers(&(desc->mtd), desc->inet.port);
    }

    else if (desc->inet.state == TCP_STATE_CONNECTING) {
	async_error_am(INETP(desc), am_closed);
    }
    else if (desc->inet.state == TCP_STATE_CONNECTED) {
	async_error_am_all(INETP(desc), am_closed);
    }
}

/*
** Cleanup & Free
*/
static void tcp_inet_stop(ErlDrvData e)
{
    tcp_descriptor* desc = (tcp_descriptor*)e;
    DEBUGF(("tcp_inet_stop(%ld) {s=%d\r\n", 
	    (long)desc->inet.port, desc->inet.s));
    tcp_close_check(desc);
    /* free input buffer & output buffer */
    if (desc->i_buf != NULL)
	release_buffer(desc->i_buf);
    desc->i_buf = NULL; /* net_mess2 may call this function recursively when 
			   faulty messages arrive on dist ports*/
    DEBUGF(("tcp_inet_stop(%ld) }\r\n", (long)desc->inet.port));
    inet_stop(INETP(desc));
}


    

/* TCP requests from Erlang */
static int tcp_inet_ctl(ErlDrvData e, unsigned int cmd, char* buf, int len,
			char** rbuf, int rsize)
{
    tcp_descriptor* desc = (tcp_descriptor*)e;
    switch(cmd) {
    case INET_REQ_OPEN:   /* open socket and return internal index */
	DEBUGF(("tcp_inet_ctl(%ld): OPEN\r\n", (long)desc->inet.port));
	if ((len == 1) && (buf[0] == INET_AF_INET))
	    return
		inet_ctl_open(INETP(desc), AF_INET, SOCK_STREAM, rbuf, rsize);
#if defined(HAVE_IN6) && defined(AF_INET6)
        else if ((len == 1) && (buf[0] == INET_AF_INET6))
	    return
		inet_ctl_open(INETP(desc), AF_INET6, SOCK_STREAM, rbuf, rsize);
#endif
	else
	    return ctl_error(EINVAL, rbuf, rsize);

    case INET_REQ_FDOPEN:   /* pass in an open socket */
	DEBUGF(("tcp_inet_ctl(%ld): FDOPEN\r\n", (long)desc->inet.port)); 
	if ((len == 5) && (buf[0] == INET_AF_INET))
	    return inet_ctl_fdopen(INETP(desc), AF_INET, SOCK_STREAM,
				   (SOCKET) get_int32(buf+1), rbuf, rsize);
#if defined(HAVE_IN6) && defined(AF_INET6)
        else if ((len == 5) && (buf[0] == INET_AF_INET6))
	    return inet_ctl_fdopen(INETP(desc), AF_INET6, SOCK_STREAM,
				   (SOCKET) get_int32(buf+1), rbuf, rsize);
#endif
	else
	    return ctl_error(EINVAL, rbuf, rsize);

    case TCP_REQ_LISTEN: { /* argument backlog */

	int backlog;
	DEBUGF(("tcp_inet_ctl(%ld): LISTEN\r\n", (long)desc->inet.port)); 
	if (desc->inet.state == TCP_STATE_CLOSED)
	    return ctl_xerror(EXBADPORT, rbuf, rsize);
	if (!IS_OPEN(INETP(desc)))
	    return ctl_xerror(EXBADPORT, rbuf, rsize);
	if (!IS_BOUND(INETP(desc)))
	    return ctl_xerror(EXBADSEQ, rbuf, rsize);
	if (len != 2)
	    return ctl_error(EINVAL, rbuf, rsize);
	backlog = get_int16(buf);
	if (sock_listen(desc->inet.s, backlog) == SOCKET_ERROR)
	    return ctl_error(sock_errno(), rbuf, rsize);
	desc->inet.state = TCP_STATE_LISTEN;
	return ctl_reply(INET_REP_OK, NULL, 0, rbuf, rsize);
    }


    case INET_REQ_CONNECT: {   /* do async connect */
	int code;
	char tbuf[2];
	unsigned timeout;

	DEBUGF(("tcp_inet_ctl(%ld): CONNECT\r\n", (long)desc->inet.port)); 
	/* INPUT: Timeout(4), Port(2), Address(N) */

	if (!IS_OPEN(INETP(desc)))
	    return ctl_xerror(EXBADPORT, rbuf, rsize);
	if (IS_CONNECTED(INETP(desc)))
	    return ctl_error(EISCONN, rbuf, rsize);
	if (!IS_BOUND(INETP(desc)))
	    return ctl_xerror(EXBADSEQ, rbuf, rsize);
	if (IS_CONNECTING(INETP(desc)))
	    return ctl_error(EINVAL, rbuf, rsize);
	if (len < 6)
	    return ctl_error(EINVAL, rbuf, rsize);
	timeout = get_int32(buf);
	buf += 4;
	len -= 4;
	if (inet_set_address(desc->inet.sfamily, &desc->inet.remote,
			     buf, &len) == NULL)
	    return ctl_error(EINVAL, rbuf, rsize);
	
	sock_select(INETP(desc), FD_CONNECT, 1);
	code = sock_connect(desc->inet.s, 
			    (struct sockaddr*) &desc->inet.remote, len);
	if ((code == SOCKET_ERROR) && 
		((sock_errno() == ERRNO_BLOCK) ||  /* Winsock2 */
		 (sock_errno() == EINPROGRESS))) {	/* Unix & OSE!! */
	    desc->inet.state = TCP_STATE_CONNECTING;
	    if (timeout != INET_INFINITY)
		driver_set_timer(desc->inet.port, timeout);
	    enq_async(INETP(desc), tbuf, INET_REQ_CONNECT);
	}
	else if (code == 0) { /* ok we are connected */
	    sock_select(INETP(desc), FD_CONNECT, 0);
	    desc->inet.state = TCP_STATE_CONNECTED;
	    if (desc->inet.active)
		sock_select(INETP(desc), (FD_READ|FD_CLOSE), 1);
	    enq_async(INETP(desc), tbuf, INET_REQ_CONNECT);
	    async_ok(INETP(desc));
	}
	else {
	    sock_select(INETP(desc), FD_CONNECT, 0);
	    return ctl_error(sock_errno(), rbuf, rsize);
	}
	return ctl_reply(INET_REP_OK, tbuf, 2, rbuf, rsize);
    }

    case TCP_REQ_ACCEPT: {  /* do async accept */
	char tbuf[2];
	unsigned timeout;
	inet_address remote;
	unsigned int n;
	SOCKET s;

	DEBUGF(("tcp_inet_ctl(%ld): ACCEPT\r\n", (long)desc->inet.port)); 
	/* INPUT: Timeout(4) */

	/* FIXME implement ACCEPT queue ! */
	if ((desc->inet.state != TCP_STATE_LISTEN && desc->inet.state != TCP_STATE_ACCEPTING &&
	     desc->inet.state != TCP_STATE_MULTI_ACCEPTING) || len != 4) {
	    return ctl_error(EINVAL, rbuf, rsize);
	}

	timeout = get_int32(buf);

	if (desc->inet.state == TCP_STATE_ACCEPTING) {
	    unsigned long time_left;
	    int oid;
	    ErlDrvTermData ocaller;
	    int oreq;
	    unsigned otimeout;
	    ErlDrvTermData caller = driver_caller(desc->inet.port);
	    MultiTimerData *mtd = NULL,*omtd = NULL;
	    ErlDrvMonitor monitor, omonitor;


	    if (driver_monitor_process(desc->inet.port, caller ,&monitor) != 0) { 
		return ctl_xerror("noproc", rbuf, rsize);
	    }
	    deq_async_w_tmo(INETP(desc),&oid,&ocaller,&oreq,&otimeout,&omonitor);
	    if (otimeout != INET_INFINITY) {
		driver_read_timer(desc->inet.port, &time_left);
		driver_cancel_timer(desc->inet.port);
		if (time_left <= 0) {
		    time_left = 1;
		}
		omtd = add_multi_timer(&(desc->mtd), desc->inet.port, ocaller, 
				       time_left, &tcp_inet_multi_timeout);
	    }
	    enq_old_multi_op(desc, oid, oreq, ocaller, omtd, &omonitor);
	    if (timeout != INET_INFINITY) {
		mtd = add_multi_timer(&(desc->mtd), desc->inet.port, caller, 
				      timeout, &tcp_inet_multi_timeout);
	    }
	    enq_multi_op(desc, tbuf, TCP_REQ_ACCEPT, caller, mtd, &monitor);
	    desc->inet.state = TCP_STATE_MULTI_ACCEPTING;
	    return ctl_reply(INET_REP_OK, tbuf, 2, rbuf, rsize);
	} else if (desc->inet.state == TCP_STATE_MULTI_ACCEPTING) {
	    ErlDrvTermData caller = driver_caller(desc->inet.port);
	    MultiTimerData *mtd = NULL;
	    ErlDrvMonitor monitor;

	    if (driver_monitor_process(desc->inet.port, caller ,&monitor) != 0) { 
		return ctl_xerror("noproc", rbuf, rsize);
	    }
	    if (timeout != INET_INFINITY) {
		mtd = add_multi_timer(&(desc->mtd), desc->inet.port, caller, 
				      timeout, &tcp_inet_multi_timeout);
	    }
	    enq_multi_op(desc, tbuf, TCP_REQ_ACCEPT, caller, mtd, &monitor);
	    return ctl_reply(INET_REP_OK, tbuf, 2, rbuf, rsize);
 	} else {
	    n = sizeof(desc->inet.remote);
	    s = sock_accept(desc->inet.s, (struct sockaddr*) &remote, &n);
	    if (s == INVALID_SOCKET) {
		if (sock_errno() == ERRNO_BLOCK) {
		    ErlDrvMonitor monitor;
		    if (driver_monitor_process(desc->inet.port, driver_caller(desc->inet.port),
					       &monitor) != 0) { 
			return ctl_xerror("noproc", rbuf, rsize);
		    }
		    enq_async_w_tmo(INETP(desc), tbuf, TCP_REQ_ACCEPT, timeout, &monitor);
		    desc->inet.state = TCP_STATE_ACCEPTING;
		    sock_select(INETP(desc),FD_ACCEPT,1);
		    if (timeout != INET_INFINITY) {
			driver_set_timer(desc->inet.port, timeout);
		    }
		} else {
		    return ctl_error(sock_errno(), rbuf, rsize);
		}
	    } else {
		ErlDrvTermData caller = driver_caller(desc->inet.port);
		tcp_descriptor* accept_desc;
		int err;
		
		if ((accept_desc = tcp_inet_copy(desc,s,caller,&err)) == NULL) {
		    sock_close(s);
		    return ctl_error(err, rbuf, rsize);
		}
		/* FIXME: may MUST lock access_port 
		 * 1 - Port is accessible via the erlang:ports()
		 * 2 - Port is accessible via callers process_info(links)
		 */
		accept_desc->inet.remote = remote;
		SET_NONBLOCKING(accept_desc->inet.s);
#ifdef __WIN32__
		driver_select(accept_desc->inet.port, accept_desc->inet.event, 
			      DO_READ, 1);
#endif
		accept_desc->inet.state = TCP_STATE_CONNECTED;
		enq_async(INETP(desc), tbuf, TCP_REQ_ACCEPT);
		async_ok_port(INETP(desc), accept_desc->inet.dport);
	    }
	    return ctl_reply(INET_REP_OK, tbuf, 2, rbuf, rsize);
	}
    }
    case INET_REQ_CLOSE:
	DEBUGF(("tcp_inet_ctl(%ld): CLOSE\r\n", (long)desc->inet.port)); 
	tcp_close_check(desc);
	erl_inet_close(INETP(desc));
	return ctl_reply(INET_REP_OK, NULL, 0, rbuf, rsize);


    case TCP_REQ_RECV: {
	unsigned timeout;
	char tbuf[2];
	int n;

	DEBUGF(("tcp_inet_ctl(%ld): RECV\r\n", (long)desc->inet.port)); 
	/* INPUT: Timeout(4),  Length(4) */
	if (!IS_CONNECTED(INETP(desc)))
	    return ctl_error(ENOTCONN, rbuf, rsize);
	if (desc->inet.active || (len != 8))
	    return ctl_error(EINVAL, rbuf, rsize);
	timeout = get_int32(buf);
	buf += 4;
	n = get_int32(buf);
	DEBUGF(("tcp_inet_ctl(%ld) timeout = %d, n = %d\r\n",
		(long)desc->inet.port,timeout,n));
	if ((desc->inet.htype != TCP_PB_RAW) && (n != 0))
	    return ctl_error(EINVAL, rbuf, rsize);
	if (n > TCP_MAX_PACKET_SIZE)
	    return ctl_error(ENOMEM, rbuf, rsize);
	if (enq_async(INETP(desc), tbuf, TCP_REQ_RECV) < 0)
	    return ctl_error(EALREADY, rbuf, rsize);

	if (tcp_recv(desc, n) == 0) {
	    if (timeout == 0)
		async_error_am(INETP(desc), am_timeout);
	    else {
		if (timeout != INET_INFINITY)
		    driver_set_timer(desc->inet.port, timeout); 
		sock_select(INETP(desc),(FD_READ|FD_CLOSE),1);
	    }
	}
	return ctl_reply(INET_REP_OK, tbuf, 2, rbuf, rsize);
    }

    case TCP_REQ_UNRECV: {
	DEBUGF(("tcp_inet_ctl(%ld): UNRECV\r\n", (long)desc->inet.port)); 
	if (!IS_CONNECTED(INETP(desc)))
	    return ctl_error(ENOTCONN, rbuf, rsize);
	tcp_push_buffer(desc, buf, len);
	if (desc->inet.active)
	    tcp_deliver(desc, 0);
	return ctl_reply(INET_REP_OK, NULL, 0, rbuf, rsize);
    }
#ifndef _OSE_
    case TCP_REQ_SHUTDOWN: {
	int how;
	DEBUGF(("tcp_inet_ctl(%ld): FDOPEN\r\n", (long)desc->inet.port)); 
	if (!IS_CONNECTED(INETP(desc))) {
	    return ctl_error(ENOTCONN, rbuf, rsize);
	}
	if (len != 1) {
	    return ctl_error(EINVAL, rbuf, rsize);
	}
	how = buf[0];
	if (sock_shutdown(INETP(desc)->s, how) == 0) {
	    return ctl_reply(INET_REP_OK, NULL, 0, rbuf, rsize);
	} else {
	    return ctl_error(sock_errno(), rbuf, rsize);
	}
    }
#endif
    default:
	DEBUGF(("tcp_inet_ctl(%ld): %u\r\n", (long)desc->inet.port, cmd)); 
	return inet_ctl(INETP(desc), cmd, buf, len, rbuf, rsize);
    }

}

/*
** tcp_inet_timeout:
** called when timer expire:
** TCP socket may be:
**
** a)  receiving   -- deselect
** b)  connecting  -- close socket
** c)  accepting   -- reset listener
**
*/

static void tcp_inet_timeout(ErlDrvData e)
{
    tcp_descriptor* desc = (tcp_descriptor*)e;
    int state = desc->inet.state;

    DEBUGF(("tcp_inet_timeout(%ld) {s=%d\r\n", 
	    (long)desc->inet.port, desc->inet.s)); 
    if ((state & INET_F_MULTI_CLIENT)) { /* Multi-client always means multi-timers */
	fire_multi_timers(&(desc->mtd), desc->inet.port, e);
    } else if ((state & TCP_STATE_CONNECTED) == TCP_STATE_CONNECTED) {
	if (desc->busy_on_send) {
	    desc->busy_on_send = 0;
	    set_busy_port(desc->inet.port, 0);
	    inet_reply_error_am(INETP(desc), am_timeout);
	}
	else {
	    /* assume recv timeout */
	    ASSERT(!desc->inet.active);
	    sock_select(INETP(desc),(FD_READ|FD_CLOSE),0);
	    desc->i_remain = 0;
	    async_error_am(INETP(desc), am_timeout);
	}
    }
    else if ((state & TCP_STATE_CONNECTING) == TCP_STATE_CONNECTING) {
	/* assume connect timeout */
	/* close the socket since it's not usable (see man pages) */
	erl_inet_close(INETP(desc));
	async_error_am(INETP(desc), am_timeout);
    }
    else if ((state & TCP_STATE_ACCEPTING) == TCP_STATE_ACCEPTING) {
	inet_async_op *this_op = desc->inet.opt;
	/* timer is set on accept */
	sock_select(INETP(desc), FD_ACCEPT, 0);
	if (this_op != NULL) {
	    driver_demonitor_process(desc->inet.port, &(this_op->monitor));
	}
	desc->inet.state = TCP_STATE_LISTEN;
	async_error_am(INETP(desc), am_timeout);
    }
    DEBUGF(("tcp_inet_timeout(%ld) }\r\n", (long)desc->inet.port)); 
}

static void tcp_inet_multi_timeout(ErlDrvData e, ErlDrvTermData caller)
{
    tcp_descriptor* desc = (tcp_descriptor*)e;
    int id,req;
    ErlDrvMonitor monitor;

    if (remove_multi_op(desc, &id, &req, caller, NULL, &monitor) != 0) {
	return;
    }
    driver_demonitor_process(desc->inet.port, &monitor);
    if (desc->multi_first == NULL) {
	sock_select(INETP(desc),FD_ACCEPT,0);
	desc->inet.state = TCP_STATE_LISTEN; /* restore state */
    }
    send_async_error(desc->inet.port, desc->inet.dport, id, caller, am_timeout);
}
    

	
/*
** command:
**   output on a socket only !
**   a reply code will be sent to connected (caller later)
**   {inet_reply, S, Status}
** NOTE! normal sockets use the the tcp_inet_commandv
** but distribution still uses the tcp_inet_command!!
*/

static void tcp_inet_command(ErlDrvData e, char *buf, int len)
{
    tcp_descriptor* desc = (tcp_descriptor*)e;
    desc->inet.caller = driver_caller(desc->inet.port);

    DEBUGF(("tcp_inet_command(%ld) {s=%d\r\n", 
	    (long)desc->inet.port, desc->inet.s)); 
    if (!IS_CONNECTED(INETP(desc)))
	inet_reply_error(INETP(desc), ENOTCONN);
    else if (tcp_send(desc, buf, len) == 0)
	inet_reply_ok(INETP(desc));
    DEBUGF(("tcp_inet_command(%ld) }\r\n", (long)desc->inet.port)); 
}


static void tcp_inet_commandv(ErlDrvData e, ErlIOVec* ev)
{
    tcp_descriptor* desc = (tcp_descriptor*)e;
    desc->inet.caller = driver_caller(desc->inet.port);

    DEBUGF(("tcp_inet_commanv(%ld) {s=%d\r\n", 
	    (long)desc->inet.port, desc->inet.s)); 
    if (!IS_CONNECTED(INETP(desc)))
	inet_reply_error(INETP(desc), ENOTCONN);
    else if (tcp_sendv(desc, ev) == 0)
	inet_reply_ok(INETP(desc));
    DEBUGF(("tcp_inet_commandv(%ld) }\r\n", (long)desc->inet.port)); 
}

static void tcp_inet_process_exit(ErlDrvData e, ErlDrvMonitor *monitorp) 
{
    tcp_descriptor* desc = (tcp_descriptor*)e;
    ErlDrvTermData who = driver_get_monitored_process(desc->inet.port,monitorp);
    int state = desc->inet.state;

    if ((state & TCP_STATE_MULTI_ACCEPTING) == TCP_STATE_MULTI_ACCEPTING) {
	int id,req;
	MultiTimerData *timeout;
	if (remove_multi_op(desc, &id, &req, who, &timeout, NULL) != 0) {
	    return;
	}
	if (timeout != NULL) {
	    remove_multi_timer(&(desc->mtd), desc->inet.port, timeout);
	}
	if (desc->multi_first == NULL) {
	    sock_select(INETP(desc),FD_ACCEPT,0);
	    desc->inet.state = TCP_STATE_LISTEN; /* restore state */
	}
    } else if ((state & TCP_STATE_ACCEPTING) == TCP_STATE_ACCEPTING) {
	int did,drid; 
	ErlDrvTermData dcaller;
	deq_async(INETP(desc), &did, &dcaller, &drid);
	driver_cancel_timer(desc->inet.port);
	sock_select(INETP(desc),FD_ACCEPT,0);
	desc->inet.state = TCP_STATE_LISTEN; /* restore state */
    }
} 



/* The socket has closed, cleanup and send event */
static int tcp_recv_closed(tcp_descriptor* desc)
{
#ifdef DEBUG
    long port = (long) desc->inet.port; /* Used after driver_exit() */
#endif
    DEBUGF(("tcp_recv_closed(%ld): s=%d, in %s, line %d\r\n",
	    port, desc->inet.s, __FILE__, __LINE__));
    if (IS_BUSY(INETP(desc))) {
	/* A send is blocked */
	desc->inet.caller = desc->inet.busy_caller;
	tcp_clear_output(desc);
	if (desc->busy_on_send) {
	    driver_cancel_timer(desc->inet.port);
	    desc->busy_on_send = 0;
	    DEBUGF(("tcp_recv_closed(%ld): busy on send\r\n", port));
	}
	desc->inet.state &= ~INET_F_BUSY;
	set_busy_port(desc->inet.port, 0);
	inet_reply_error_am(INETP(desc), am_closed);
	DEBUGF(("tcp_recv_closed(%ld): busy reply 'closed'\r\n", port));
    }
    if (!desc->inet.active) {
	/* We must cancel any timer here ! */
	driver_cancel_timer(desc->inet.port);
	/* passive mode do not terminate port ! */
	tcp_clear_input(desc);
	if (desc->inet.exitf) {
	    desc_close(INETP(desc));
	} else {
	    desc_close_read(INETP(desc));
	}
	async_error_am_all(INETP(desc), am_closed);
	/* next time EXBADSEQ will be delivered  */
	DEBUGF(("tcp_recv_closed(%ld): passive reply all 'closed'\r\n", port));
    } else {
	tcp_clear_input(desc);
	tcp_closed_message(desc);
	if (desc->inet.exitf) {
	    driver_exit(desc->inet.port, 0);
	} else {
	    desc_close_read(INETP(desc));
	}
	DEBUGF(("tcp_recv_closed(%ld): active close\r\n", port));
    }
    DEBUGF(("tcp_recv_closed(%ld): done\r\n", port));
    return -1;
}


/* We have a read error determine the action */
static int tcp_recv_error(tcp_descriptor* desc, int err)
{
    if (err != ERRNO_BLOCK) {
	if (IS_BUSY(INETP(desc))) {
	    /* A send is blocked */
	    desc->inet.caller = desc->inet.busy_caller;
	    tcp_clear_output(desc);
	    if (desc->busy_on_send) {
		driver_cancel_timer(desc->inet.port);
		desc->busy_on_send = 0;
	    }
	    desc->inet.state &= ~INET_F_BUSY;
	    set_busy_port(desc->inet.port, 0);
	    inet_reply_error_am(INETP(desc), am_closed);
	}
	if (!desc->inet.active) {
	    /* We must cancel any timer here ! */
	    driver_cancel_timer(desc->inet.port);
	    tcp_clear_input(desc);
	    if (desc->inet.exitf) {
		desc_close(INETP(desc));
	    } else {
		desc_close_read(INETP(desc));
	    }
	    async_error_am_all(INETP(desc), error_atom(err));
	} else {
	    tcp_clear_input(desc);
	    tcp_error_message(desc, err); /* first error */
	    tcp_closed_message(desc);     /* then closed */
	    if (desc->inet.exitf)
		driver_exit(desc->inet.port, err);
	    else
		desc_close(INETP(desc));
	}
	return -1;
    }
    return 0;
}



/*
** Calculate number of bytes that remain to read before deliver
** Assume buf, ptr_start, ptr has been setup
**
** return  > 0 if more to read
**         = 0 if holding complete packet
**         < 0 on error
**
** if return value == 0 then *len will hold the length of the first packet
**    return value > 0 then if *len == 0 then value means upperbound
**                             *len > 0  then value means exact
**
*/
static int tcp_remain(tcp_descriptor* desc, int* len)
{
    char* ptr = desc->i_ptr_start;
    int nfill = (desc->i_ptr - desc->i_buf->orig_bytes); /* filled */
    int nsz   = desc->i_bufsz - nfill;                   /* remain */
    int n = desc->i_ptr - ptr;  /* number of bytes read */
    int plen;
    int hlen;

    DEBUGF(("tcp_remain(%ld): s=%d, n=%d, nfill=%d nsz=%d\r\n", 
	    (long)desc->inet.port, desc->inet.s, n, nfill, nsz));

    switch(desc->inet.htype) {
    case TCP_PB_RAW:
	if (n == 0) goto more;
	else {
	    *len = n;
	    DEBUGF((" => nothing remain packet=%d\r\n", n));	    
	    return 0;  /* deliver */
	}

    case TCP_PB_1:
	/* TCP_PB_1:    [L0 | Data] */
	hlen = 1;
	if (n < hlen) goto more;
	plen = get_int8(ptr);
	goto remain;

    case TCP_PB_2:
	/* TCP_PB_2:    [L1,L0 | Data] */
	hlen = 2;
	if (n < hlen) goto more;
	plen = get_int16(ptr);
	goto remain;

    case TCP_PB_4:
	/* TCP_PB_4:    [L3,L2,L1,L0 | Data] */
	hlen = 4;
	if (n < hlen) goto more;
	plen = get_int32(ptr);
	goto remain;

    case TCP_PB_RM:
	/* TCP_PB_RM:    [L3,L2,L1,L0 | Data] 
	 ** where MSB (bit) is used to signal end of record
	 */
	hlen = 4;
	if (n < hlen) goto more;
	plen = get_int32(ptr) & 0x7fffffff;
	goto remain;

    case TCP_PB_LINE_LF: {
	/* TCP_PB_LINE_LF:  [Data ... \n]  */
	char* ptr2;
	if  ((ptr2 = memchr(ptr, '\n', n)) == NULL) {
	    if ((nsz == 0) && (nfill == n)) { /* buffer full */
		*len = n;
		DEBUGF((" => line buffer full (no NL)=%d\r\n", n));
		return 0;
	    }
	    goto more;
	}
	else {
	    *len = (ptr2 - ptr) + 1;  /* include newline */
	    DEBUGF((" => nothing remain packet=%d\r\n", *len));
	    return 0;
	}
    }

    case TCP_PB_ASN1: {
	/* TCP_PB_ASN1: handles long (4 bytes) or short length format */
	char* tptr = ptr;
	int length;
	int nn = n;

	if (n < 2) goto more;
	nn--;
	if ((*tptr++ & 0x1f) == 0x1f) { /* Long tag format */
	    while(nn && ((*tptr & 0x80) == 0x80)) {
		tptr++;
		nn--;
	    }
	    if (nn < 2) goto more;
	    tptr++;
	    nn--;
	}

	/* tptr now point to length field and n characters remain */
	length = *tptr & 0x7f;
	if ((*tptr & 0x80) == 0x80) {   /* Long length format */
	    tptr++;
	    nn--;
	    if (nn < length) goto more;
	    switch(length) {
	    case 0: plen = 0; break;
	    case 1: plen = get_int8(tptr);  tptr += 1; break;
	    case 2: plen = get_int16(tptr); tptr += 2; break;
	    case 3: plen = get_int24(tptr); tptr += 3; break;
	    case 4: plen = get_int32(tptr); tptr += 4; break;
	    default: goto error; /* error */
	    }
	}
	else {
	    tptr++;
	    plen = length;
	}
	hlen = (tptr-ptr);
	goto remain;
    }


    case TCP_PB_CDR: {
	struct cdr_head* hp;
	hlen = sizeof(struct cdr_head);
	if (n < hlen) goto more;
	hp = (struct cdr_head*) ptr;
	if (sys_memcmp(hp->magic, CDR_MAGIC, 4) != 0)
	    goto error;
	if (hp->flags & 0x01) /* Byte ordering flag */
	    plen = get_little_int32(hp->message_size);
	else
	    plen = get_int32(hp->message_size);
	goto remain;
    }

    case TCP_PB_FCGI: {
	struct fcgi_head* hp;
	hlen = sizeof(struct fcgi_head);
	if (n < hlen) goto more;
	hp = (struct fcgi_head*) ptr;
	if (hp->version != FCGI_VERSION_1)
	    goto error;			/* ERROR, unknown header version */
	plen = ((hp->contentLengthB1 << 8) | hp->contentLengthB0)
	    + hp->paddingLength;
	goto remain;
    }
#ifdef USE_HTTP
    case TCP_PB_HTTPH:
	desc->http_state = 1;
    case TCP_PB_HTTP: {
        /* TCP_PB_HTTP:  data \r\n(SP data\r\n)*  */
        plen = n;
	if (((plen == 1) && NL(ptr)) || ((plen == 2) && CRNL(ptr)))
	    goto done;
	else {
	    char* ptr1 = ptr;
	    int   len = plen;

	    while(1) {
	      char* ptr2 = memchr(ptr1, '\n', len);

	      if  (ptr2 == NULL) {
		  if ((nsz == 0) && (nfill == n)) { /* buffer full */
		      plen = n;
		      goto done;
		  }
		  goto more;
	      }
	      else {
  		  plen = (ptr2 - ptr) + 1;

		  if (desc->http_state == 0) 
		      goto done;
	        
		  if (plen < n) {
		      if (SP(ptr2+1)) {
			  ptr1 = ptr2+1;
			  len = n - plen;
		      }
		      else
			  goto done;
		  }
		  else
		      goto more;
	      }
	    }
	}
    }
#endif
    case TCP_PB_TPKT: {
	struct tpkt_head* hp;
	hlen = sizeof(struct tpkt_head);
	if (n < hlen) 
	    goto more;
	hp = (struct tpkt_head*) ptr;
	if (hp->vrsn == TPKT_VRSN) {
	    plen = get_int16(hp->packet_length) - hlen;
	    if (plen < 0)
		goto error;
	} else
	    goto error;
	goto remain;
    }

    default:  /* this can not occure (make compiler happy) */
	DEBUGF((" => case error\r\n"));
	return -1;
    }

 done: {
      *len = plen;
      DEBUGF((" => nothing remain packet=%d\r\n", plen));
      return 0;
    }

 remain: {
     int tlen, remain;
     if (desc->inet.psize != 0 && 
	 ((unsigned int)plen) > desc->inet.psize) goto error;
     tlen = plen + hlen;
     remain = tlen - n;
     if (remain <= 0) {
	 *len = tlen;
	 DEBUGF((" => nothing remain packet=%d\r\n", tlen));
	 return 0;
     }
     else {
	 if (tcp_expand_buffer(desc, tlen) < 0)
	     return -1;
	 DEBUGF((" => remain=%d\r\n", remain));
	 *len = remain;
	 return remain;
     }
 }

 more:
    *len = 0;
    if (nsz == 0) {
	if (nfill == n)
	    goto error;
	DEBUGF((" => restart more=%d\r\n", nfill - n));
	return nfill - n;
    }
    else {
	DEBUGF((" => more=%d \r\n", nsz));
	return nsz;
    }

 error:
    DEBUGF((" => packet error\r\n"));
    return -1;
}

/*
** Deliver all packets ready 
** if len == 0 then check start with a check for ready packet
*/
static int tcp_deliver(tcp_descriptor* desc, int len)
{
    int count = 0;
    int n;

    /* Poll for ready packet */
    if (len == 0) {
	/* empty buffer or waiting for more input */
	if ((desc->i_buf == NULL) || (desc->i_remain > 0))
	    return count;
	if ((n = tcp_remain(desc, &len)) != 0) {
	    if (n < 0) /* packet error */
		return n;
	    if (len > 0)  /* more data pending */
		desc->i_remain = len;
	    return count;
	}
    }

    while (len > 0) {
	int code = 0;

	inet_input_count(INETP(desc), len);

	/* deliver binary? */
	if (len*4 >= desc->i_buf->orig_size*3) { /* >=75% */
	    /* something after? */
	    if (desc->i_ptr_start + len == desc->i_ptr) { /* no */
		code = tcp_reply_binary_data(desc, desc->i_buf,
					     (desc->i_ptr_start -
					      desc->i_buf->orig_bytes),
					     len);
		tcp_clear_input(desc);
	    }
	    else { /* move trail to beginning of a new buffer */
		ErlDrvBinary* bin;
		char* ptr_end = desc->i_ptr_start + len;
		int sz = desc->i_ptr - ptr_end;

		bin = alloc_buffer(desc->i_bufsz);
		memcpy(bin->orig_bytes, ptr_end, sz);

		code = tcp_reply_binary_data(desc, desc->i_buf,
					     (desc->i_ptr_start-
					      desc->i_buf->orig_bytes),
					     len);
		free_buffer(desc->i_buf);
		desc->i_buf = bin;
		desc->i_ptr_start = desc->i_buf->orig_bytes;
		desc->i_ptr = desc->i_ptr_start + sz;
		desc->i_remain = 0;
	    }
	}
	else {
	    code = tcp_reply_data(desc, desc->i_ptr_start, len);
	    /* XXX The buffer gets thrown away on error  (code < 0)    */
	    /* Windows needs workaround for this in tcp_inet_event...  */
	    desc->i_ptr_start += len;
	    if (desc->i_ptr_start == desc->i_ptr)
		tcp_clear_input(desc);
	    else
		desc->i_remain = 0;

	}

	if (code < 0)
	    return code;

	count++;
	len = 0;

	if (!desc->inet.active) {
	    driver_cancel_timer(desc->inet.port);
	    sock_select(INETP(desc),(FD_READ|FD_CLOSE),0);
	    if (desc->i_buf != NULL)
		tcp_restart_input(desc);
	}
	else if (desc->i_buf != NULL) {
	    if ((n = tcp_remain(desc, &len)) != 0) {
		if (n < 0) /* packet error */
		    return n;
		tcp_restart_input(desc);
		if (len > 0)
		    desc->i_remain = len;
		len = 0;
	    }
	}
    }
    return count;
}


static int tcp_recv(tcp_descriptor* desc, int request_len)
{
    int n;
    int len;
    int nread;

    if (desc->i_buf == NULL) {  /* allocte a read buffer */
	int sz = (request_len > 0) ? request_len : desc->inet.bufsz;

	if ((desc->i_buf = alloc_buffer(sz)) == NULL)
	    return -1;
	/* XXX: changing bufsz during recv SHOULD/MAY? affect 
	 * ongoing operation but is not now 
	 */
	desc->i_bufsz = sz; /* use i_bufsz not i_buf->orig_size ! */
	desc->i_ptr_start = desc->i_buf->orig_bytes;
	desc->i_ptr = desc->i_ptr_start;
	nread = sz;
	if (request_len > 0)
	    desc->i_remain = request_len;
	else
	    desc->i_remain = 0;
    }
    else if (request_len > 0) { /* we have a data in buffer and a request */
	n = desc->i_ptr - desc->i_ptr_start;
	if (n >= request_len)
	    return tcp_deliver(desc, request_len);
	else if (tcp_expand_buffer(desc, request_len) < 0)
	    return tcp_recv_error(desc, ENOMEM);
	else
	    desc->i_remain = nread = request_len - n;
    }
    else if (desc->i_remain == 0) {  /* poll remain from buffer data */
	if ((nread = tcp_remain(desc, &len)) < 0)
	    return tcp_recv_error(desc, EMSGSIZE);
	else if (nread == 0)
	    return tcp_deliver(desc, len);
	else if (len > 0)
	    desc->i_remain = len;  /* set remain */
    }
    else  /* remain already set use it */
	nread = desc->i_remain;
    
    DEBUGF(("tcp_recv(%ld): s=%d about to read %d bytes...\r\n",  
	    (long)desc->inet.port, desc->inet.s, nread));

    n = sock_recv(desc->inet.s, desc->i_ptr, nread, 0);

    if (n == SOCKET_ERROR) {
	int err = sock_errno();
	if (err == ECONNRESET) {
	    DEBUGF((" => detected close (connreset)\r\n"));
	    return tcp_recv_closed(desc);
	}
	if (err == ERRNO_BLOCK) {
	    DEBUGF((" => would block\r\n"));
	    return 0;
	}
	else {
	    DEBUGF((" => error: %d\r\n", err));
	    return tcp_recv_error(desc, err);
	}
    }
    else if (n == 0) {
	DEBUGF(("  => detected close\r\n"));
	return tcp_recv_closed(desc);
    }

    DEBUGF((" => got %d bytes\r\n", n));
    desc->i_ptr += n;
    if (desc->i_remain > 0) {
	desc->i_remain -= n;
	if (desc->i_remain == 0)
	    return tcp_deliver(desc, desc->i_ptr - desc->i_ptr_start);
    }
    else {
	if ((nread = tcp_remain(desc, &len)) < 0)
	    return tcp_recv_error(desc, EMSGSIZE);
	else if (nread == 0)
	    return tcp_deliver(desc, len);
	else if (len > 0)
	    desc->i_remain = len;  /* set remain */
    }
    return 0;
}


#ifdef __WIN32__


static int winsock_event_select(inet_descriptor *desc, int flags, int on)
{
    int save_event_mask = desc->event_mask;
    
    desc->forced_events = 0;
    if (on) 
	desc->event_mask |= flags;
    else
	desc->event_mask &= (~flags);
    DEBUGF(("port %d: winsock_event_select: "
	    "flags=%02X, on=%d, event_mask=%02X\n", 
	    desc->port, flags, on, desc->event_mask));
    /* The RIGHT WAY (TM) to do this is to make sure:
       A) The cancelling of all network events is done with
          NULL as the event parameter (bug in NT's winsock),
       B) The actual event handle is reset so that it is only
          raised if one of the requested network events is active,
       C) Avoid race conditions by making sure that the event cannot be set
          while we are preparing to set the correct network event mask.
       The simplest way to do it is to turn off all events, reset the
       event handle and then, if event_mask != 0, turn on the appropriate
       events again. */
    if (WSAEventSelect(desc->s, NULL, 0) != 0) {
	DEBUGF(("port %d: winsock_event_select: "
		"WSAEventSelect returned error, code %d.\n", 
		sock_errno()));
	desc->event_mask = save_event_mask;
	return -1;
    }
    if (!ResetEvent(desc->event)) {
	DEBUGF(("port %d: winsock_event_select: "
		"ResetEvent returned error, code %d.\n", 
		GetLastError()));
	desc->event_mask = 0;
	return -1;
    }
    if (desc->event_mask != 0) {
	if (WSAEventSelect(desc->s, 
			     desc->event, 
			     desc->event_mask) != 0) {
	    DEBUGF(("port %d: winsock_event_select: "
		    "WSAEventSelect returned error, code %d.\n", 
		    sock_errno()));
	    desc->event_mask = 0;
	    return -1;
	}

	/* Now, WSAEventSelect() is trigged only when the queue goes from
	   full to empty or from empty to full; therefore we need an extra test 
	   to see whether it is writeable, readable or closed... */
	if ((desc->event_mask & FD_WRITE)) {
	    TIMEVAL tmo = {0,0};
	    FD_SET fds;
	    int ret;
	
	    FD_ZERO(&fds);
	    FD_SET(desc->s,&fds);
	    ret = select(desc->s+1,0,&fds,0,&tmo);
	    if (ret > 0) {
		SetEvent(desc->event);
		desc->forced_events |= FD_WRITE;
	    }
	}
	if ((desc->event_mask & (FD_READ|FD_CLOSE))) {
	    int readable = 0;
	    int closed = 0;
	    TIMEVAL tmo = {0,0};
	    FD_SET fds;
	    int ret;
	    unsigned long arg;
	  
	    FD_ZERO(&fds);
	    FD_SET(desc->s,&fds);
	    ret = select(desc->s+1,&fds,0,0,&tmo);
	    if (ret > 0) {
		++readable;
		if (ioctlsocket(desc->s,FIONREAD,&arg) != 0) {
		    ++closed;	/* Which gives a FD_CLOSE event */
		} else {
		    closed = (arg == 0);
		}
	    }
	    if ((desc->event_mask & FD_READ) && readable && !closed) {
		SetEvent(desc->event);
		desc->forced_events |= FD_READ;
	    }
	    if ((desc->event_mask & FD_CLOSE) && closed) {
		SetEvent(desc->event);
		desc->forced_events |= FD_CLOSE;
	    }
	}
    }
    return 0;
}

static void tcp_inet_event(ErlDrvData e, ErlDrvEvent event)
{
    tcp_descriptor* desc = (tcp_descriptor*)e;
    WSANETWORKEVENTS netEv;
    int err;

    DEBUGF(("tcp_inet_event(%ld) {s=%d\r\n", 
	    (long)desc->inet.port, desc->inet.s));
    if (WSAEnumNetworkEvents(desc->inet.s, desc->inet.event,
					&netEv) != 0) {
	DEBUGF((" => EnumNetworkEvents = %d\r\n", sock_errno() ));
	goto error;
    }

    DEBUGF((" => event=%02X, mask=%02X\r\n",
	    netEv.lNetworkEvents, desc->inet.event_mask));

    /* Add the forced events. */

    netEv.lNetworkEvents |= desc->inet.forced_events;

    /*
     * Calling WSAEventSelect() with a mask of 0 doesn't always turn off
     * all events.  To avoid acting on events we don't want, we mask
     * the events with mask for the events we really want.
     */

#ifdef DEBUG
    if ((netEv.lNetworkEvents & ~(desc->inet.event_mask)) != 0) {
	DEBUGF(("port %d:  ... unexpected event: %d\r\n",
		desc->inet.port, netEv.lNetworkEvents & ~(desc->inet.event_mask)));
    }
#endif
    netEv.lNetworkEvents &= desc->inet.event_mask;

    if (netEv.lNetworkEvents & FD_READ) {
	if (tcp_inet_input(desc, event) < 0) {
	    goto error;
	}
	if (netEv.lNetworkEvents & FD_CLOSE) {
	    /*
	     * We must loop to read out the remaining packets (if any).
	     */
	    for (;;) {
		DEBUGF(("Retrying read due to closed port\r\n"));
		/* XXX The buffer will be thrown away on error (empty que).
		   Possible SMP FIXME. */
		if (!desc->inet.active && (desc->inet.opt) == NULL) {
		    goto error;
		}
		if (tcp_inet_input(desc, event) < 0) {
		    goto error;
		}
	    }
	}
    }
    if (netEv.lNetworkEvents & FD_WRITE) {
	if (tcp_inet_output(desc, event) < 0)
	    goto error;
    }
    if (netEv.lNetworkEvents & FD_CONNECT) {
	if ((err = netEv.iErrorCode[FD_CONNECT_BIT]) != 0) {
	    async_error(INETP(desc), err);
	} else {
	    tcp_inet_output(desc, event);
	}
    } else if (netEv.lNetworkEvents & FD_ACCEPT) {
	if ((err = netEv.iErrorCode[FD_ACCEPT_BIT]) != 0)
	    async_error(INETP(desc), err);
	else
	    tcp_inet_input(desc, event);
    }
    if (netEv.lNetworkEvents & FD_CLOSE) {
	/* error in err = netEv.iErrorCode[FD_CLOSE_BIT] */
	DEBUGF(("Detected close in %s, line %d\r\n", __FILE__, __LINE__));
	tcp_recv_closed(desc);
    }
    DEBUGF(("tcp_inet_event(%ld) }\r\n", (long)desc->inet.port));
    return;

 error:
    DEBUGF(("tcp_inet_event(%ld) error}\r\n", (long)desc->inet.port));
    return;
}

#endif /* WIN32 */


/* socket has input:
** 1. TCP_STATE_ACCEPTING  => non block accept ? 
** 2. TCP_STATE_CONNECTED => read input
*/
static int tcp_inet_input(tcp_descriptor* desc, HANDLE event)
{
    int ret = 0;
#ifdef DEBUG
    long port = (long) desc->inet.port;  /* Used after driver_exit() */
#endif
    DEBUGF(("tcp_inet_input(%ld) {s=%d\r\n", port, desc->inet.s));
    if (desc->inet.state == TCP_STATE_ACCEPTING) {
	SOCKET s;
	unsigned int len;
	inet_address remote;
	inet_async_op *this_op = desc->inet.opt;
	
	len = sizeof(desc->inet.remote);
	s = sock_accept(desc->inet.s, (struct sockaddr*) &remote, &len);
	if (s == INVALID_SOCKET && sock_errno() == ERRNO_BLOCK) {
	    /* Just try again, no real error, just a ghost trigger from poll, 
	       keep the default return code and everything else as is */
	    goto done;
	}

	sock_select(INETP(desc),FD_ACCEPT,0);
	desc->inet.state = TCP_STATE_LISTEN; /* restore state */

	if (this_op != NULL) {
	    driver_demonitor_process(desc->inet.port, &(this_op->monitor));
	}


	driver_cancel_timer(desc->inet.port); /* posssibly cancel a timer */

	if (s == INVALID_SOCKET) {
	    ret = async_error(INETP(desc), sock_errno());
	    goto done;
	}
	else {
	    ErlDrvTermData caller;
	    tcp_descriptor* accept_desc;
	    int err;

	    if (desc->inet.opt == NULL) {
		/* No caller setup */
		sock_close(s);
		ret = async_error(INETP(desc), EINVAL);
		goto done;
	    }
	    caller = desc->inet.opt->caller;
	    if ((accept_desc = tcp_inet_copy(desc,s,caller,&err)) == NULL) {
		sock_close(s);
		ret = async_error(INETP(desc), err);
		goto done;
	    }
	    /* FIXME: may MUST lock port 
	     * 1 - Port is accessible via the erlang:ports()
	     * 2 - Port is accessible via callers process_info(links)
	     */
	    accept_desc->inet.remote = remote;
	    SET_NONBLOCKING(accept_desc->inet.s);
#ifdef __WIN32__
	    driver_select(accept_desc->inet.port, accept_desc->inet.event, 
			  DO_READ, 1);
#endif
	    accept_desc->inet.state = TCP_STATE_CONNECTED;
	    ret =  async_ok_port(INETP(desc), accept_desc->inet.dport);
	    goto done;
	}
    } else if (desc->inet.state == TCP_STATE_MULTI_ACCEPTING) {
	SOCKET s;
	unsigned int len;
	inet_address remote;
	int id,req;
	ErlDrvTermData caller;
	MultiTimerData *timeout;
	ErlDrvMonitor monitor;
#ifdef HARDDEBUG
	int times = 0;
#endif

	while (desc->inet.state == TCP_STATE_MULTI_ACCEPTING) {
	    len = sizeof(desc->inet.remote);
	    s = sock_accept(desc->inet.s, (struct sockaddr*) &remote, &len);
	    
	    if (s == INVALID_SOCKET && sock_errno() == ERRNO_BLOCK) {
		/* Just try again, no real error, keep the last return code */
		goto done;
	    }
#ifdef HARDDEBUG
	    if (++times > 1) {
		erts_fprintf(stderr,"Accepts in one suite: %d :-)\r\n",times);
	    }
#endif
	    if (deq_multi_op(desc,&id,&req,&caller,&timeout,&monitor) != 0) {
		ret = -1;
		goto done;
	    }
	    
	    if (desc->multi_first == NULL) {
		sock_select(INETP(desc),FD_ACCEPT,0);
		desc->inet.state = TCP_STATE_LISTEN; /* restore state */
	    }
	    
	    if (timeout != NULL) {
		remove_multi_timer(&(desc->mtd), desc->inet.port, timeout);
	    }
	    
	    driver_demonitor_process(desc->inet.port, &monitor);
	    
	    
	    if (s == INVALID_SOCKET) { /* Not ERRNO_BLOCK, that's handled right away */
		ret = send_async_error(desc->inet.port, desc->inet.dport, 
				       id, caller, error_atom(sock_errno()));
		goto done;
	    }
	    else {
		tcp_descriptor* accept_desc;
		int err;
		
		if ((accept_desc = tcp_inet_copy(desc,s,caller,&err)) == NULL) {
		    sock_close(s);
		    ret = send_async_error(desc->inet.port, desc->inet.dport, 
					   id, caller, error_atom(err));
		    goto done;
		}
		accept_desc->inet.remote = remote;
		SET_NONBLOCKING(accept_desc->inet.s);
#ifdef __WIN32__
		driver_select(accept_desc->inet.port, accept_desc->inet.event, 
			      DO_READ, 1);
#endif
		accept_desc->inet.state = TCP_STATE_CONNECTED;
		ret =  send_async_ok_port(desc->inet.port, desc->inet.dport, 
					  id, caller, accept_desc->inet.dport);
	    }
	}
    }
    else if (IS_CONNECTED(INETP(desc))) {
	ret = tcp_recv(desc, 0);
	goto done;
    }
    else {
	/* maybe a close op from connection attempt?? */
	sock_select(INETP(desc),FD_ACCEPT,0);
	DEBUGF(("tcp_inet_input(%ld): s=%d bad state: %04x\r\n", 
		port, desc->inet.s, desc->inet.state));
    }
 done:
    DEBUGF(("tcp_inet_input(%ld) }\r\n", port));
    return ret;
}

static int tcp_send_error(tcp_descriptor* desc, int err)
{
    inet_address other;
    unsigned int sz = sizeof(other);
    int code;

    if (IS_BUSY(INETP(desc))) {
	desc->inet.caller = desc->inet.busy_caller;
	if (desc->busy_on_send) {
	    driver_cancel_timer(desc->inet.port);
	    desc->busy_on_send = 0;	
	}
	desc->inet.state &= ~INET_F_BUSY;
	set_busy_port(desc->inet.port, 0);
    }

    code = sock_peer(desc->inet.s,(struct sockaddr*) &other,&sz);
    if ((code == SOCKET_ERROR) && (sock_errno() == ENOTCONN ||
				   sock_errno() == EPIPE)) {
	DEBUGF(("driver_failure_eof(%ld) in %s, line %d\r\n",
		(long)desc->inet.port, __FILE__, __LINE__));
	if (desc->inet.active) {
	    tcp_closed_message(desc);
	    inet_reply_error_am(INETP(desc), am_closed);
	    if (desc->inet.exitf)
		driver_exit(desc->inet.port, 0);
	    else
		desc_close(INETP(desc));
	}
	else {
	    tcp_clear_output(desc);
	    tcp_clear_input(desc);
	    tcp_close_check(desc);
	    erl_inet_close(INETP(desc));
	    inet_reply_error_am(INETP(desc), am_closed);
	}
    }
    else  {
	inet_reply_error(INETP(desc), sock_errno());
    }
    return -1;
}

/*
** Send non-blocking vector data
*/
static int tcp_sendv(tcp_descriptor* desc, ErlIOVec* ev)
{
    int sz;
    char buf[4];
    int h_len;
    int n;
    ErlDrvPort ix = desc->inet.port;
    int len = ev->size;

    switch(desc->inet.htype) {
    case TCP_PB_1: 
	put_int8(len, buf);
	h_len = 1;
	break;
    case TCP_PB_2: 
	put_int16(len, buf);
	h_len = 2; 
	break;
    case TCP_PB_4: 
	put_int32(len, buf);
	h_len = 4; 
	break;
    default:
	if (len == 0)
	    return 0;
	h_len = 0;
	break;
    }

    inet_output_count(INETP(desc), len+h_len);

    if (h_len > 0) {
	ev->iov[0].iov_base = buf;
	ev->iov[0].iov_len = h_len;
	ev->size += h_len;
    }

    if ((sz = driver_sizeq(ix)) > 0) {
	driver_enqv(ix, ev, 0);
	if (sz+ev->size >= desc->high) {
	    DEBUGF(("tcp_sendv(%ld): s=%d, sender forced busy\r\n",
		    (long)desc->inet.port, desc->inet.s));
	    desc->inet.state |= INET_F_BUSY;  /* mark for low-watermark */
	    desc->inet.busy_caller = desc->inet.caller;
	    set_busy_port(desc->inet.port, 1);
	    if (desc->send_timeout != INET_INFINITY) {
		desc->busy_on_send = 1;
		driver_set_timer(desc->inet.port, desc->send_timeout);
	    }
	    return 1;
	}
    }
    else {
	int vsize = (ev->vsize > MAX_VSIZE) ? MAX_VSIZE : ev->vsize;
	
	DEBUGF(("tcp_sendv(%ld): s=%d, about to send %d,%d bytes\r\n",
		(long)desc->inet.port, desc->inet.s, h_len, len));
	if (desc->tcp_add_flags & TCP_ADDF_DELAY_SEND) {
	    n = 0;
	} else if (sock_sendv(desc->inet.s, ev->iov, vsize, &n, 0) 
		   == SOCKET_ERROR) {
	    if ((sock_errno() != ERRNO_BLOCK) && (sock_errno() != EINTR)) {
		int err = sock_errno();
		DEBUGF(("tcp_sendv(%ld): s=%d, "
			"sock_sendv(size=2) errno = %d\r\n",
			(long)desc->inet.port, desc->inet.s, err));
		return tcp_send_error(desc, err);
	    }
	    n = 0;
	}
	else if (n == ev->size) {
	    ASSERT(NO_SUBSCRIBERS(&INETP(desc)->empty_out_q_subs));
	    return 0;
	}

	DEBUGF(("tcp_sendv(%ld): s=%d, Send failed, queuing\r\n", 
		(long)desc->inet.port, desc->inet.s));
	driver_enqv(ix, ev, n); 
	sock_select(INETP(desc),(FD_WRITE|FD_CLOSE), 1);
    }
    return 0;
}

/*
** Send non blocking data
*/
static int tcp_send(tcp_descriptor* desc, char* ptr, int len)
{
    int sz;
    char buf[4];
    int h_len;
    int n;
    ErlDrvPort ix = desc->inet.port;
    SysIOVec iov[2];

    switch(desc->inet.htype) {
    case TCP_PB_1: 
	put_int8(len, buf);
	h_len = 1;
	break;
    case TCP_PB_2: 
	put_int16(len, buf);
	h_len = 2; 
	break;
    case TCP_PB_4: 
	put_int32(len, buf);
	h_len = 4; 
	break;
    default:
	if (len == 0)
	    return 0;
	h_len = 0;
	break;
    }

    inet_output_count(INETP(desc), len+h_len);


    if ((sz = driver_sizeq(ix)) > 0) {
	if (h_len > 0)
	    driver_enq(ix, buf, h_len);
	driver_enq(ix, ptr, len);
	if (sz+h_len+len >= desc->high) {
	    DEBUGF(("tcp_send(%ld): s=%d, sender forced busy\r\n",
		    (long)desc->inet.port, desc->inet.s));
	    desc->inet.state |= INET_F_BUSY;  /* mark for low-watermark */
	    desc->inet.busy_caller = desc->inet.caller;
	    set_busy_port(desc->inet.port, 1);
	    if (desc->send_timeout != INET_INFINITY) {
		desc->busy_on_send = 1;
		driver_set_timer(desc->inet.port, desc->send_timeout);
	    }
	    return 1;
	}
    }
    else {
	iov[0].iov_base = buf;
	iov[0].iov_len = h_len;
	iov[1].iov_base = ptr;
	iov[1].iov_len = len;

	DEBUGF(("tcp_send(%ld): s=%d, about to send %d,%d bytes\r\n",
		(long)desc->inet.port, desc->inet.s, h_len, len));
	if (desc->tcp_add_flags & TCP_ADDF_DELAY_SEND) {
	    sock_send(desc->inet.s, buf, 0, 0);
	    n = 0;
	} else 	if (sock_sendv(desc->inet.s,iov,2,&n,0) == SOCKET_ERROR) {
	    if ((sock_errno() != ERRNO_BLOCK) && (sock_errno() != EINTR)) {
		int err = sock_errno();
		DEBUGF(("tcp_send(%ld): s=%d,sock_sendv(size=2) errno = %d\r\n",
			(long)desc->inet.port, desc->inet.s, err));
		return tcp_send_error(desc, err);
	    }
	    n = 0;
	}
	else if (n == len+h_len) {
	    ASSERT(NO_SUBSCRIBERS(&INETP(desc)->empty_out_q_subs));
	    return 0;
	}

	DEBUGF(("tcp_send(%ld): s=%d, Send failed, queuing", 
		(long)desc->inet.port, desc->inet.s));

	if (n < h_len) {
	    driver_enq(ix, buf+n, h_len-n);
	    driver_enq(ix, ptr, len);
	}
	else {
	    n -= h_len;
	    driver_enq(ix, ptr+n, len-n);
	}
	sock_select(INETP(desc),(FD_WRITE|FD_CLOSE), 1);
    }
    return 0;
}

static void tcp_inet_drv_output(ErlDrvData data, ErlDrvEvent event)
{
    (void)tcp_inet_output((tcp_descriptor*)data, (HANDLE)event);
}

static void tcp_inet_drv_input(ErlDrvData data, ErlDrvEvent event)
{
    (void)tcp_inet_input((tcp_descriptor*)data, (HANDLE)event);
}

/* socket ready for ouput:
** 1. TCP_STATE_CONNECTING => non block connect ?
** 2. TCP_STATE_CONNECTED  => write output
*/
static int tcp_inet_output(tcp_descriptor* desc, HANDLE event)
{
    int ret = 0;
    ErlDrvPort ix = desc->inet.port;

    DEBUGF(("tcp_inet_output(%ld) {s=%d\r\n", 
	    (long)desc->inet.port, desc->inet.s));
    if (desc->inet.state == TCP_STATE_CONNECTING) {
	sock_select(INETP(desc),FD_CONNECT,0);

	driver_cancel_timer(ix);  /* posssibly cancel a timer */
#ifndef __WIN32__
	/*
	 * XXX This is strange.  This *should* work on Windows NT too,
	 * but doesn't.  An bug in Winsock 2.0 for Windows NT?
	 *
	 * See "Unix Netwok Programming", W.R.Stevens, p 412 for a
	 * discussion about Unix portability and non blocking connect.
	 */

#ifndef SO_ERROR
	{
	    int sz = sizeof(desc->inet.remote);
	    int code = sock_peer(desc->inet.s,
				 (struct sockaddr*) &desc->inet.remote, &sz);

	    if (code == SOCKET_ERROR) {
		desc->inet.state = TCP_STATE_BOUND;  /* restore state */
		ret =  async_error(INETP(desc), sock_errno());
		goto done;
	    }
	}
#else
	{
	    int error = 0;	/* Has to be initiated, we check it */
	    unsigned int sz = sizeof(error); /* even if we get -1 */
	    int code = sock_getopt(desc->inet.s, SOL_SOCKET, SO_ERROR, 
				   (void *)&error, &sz);

	    if ((code < 0) || error) {
		desc->inet.state = TCP_STATE_BOUND;  /* restore state */
		ret = async_error(INETP(desc), error);
		goto done;
	    }
	}
#endif /* SOCKOPT_CONNECT_STAT */
#endif /* !__WIN32__ */

	desc->inet.state = TCP_STATE_CONNECTED;
	if (desc->inet.active)
	    sock_select(INETP(desc),(FD_READ|FD_CLOSE),1);
	async_ok(INETP(desc));
    }
    else if (IS_CONNECTED(INETP(desc))) {
	for (;;) {
	    int vsize;
	    int n;
	    SysIOVec* iov;

	    if ((iov = driver_peekq(ix, &vsize)) == NULL) {
		sock_select(INETP(desc), FD_WRITE, 0);
		send_empty_out_q_msgs(INETP(desc));
		goto done;
	    }
	    vsize = vsize > MAX_VSIZE ? MAX_VSIZE : vsize;
	    DEBUGF(("tcp_inet_output(%ld): s=%d, About to send %d items\r\n", 
		    (long)desc->inet.port, desc->inet.s, vsize));
	    if (sock_sendv(desc->inet.s, iov, vsize, &n, 0)==SOCKET_ERROR) {
		if ((sock_errno() != ERRNO_BLOCK) && (sock_errno() != EINTR)) {
		    DEBUGF(("tcp_inet_output(%ld): sock_sendv(%d) errno = %d\r\n",
			    (long)desc->inet.port, vsize, sock_errno()));
		    ret =  tcp_send_error(desc, sock_errno());
		    goto done;
		}
		goto done;
	    }
	    if (driver_deq(ix, n) <= desc->low) {
		if (IS_BUSY(INETP(desc))) {
		    desc->inet.caller = desc->inet.busy_caller;
		    desc->inet.state &= ~INET_F_BUSY;
		    set_busy_port(desc->inet.port, 0);
		    /* if we have a timer then cancel and send ok to client */
		    if (desc->busy_on_send) {
			driver_cancel_timer(desc->inet.port);
			desc->busy_on_send = 0;
		    }
		    inet_reply_ok(INETP(desc));
		}
	    }
	}
    }
    else {
	sock_select(INETP(desc),FD_CONNECT,0);
	DEBUGF(("tcp_inet_output(%ld): bad state: %04x\r\n", 
		(long)desc->inet.port, desc->inet.state));
    }
 done:
    DEBUGF(("tcp_inet_output(%ld) }\r\n", (long)desc->inet.port));
    return ret;
}

/*-----------------------------------------------------------------------------

   UDP & SCTP (the latter in a 1<->M Mode)

-----------------------------------------------------------------------------*/

#if defined(HAVE_SO_BSDCOMPAT)
#if defined(__linux__)
#include <sys/utsname.h>
static int should_use_so_bsdcompat(void)
{
    /* SMP: FIXME this is probably not SMP safe but may be ok anyway? */
    static int init_done;
    static int so_bsdcompat_is_obsolete;

    if (!init_done) {
	struct utsname utsname;
	unsigned int version, patchlevel;

	init_done = 1;
	if (uname(&utsname) < 0) {
	    fprintf(stderr, "uname: %s\r\n", strerror(sock_errno()));
	    return 1;
	}
	/* Format is <version>.<patchlevel>.<sublevel><extraversion>
	   where the first three are unsigned integers and the last
	   is an arbitrary string. We only care about the first two. */
	if (sscanf(utsname.release, "%u.%u", &version, &patchlevel) != 2) {
	    fprintf(stderr, "uname: unexpected release '%s'\r\n",
		    utsname.release);
	    return 1;
	}
	/* SO_BSDCOMPAT is deprecated and triggers warnings in 2.5
	   kernels. It is a no-op in 2.4 but not in 2.2 kernels. */
	if (version > 2 || (version == 2 && patchlevel >= 5))
	    so_bsdcompat_is_obsolete = 1;
    }
    return !so_bsdcompat_is_obsolete;
}
#else	/* __linux__ */
#define should_use_so_bsdcompat() 1
#endif	/* __linux__ */
#endif	/* HAVE_SO_BSDCOMPAT */

static int packet_inet_init()
{
    return 0;
}

static ErlDrvData packet_inet_start(ErlDrvPort port, char* args, int protocol)
{
    /* "inet_start" returns "ErlDrvData", but in fact it is "inet_descriptor*",
       so we can preserve it as "ErlDrvData":
    */
    ErlDrvData	    drvd = inet_start(port, sizeof(udp_descriptor),
				      protocol);
    udp_descriptor* desc = (udp_descriptor*) drvd;

    if (desc == NULL)
	return ERL_DRV_ERROR_ERRNO;

    desc->read_packets = INET_PACKET_POLL;
    return drvd;
}

static ErlDrvData udp_inet_start(ErlDrvPort port, char *args)
{
    return packet_inet_start(port, args, IPPROTO_UDP);
}

#ifdef HAVE_SCTP
static ErlDrvData sctp_inet_start(ErlDrvPort port, char *args)
{
    return packet_inet_start(port, args, IPPROTO_SCTP);
}
#endif

static void packet_inet_stop(ErlDrvData e)
{
    /* There should *never* be any "empty out q" subscribers on
       an UDP or SCTP socket!
       NB: as in "inet_start", we  can always cast "ErlDRvData"
       into "udp_descriptor*" or "inet_descriptor*":
    */
    udp_descriptor * udesc = (udp_descriptor*) e;
    inet_descriptor* descr = INETP(udesc);

    ASSERT(NO_SUBSCRIBERS(&(descr->empty_out_q_subs)));
    inet_stop(descr);
}

static int packet_error(udp_descriptor* udesc, int err)
{
    inet_descriptor * desc = INETP(udesc);
    if (!desc->active)
	async_error(desc, err);
    driver_failure_posix(desc->port, err);
    return -1;
}

/*
** Various functions accessible via "port_control" on the Erlang side:
*/
static int packet_inet_ctl(ErlDrvData e, unsigned int cmd, char* buf, int len,
			   char** rbuf, int rsize)
{
    int replen;
    udp_descriptor * udesc = (udp_descriptor *) e;
    inet_descriptor* desc  = INETP(udesc);
    int type = SOCK_DGRAM;
    int af;
#ifdef HAVE_SCTP
    if (IS_SCTP(desc)) type = SOCK_SEQPACKET;
#endif

    switch(cmd) {
    case INET_REQ_OPEN:   /* open socket and return internal index */
	DEBUGF(("packet_inet_ctl(%ld): OPEN\r\n", (long)desc->port)); 
	if (len != 1) {
	    return ctl_error(EINVAL, rbuf, rsize);
	}
	switch (buf[0]) {
	case INET_AF_INET:  af = AF_INET; break;
#if defined(HAVE_IN6) && defined(AF_INET6)
	case INET_AF_INET6: af = AF_INET6; break; 
#endif
	default:
	    return ctl_error(EINVAL, rbuf, rsize);
	}
	replen = inet_ctl_open(desc, af, type, rbuf, rsize);

	if ((*rbuf)[0] != INET_REP_ERROR) {
	    if (desc->active)
		sock_select(desc,FD_READ,1);
#ifdef HAVE_SO_BSDCOMPAT
	    /*
	     * Make sure that sending UDP packets to a non existing port on an
	     * existing machine doesn't close the socket. (Linux behaves this
	     * way)
	     */
	    if (should_use_so_bsdcompat()) {
		int one = 1;
		/* Ignore errors */
		sock_setopt(desc->s, SOL_SOCKET, SO_BSDCOMPAT, &one,
			    sizeof(one));
	    }
#endif
	}
	return replen;


    case INET_REQ_FDOPEN:   /* pass in an open (and bound) socket */
	DEBUGF(("packet inet_ctl(%ld): FDOPEN\r\n", (long)desc->port));
	if ((len == 5) && (buf[0] == INET_AF_INET))
	    replen = inet_ctl_fdopen(desc, AF_INET, SOCK_DGRAM,
				     (SOCKET)get_int32(buf+1),rbuf,rsize);
#if defined(HAVE_IN6) && defined(AF_INET6)
	else if ((len == 5) && (buf[0] == INET_AF_INET6))
	    replen = inet_ctl_fdopen(desc, AF_INET6, SOCK_DGRAM,
				     (SOCKET)get_int32(buf+1),rbuf,rsize);
#endif
	else
	    return ctl_error(EINVAL, rbuf, rsize);

	if ((*rbuf)[0] != INET_REP_ERROR) {
	    if (desc->active)
		sock_select(desc,FD_READ,1);
#ifdef HAVE_SO_BSDCOMPAT
	    /*
	     * Make sure that sending UDP packets to a non existing port on an
	     * existing machine doesn't close the socket. (Linux behaves this
	     * way)
	     */
	    if (should_use_so_bsdcompat()) {
		int one = 1;
		/* Ignore errors */
		sock_setopt(desc->s, SOL_SOCKET, SO_BSDCOMPAT, &one,
			    sizeof(one));
	    }
#endif
	}
	return replen;


    case INET_REQ_CLOSE:
	DEBUGF(("packet_inet_ctl(%ld): CLOSE\r\n", (long)desc->port)); 
	erl_inet_close(desc);
	return ctl_reply(INET_REP_OK, NULL, 0, rbuf, rsize);
	return 0;


    case INET_REQ_CONNECT:  {
	/* UDP and SCTP connect operations are completely different. UDP
	   connect means only setting the default peer addr locally,  so
	   it is always synchronous. SCTP connect means actual establish-
	   ing of an SCTP association with a remote peer, so it is async-
	   ronous, and similar to TCP connect. However, unlike TCP, SCTP
	   allows the socket to have multiple simultaneous associations:
	*/
	int code;
	char tbuf[2];
	unsigned timeout;

	DEBUGF(("packet_inet_ctl(%ld): CONNECT\r\n", (long)desc->port)); 
	
	/* INPUT: [ Timeout(4), Port(2), Address(N) ] */

	if (!IS_OPEN(desc))
	    return ctl_xerror(EXBADPORT, rbuf, rsize);

	if (!IS_BOUND(desc))
	    return ctl_xerror(EXBADSEQ,  rbuf, rsize);
#ifdef HAVE_SCTP
	if (IS_SCTP(desc)) { 
	    if (IS_CONNECTING(desc))
		return ctl_error(EINVAL, rbuf, rsize);
	    if (len < 6)
		return ctl_error(EINVAL, rbuf, rsize);
	    timeout = get_int32(buf);
	    buf += 4;
	    len -= 4;

	    /* For SCTP, we do not set the peer's addr in desc->remote, as
	       multiple peers are possible: */
	    inet_address remote;
	    if (inet_set_address(desc->sfamily, &remote, buf, &len) == NULL)
		return ctl_error(EINVAL, rbuf, rsize);
	
	    sock_select(desc, FD_CONNECT, 1);
	    code = sock_connect(desc->s, &remote.sa, len);

	    if ((code == SOCKET_ERROR) && (sock_errno() == EINPROGRESS)) {
		/* XXX: Unix only -- WinSock would have a different cond! */
		desc->state = SCTP_STATE_CONNECTING;
		if (timeout != INET_INFINITY)
		    driver_set_timer(desc->port, timeout);
		enq_async(desc, tbuf, INET_REQ_CONNECT);
	    }
	    else if (code == 0) { /* OK we are connected */
		sock_select(desc, FD_CONNECT, 0);
		desc->state = PACKET_STATE_CONNECTED;
		enq_async(desc, tbuf, INET_REQ_CONNECT);
		async_ok(desc);
	    }
	    else {
		sock_select(desc, FD_CONNECT, 0);
		return ctl_error(sock_errno(), rbuf, rsize);
	    }
	    return ctl_reply(INET_REP_OK, tbuf, 2, rbuf, rsize);
	}
#endif
	/* UDP */
	if (len == 0) {
	    /* What does it mean???  NULL sockaddr??? */
	    sock_connect(desc->s, (struct sockaddr*) NULL, 0);
	    desc->state &= ~INET_F_ACTIVE;
	    enq_async(desc, tbuf, INET_REQ_CONNECT);
	    async_ok (desc);
	}
	else if (len < 6)
	    return ctl_error(EINVAL, rbuf, rsize);
	else {
	    timeout = get_int32(buf); /* IGNORED */
	    buf += 4;
	    len -= 4;
	    if (inet_set_address(desc->sfamily, 
				 &desc->remote, buf, &len) == NULL)
		return ctl_error(EINVAL, rbuf, rsize);
	    
	    code = sock_connect(desc->s,
				(struct sockaddr*) &desc->remote, len);
	    if (code == SOCKET_ERROR) {
		sock_connect(desc->s, (struct sockaddr*) NULL, 0);
		desc->state &= ~INET_F_ACTIVE;
		return ctl_error(sock_errno(), rbuf, rsize);
	    }
	    else /* ok we are connected */ {
		enq_async(desc, tbuf, INET_REQ_CONNECT);
		desc->state |= INET_F_ACTIVE;
		async_ok (desc);
	    }
	}
	return ctl_reply(INET_REP_OK, tbuf, 2, rbuf, rsize);
    }

#ifdef HAVE_SCTP
    case SCTP_REQ_LISTEN:
	{	/* LISTEN is only for SCTP sockets, not UDP. This code is borrowed
		   from the TCP section. Returns: {ok,[]} on success.
		*/
	    DEBUGF(("packet_inet_ctl(%ld): LISTEN\r\n", (long)desc->port)); 
	    if (!IS_SCTP(desc))
		return ctl_xerror(EXBADPORT, rbuf, rsize);
	    if (!IS_OPEN(desc))
		return ctl_xerror(EXBADPORT, rbuf, rsize);
	    if (!IS_BOUND(desc))
		return ctl_xerror(EXBADSEQ, rbuf, rsize);

	    /* The arg is a binary value: 1:enable, 0:disable */
	    if (len != 1)
		return ctl_error(EINVAL, rbuf, rsize);
	    int flag = get_int8(buf);

	    if (sock_listen(desc->s, flag) == SOCKET_ERROR)
		return ctl_error(sock_errno(), rbuf, rsize);

	    desc->state = SCTP_STATE_LISTEN;   /* XXX: not used? */
	    return ctl_reply(INET_REP_OK, NULL, 0, rbuf, rsize);
	}

    case SCTP_REQ_BINDX:
	{   /* Multi-homing bind for SCTP: */
	    if (!IS_SCTP(desc))
		return ctl_xerror(EXBADPORT, rbuf, rsize);

	    /* Construct the list of addresses we bind to. The curr limit is
	       256 addrs. Buff structure: Flags(1), ListItem,...:
	    */
	    char* curr     = buf;
	    int   add_flag = get_int8(curr);
	    curr++;
	    struct sockaddr addrs[256];
	    int   n;

	    for(n=0; n < 256 && curr < buf+len; n++)
		{
		    /* List item format: Port(2), IP(4|16) -- compatible with
		       "inet_set_address": */
		    inet_address tmp;
		    int  alen  = buf + len - curr;
		    curr = inet_set_address(desc->sfamily, &tmp, curr, &alen);
		    if (curr == NULL)
			return ctl_error(EINVAL, rbuf, rsize);

		    /* Now: we need to squeeze "tmp" into the size of "sockaddr",
		       which is smaller than "tmp" for IPv6 (extra IN6 info will
		       be cut off): */
		    memcpy(addrs + n, &tmp, sizeof(struct sockaddr));
		}
	    /* Make the real flags: */
	    int rflag = add_flag ? SCTP_BINDX_ADD_ADDR : SCTP_BINDX_REM_ADDR;

	    /* Invoke the call: */
	    if (sctp_bindx(desc->s, addrs, n, rflag) < 0)
		return ctl_error(sock_errno(), rbuf, rsize);

	    desc->state = INET_STATE_BOUND;

	    return ctl_reply(INET_REP_OK, NULL, 0, rbuf, rsize);
	}
#endif  /* HAVE_SCTP */

    case PACKET_REQ_RECV:
	{	/* THIS IS A FRONT-END for "recv*" requests. It only enqueues the
		   request  and possibly returns the data  immediately available.
		   The actual data returning function is the back-end ("*input"):
		*/
	    unsigned timeout;
	    char tbuf[2];

	    DEBUGF(("packet_inet_ctl(%ld): RECV\r\n", (long)desc->port)); 
	    /* INPUT: Timeout(4), Length(4) */
	    if (!IS_OPEN(desc))
		return ctl_xerror(EXBADPORT, rbuf, rsize);
	    if (!IS_BOUND(desc))
		return ctl_error(EINVAL, rbuf, rsize);
	    if (desc->active || (len != 8))
		return ctl_error(EINVAL, rbuf, rsize);
	    timeout = get_int32(buf);
	    /* The 2nd arg, Length(4), is ignored for both UDP ans SCTP protocols,
	       since they are msg-oriented. */

	    if (enq_async(desc, tbuf, PACKET_REQ_RECV) < 0)
		return ctl_error(EALREADY, rbuf, rsize);

	    if (packet_inet_input(udesc, desc->event) == 0) {
		if (timeout == 0)
		    async_error_am(desc, am_timeout);
		else {
		    if (timeout != INET_INFINITY)
			driver_set_timer(desc->port, timeout);
		}
	    }
	    return ctl_reply(INET_REP_OK, tbuf, 2, rbuf, rsize);
	}
	
    default:
	/* Delegate the request to the INET layer. In particular,
	   INET_REQ_BIND goes here. If the req is not recognised
	   there either, an error is returned:
	*/
	return inet_ctl(desc, cmd, buf, len, rbuf, rsize);
    }
}

static void packet_inet_timeout(ErlDrvData e)
{
    udp_descriptor  * udesc = (udp_descriptor*) e;
    inet_descriptor * desc  = INETP(udesc);
    if (!(desc->active))
	sock_select(desc, FD_READ, 0);
    async_error_am (desc, am_timeout);
}


/* THIS IS A "send*" REQUEST; on the Erlang side: "port_command".
** input should be: P1 P0 Address buffer .
** For UDP,  buffer (after Address) is just data to be sent.
** For SCTP, buffer contains a list representing 2 items:
**   (1) 6 parms for sctp_sndrcvinfo, as in sctp_get_sendparams();
**   (2) 0+ real data bytes.
** There is no destination address -- SCTYP send is performed over
** an existing association, using "sctp_sndrcvinfo" specified.
*/
static void packet_inet_command(ErlDrvData e, char* buf, int len)
{
    udp_descriptor * udesc= (udp_descriptor*) e;
    inet_descriptor* desc = INETP(udesc);
    char* ptr		  = buf;
    char* qtr;
    int sz;
    int code;
    inet_address other;

    desc->caller = driver_caller(desc->port);

    if (!IS_OPEN(desc)) {
	inet_reply_error(desc, EINVAL);
	return;
    }
    if (!IS_BOUND(desc)) {
	inet_reply_error(desc, EINVAL);
	return;
    }

#ifdef HAVE_SCTP
    if (IS_SCTP(desc))
    {
	int           data_len;
	struct iovec  iov[1];		 /* For real data            */
	struct msghdr mhdr;		 /* Message wrapper          */
	struct sctp_sndrcvinfo *sri;     /* The actual ancilary data */
	union {                          /* For ancilary data        */
	    struct cmsghdr hdr;
	    char ancd[CMSG_SPACE(sizeof(*sri))];
	} cmsg;
	
	if (len < SCTP_GET_SENDPARAMS_LEN) {
	    inet_reply_error(desc, EINVAL);
	    return;
	}
	
	/* The ancilary data */
	sri = (struct sctp_sndrcvinfo *) (CMSG_DATA(&cmsg.hdr));
	/* Get the "sndrcvinfo" from the buffer, advancing the "ptr": */
	ptr  = sctp_get_sendparams(sri, ptr);
	
	/* The ancilary data wrapper */
	cmsg.hdr.cmsg_level = IPPROTO_SCTP;
	cmsg.hdr.cmsg_type  = SCTP_SNDRCV;
	cmsg.hdr.cmsg_len   = CMSG_LEN(sizeof(*sri));
	
	data_len = (buf + len) - ptr;
	/* The whole msg */
	mhdr.msg_name           = NULL;	        /* Already connected  */
	mhdr.msg_namelen        = 0;
	if (data_len == 0) {
	    mhdr.msg_iov    = NULL;             /* No real data */
	    mhdr.msg_iovlen = 0;
	} else {
	    iov[0].iov_len    = data_len;
	    iov[0].iov_base   = ptr;            /* The real data */
	    mhdr.msg_iov      = iov;
	    mhdr.msg_iovlen   = 1;
	}
	mhdr.msg_control        = cmsg.ancd;    /* For ancilary data  */
	mhdr.msg_controllen     = cmsg.hdr.cmsg_len;
	mhdr.msg_flags          = 0;            /* Not used with "sendmsg"   */
	
	/* Now do the actual sending. NB: "flags" in "sendmsg" itself are NOT
	   used: */
	code = sock_sendmsg(desc->s, &mhdr, 0);
	goto check_result_code;
    }
#endif
    /* UDP socket. Even if it is connected, there is an address prefix
       here -- ignored for connected sockets: */
    sz = len;
    qtr = inet_set_address(desc->sfamily, &other, ptr, &sz);
    if (qtr == NULL) {
	inet_reply_error(desc, EINVAL);
	return;
    }
    len -= (qtr - ptr);
    ptr = qtr;
    /* Now "ptr" is the user data ptr, "len" is data length: */
    inet_output_count(desc, len);
    
    if (desc->state & INET_F_ACTIVE) { /* connected (ignore address) */
	code = sock_send(desc->s, ptr, len, 0);
    }
    else {
	code = sock_sendto(desc->s, ptr, len, 0, &other.sa, sz);
    }

#ifdef HAVE_SCTP    
 check_result_code:
    /* "code" analysis is the same for both SCTP and UDP cases above: */
#endif
    if (code == SOCKET_ERROR) {
	int err = sock_errno();
	inet_reply_error(desc, err);
    }
    else
	inet_reply_ok(desc);
}


#ifdef __WIN32__
static void packet_inet_event(ErlDrvData e, ErlDrvEvent event)
{
    udp_descriptor * udesc = (udp_descriptor*)e;
    inet_descriptor* desc  = INETP(udesc);
    WSANETWORKEVENTS netEv;

    if ((WSAEnumNetworkEvents)(desc->s, desc->event, &netEv) != 0) {
	DEBUGF(( "port %d: EnumNetwrokEvents = %d\r\n", 
		desc->port, sock_errno() ));
	return; /* -1; */
    }
    netEv.lNetworkEvents |= desc->forced_events;
    if (netEv.lNetworkEvents & FD_READ) {
	packet_inet_input(udesc, (HANDLE)event);
    }
}

#endif

static void packet_inet_drv_input(ErlDrvData e, ErlDrvEvent event)
{
    (void)  packet_inet_input((udp_descriptor*)e, (HANDLE)event);
}

/*
** THIS IS A BACK-END FOR "recv*" REQUEST, which actually receives the
**	data requested, and delivers them to the caller:
*/
static int packet_inet_input(udp_descriptor* udesc, HANDLE event)
{
    inet_descriptor* desc = INETP(udesc);
    int n;
    unsigned int len;
    inet_address other;
    char abuf[sizeof(inet_address)];  /* buffer address; enough??? */
    int  sz;
    char* ptr;
    ErlDrvBinary* buf; /* binary */
    int packet_count = udesc->read_packets;
    int count = 0;     /* number of packets delivered to owner */
#ifdef HAVE_SCTP
    struct msghdr mhdr;	  	     /* Top-level msg structure    */
    struct iovec  iov[1]; 	     /* Data or Notification Event */
    char   ancd[SCTP_ANC_BUFF_SIZE]; /* Ancillary Data		   */
    int short_recv = 0;
#endif

    while(packet_count--) {
	len = sizeof(other);
	sz = desc->bufsz;
	/* Allocate space for message and address. NB: "bufsz" is in "desc",
	   but the "buf" itself is allocated separately:
	*/
	if ((buf = alloc_buffer(sz+len)) == NULL)
	    return packet_error(udesc, ENOMEM);
	ptr = buf->orig_bytes + len;  /* pointer to message part */

	/* Note: On Windows NT, recvfrom() fails if the socket is connected. */
#ifdef HAVE_SCTP
	/* For SCTP we must use recvmsg() */
	if (IS_SCTP(desc)) {
	    iov->iov_base = ptr; /* Data will come here    */
	    iov->iov_len  = sz;	 /* Remaining buffer space */
	    
	    mhdr.msg_name	= &other;  /* Peer addr comes into "other" */
	    mhdr.msg_namelen	= len;
	    mhdr.msg_iov	= iov;
	    mhdr.msg_iovlen	= 1;
	    mhdr.msg_control	= ancd;
	    mhdr.msg_controllen	= SCTP_ANC_BUFF_SIZE;
	    mhdr.msg_flags	= 0;	   /* To be filled by "recvmsg"    */
	    
	    /* Do the actual SCTP receive: */
	    n = sock_recvmsg(desc->s, &mhdr, 0);
	    goto check_result;
	}
#endif
	/* Use recv() instead on connected sockets. */
	if ((desc->state & INET_F_ACTIVE)) {
	    n = sock_recv(desc->s, ptr, sz, 0);
	    other = desc->remote;
	}
	else
	    n = sock_recvfrom(desc->s, ptr, sz, 0, &other.sa, &len);

#ifdef HAVE_SCTP
    check_result:
#endif
	/* Analyse the result: */
	if (n == SOCKET_ERROR
#ifdef HAVE_SCTP
	    || (short_recv = (IS_SCTP(desc) && !(mhdr.msg_flags & MSG_EOR)))
	    /* NB: here we check for EOR not being set -- this is an error as
	       well, we don't support partial msgs:
	    */
#endif
	    ) {
	    int err = sock_errno();
	    release_buffer(buf);
	    if (err != ERRNO_BLOCK) {
		if (!desc->active) {
#ifdef HAVE_SCTP
		    if (short_recv)
			async_error_am(desc, am_short_recv);
		    else
#else
			async_error(desc, err);
#endif
		    driver_cancel_timer(desc->port);
		    sock_select(desc,FD_READ,0);
		}
		else {
		    /* This is for an active desc only: */
		    packet_error_message(udesc, err);
		}
	    }
	    else if (!desc->active)
		sock_select(desc,FD_READ,1);
	    return count;		/* strange, not ready */
	}
	else {
	    int offs;
	    int nsz;
	    int code;
	    unsigned int alen = len;
	    void * extra = NULL;

	    inet_input_count(desc, n);
	    inet_get_address(desc->sfamily, abuf, &other, &alen);
	    /* Copy formatted address to the buffer allocated; "alen" is the
	       actual length which must be <= than the original reserved "len".
	       This means that the addr + data in the buffer are contiguous,
	       but they may start not at the "orig_bytes", but with some "offs"
	       from them:
	    */
	    ASSERT (alen <= len);
	    sys_memcpy(ptr - alen, abuf, alen); 
	    ptr -= alen;
	    nsz  = n + alen;              /* nsz = data + address */
	    offs = ptr - buf->orig_bytes; /* initial pointer offset */

	    /* Check if we need to reallocate binary */
	    if ((desc->mode == INET_MODE_BINARY) &&
		(desc->hsz < n) && (nsz < BIN_REALLOC_LIMIT(sz))) {
		ErlDrvBinary* tmp;
		if ((tmp = realloc_buffer(buf,nsz+offs)) != NULL)
		    buf = tmp;
	    }
#ifdef HAVE_SCTP
	    if (IS_SCTP(desc)) extra = &mhdr;
#endif
	    /* Actual parsing and return of the data received, occur here: */
	    code = packet_reply_binary_data(desc, (unsigned int)alen,
					    buf, offs, nsz, extra);
	    free_buffer(buf);
	    if (code < 0)
		return count;
	    count++;
	    if (!desc->active) {
		driver_cancel_timer(desc->port); /* possibly cancel */
		sock_select(desc,FD_READ,0);
		return count;  /* passive mode (read one packet only) */
	    }
	}
    }
    return count;
}

static void packet_inet_drv_output(ErlDrvData e, ErlDrvEvent event)
{
    (void)  packet_inet_output((udp_descriptor*)e, (HANDLE)event);
}

/* UDP/SCTP socket ready for output:
**	This is a Back-End for Non-Block SCTP Connect (SCTP_STATE_CONNECTING)
*/
static int packet_inet_output(udp_descriptor* udesc, HANDLE event)
{
    inet_descriptor* desc = INETP(udesc);
    int ret = 0;
    ErlDrvPort ix = desc->port;

    DEBUGF(("packet_inet_output(%ld) {s=%d\r\n", 
	    (long)desc->port, desc->s));

    if (desc->state == SCTP_STATE_CONNECTING) {
	sock_select(desc, FD_CONNECT, 0);

	driver_cancel_timer(ix);  /* posssibly cancel a timer */
#ifndef __WIN32__
	/*
	 * XXX This is strange.  This *should* work on Windows NT too,
	 * but doesn't.  An bug in Winsock 2.0 for Windows NT?
	 *
	 * See "Unix Netwok Programming", W.R.Stevens, p 412 for a
	 * discussion about Unix portability and non blocking connect.
	 */

#ifndef SO_ERROR
	{
	    int sz = sizeof(desc->remote);
	    int code = sock_peer(desc->s,
				 (struct sockaddr*) &desc->remote, &sz);

	    if (code == SOCKET_ERROR) {
		desc->state = PACKET_STATE_BOUND;  /* restore state */
		ret =  async_error(desc, sock_errno());
		goto done;
	    }
	}
#else
	{
	    int error = 0;	/* Has to be initiated, we check it */
	    unsigned int sz = sizeof(error);   /* even if we get -1 */
	    int code = sock_getopt(desc->s, SOL_SOCKET, SO_ERROR, 
				   (void *)&error, &sz);

	    if ((code < 0) || error) {
		desc->state = PACKET_STATE_BOUND;  /* restore state */
		ret = async_error(desc, error);
		goto done;
	    }
	}
#endif /* SOCKOPT_CONNECT_STAT */
#endif /* !__WIN32__ */

	desc->state = PACKET_STATE_CONNECTED;
	async_ok(desc);
    }
    else {
	sock_select(desc,FD_CONNECT,0);

	DEBUGF(("packet_inet_output(%ld): bad state: %04x\r\n", 
		(long)desc->port, desc->state));
    }
 done:
    DEBUGF(("packet_inet_output(%ld) }\r\n", (long)desc->port));
    return ret;
}

/*---------------------------------------------------------------------------*/

#ifdef __WIN32__

/*
 * Although we no longer need to lookup all of winsock2 dynamically,
 * there are still some function(s) we need to look up.
 */
static void find_dynamic_functions(void)
{
    char kernel_dll_name[] = "kernel32";
    HMODULE module;
    module = GetModuleHandle(kernel_dll_name);
    fpSetHandleInformation = (module != NULL) ? 
	(BOOL (WINAPI *)(HANDLE,DWORD,DWORD)) 
	    GetProcAddress(module,"SetHandleInformation") : 
	NULL;
}
			      


/*
 * We must make sure that the socket handles are not inherited
 * by port programs (if there are inherited, the sockets will not
 * get closed when the emulator terminates, and epmd and other Erlang
 * nodes will not notice that we have exited).
 *
 * XXX It is not clear whether this works/is necessary in Windows 95.
 * There could also be problems with Winsock implementations from other
 * suppliers than Microsoft.
 */

static SOCKET
make_noninheritable_handle(SOCKET s)
{
    if (s != INVALID_SOCKET) {
	if (fpSetHandleInformation != NULL) {
	    (*fpSetHandleInformation)((HANDLE) s, HANDLE_FLAG_INHERIT, 0);
	} else {
	    HANDLE non_inherited;
	    HANDLE this_process = GetCurrentProcess();
	    if (DuplicateHandle(this_process, (HANDLE) s,
				this_process, &non_inherited, 0,
				FALSE, DUPLICATE_SAME_ACCESS)) {
		sock_close(s);
		s = (SOCKET) non_inherited;
	    }
	} 	
    }
    return s;
}

#endif  /* UDP for __WIN32__ */

/*
 * Multi-timers
 */

static void absolute_timeout(unsigned millis, ErlDrvNowData *out)
{
    unsigned rest;
    unsigned long millipart;
    unsigned long secpart;
    unsigned long megasecpart;
    unsigned tmo_secs = (millis / 1000U);
    unsigned tmo_millis = (millis % 1000);
    driver_get_now(out);
    rest = (out->microsecs) % 1000;
    millipart = ((out->microsecs) / 1000UL);
    if (rest >= 500) {
	++millipart;
    }
    secpart = out->secs;
    megasecpart = out->megasecs;
    millipart += tmo_millis;
    secpart += (millipart / 1000000UL);
    millipart %= 1000000UL;
    secpart += tmo_secs;
    megasecpart += (secpart / 1000000UL);
    secpart %= 1000000UL;
    out->megasecs = megasecpart;
    out->secs = secpart;
    out->microsecs = (millipart * 1000UL);
}

static unsigned relative_timeout(ErlDrvNowData *in) 
{
    ErlDrvNowData now;
    unsigned rest;
    unsigned long millipart, in_millis, in_secs, in_megasecs;

    driver_get_now(&now);

    in_secs = in->secs;
    in_megasecs = in->megasecs;

    rest = (now.microsecs) % 1000;
    millipart = ((now.microsecs) / 1000UL);
    if (rest >= 500) {
	++millipart;
    }
    in_millis = ((in->microsecs) / 1000UL);
    if ( in_millis < millipart ) {
	if (in_secs > 0) {
	    --in_secs;
	} else {
	    in_secs = (1000000UL - 1UL);
	    if (in_megasecs <= now.megasecs) {
		return 0;
	    } else {
		--in_megasecs;
	    }
	}
	in_millis += 1000UL;
    }
    in_millis -= millipart;
    
    if (in_secs < now.secs) {
	if (in_megasecs <= now.megasecs) {
	    return 0;
	} else {
	    --in_megasecs;
	}
	in_secs += 1000000;
    }
    in_secs -= now.secs;
    if (in_megasecs < now.megasecs) {
	return 0;
    } else {
	in_megasecs -= now.megasecs;
    }
    return (unsigned) ((in_megasecs * 1000000000UL) + 
		       (in_secs * 1000UL) + 
		       in_millis);
}

#ifdef DEBUG
static int nowcmp(ErlDrvNowData *d1, ErlDrvNowData *d2)
{
    /* Assume it's not safe to do signed conversion on megasecs... */
    if (d1->megasecs < d2->megasecs) {
	return -1;
    } else if (d1->megasecs > d2->megasecs) {
	return 1;
    } else if (d1->secs != d2->secs) {
	return ((int) d1->secs) - ((int) d2->secs);
    } 
    return ((int) d1->microsecs) - ((int) d2->microsecs);
}
#endif

static void fire_multi_timers(MultiTimerData **first, ErlDrvPort port,
			      ErlDrvData data)
{
    unsigned next_timeout;
    if (!*first) {
	ASSERT(0);
	return;
    }
#ifdef DEBUG
    {
	ErlDrvNowData chk;
	driver_get_now(&chk);
	chk.microsecs /= 10000UL;
	chk.microsecs *= 10000UL;
	chk.microsecs += 10000;
	ASSERT(nowcmp(&chk,&((*first)->when)) >= 0);
    }
#endif
    do {
	MultiTimerData *save = *first;
	*first = save->next;
	(*(save->timeout_function))(data,save->caller);
	FREE(save);
	if (*first == NULL) {
	    return;
	}
	(*first)->prev = NULL;
	next_timeout = relative_timeout(&((*first)->when));
    } while (next_timeout == 0);
    driver_set_timer(port,next_timeout);
}

static void clean_multi_timers(MultiTimerData **first, ErlDrvPort port)
{
    MultiTimerData *p;
    if (*first) {
	driver_cancel_timer(port);
    }
    while (*first) {
	p = *first;
	*first = p->next;
	FREE(p);
    }
}
static void remove_multi_timer(MultiTimerData **first, ErlDrvPort port, MultiTimerData *p)
{
    if (p->prev != NULL) {
	p->prev->next = p->next;
    } else {
	driver_cancel_timer(port);
	*first = p->next;
	if (*first) {
	    unsigned ntmo = relative_timeout(&((*first)->when));
	    driver_set_timer(port,ntmo);
	}
    }
    if (p->next != NULL) {
	p->next->prev = p->prev;
    }
    FREE(p);
}

static MultiTimerData *add_multi_timer(MultiTimerData **first, ErlDrvPort port, 
				       ErlDrvTermData caller, unsigned timeout,
				       void (*timeout_fun)(ErlDrvData drv_data, 
							   ErlDrvTermData caller))
{
    MultiTimerData *mtd, *p, *s;
    mtd = ALLOC(sizeof(MultiTimerData));
    absolute_timeout(timeout, &(mtd->when));
    mtd->timeout_function = timeout_fun;
    mtd->caller = caller;
    mtd->next = mtd->prev = NULL;
    for(p = *first,s = NULL; p != NULL; s = p, p = p->next) {
	if (p->when.megasecs >= mtd->when.megasecs) {
	    break;
	}
    }
    if (!p || p->when.megasecs > mtd->when.megasecs) {
	goto found;
    }
    for (; p!= NULL; s = p, p = p->next) {
	if (p->when.secs >= mtd->when.secs) {
	    break;
	}
    }
    if (!p || p->when.secs > mtd->when.secs) {
	goto found;
    }
    for (; p!= NULL; s = p, p = p->next) {
	if (p->when.microsecs >= mtd->when.microsecs) {
	    break;
	}
    }
 found:
    if (!p) {
	if (!s) {
	    *first = mtd;
	} else {
	    s->next = mtd;
	    mtd->prev = s;
	}
    } else {
	if (!s) {
	    *first = mtd;
	} else {
	    s->next = mtd;
	    mtd->prev = s;
	}
	mtd->next = p;
	p->prev = mtd;
    }
    if (!s) {
	if (mtd->next) {
	    driver_cancel_timer(port);
	}
	driver_set_timer(port,timeout);
    }
    return mtd;
}
	




/*-----------------------------------------------------------------------------

   Subscription

-----------------------------------------------------------------------------*/

static int
save_subscriber(subs, subs_pid)
subs_list *subs; ErlDrvTermData subs_pid;
{
  subs_list *tmp;

  if(NO_SUBSCRIBERS(subs)) {
    subs->subscriber = subs_pid;
    subs->next = NULL;
  }
  else {
    tmp = subs->next;
    subs->next = ALLOC(sizeof(subs_list));
    if(subs->next == NULL) {
      subs->next = tmp;
      return 0;
    }
    subs->next->subscriber = subs_pid;
    subs->next->next = tmp;
  }
  return 1;
}

static void
free_subscribers(subs)
subs_list *subs;
{
  subs_list *this;
  subs_list *next;

  this = subs->next;
  while(this) {
    next = this->next;
    FREE((void *) this);
    this = next;
  }

  subs->subscriber = NO_PROCESS;
  subs->next = NULL;
}

static void send_to_subscribers
(
    ErlDrvPort	   port,
    subs_list	   *subs,
    int		   free_subs,
    ErlDrvTermData msg[],
    int msg_len
)
{
  subs_list *this;
  subs_list *next;
  int first = 1;

  if(NO_SUBSCRIBERS(subs))
    return;

  this = subs;
  while(this) {
    
    (void) driver_send_term(port, this->subscriber, msg, msg_len);

    if(free_subs && !first) {
      next = this->next;
      FREE((void *) this);
      this = next;
    }
    else
      this = this->next;
    first = 0;
  }

  if(free_subs) {
    subs->subscriber = NO_PROCESS;
    subs->next = NULL;
  }

}

/*
 * A *very* limited socket interface. Used by the memory tracer
 * (erl_mtrace.c).
 */
#include "erl_sock.h"

erts_sock_t erts_sock_open(void)
{
    SOCKET s;
    
    if(!sock_init())
	return ERTS_SOCK_INVALID_SOCKET;

    s = sock_open(AF_INET, SOCK_STREAM, 0);

    if (s == INVALID_SOCKET)
	return ERTS_SOCK_INVALID_SOCKET;

    return (erts_sock_t) s;
}

void erts_sock_close(erts_sock_t socket)
{
    if (socket != ERTS_SOCK_INVALID_SOCKET)
	sock_close((SOCKET) socket);
}


int erts_sock_connect(erts_sock_t socket, byte *ip_addr, int len, Uint16 port)
{
    SOCKET s = (SOCKET) socket;
    char buf[2 + 4];
    int blen = 6;
    inet_address addr;

    if (socket == ERTS_SOCK_INVALID_SOCKET || len != 4)
	return 0;

    put_int16(port, buf);
    memcpy((void *) (buf + 2), (void *) ip_addr, 4);

    if (!inet_set_address(AF_INET, &addr, buf, &blen))
	return 0;

    if (SOCKET_ERROR == sock_connect(s,
				     (struct sockaddr *) &addr,
				     sizeof(struct sockaddr_in)))
	return 0;
    return 1;
}

Sint erts_sock_send(erts_sock_t socket, const void *buf, Sint len)
{
    return (Sint) sock_send((SOCKET) socket, buf, (size_t) len, 0);
}


int erts_sock_gethostname(char *buf, int bufsz)
{
    if (sock_hostname(buf, bufsz) == SOCKET_ERROR)
	return -1;
    return 0;
}


int erts_sock_errno()
{
    return sock_errno();
}
