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
 *     $Id$
 */
/*
 * Purpose: Connect to any node at any host. (EI version)
 */

#include "config.h"

#include <stdlib.h>
#include <sys/types.h>
#include <fcntl.h>

#ifdef __WIN32__
#include <winsock2.h>
#include <windows.h>
#include <winbase.h>

#elif VXWORKS
#include <vxWorks.h>
#include <hostLib.h>
#include <selectLib.h>
#include <ifLib.h>
#include <sockLib.h>
#include <taskLib.h>
#include <inetLib.h>

#include <unistd.h>
#include <sys/types.h>
#include <sys/times.h>
#include <unistd.h>
#include <sys/types.h>
#include <sys/socket.h>
#include <netinet/in.h>
#include <netinet/tcp.h> 
#include <timers.h> 

#define getpid() taskIdSelf()

#else /* some other unix */
#include <unistd.h>
#include <sys/types.h>
#include <sys/times.h>

#if TIME_WITH_SYS_TIME
# include <sys/time.h>
# include <time.h>
#else
# if HAVE_SYS_TIME_H
#  include <sys/time.h>
# else
#  include <time.h>
# endif
#endif

#include <sys/socket.h>
#include <netinet/in.h>
#include <netinet/tcp.h> 
#include <arpa/inet.h>
#include <netdb.h>
#include <sys/utsname.h>  /* for gen_challenge (NEED FIX?) */
#include <time.h>
#endif

/* common includes */
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <errno.h>
#include <ctype.h>

#include "eidef.h"
#include "eiext.h"
#include "ei_portio.h"
#include "ei_internal.h"
#include "ei_connect_int.h"
#include "ei_locking.h"
#include "eisend.h"
#include "eirecv.h"
#include "eimd5.h"
#include "putget.h"
#include "ei_resolve.h"
#include "ei_epmd.h"

int ei_tracelevel = 0;

#define COOKIE_FILE "/.erlang.cookie"
#define EI_MAX_HOME_PATH 1024

/* FIXME why not macro? */
static char *null_cookie = "";

static int get_cookie(char *buf, int len);
static int get_home(char *buf, int size);

/* forwards */
static unsigned gen_challenge(void);
static void gen_digest(unsigned challenge, char cookie[], 
		       unsigned char digest[16]);
static int send_status(int fd, char *status);
static int recv_status(int fd);
static int send_challenge(int fd, char *nodename, 
			  unsigned challenge, unsigned version);
static int recv_challenge(int fd, unsigned *challenge, 
			  unsigned *version,
			  unsigned *flags, ErlConnect *namebuf);
static int send_challenge_reply(int fd, unsigned char digest[16], 
				unsigned challenge);
static int recv_challenge_reply(int fd, 
				unsigned our_challenge,
				char cookie[], 
				unsigned *her_challenge);
static int send_challenge_ack(int fd, unsigned char digest[16]);
static int recv_challenge_ack(int fd, 
			      unsigned our_challenge,
			      char cookie[]);
static int send_name(int fd, char *nodename, 
		     unsigned version); 

/* Common for both handshake types */
static int recv_name(int fd, 
		     unsigned *version,
		     unsigned *flags, ErlConnect *namebuf);


/***************************************************************************
 *
 *  For each file descriptor returned from ei_connect() we save information
 *  about distribution protocol version, node information for this node
 *  and the cookie.
 *
 ***************************************************************************/

typedef struct ei_socket_info_s {
    int socket;
    int dist_version;
    ei_cnode cnode;	/* A copy, not a pointer. We don't know when freed */
    char cookie[EI_MAX_COOKIE_SIZE+1];
} ei_socket_info;

int ei_n_sockets = 0, ei_sz_sockets = 0;
ei_socket_info *ei_sockets = NULL;
#ifdef _REENTRANT
ei_mutex_t* ei_sockets_lock = NULL;
#endif /* _REENTRANT */


/***************************************************************************
 *
 *  XXX
 *
 ***************************************************************************/

static int put_ei_socket_info(int fd, int dist_version, char* cookie, ei_cnode *ec)
{
    int i;

#ifdef _REENTRANT
    ei_mutex_lock(ei_sockets_lock, 0);
#endif /* _REENTRANT */
    for (i = 0; i < ei_n_sockets; ++i) {
	if (ei_sockets[i].socket == fd) {
	    if (dist_version == -1) {
		memmove(&ei_sockets[i], &ei_sockets[i+1],
			sizeof(ei_sockets[0])*(ei_n_sockets-i-1));
	    } else {
		ei_sockets[i].dist_version = dist_version;
		/* Copy the content, see ei_socket_info */
		ei_sockets[i].cnode = *ec;
		strcpy(ei_sockets[i].cookie, cookie);
	    }
#ifdef _REENTRANT
	    ei_mutex_unlock(ei_sockets_lock);
#endif /* _REENTRANT */
	    return 0;
	}
    }
    if (ei_n_sockets == ei_sz_sockets) {
	ei_sz_sockets += 5;
	ei_sockets = realloc(ei_sockets,
			     sizeof(ei_sockets[0])*ei_sz_sockets);
	if (ei_sockets == NULL) {
	    ei_sz_sockets = ei_n_sockets = 0;
#ifdef _REENTRANT
	    ei_mutex_unlock(ei_sockets_lock);
#endif /* _REENTRANT */
	    return -1;
	}
	ei_sockets[ei_n_sockets].socket = fd;
	ei_sockets[ei_n_sockets].dist_version = dist_version;
	ei_sockets[i].cnode = *ec;
	strcpy(ei_sockets[ei_n_sockets].cookie, cookie);
	++ei_n_sockets;
    }
#ifdef _REENTRANT
    ei_mutex_unlock(ei_sockets_lock);
#endif /* _REENTRANT */
    return 0;
}

#if 0
/* FIXME not used ?! */
static int remove_ei_socket_info(int fd, int dist_version, char* cookie)
{
    return put_ei_socket_info(fd, -1, NULL);
}
#endif

static ei_socket_info* get_ei_socket_info(int fd)
{
    int i;
#ifdef _REENTRANT
    ei_mutex_lock(ei_sockets_lock, 0);
#endif /* _REENTRANT */
    for (i = 0; i < ei_n_sockets; ++i)
	if (ei_sockets[i].socket == fd) {
	    /*fprintf("get_ei_socket_info %d  %d \"%s\"\n",
		    fd, ei_sockets[i].dist_version, ei_sockets[i].cookie);*/
#ifdef _REENTRANT
	    ei_mutex_unlock(ei_sockets_lock);
#endif /* _REENTRANT */
	    return &ei_sockets[i];
	}
#ifdef _REENTRANT
    ei_mutex_unlock(ei_sockets_lock);
#endif /* _REENTRANT */
    return NULL;
}

ei_cnode *ei_fd_to_cnode(int fd)
{
    ei_socket_info *sockinfo = get_ei_socket_info(fd);
    if (sockinfo == NULL) return NULL;
    return &sockinfo->cnode;
}

/***************************************************************************
 *  XXXX
 ***************************************************************************/

int ei_distversion(int fd)
{
    ei_socket_info* e = get_ei_socket_info(fd);
    if (e == NULL)
	return -1;
    else
	return e->dist_version;
}

static const char* ei_cookie(int fd)
{
    ei_socket_info* e = get_ei_socket_info(fd);
    if (e == NULL)
	return NULL;
    else
	return e->cookie;
}

const char *ei_thisnodename(const ei_cnode* ec)
{
    return ec->thisnodename;
}

const char *ei_thishostname(const ei_cnode* ec)
{
    return ec->thishostname;
}

const char *ei_thisalivename(const ei_cnode* ec)
{
    return ec->thisalivename;
}

short ei_thiscreation(const ei_cnode* ec)
{
    return ec->creation;
}

/* FIXME: this function is not an api, why not? */
const char *ei_thiscookie(const ei_cnode* ec)
{
    return (const char *)ec->ei_connect_cookie;
}

erlang_pid *ei_self(ei_cnode* ec)
{
    return &ec->self;
}

/* two internal functions that will let us support different cookies
* (to be able to connect to other nodes that don't have the same
* cookie as each other or us)
*/
const char *ei_getfdcookie(int fd)
{
    const char* r = ei_cookie(fd);
    if (r == NULL) r = "";
    return r;
}

/* call with cookie to set value to use on descriptor fd,
* or specify NULL to use default
*/
/* FIXME why defined but not used? */
#if 0
static int ei_setfdcookie(ei_cnode* ec, int fd, char *cookie)
{
    int dist_version = ei_distversion(fd);

    if (cookie == NULL)
	cookie = ec->ei_connect_cookie;
    return put_ei_socket_info(fd, dist_version, cookie);
}
#endif

static int get_int32(unsigned char *s)
{
    return ((s[0] << 24) | (s[1] << 16) | (s[2] << 8) | (s[3] ));
}


#ifdef __WIN32__
void win32_error(char *buf, int buflen)
{
    FormatMessage(FORMAT_MESSAGE_FROM_SYSTEM|FORMAT_MESSAGE_IGNORE_INSERTS,
	0,	/* n/a */
	WSAGetLastError(), /* error code */
	MAKELANGID(LANG_NEUTRAL, SUBLANG_DEFAULT), /* language */
	buf,
	buflen,
	NULL);
    return;
}

static int initWinSock(void)
{
    WORD wVersionRequested;  
    WSADATA wsaData; 
    int i; 
    /* FIXME problem for threaded ? */ 
    static int initialized = 0;
    
    wVersionRequested = MAKEWORD(1, 1); 
    if (!initialized) {
	initialized = 1;
	/* FIXME not terminate, just a message?! */
	if ((i = WSAStartup(wVersionRequested, &wsaData))) {
	    EI_TRACE_ERR1("ei_connect_init",
			  "ERROR: can't initialize windows sockets: %d",i);
	    return 0;
	}
	
	if (LOBYTE(wsaData.wVersion) != 1 || HIBYTE(wsaData.wVersion) != 1) { 
	    EI_TRACE_ERR0("initWinSock","ERROR: this version of windows "
			  "sockets not supported");
	    WSACleanup(); 
	    return 0;
	}
    }
    return 1;
}
#endif

/*
* Perhaps run this routine instead of ei_connect_init/2 ?
* Initailize by setting:
* thishostname, thisalivename, thisnodename and thisipaddr
*/
int ei_connect_xinit(ei_cnode* ec, const char *thishostname,
		     const char *thisalivename, const char *thisnodename,
		     Erl_IpAddr thisipaddr, const char *cookie,
		     const short creation)
{
    char *dbglevel;
    
/* FIXME this code was enabled for erl_connect_xinit(), why not here? */
#if 0    
#ifdef __WIN32__
    if (!initWinSock()) {
	EI_TRACE_ERR0("ei_connect_xinit","can't initiate winsock");
	return ERL_ERROR;
    }
#endif
#endif

#ifdef _REENTRANT
    if (ei_sockets_lock == NULL) {
	ei_sockets_lock = ei_mutex_create();
    }
#endif /* _REENTRANT */

    ec->creation = creation;
    
    if (cookie) {
	if (strlen(cookie) >= sizeof(ec->ei_connect_cookie)) { 
	    EI_TRACE_ERR0("ei_connect_xinit",
			  "ERROR: Cookie size too large");
	    return ERL_ERROR;
	} else {
	    strcpy(ec->ei_connect_cookie, cookie);
	}
    } else if (!get_cookie(ec->ei_connect_cookie, sizeof(ec->ei_connect_cookie))) {
	return ERL_ERROR;
    }
    
    if (strlen(thishostname) >= sizeof(ec->thishostname)) {
	EI_TRACE_ERR0("ei_connect_xinit","ERROR: Thishostname too long");
	return ERL_ERROR;
    }
    strcpy(ec->thishostname, thishostname);
    
    if (strlen(thisalivename) >= sizeof(ec->thisalivename)) {
	EI_TRACE_ERR0("ei_connect_init","Thisalivename too long");
	return ERL_ERROR;
    }
	
    strcpy(ec->thisalivename, thisalivename);
    
    if (strlen(thisnodename) >= sizeof(ec->thisnodename)) {
	EI_TRACE_ERR0("ei_connect_init","Thisnodename too long");
	return ERL_ERROR;
    }
    strcpy(ec->thisnodename, thisnodename);

/* FIXME right now this_ipaddr is never used */    
/*    memmove(&ec->this_ipaddr, thisipaddr, sizeof(ec->this_ipaddr)); */
    
    strcpy(ec->self.node,thisnodename);
    ec->self.num = 0;
    ec->self.serial = 0;
    ec->self.creation = creation;

    if ((dbglevel = getenv("EI_TRACELEVEL")) != NULL ||
	(dbglevel = getenv("ERL_DEBUG_DIST")) != NULL)
	ei_tracelevel = atoi(dbglevel);

    return 0;
}


/*
* Initialize by set: thishostname, thisalivename, 
* thisnodename and thisipaddr. At success return 0,
* otherwise return -1.
*/
int ei_connect_init(ei_cnode* ec, const char* this_node_name,
		    const char *cookie, short creation)
{
    struct hostent *hp;
    char thishostname[EI_MAXHOSTNAMELEN+1];
    char thisnodename[MAXNODELEN+1];
    char thisalivename[EI_MAXALIVELEN+1];

#ifdef __WIN32__
    if (!initWinSock()) {
	EI_TRACE_ERR0("ei_connect_xinit","can't initiate winsock");
	return ERL_ERROR;
    }
#endif /* win32 */
#ifdef _REENTRANT
    if (ei_sockets_lock == NULL) {
	ei_sockets_lock = ei_mutex_create();
    }
#endif /* _REENTRANT */
    
    if (gethostname(thishostname, EI_MAXHOSTNAMELEN) == -1) {
#ifdef __WIN32__
	EI_TRACE_ERR1("ei_connect_init","Failed to get host name: %d",
		      WSAGetLastError());
#else
	EI_TRACE_ERR1("ei_connect_init","Failed to get host name: %d",errno);
#endif /* win32 */
	return ERL_ERROR;
    }
    
    if (this_node_name == NULL)
	sprintf(thisalivename, "c%d", (int) getpid());
    else
	strcpy(thisalivename, this_node_name);
    
    if ((hp = ei_gethostbyname(thishostname)) == 0) {
#ifdef __WIN32__
	char reason[1024];
	
	win32_error(reason,sizeof(reason));
	EI_TRACE_ERR2("ei_connect_init",
		      "Can't get ip address for host %s: %s",
		      thishostname, reason);
#else
	EI_TRACE_ERR2("ei_connect_init",
		      "Can't get ip address for host %s: %d",
		      thishostname,h_errno);
#endif /* win32 */
	return ERL_ERROR;
    }

    strcpy(thishostname, hp->h_name);
    sprintf(thisnodename, "%s@%s", this_node_name, hp->h_name);
    
    return ei_connect_xinit(ec, thishostname, thisalivename, thisnodename,
	(struct in_addr *)*hp->h_addr_list, cookie, creation);
}


/* connects to port at ip-address ip_addr 
* and returns fd to socket 
* port has to be in host byte order 
*/
static int cnct(uint16 port, struct in_addr *ip_addr, int addr_len)
{
    int s;
    struct sockaddr_in iserv_addr;
    
    if ((s = socket(AF_INET, SOCK_STREAM, 0)) < 0) {
	erl_errno = errno;
	return ERL_ERROR;
    }
    
    memset((char*)&iserv_addr, 0, sizeof(struct sockaddr_in));
    memcpy((char*)&iserv_addr.sin_addr, (char*)ip_addr, addr_len);
    iserv_addr.sin_family = AF_INET;
    iserv_addr.sin_port = htons(port);
    
    if (connect(s, (struct sockaddr*)&iserv_addr, sizeof(iserv_addr)) < 0) {
	erl_errno = errno;
	closesocket(s);
	return ERL_ERROR;
    }
    
    return s;
} /* cnct */

  /* 
  * Set up a connection to a given Node, and 
  * interchange hand shake messages with it.
  * Returns a valid file descriptor at success,
  * otherwise a negative error code.
*/
int ei_connect(ei_cnode* ec, char *nodename)
{
    char *hostname, alivename[BUFSIZ];
    struct hostent *hp;
#if !defined (__WIN32__) 
    /* these are needed for the call to gethostbyname_r */
    struct hostent host;
    char buffer[1024];
    int ei_h_errno;
#endif /* !win32 */
    
    /* extract the host and alive parts from nodename */
    if (!(hostname = strchr(nodename,'@'))) {
	EI_TRACE_ERR0("ei_connect","Node name has no @ in name");
	return ERL_ERROR;
    } else {
	strncpy(alivename, nodename, hostname - nodename);
	alivename[hostname - nodename] = 0x0;
	hostname++;
    }
    
#ifndef __WIN32__
    hp = ei_gethostbyname_r(hostname,&host,buffer,1024,&ei_h_errno);
    if (hp == NULL) {
	EI_TRACE_ERR2("erl_connect",
		      "Can't find host for %s: %d\n",nodename,ei_h_errno);
	erl_errno = EHOSTUNREACH;
	return ERL_ERROR;
    }
    
#else /* __WIN32__ */
    if ((hp = ei_gethostbyname(hostname)) == NULL) {
	char reason[1024];
	win32_error(reason,sizeof(reason));
	EI_TRACE_ERR2("erl_connect",
		      "Can't find host for %s: %s",nodename,reason);
	erl_errno = EHOSTUNREACH;
	return ERL_ERROR;
    }
#endif /* win32 */
    
    return ei_xconnect(ec, (Erl_IpAddr) *hp->h_addr_list, alivename);
} /* erl_connect */


  /* ip_addr is now in network byte order 
  *
  * first we have to get hold of the portnumber to
  *  the node through epmd at that host 
  *
*/
int ei_xconnect(ei_cnode* ec, Erl_IpAddr adr, char *alivename)
{
    struct in_addr *ip_addr=(struct in_addr *) adr;
    int rport = 0; /*uint16 rport = 0;*/
    int sockd;
    int one = 1;
    int dist = 0;
    ErlConnect her_name;
    unsigned her_flags, her_version;

    if ((rport = ei_epmd_port(ip_addr,alivename,&dist)) < 0) {
	EI_TRACE_ERR0("ei_xconnect","-> CONNECT can't get remote port");
	return ERL_NO_PORT;
    }
    
    /* we now have port number to enode, try to connect */
    if((sockd = cnct((uint16)rport, ip_addr, sizeof(struct in_addr))) < 0) {
	EI_TRACE_ERR0("ei_xconnect","-> CONNECT socket connect failed");
	erl_errno = EIO;
	return ERL_CONNECT_FAIL;
    }

    EI_TRACE_CONN0("ei_xconnect","-> CONNECT connected to remote");
    
    if (dist <= 4) {
	EI_TRACE_ERR0("ei_xconnect","-> CONNECT remote version not compatible");
	erl_errno = EIO;
	goto error;
    }
    else {
	unsigned our_challenge, her_challenge;
	unsigned char our_digest[16];
	
	if (send_name(sockd, ec->thisnodename, (unsigned) dist))
	    goto error;
	if (recv_status(sockd))
	    goto error;
	if (recv_challenge(sockd, &her_challenge, &her_version,
	    &her_flags, &her_name))
	    goto error;
	our_challenge = gen_challenge();
	gen_digest(her_challenge, ec->ei_connect_cookie, our_digest);
	if (send_challenge_reply(sockd, our_digest, our_challenge))
	    goto error;
	if (recv_challenge_ack(sockd, our_challenge, ec->ei_connect_cookie))
	    goto error;
	put_ei_socket_info(sockd, dist, null_cookie, ec); /* FIXME check that 0 */
	erl_errno = EIO;  /* FIXME why, why??? Where do we clear erl_errno? */
    }
    
    setsockopt(sockd, IPPROTO_TCP, TCP_NODELAY, (char *)&one, sizeof(one));
    setsockopt(sockd, SOL_SOCKET, SO_KEEPALIVE, (char *)&one, sizeof(one));

    EI_TRACE_CONN1("ei_xconnect","-> CONNECT (ok) remote = %s",alivename);
    
    return sockd;
    
error:
    EI_TRACE_ERR0("ei_xconnect","-> CONNECT failed");
    closesocket(sockd);
    return ERL_ERROR;
} /* erl_xconnect */

  /* 
  * For symmetry reasons
*/
#if 0
int ei_close_connection(int fd)
{
    return closesocket(fd);
} /* erl_close_connection */
#endif

  /*
  * Accept and initiate a connection from an other
  * Erlang node. Return a file descriptor at success,
  * otherwise -1;
*/
int ei_accept(ei_cnode* ec, int lfd, ErlConnect *conp)
{
    int fd;
    struct sockaddr_in cli_addr;
    int cli_addr_len=sizeof(struct sockaddr_in);
    unsigned her_version, her_flags;
    ErlConnect her_name;

    EI_TRACE_CONN0("ei_accept","<- ACCEPT waiting for connection");
    
    if ((fd = accept(lfd, (struct sockaddr*) &cli_addr, 
	&cli_addr_len )) < 0) {
	EI_TRACE_ERR0("ei_accept","<- ACCEPT socket accept failed");
	goto error;
    }
    
    EI_TRACE_CONN0("ei_accept","<- ACCEPT connected to remote");
    
    if (recv_name(fd, &her_version, &her_flags, &her_name)) {
	EI_TRACE_ERR0("ei_accept","<- ACCEPT initial ident failed");
	goto error;
    }
    
    if (her_version <= 4) {
	EI_TRACE_ERR0("ei_accept","<- ACCEPT remote version not compatible");
	goto error;
    }
    else {
	unsigned our_challenge;
	unsigned her_challenge;
	unsigned char our_digest[16];
	
	if (send_status(fd,"ok"))
	    goto error;
	our_challenge = gen_challenge();
	if (send_challenge(fd, ec->thisnodename, 
	    our_challenge, her_version))
	    goto error;
	if (recv_challenge_reply(fd, our_challenge, 
	    ec->ei_connect_cookie, 
	    &her_challenge))
	    goto error;
	gen_digest(her_challenge, ec->ei_connect_cookie, our_digest);
	if (send_challenge_ack(fd, our_digest))
	    goto error;
	put_ei_socket_info(fd, her_version, null_cookie, ec);
    }
    if (conp) 
	*conp = her_name;
    
    EI_TRACE_CONN1("ei_accept","<- ACCEPT (ok) remote = %s",her_name.nodename);
    return fd;
    
error:
    EI_TRACE_ERR0("ei_accept","<- ACCEPT failed");
    closesocket(fd);
    erl_errno = EIO;
    return ERL_ERROR;
} /* erl_accept */


/* Receives a message from an Erlang socket.
 * If the message was a TICK it is immediately
 * answered. Returns: ERL_ERROR, ERL_TICK or
 * the number of bytes read.
 */
int ei_receive(int fd, unsigned char *bufp, int bufsize) 
{
    int len;
    unsigned char fourbyte[4]={0,0,0,0};
    
    if (ei_read_fill(fd, (char *) bufp, 4)  != 4) {
	erl_errno = EIO;
	return ERL_ERROR;
    }
    
    /* Tick handling */
    if ((len = get_int32(bufp)) == ERL_TICK) 
    {
	ei_write_fill(fd, (char *) fourbyte, 4);
	erl_errno = EAGAIN;
	return ERL_TICK;
    }
    else if (len > bufsize) 
    {
	/* FIXME: We should drain the message. */
	erl_errno = EMSGSIZE;
	return ERL_ERROR;
    }
    else if (ei_read_fill(fd, (char *) bufp, len) != len)
    {
	erl_errno = EIO;
	return ERL_ERROR;
    }
    
    return len;
    
}

int ei_reg_send(ei_cnode* ec, int fd, char *server_name, char* buf, int len)
{
    erlang_pid *self = ei_self(ec);
    self->num = fd;
    if (ei_send_reg_encoded(fd, self, server_name, buf, len)) {
	erl_errno = EIO;
	return -1;
    }
    return 0;
}

/* 
* Sends an Erlang message to a process at an Erlang node
*/
int ei_send(int fd, erlang_pid* to, char* buf, int len)
{
    if (ei_send_encoded(fd, to, buf, len) != 0) {
	erl_errno = EIO;
	return -1;
    }
    return 0;
}


/* 
* Try to receive an Erlang message on a given socket. Returns
* ERL_TICK, ERL_MSG, or ERL_ERROR. Sets `erl_errno' on ERL_ERROR and
* ERL_TICK (to EAGAIN in the latter case).
*/

int ei_do_receive_msg(int fd, int staticbuffer_p, 
		      erlang_msg* msg, ei_x_buff* x)
{
    int msglen;
    int i;
    
    if (!(i=ei_recv_internal(fd, &x->buff, &x->buffsz, msg, &msglen, 
	staticbuffer_p))) {
	erl_errno = EAGAIN;
	return ERL_TICK;
    }
    if (i<0) {
	/* erl_errno set by ei_recv_internal() */
	return ERL_ERROR;
    }
    if (staticbuffer_p && msglen > x->buffsz)
    {
	erl_errno = EMSGSIZE;
	return ERL_ERROR;
    }
    x->index = x->buffsz;
    switch (msg->msgtype) {	/* FIXME are these all? */
    case ERL_SEND:
    case ERL_REG_SEND:
    case ERL_LINK:
    case ERL_UNLINK:
    case ERL_GROUP_LEADER:
    case ERL_EXIT:
    case ERL_EXIT2:
    case ERL_NODE_LINK:
	return ERL_MSG;
	
    default:
	/*if (emsg->to) erl_free_term(emsg->to);
	  if (emsg->from) erl_free_term(emsg->from);
	  if (emsg->msg) erl_free_term(emsg->msg);
	  emsg->to = NULL;
	  emsg->from = NULL;
	  emsg->msg = NULL;*/
	
	erl_errno = EIO;
	return ERL_ERROR;
    }
} /* do_receive_msg */


int ei_receive_msg(int fd, erlang_msg* msg, ei_x_buff* x)
{
    return ei_do_receive_msg(fd, 1, msg, x);
}

int ei_xreceive_msg(int fd, erlang_msg *msg, ei_x_buff *x)
{
    return ei_do_receive_msg(fd, 0, msg, x);
}

/* 
* The RPC consists of two parts, send and receive.
* Here is the send part ! 
* { PidFrom, { call, Mod, Fun, Args, user }} 
*/
/*
* Now returns non-negative number for success, negative for failure.
*/
int ei_rpc_to(ei_cnode *ec, int fd, char *mod, char *fun,
	      const char *buf, int len)
{

    ei_x_buff x;
    erlang_pid *self = ei_self(ec);
    self->num = fd;

    /* encode header */
    ei_x_new_with_version(&x);
    ei_x_encode_tuple_header(&x, 2);  /* A */
    
    self->num = fd;
    ei_x_encode_pid(&x, self);	      /* A 1 */
    
    ei_x_encode_tuple_header(&x, 5);  /* B A 2 */
    ei_x_encode_atom(&x, "call");     /* B 1 */
    ei_x_encode_atom(&x, mod);	      /* B 2 */
    ei_x_encode_atom(&x, fun);	      /* B 3 */
    ei_x_append_buf(&x, buf, len);    /* B 4 */
    ei_x_encode_atom(&x, "user");     /* B 5 */

    /* ei_x_encode_atom(&x,"user"); */
    ei_send_reg_encoded(fd, self, "rex", x.buff, x.index);
    ei_x_free(&x);
	
    return 0;
} /* rpc_to */

  /*
  * And here is the rpc receiving part. A negative
  * timeout means 'infinity'. Returns either of: ERL_MSG,
  * ERL_TICK, ERL_ERROR or ERL_TIMEOUT.
*/
int ei_rpc_from(ei_cnode *ec, int fd, int timeout, erlang_msg *msg,
		ei_x_buff *x) 
{
    fd_set readmask;
    struct timeval tv;
    struct timeval *t = NULL;
    
    if (timeout >= 0) {
	tv.tv_sec = timeout / 1000;
	tv.tv_usec = (timeout % 1000) * 1000;
	t = &tv;
    }
    
    FD_ZERO(&readmask);
    FD_SET(fd,&readmask);
    
    switch (select(FD_SETSIZE, &readmask, NULL, NULL, t)) {
    case -1: 
	erl_errno = EIO;
	return ERL_ERROR;
	
    case 0:
	erl_errno = ETIMEDOUT;
	return ERL_TIMEOUT;
	
    default:
	if (FD_ISSET(fd, &readmask)) {
	    return ei_xreceive_msg(fd, msg, x);
	} else {
	    erl_errno = EIO;
	    return ERL_ERROR;
	}
    }
} /* rpc_from */

  /*
  * A true RPC. It return a NULL pointer
  * in case of failure, otherwise a valid
  * (ETERM *) pointer containing the reply
  */
int ei_rpc(ei_cnode* ec, int fd, char *mod, char *fun,
	   const char* inbuf, int inbuflen, ei_x_buff* x)
{
    int i, index;
    ei_term t;
    erlang_msg msg;
    char rex[MAXATOMLEN+1];

    if (ei_rpc_to(ec, fd, mod, fun, inbuf, inbuflen) < 0) {
	return -1;
    }
    /* FIXME are we not to reply to the tick? */
    while ((i = ei_rpc_from(ec, fd, ERL_NO_TIMEOUT, &msg, x)) == ERL_TICK)
	;

    if (i == ERL_ERROR)  return -1;
    /*ep = erl_element(2,emsg.msg);*/ /* {RPC_Tag, RPC_Reply} */
    index = 0;
    if (ei_decode_version(x->buff, &index, &i) < 0
	|| ei_decode_ei_term(x->buff, &index, &t) < 0)
	return -1;		/* FIXME ei_decode_version don't set erl_errno as before */
    /* FIXME this is strange, we don't check correct "rex" atom
       and we let it pass if not ERL_SMALL_TUPLE_EXT and arity == 2 */
    if (t.ei_type == ERL_SMALL_TUPLE_EXT && t.arity == 2)
	if (ei_decode_atom(x->buff, &index, rex) < 0)
	    return -1;
    /* remove header */
    x->index -= index;
    memmove(x->buff, &x->buff[index], x->index);
    return 0;
}


  /*
  ** Handshake
*/


/* FROM RTP RFC 1889  (except that we use all bits, bug in RFC?) */
static unsigned int md_32(char* string, int length)
{
    MD5_CTX ctx;
    union {
	char c[16];
	unsigned x[4];
    } digest;
    ei_MD5Init(&ctx);
    ei_MD5Update(&ctx, (unsigned char *) string, 
	       (unsigned) length);
    ei_MD5Final((unsigned char *) digest.c, &ctx);
    return (digest.x[0] ^ digest.x[1] ^ digest.x[2] ^ digest.x[3]);
}

#if defined(__WIN32__)
unsigned int gen_challenge(void)
{
    struct {
	SYSTEMTIME tv;
	DWORD cpu;
	int pid;
    } s;
    GetSystemTime(&s.tv);
    s.cpu  = GetTickCount();
    s.pid  = getpid();
    return md_32((char*) &s, sizeof(s));
}

#elif  defined(VXWORKS)

static unsigned int gen_challenge(void)
{
    struct {
	struct timespec tv;
	clock_t cpu;
	int pid;
    } s;
    s.cpu  = clock();
    clock_gettime(CLOCK_REALTIME, &s.tv);
    s.pid = getpid();
    return md_32((char*) &s, sizeof(s));
}

#else  /* some unix */

static unsigned int gen_challenge(void)
{
    struct {
	struct timeval tv;
	clock_t cpu;
	pid_t pid;
	u_long hid;
	uid_t uid;
	gid_t gid;
	struct utsname name;
    } s;

    gettimeofday(&s.tv, 0);
    uname(&s.name);
    s.cpu  = clock();
    s.pid  = getpid();
    s.hid  = gethostid();
    s.uid  = getuid();
    s.gid  = getgid();

    return md_32((char*) &s, sizeof(s));
}
#endif

static void gen_digest(unsigned challenge, char cookie[], 
		       unsigned char digest[16])
{
    MD5_CTX c;
    
    char chbuf[20];
    
    sprintf(chbuf,"%u", challenge);
    ei_MD5Init(&c);
    ei_MD5Update(&c, (unsigned char *) cookie, 
	       (unsigned) strlen(cookie));
    ei_MD5Update(&c, (unsigned char *) chbuf, 
	       (unsigned) strlen(chbuf));
    ei_MD5Final(digest, &c);
}


static char *hex(char digest[16])
{
    unsigned char *d = (unsigned char *) digest;
    /* FIXME problem for threaded ? */
    static char buff[sizeof(digest)*2 + 1];
    char *p = buff;
    static char tab[] = "0123456789abcdef";
    int i;
    
    for (i = 0; i < sizeof(digest); ++i) {
	*p++ = tab[(int)((*d) >> 4)];
	*p++ = tab[(int)((*d++) & 0xF)];
    }
    *p = '\0';
    return buff;
}

static int read_2byte_package(int fd, char **buf, int *buflen, 
			      int *is_static)
{
    unsigned char nbuf[2];
    unsigned char *x = nbuf;
    unsigned len;
    
    if(ei_read_fill(fd, (char *) nbuf, 2) != 2) {
	erl_errno = EIO;
	return -1;
    }
    len = get16be(x);
    
    if (len > *buflen) {
	if (*is_static) {
	    char *tmp = malloc(len);
	    if (!tmp) {
		erl_errno = ENOMEM;
		return -1;
	    }
	    *buf = tmp;
	    *is_static = 0;
	    *buflen = len;
	} else {
	    char *tmp = realloc(*buf, len);
	    if (!tmp) {
		erl_errno = ENOMEM;
		return -1;
	    }
	    *buf = tmp;
	    *buflen = len;
	}
    }
    if (ei_read_fill(fd, *buf, len) != len) {
	erl_errno = EIO;
	return -1;
    }
    return len;
}


static int send_status(int fd, char *status)
{
    char *buf, *s;
    char dbuf[DEFBUF_SIZ];
    int siz = strlen(status) + 1 + 2;
    buf = (siz > DEFBUF_SIZ) ? malloc(siz) : dbuf;
    if (!buf) {
	erl_errno = ENOMEM;
	return -1;
    }
    s = buf;
    put16be(s,siz - 2);
    put8(s, 's');
    memcpy(s, status, strlen(status));
    if (ei_write_fill(fd, buf, siz) != siz) {
	EI_TRACE_ERR0("send_status","-> SEND_STATUS socket write failed");
	if (buf != dbuf)
	    free(buf);
	erl_errno = EIO;
	return -1;
    }

    EI_TRACE_CONN1("send_status","-> SEND_STATUS (%s)",status);

    if (buf != dbuf)
	free(buf);
    return 0;
}

static int recv_status(int fd)
{
    char dbuf[DEFBUF_SIZ];
    char *buf = dbuf;
    int is_static = 1;
    int buflen = DEFBUF_SIZ;
    int rlen;
    
    if ((rlen = read_2byte_package(fd, &buf, &buflen, &is_static)) <= 0) {
	EI_TRACE_ERR1("recv_status",
		      "<- RECV_STATUS socket read failed (%d)", rlen);
	goto error;
    }
    if (rlen == 3 && buf[0] == 's' && buf[1] == 'o' && 
	buf[2] == 'k') {
	if (!is_static)
	    free(buf);
	EI_TRACE_CONN0("recv_status","<- RECV_STATUS (ok)");
	return 0;
    }
error:
    if (!is_static)
	free(buf);
    return -1;
}

/* FIXME fix the signed/unsigned mess..... */

static int send_name_or_challenge(int fd, char *nodename,
				  int f_chall,
				  unsigned challenge,
				  unsigned version) 
{
    char *buf;
    unsigned char *s;
    char dbuf[DEFBUF_SIZ];
    int siz = 2 + 1 + 2 + 4 + strlen(nodename);
    const char* function[] = {"SEND_NAME", "SEND_CHALLENGE"};
    if (f_chall)
	siz += 4;
    buf = (siz > DEFBUF_SIZ) ? malloc(siz) : dbuf;
    if (!buf) {
	erl_errno = ENOMEM;
	return -1;
    }
    s = (unsigned char *)buf;
    put16be(s,siz - 2);
    put8(s, 'n');
    put16be(s, version);
    put32be(s, (DFLAG_EXTENDED_REFERENCES|DFLAG_FUN_TAGS|DFLAG_NEW_FUN_TAGS));
    if (f_chall)
	put32be(s, challenge);
    memcpy(s, nodename, strlen(nodename));
    
    if (ei_write_fill(fd, buf, siz) != siz) {
	EI_TRACE_ERR1("send_name_or_challenge",
		      "-> %s socket write failed", function[f_chall]);
	if (buf != dbuf)
	    free(buf);
	erl_errno = EIO;
	return -1;
    }
    
    EI_TRACE_CONN4("send_name_or_challenge",
		   "-> %s (ok) challenge = %d, version = %d, nodename = %s",
		   function[f_chall],challenge, version, nodename);
    
    if (buf != dbuf)
	free(buf);
    return 0;
}

static int recv_challenge(int fd, unsigned *challenge, 
			  unsigned *version,
			  unsigned *flags, ErlConnect *namebuf)
{
    char dbuf[DEFBUF_SIZ];
    char *buf = dbuf;
    int is_static = 1;
    int buflen = DEFBUF_SIZ;
    int rlen;
    char *s;
    struct sockaddr_in sin;
    int sin_len = sizeof(sin);
    char tag;
    
    if ((rlen = read_2byte_package(fd, &buf, &buflen, &is_static)) <= 0) {
	EI_TRACE_ERR1("recv_challenge",
		      "<- RECV_CHALLENGE socket read failed (%d)",rlen);
	goto error;
    }
    if ((rlen - 11) > MAXNODELEN) {
	EI_TRACE_ERR1("recv_challenge",
		      "<- RECV_CHALLENGE nodename too long (%d)",rlen - 11);
	erl_errno = EIO;
	goto error;
    }
    s = buf;
    if ((tag = get8(s)) != 'n') {
	EI_TRACE_ERR2("recv_challenge",
		      "<- RECV_CHALLENGE incorrect tag, "
		      "expected 'n' got '%c' (%u)",tag,tag);
	goto error;
    }
    *version = get16be(s);
    *flags = get32be(s);
    *challenge = get32be(s);

    if (!(*flags & DFLAG_EXTENDED_REFERENCES)) {
	EI_TRACE_ERR0("recv_challenge","<- RECV_CHALLENGE peer cannot "
		      "handle extended references");
	erl_errno = EIO;
	goto error;
    }

    if (getpeername(fd, (struct sockaddr *) &sin, &sin_len) < 0) {
	EI_TRACE_ERR0("recv_challenge","<- RECV_CHALLENGE can't get peername");
	erl_errno = errno;
	goto error;
    }
    memcpy(namebuf->ipadr, &(sin.sin_addr.s_addr), 
	sizeof(sin.sin_addr.s_addr));
    memcpy(namebuf->nodename, s, rlen - 11);
    namebuf->nodename[rlen - 11] = '\0';
    if (!is_static)
	free(buf);
    EI_TRACE_CONN4("recv_challenge","<- RECV_CHALLENGE (ok) node = %s, "
	    "version = %u, "
	    "flags = %u, "
	    "challenge = %d",
	    namebuf->nodename,
	    *version,
	    *flags,
	    *challenge
	    );
    return 0;
error:
    if (!is_static)
	free(buf);
    return -1;
}

static int send_challenge_reply(int fd, unsigned char digest[16], 
				unsigned challenge) 
{
    char *s;
    char buf[DEFBUF_SIZ];
    int siz = 2 + 1 + 4 + 16;
    s = buf;
    put16be(s,siz - 2);
    put8(s, 'r');
    put32be(s, challenge);
    memcpy(s, digest, 16);
    
    if (ei_write_fill(fd, buf, siz) != siz) {
	EI_TRACE_ERR0("send_challenge_reply",
		      "-> SEND_CHALLENGE_REPLY socket write failed");
	erl_errno = EIO;
	return -1;
    }
    
    EI_TRACE_CONN2("send_challenge_reply",
		   "-> SEND_CHALLENGE_REPLY (ok) challenge = %d, digest = %s",
		   challenge,hex(digest));
    return 0;
}

static int recv_challenge_reply (int fd, 
				 unsigned our_challenge,
				 char cookie[], 
				 unsigned *her_challenge)
{
    char dbuf[DEFBUF_SIZ];
    char *buf = dbuf;
    int is_static = 1;
    int buflen = DEFBUF_SIZ;
    int rlen;
    char *s;
    char tag;
    char her_digest[16], expected_digest[16];
    
    if ((rlen = read_2byte_package(fd, &buf, &buflen, &is_static)) != 21) {
	EI_TRACE_ERR1("recv_challenge_reply",
		      "<- RECV_CHALLENGE_REPLY socket read failed (%d)",rlen);
	goto error;
    }
    
    s = buf;
    if ((tag = get8(s)) != 'r') {
	EI_TRACE_ERR2("recv_challenge_reply",
		      "<- RECV_CHALLENGE_REPLY incorrect tag, "
		      "expected 'r' got '%c' (%u)",tag,tag);
	erl_errno = EIO;
	goto error;
    }
    *her_challenge = get32be(s);
    memcpy(her_digest, s, 16);
    gen_digest(our_challenge, cookie, (unsigned char*)expected_digest);
    if (memcmp(her_digest, expected_digest, 16)) {
	EI_TRACE_ERR0("recv_challenge_reply",
		      "<- RECV_CHALLENGE_REPLY authorization failure");
	erl_errno = EIO;
	goto error;
    }
    if (!is_static)
	free(buf);
    EI_TRACE_CONN2("recv_challenge_reply",
		   "<- RECV_CHALLENGE_REPLY (ok) challenge = %u, digest = %s",
		   *her_challenge,hex(her_digest));
    return 0;
    
error:
    if (!is_static)
	free(buf);
    return -1;
}

static int send_challenge_ack(int fd, unsigned char digest[16]) 
{
    char *s;
    char buf[DEFBUF_SIZ];
    int siz = 2 + 1 + 16;
    s = buf;
    
    put16be(s,siz - 2);
    put8(s, 'a');
    memcpy(s, digest, 16);
    
    if (ei_write_fill(fd, buf, siz) != siz) {
	EI_TRACE_ERR0("recv_challenge_reply",
		      "-> SEND_CHALLENGE_ACK socket write failed");
	erl_errno = EIO;
	return -1;
    }
    
    EI_TRACE_CONN1("recv_challenge_reply",
		   "-> SEND_CHALLENGE_ACK (ok) digest = %s",hex(digest));
    
    return 0;
}

static int recv_challenge_ack(int fd, 
			      unsigned our_challenge,
			      char cookie[])
{
    char dbuf[DEFBUF_SIZ];
    char *buf = dbuf;
    int is_static = 1;
    int buflen = DEFBUF_SIZ;
    int rlen;
    char *s;
    char tag;
    char her_digest[16], expected_digest[16];
    
    if ((rlen = read_2byte_package(fd, &buf, &buflen, &is_static)) != 17) {
	EI_TRACE_ERR1("recv_challenge_ack",
		      "<- RECV_CHALLENGE_ACK socket read failed (%d)",rlen);
	goto error;
    }
    
    s = buf;
    if ((tag = get8(s)) != 'a') {
	EI_TRACE_ERR2("recv_challenge_ack",
		      "<- RECV_CHALLENGE_ACK incorrect tag, "
		      "expected 'a' got '%c' (%u)",tag,tag);
	erl_errno = EIO;
	goto error;
    }
    memcpy(her_digest, s, 16);
    gen_digest(our_challenge, cookie, (unsigned char *)expected_digest);
    if (memcmp(her_digest, expected_digest, 16)) {
	EI_TRACE_ERR0("recv_challenge_ack",
		      "<- RECV_CHALLENGE_ACK authorization failure");
	erl_errno = EIO;
	goto error;
    }
    if (!is_static)
	free(buf);
    EI_TRACE_CONN1("recv_challenge_ack",
		   "<- RECV_CHALLENGE_ACK (ok) digest = %s",hex(her_digest));
    return 0;

error:
    if (!is_static)
	free(buf);
    return -1;
}

static int send_name(int fd, char *nodename, unsigned version) 
{
    return send_name_or_challenge(fd, nodename, 0, 0, version);
}

static int send_challenge(int fd, char *nodename, 
			  unsigned challenge, unsigned version)
{
    return send_name_or_challenge(fd, nodename, 1, challenge, version);
}

static int recv_name(int fd, 
		     unsigned *version,
		     unsigned *flags, ErlConnect *namebuf)
{
    char dbuf[DEFBUF_SIZ];
    char *buf = dbuf;
    int is_static = 1;
    int buflen = DEFBUF_SIZ;
    int rlen;
    char *s;
    struct sockaddr_in sin;
    int sin_len = sizeof(sin);
    char tag;
    
    if ((rlen = read_2byte_package(fd, &buf, &buflen, &is_static)) <= 0) {
	EI_TRACE_ERR1("recv_name","<- RECV_NAME socket read failed (%d)",rlen);
	goto error;
    }
    if ((rlen - 7) > MAXNODELEN) {
	EI_TRACE_ERR1("recv_name","<- RECV_NAME nodename too long (%d)",rlen-7);
	erl_errno = EIO;
	goto error;
    }
    s = buf;
    tag = get8(s);
    if (tag != 'n') {
	EI_TRACE_ERR2("recv_name","<- RECV_NAME incorrect tag, "
		      "expected 'n' got '%c' (%u)",tag,tag);
	erl_errno = EIO;
	goto error;
    }
    *version = get16be(s);
    *flags = get32be(s);

    if (!(*flags & DFLAG_EXTENDED_REFERENCES)) {
	EI_TRACE_ERR0("recv_name","<- RECV_CHALLENGE peer cannot handle"
		      "extended references");
	erl_errno = EIO;
	goto error;
    }

    if (getpeername(fd, (struct sockaddr *) &sin, &sin_len) < 0) {
	EI_TRACE_ERR0("recv_name","<- RECV_NAME can't get peername");
	erl_errno = errno;
	goto error;
    }
    memcpy(namebuf->ipadr, &(sin.sin_addr.s_addr), 
	sizeof(sin.sin_addr.s_addr));
    memcpy(namebuf->nodename, s, rlen - 7);
    namebuf->nodename[rlen - 7] = '\0';
    if (!is_static)
	free(buf);
    EI_TRACE_CONN3("recv_name",
		   "<- RECV_NAME (ok) node = %s, version = %u, flags = %u",
		   namebuf->nodename,*version,*flags);
    return 0;
    
error:
    if (!is_static)
	free(buf);
    return -1;
}

/***************************************************************************
 *
 *  Returns 1 on success and 0 on failure.
 *
 ***************************************************************************/


/* size is the buffer size, e.i. string length + 1 */

static int get_home(char *buf, int size)
{
    char* homedrive;
    char* homepath;
    
#ifdef __WIN32__
    homedrive = getenv("HOMEDRIVE");
    homepath = getenv("HOMEPATH");
#else
    homedrive = "";
    homepath = getenv("HOME");
#endif
    
    if (!homedrive || !homepath) {
	buf[0] = '.';
	buf[1] = '\0';
	return 1;
    } else if (strlen(homedrive)+strlen(homepath) < size-1) {
	strcpy(buf, homedrive);
	strcat(buf, homepath);
	return 1;
    }
    
    return 0;
}


static int get_cookie(char *buf, int bufsize)
{
    char fname[EI_MAX_HOME_PATH + sizeof(COOKIE_FILE) + 1];
    int fd;
    int len;
    unsigned char next_c;
    
    if (!get_home(fname, EI_MAX_HOME_PATH+1)) {
	fprintf(stderr,"<ERROR> get_cookie: too long path to home");
	return 0;
    }

    strcat(fname, COOKIE_FILE);
    if ((fd = open(fname, O_RDONLY, 0777)) < 0) {
	fprintf(stderr,"<ERROR> get_cookie: can't open cookie file");
	return 0;
    }
    
    if ((len = read(fd, buf, bufsize-1)) < 0) {
	fprintf(stderr,"<ERROR> get_cookie: reading cookie file");
	close(fd);
	return 0;
    }

    /* If more to read it is too long. Not 100% correct test but will do. */
    if (read(fd, &next_c, 1) > 0 && !isspace(next_c)) {
	fprintf(stderr,"<ERROR> get_cookie: cookie in %s is too long",fname);
	close(fd);
	return 0;
    }

    close(fd);

    /* Remove all newlines after the first newline */
    buf[len] = '\0';		/* Terminate string */
    len = strcspn(buf,"\r\n");
    buf[len] = '\0';		/* Terminate string again */

    return 1;			/* Success! */
}