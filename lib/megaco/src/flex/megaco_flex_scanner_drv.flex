  /*  ``The contents of this file are subject to the Erlang Public License,
   *  Version 1.1, (the "License"); you may not use this file except in
   *  compliance with the License. You should have received a copy of the
   *  Erlang Public License along with this software. If not, it can be
   *  retrieved via the world wide web at http://www.erlang.org/.
   *  
   *  Software distributed under the License is distributed on an "AS IS"
   *  basis, WITHOUT WARRANTY OF ANY KIND, either express or implied. See
   *  the License for the specific language governing rights and limitations
   *  under the License.
   *  
   *  The Initial Developer of the Original Code is Ericsson Utvecklings AB.
   *  Portions created by Ericsson are Copyright 1999, Ericsson Utvecklings
   *  AB. All Rights Reserved.''
   *  
   * 	  $Id$
   * ----------------------------------------------------------------------
   *  Author:   Hakan Mattsson <hakan@cslab.ericsson.com>
   *  Purpose : Scanner for text encoded Megaco/H.248 messages
   * ----------------------------------------------------------------------
   * 
   * Throughout this file the prefix mfs is used for megaco_flex_scanner.
   * The reason is to get shorter function and variable names.
   */
%option case-insensitive

  /* MEGACO_YY_LINENO_OPTION
   * Note that this construction is intended to make it
   * possible to generate flex files that either reports
   * line-number or one that don't.
   * See MEGACO_DUMMY_DECL_YY_LINENO and
   *     MEGACO_LINENO_OR_TOKENCOUNTER below.
   */
%option yylineno

%option noyywrap
%option noinput
%option nounput 
%{

#define HAVE_UIO_H
#include "erl_driver.h"
#include <stdarg.h>
#include <stdlib.h>
#include <string.h>
#include <ctype.h>

#define TRUE  1;
#define FALSE 0;

#define FREE(bufP)        driver_free(bufP)
#define ALLOC(sz)         driver_alloc(sz)
#define REALLOC(bufP, sz) driver_realloc(bufP, sz)

#define YY_MAIN false

#define YY_FATAL_ERROR(msg) mfs_fatal_error(msg)

static ErlDrvTermData mfs_AddToken = 0;
static ErlDrvTermData mfs_AndAUDITSelectToken = 0;          /* v3 */
static ErlDrvTermData mfs_AuditCapToken = 0;
static ErlDrvTermData mfs_AuditToken = 0;
static ErlDrvTermData mfs_AuditValueToken = 0;
static ErlDrvTermData mfs_AuthToken = 0;
static ErlDrvTermData mfs_BothToken = 0;                    /* v3 */
static ErlDrvTermData mfs_BothwayToken = 0;
static ErlDrvTermData mfs_BriefToken = 0;
static ErlDrvTermData mfs_BufferToken = 0;
static ErlDrvTermData mfs_COLON = 0;
static ErlDrvTermData mfs_COMMA = 0;
static ErlDrvTermData mfs_ContextAttrToken = 0;             /* v3 */
static ErlDrvTermData mfs_ContextAuditToken = 0;
static ErlDrvTermData mfs_ContextListToken = 0;             /* v3 */
static ErlDrvTermData mfs_CtxToken = 0;
static ErlDrvTermData mfs_DelayToken = 0;
static ErlDrvTermData mfs_DeleteToken = 0;
static ErlDrvTermData mfs_DigitMapDescriptor = 0;
static ErlDrvTermData mfs_DigitMapDescriptorToken = 0;
static ErlDrvTermData mfs_DigitMapToken = 0;
static ErlDrvTermData mfs_DigitMapValue = 0;
static ErlDrvTermData mfs_DirectionToken = 0;               /* v3 */
static ErlDrvTermData mfs_DiscardToken = 0;
static ErlDrvTermData mfs_DisconnectedToken = 0;
static ErlDrvTermData mfs_DurationToken = 0;
static ErlDrvTermData mfs_EQUAL = 0;
static ErlDrvTermData mfs_EmbedToken = 0;
static ErlDrvTermData mfs_EmergencyToken = 0;
static ErlDrvTermData mfs_EmergencyOffToken = 0;            /* v3 */
static ErlDrvTermData mfs_EmergencyValueToken = 0;          /* v3 */
static ErlDrvTermData mfs_ErrorToken = 0;
static ErlDrvTermData mfs_EventBufferToken = 0;
static ErlDrvTermData mfs_EventsToken = 0;
static ErlDrvTermData mfs_ExternalToken = 0;                /* v3 */
static ErlDrvTermData mfs_FailoverToken = 0;
static ErlDrvTermData mfs_ForcedToken = 0;
static ErlDrvTermData mfs_GREATER = 0;
static ErlDrvTermData mfs_GracefulToken = 0;
static ErlDrvTermData mfs_H221Token = 0;
static ErlDrvTermData mfs_H223Token = 0;
static ErlDrvTermData mfs_H226Token = 0;
static ErlDrvTermData mfs_HandOffToken = 0;
static ErlDrvTermData mfs_IEPSToken = 0;                    /* v3 */
static ErlDrvTermData mfs_IllegalChar = 0;
static ErlDrvTermData mfs_ImmAckRequiredToken = 0;
static ErlDrvTermData mfs_InactiveToken = 0;
static ErlDrvTermData mfs_InSvcToken = 0;
static ErlDrvTermData mfs_IntsigDelayToken = 0;             /* v3 */
static ErlDrvTermData mfs_InternalToken = 0;                /* v3 */
static ErlDrvTermData mfs_InterruptByEventToken = 0;
static ErlDrvTermData mfs_InterruptByNewSignalsDescrToken = 0;
static ErlDrvTermData mfs_IsolateToken = 0;
static ErlDrvTermData mfs_IterationToken = 0;               /* v3 */
static ErlDrvTermData mfs_KeepActiveToken = 0;
static ErlDrvTermData mfs_LBRKT = 0;
static ErlDrvTermData mfs_LESSER = 0;
static ErlDrvTermData mfs_LSBRKT = 0;
static ErlDrvTermData mfs_LocalControlToken = 0;
static ErlDrvTermData mfs_LocalDescriptorToken = 0;
static ErlDrvTermData mfs_LocalToken = 0;
static ErlDrvTermData mfs_LockStepToken = 0;
static ErlDrvTermData mfs_LoopbackToken = 0;
static ErlDrvTermData mfs_MediaToken = 0;
static ErlDrvTermData mfs_MegacopToken = 0;
static ErlDrvTermData mfs_MethodToken = 0;
/* static ErlDrvTermData mfs_MessageSegmentToken = 0; */
static ErlDrvTermData mfs_MgcIdToken = 0;
static ErlDrvTermData mfs_ModeToken = 0;
static ErlDrvTermData mfs_ModemToken = 0;
static ErlDrvTermData mfs_ModifyToken = 0;
static ErlDrvTermData mfs_MoveToken = 0;
static ErlDrvTermData mfs_MtpAddressToken = 0;
static ErlDrvTermData mfs_MuxToken = 0;
static ErlDrvTermData mfs_NEQUAL = 0;
static ErlDrvTermData mfs_NeverNotifyToken = 0;             /* v3 */
static ErlDrvTermData mfs_NotifyCompletionToken = 0;
static ErlDrvTermData mfs_NotifyImmediateToken = 0;         /* v3 */
static ErlDrvTermData mfs_NotifyRegulatedToken = 0;         /* v3 */
static ErlDrvTermData mfs_NotifyToken = 0;
static ErlDrvTermData mfs_Nx64kToken = 0;
static ErlDrvTermData mfs_ObservedEventsToken = 0;
static ErlDrvTermData mfs_OffToken = 0;
static ErlDrvTermData mfs_OnOffToken = 0;
static ErlDrvTermData mfs_OnToken = 0;
static ErlDrvTermData mfs_OnewayToken = 0;
static ErlDrvTermData mfs_OnewayBothToken = 0;              /* v3 */
static ErlDrvTermData mfs_OnewayExternalToken = 0;          /* v3 */
static ErlDrvTermData mfs_OrAUDITselectToken = 0;           /* v3 */
static ErlDrvTermData mfs_OtherReasonToken = 0;
static ErlDrvTermData mfs_OutOfSvcToken = 0;
static ErlDrvTermData mfs_PackagesToken = 0;
static ErlDrvTermData mfs_PendingToken = 0;
static ErlDrvTermData mfs_PriorityToken = 0;
static ErlDrvTermData mfs_ProfileToken = 0;
static ErlDrvTermData mfs_QuotedChars = 0;
static ErlDrvTermData mfs_RBRKT = 0;
static ErlDrvTermData mfs_RSBRKT = 0;
static ErlDrvTermData mfs_ReasonToken = 0;
static ErlDrvTermData mfs_RecvonlyToken = 0;
static ErlDrvTermData mfs_RemoteDescriptorToken = 0;
static ErlDrvTermData mfs_RemoteToken = 0;
static ErlDrvTermData mfs_RequestIDToken = 0;               /* v3 */
static ErlDrvTermData mfs_ReplyToken = 0;
static ErlDrvTermData mfs_ReservedGroupToken = 0;
static ErlDrvTermData mfs_ReservedValueToken = 0;
static ErlDrvTermData mfs_ResetEventsDescriptorToken = 0;   /* v3 */
static ErlDrvTermData mfs_ResponseAckToken = 0;
static ErlDrvTermData mfs_RestartToken = 0;
static ErlDrvTermData mfs_SEP = 0;
static ErlDrvTermData mfs_SafeChars = 0;
/* static ErlDrvTermData mfs_SegmentationCOmpleteToken = 0;  */  /* v3 */
static ErlDrvTermData mfs_SendonlyToken = 0;
static ErlDrvTermData mfs_SendrecvToken = 0;
static ErlDrvTermData mfs_ServiceChangeAddressToken = 0;
static ErlDrvTermData mfs_ServiceChangeIncompleteToken = 0; /* v3 */
static ErlDrvTermData mfs_ServiceChangeToken = 0;
static ErlDrvTermData mfs_ServiceStatesToken = 0;
static ErlDrvTermData mfs_ServicesToken = 0;
static ErlDrvTermData mfs_SignalListToken = 0;
static ErlDrvTermData mfs_SignalTypeToken = 0;
static ErlDrvTermData mfs_SignalsToken = 0;
static ErlDrvTermData mfs_StatsToken = 0;
static ErlDrvTermData mfs_StreamToken = 0;
static ErlDrvTermData mfs_SubtractToken = 0;
static ErlDrvTermData mfs_SynchISDNToken = 0;
static ErlDrvTermData mfs_TerminationStateToken = 0;
static ErlDrvTermData mfs_TestToken = 0;
static ErlDrvTermData mfs_TimeOutToken = 0;
static ErlDrvTermData mfs_TimeStampToken = 0; /* OTP-5042 */
static ErlDrvTermData mfs_TopologyToken = 0;
static ErlDrvTermData mfs_TransToken = 0;
static ErlDrvTermData mfs_V18Token = 0;
static ErlDrvTermData mfs_V22Token = 0;
static ErlDrvTermData mfs_V22bisToken = 0;
static ErlDrvTermData mfs_V32Token = 0;
static ErlDrvTermData mfs_V32bisToken = 0;
static ErlDrvTermData mfs_V34Token = 0;
static ErlDrvTermData mfs_V76Token = 0;
static ErlDrvTermData mfs_V90Token = 0;
static ErlDrvTermData mfs_V91Token = 0;
static ErlDrvTermData mfs_VersionToken = 0;
static ErlDrvTermData mfs_asn1_NOVALUE = 0;
static ErlDrvTermData mfs_endOfMessage = 0;

/* MEGACO_DUMMY_DECL_YY_LINENO
 * Note that this construction is intended to make it
 * possible to generate flex files that either reports
 * line-number or one that don't.
 * See MEGACO_YY_LINENO_OPTION above and
 *     MEGACO_LINENO_OR_TOKENCOUNTER below.
 */
/* static int yylineno = 1; */

static ErlDrvPort      mfs_port                = 0;
static char* 	       mfs_digit_map_name_ptr  = 0;
static int 	       mfs_digit_map_name_len  = 0;
static char* 	       mfs_digit_map_value_ptr = 0;
static int 	       mfs_digit_map_value_len = 0;
static char* 	       mfs_digit_map_start_ptr = 0;
static char* 	       mfs_digit_map_short_ptr = 0;
static char* 	       mfs_digit_map_long_ptr  = 0;
static char* 	       mfs_digit_map_duration_ptr = 0;
static int 	       mfs_error               = FALSE;
static char 	       mfs_error_msg[256];
static char* 	       mfs_text_buf            = 0;
static char* 	       mfs_text_ptr            = 0;
static ErlDrvTermData* mfs_term_spec           = 0;
static int   	       mfs_term_spec_size      = 0;
static int   	       mfs_term_spec_index     = 0;
static int   	       mfs_token_counter       = 0;

static void mfs_alloc_failed(char* msg, int sz);
static void mfs_fatal_error(char* msg); 
static void mfs_short_load_token(ErlDrvTermData token_tag);
static void mfs_lower_load_token(ErlDrvTermData token_tag);
static void mfs_octet_load_token(ErlDrvTermData token_tag, int is_empty);
static void mfs_load_map_name();
static void mfs_load_map_value();
static void mfs_load_map_timer();
static void mfs_load_map_token();
static void mfs_ensure_term_spec(int size);

static ErlDrvData mfs_start(ErlDrvPort port, char *buf);
static void 	  mfs_stop(ErlDrvData handle);
static void 	  mfs_command(ErlDrvData handle, 
                                              char *buf, int buf_len);
static int 	  mfs_control(ErlDrvData handle, 
                                              unsigned int command,
                        	             char *buf, int buf_len, 
      			                     char **res_buf, int res_buf_len);
static void 	  mfs_finish(void);

/* 
 * The driver entry 
 */

static ErlDrvEntry mfs_entry = {
    NULL,              /* init, always NULL for dynamic drivers */
    mfs_start,         /* start, called when port is opened */
    mfs_stop,          /* stop, called when port is closed */
    mfs_command,       /* output, called when erlang has sent */
    NULL,              /* ready_input, called when input descriptor ready */
    NULL,              /* ready_output, called when output descriptor ready */
    MEGACO_DRV_NAME,   /* char *driver_name, the arg to open_port */
    mfs_finish,        /* finish, called when unloaded */
    NULL,              /* void * that is not used (BC) */
    mfs_control,       /* control, port_control callback */
    NULL,              /* timeout, called on timeouts */
    NULL               /* outputv, vector output interface */
};    

#define LOAD_TOKEN(TokenTag) mfs_lower_load_token(TokenTag)

#define LOAD_SHORT_TOKEN(TokenTag) mfs_short_load_token(TokenTag)

#define LOAD_OCTET_TOKEN(TokenTag) mfs_octet_load_token(TokenTag, 0)

#define LOAD_EMPTY_OCTET_TOKEN(TokenTag) mfs_octet_load_token(TokenTag, 1)


/* OTP-4236 */
#define ASSIGN_TERM_SPEC(what)                     \
{                                                  \
   if (mfs_term_spec != NULL)                      \
     mfs_term_spec[mfs_term_spec_index++] = what;  \
}

%}

%x SKIP_RBRKT MTP_HEXDIG LOCAL_OCTETS REMOTE_OCTETS 
%x MAP_NAME MAP_OPT_LBRKT MAP_VALUE MAP_SKIP_COMMA MAP_BODY
%x QUOTED_CHARS SKIP_DQUOTE

digit       ([0-9])
alpha       ([a-zA-Z])
hexdig      ([0-9a-fA-F])
sp          (\x20)
htab        (\x09)
cr          (\x0D)
lf          (\x0A)
slash       (\/)
dquote      (\")
colon       (\:)
dot         (\.)
wsp         ({sp}|{htab})
eol         ({cr}|({cr}{lf})|{lf})
safechar    ({digit}|{alpha}|[\+\-\&\!\_\/\'\?\@\^\`\~\*\$\\\(\)\%\|\.])
restchar    ([\;\[\]\{\}\:\,\#\<\>\=])
octet       ((\\\})|[\x01-\x7C\x7E-\xFF])
            
comment     (\;({safechar}|{restchar}|{wsp}|\x22)*{eol})
lwsp        ({wsp}|{comment}|{eol})*
            
equal       ({lwsp}\={lwsp})
nequal      ({lwsp}\#{lwsp})
lesser      ({lwsp}\<{lwsp})
greater     ({lwsp}\>{lwsp})
lbrkt       ({lwsp}\{{lwsp})
rbrkt       ({lwsp}\}{lwsp})
lsbrkt      ({lwsp}\[{lwsp})
rsbrkt      ({lwsp}\]{lwsp})
lpar        ({lwsp}\({lwsp})
rpar        ({lwsp}\){lwsp})
vbar        ({lwsp}\|{lwsp})
comma       ({lwsp}\,{lwsp})
sep         (({wsp}|{eol}|{comment}){lwsp})+
opt         ((o\-)?)
wild        ((w\-)?)

%%

<SKIP_RBRKT>{rbrkt}                     BEGIN(INITIAL);
                           
{digit}{8,8}t{digit}{8,8}               LOAD_TOKEN(mfs_TimeStampToken); /* OTP-5042 */
                                        
(MTP){lbrkt}                            BEGIN(MTP_HEXDIG);
<MTP_HEXDIG>{hexdig}{4,8}               {LOAD_TOKEN(mfs_MtpAddressToken); BEGIN(SKIP_RBRKT);}
                                        
((Local)|L){lbrkt}                      BEGIN(LOCAL_OCTETS);
<LOCAL_OCTETS>{rbrkt}                   {LOAD_EMPTY_OCTET_TOKEN(mfs_LocalDescriptorToken); BEGIN(INITIAL);}
<LOCAL_OCTETS>{octet}+                  {LOAD_OCTET_TOKEN(mfs_LocalDescriptorToken); BEGIN(SKIP_RBRKT);}
                          
((Remote)|R){lbrkt}                     BEGIN(REMOTE_OCTETS);
<REMOTE_OCTETS>{rbrkt}                  {LOAD_EMPTY_OCTET_TOKEN(mfs_RemoteDescriptorToken); BEGIN(INITIAL);}
<REMOTE_OCTETS>{octet}+                 {LOAD_OCTET_TOKEN(mfs_RemoteDescriptorToken); BEGIN(SKIP_RBRKT);}
                                        
((DigitMap)|DM)                         LOAD_TOKEN(mfs_DigitMapToken);
((DigitMap)|DM){equal}                  BEGIN(MAP_NAME);
((DigitMap)|DM){equal}{lbrkt}           BEGIN(MAP_VALUE);
((DigitMap)|DM){lbrkt}                  BEGIN(MAP_VALUE);

<MAP_NAME>{safechar}+                   {mfs_load_map_name(); BEGIN(MAP_OPT_LBRKT);}

<MAP_OPT_LBRKT>{lbrkt}                  BEGIN(MAP_VALUE);
<MAP_OPT_LBRKT><<EOF>>                  {mfs_load_map_token(); LOAD_TOKEN(mfs_endOfMessage); BEGIN(INITIAL); yyterminate();}
<MAP_OPT_LBRKT>.|\n                     {mfs_load_map_token(); yyless(0); BEGIN(INITIAL);}

<MAP_VALUE>t{colon}{digit}{1,2}         {mfs_load_map_timer(); BEGIN(MAP_SKIP_COMMA);}
<MAP_VALUE>s{colon}{digit}{1,2}         {mfs_load_map_timer(); BEGIN(MAP_SKIP_COMMA);}
<MAP_VALUE>l{colon}{digit}{1,2}         {mfs_load_map_timer(); BEGIN(MAP_SKIP_COMMA);}
<MAP_VALUE>z{colon}{digit}{1,2}         {mfs_load_map_timer(); BEGIN(MAP_SKIP_COMMA);}
<MAP_VALUE>.|\n                         {yyless(0); BEGIN(MAP_BODY);}

<MAP_SKIP_COMMA>{comma}                 BEGIN(MAP_VALUE);

<MAP_BODY>{octet}+                     {mfs_load_map_value(); mfs_load_map_token(); BEGIN(SKIP_RBRKT);}

{equal}                                 LOAD_SHORT_TOKEN(mfs_EQUAL);
{colon}                                 LOAD_SHORT_TOKEN(mfs_COLON);
{lbrkt}                                 LOAD_SHORT_TOKEN(mfs_LBRKT);
{rbrkt}                                 LOAD_SHORT_TOKEN(mfs_RBRKT);
{lsbrkt}                                LOAD_SHORT_TOKEN(mfs_LSBRKT);
{rsbrkt}                                LOAD_SHORT_TOKEN(mfs_RSBRKT);
{comma}                                 LOAD_SHORT_TOKEN(mfs_COMMA);
{nequal}                                LOAD_SHORT_TOKEN(mfs_NEQUAL);
{lesser}                                LOAD_SHORT_TOKEN(mfs_LESSER);
{greater}                               LOAD_SHORT_TOKEN(mfs_GREATER);
{sep}                                   LOAD_SHORT_TOKEN(mfs_SEP);

{dquote}                                BEGIN(QUOTED_CHARS);

<QUOTED_CHARS>({safechar}|{restchar}|{wsp})+ {LOAD_TOKEN(mfs_QuotedChars); BEGIN(SKIP_DQUOTE);}

<SKIP_DQUOTE>{dquote}                   BEGIN(INITIAL);
                                        
{opt}add                                LOAD_TOKEN(mfs_AddToken);
{opt}a                                  LOAD_TOKEN(mfs_AddToken);
andlgc                                  LOAD_TOKEN(mfs_AndAUDITSelectToken);
audit                                   LOAD_TOKEN(mfs_AuditToken);
at                                      LOAD_TOKEN(mfs_AuditToken);
{opt}{wild}auditcapability              LOAD_TOKEN(mfs_AuditCapToken);
{opt}{wild}ac                           LOAD_TOKEN(mfs_AuditCapToken);
{opt}{wild}auditvalue                   LOAD_TOKEN(mfs_AuditValueToken);
{opt}{wild}av                           LOAD_TOKEN(mfs_AuditValueToken);
authentication                          LOAD_TOKEN(mfs_AuthToken);
au                                      LOAD_TOKEN(mfs_AuthToken);
both                                    LOAD_TOKEN(mfs_BothToken);
b                                       LOAD_TOKEN(mfs_BothToken);
bothway                                 LOAD_TOKEN(mfs_BothwayToken);
bw                                      LOAD_TOKEN(mfs_BothwayToken);
brief                                   LOAD_TOKEN(mfs_BriefToken);
br                                      LOAD_TOKEN(mfs_BriefToken);
buffer                                  LOAD_TOKEN(mfs_BufferToken);
bf                                      LOAD_TOKEN(mfs_BufferToken);
context                                 LOAD_TOKEN(mfs_CtxToken);
c                                       LOAD_TOKEN(mfs_CtxToken);
contextattr                             LOAD_TOKEN(mfs_ContextAttrToken);
ct                                      LOAD_TOKEN(mfs_ContextAttrToken);
contextaudit                            LOAD_TOKEN(mfs_ContextAuditToken);
ca                                      LOAD_TOKEN(mfs_ContextAuditToken);
contextlist                             LOAD_TOKEN(mfs_ContextListToken);
clt                                     LOAD_TOKEN(mfs_ContextListToken);
spadirection                            LOAD_TOKEN(mfs_DirectionToken);
direction                               LOAD_TOKEN(mfs_DirectionToken);
spadi                                   LOAD_TOKEN(mfs_DirectionToken);
di                                      LOAD_TOKEN(mfs_DirectionToken);
discard                                 LOAD_TOKEN(mfs_DiscardToken);
ds                                      LOAD_TOKEN(mfs_DiscardToken);
disconnected                            LOAD_TOKEN(mfs_DisconnectedToken);
dc                                      LOAD_TOKEN(mfs_DisconnectedToken);
delay                                   LOAD_TOKEN(mfs_DelayToken);
dl                                      LOAD_TOKEN(mfs_DelayToken);
delete                                  LOAD_TOKEN(mfs_DeleteToken);
de                                      LOAD_TOKEN(mfs_DeleteToken);
duration                                LOAD_TOKEN(mfs_DurationToken);
dr                                      LOAD_TOKEN(mfs_DurationToken);
embed                                   LOAD_TOKEN(mfs_EmbedToken);
em                                      LOAD_TOKEN(mfs_EmbedToken);
emergency                               LOAD_TOKEN(mfs_EmergencyToken);
eg                                      LOAD_TOKEN(mfs_EmergencyToken);
emergencyoff                            LOAD_TOKEN(mfs_EmergencyOffToken); 
emergencyofftoken                       LOAD_TOKEN(mfs_EmergencyOffToken);
ego                                     LOAD_TOKEN(mfs_EmergencyOffToken);
emergencyvalue                          LOAD_TOKEN(mfs_EmergencyValueToken); 
egv                                     LOAD_TOKEN(mfs_EmergencyValueToken);
error                                   LOAD_TOKEN(mfs_ErrorToken);
er                                      LOAD_TOKEN(mfs_ErrorToken);
eventbuffer                             LOAD_TOKEN(mfs_EventBufferToken);
eb                                      LOAD_TOKEN(mfs_EventBufferToken);
events                                  LOAD_TOKEN(mfs_EventsToken);
e                                       LOAD_TOKEN(mfs_EventsToken);
external                                LOAD_TOKEN(mfs_ExternalToken);
ex                                      LOAD_TOKEN(mfs_ExternalToken);
failover                                LOAD_TOKEN(mfs_FailoverToken);
fl                                      LOAD_TOKEN(mfs_FailoverToken);
forced                                  LOAD_TOKEN(mfs_ForcedToken);
fo                                      LOAD_TOKEN(mfs_ForcedToken);
graceful                                LOAD_TOKEN(mfs_GracefulToken);
gr                                      LOAD_TOKEN(mfs_GracefulToken);
h221                                    LOAD_TOKEN(mfs_H221Token);
h223                                    LOAD_TOKEN(mfs_H223Token);
h226                                    LOAD_TOKEN(mfs_H226Token);
handoff                                 LOAD_TOKEN(mfs_HandOffToken);
ho                                      LOAD_TOKEN(mfs_HandOffToken);
iepscall                                LOAD_TOKEN(mfs_IEPSToken);
ieps                                    LOAD_TOKEN(mfs_IEPSToken);
inactive                                LOAD_TOKEN(mfs_InactiveToken);
in                                      LOAD_TOKEN(mfs_InactiveToken);
immackrequired                          LOAD_TOKEN(mfs_ImmAckRequiredToken);
ia                                      LOAD_TOKEN(mfs_ImmAckRequiredToken);
inservice                               LOAD_TOKEN(mfs_InSvcToken);
iv                                      LOAD_TOKEN(mfs_InSvcToken);
internal                                LOAD_TOKEN(mfs_InternalToken);
it                                      LOAD_TOKEN(mfs_InternalToken);
intersignal                             LOAD_TOKEN(mfs_IntsigDelayToken);
spais                                   LOAD_TOKEN(mfs_IntsigDelayToken);
isolate                                 LOAD_TOKEN(mfs_IsolateToken);
is                                      LOAD_TOKEN(mfs_IsolateToken);
intbyevent                              LOAD_TOKEN(mfs_InterruptByEventToken);
ibe                                     LOAD_TOKEN(mfs_InterruptByEventToken);
intbysigdescr                           LOAD_TOKEN(mfs_InterruptByNewSignalsDescrToken);
ibs                                     LOAD_TOKEN(mfs_InterruptByNewSignalsDescrToken);
iteration                               LOAD_TOKEN(mfs_IterationToken);
ir                                      LOAD_TOKEN(mfs_IterationToken);
keepactive                              LOAD_TOKEN(mfs_KeepActiveToken);
ka                                      LOAD_TOKEN(mfs_KeepActiveToken);
local                                   LOAD_TOKEN(mfs_LocalToken);
l                                       LOAD_TOKEN(mfs_LocalToken);
localcontrol                            LOAD_TOKEN(mfs_LocalControlToken);
lockstep                                LOAD_TOKEN(mfs_LockStepToken);
sp                                      LOAD_TOKEN(mfs_LockStepToken);
o                                       LOAD_TOKEN(mfs_LocalControlToken);
loopback                                LOAD_TOKEN(mfs_LoopbackToken);
lb                                      LOAD_TOKEN(mfs_LoopbackToken);
media                                   LOAD_TOKEN(mfs_MediaToken);
m                                       LOAD_TOKEN(mfs_MediaToken);
megaco                                  LOAD_TOKEN(mfs_MegacopToken);
!                                       LOAD_TOKEN(mfs_MegacopToken);
method                                  LOAD_TOKEN(mfs_MethodToken);
mt                                      LOAD_TOKEN(mfs_MethodToken);
mgcidtotry                              LOAD_TOKEN(mfs_MgcIdToken);
mg                                      LOAD_TOKEN(mfs_MgcIdToken);
mode                                    LOAD_TOKEN(mfs_ModeToken);
mo                                      LOAD_TOKEN(mfs_ModeToken);
{opt}modify                             LOAD_TOKEN(mfs_ModifyToken);
{opt}mf                                 LOAD_TOKEN(mfs_ModifyToken);
modem                                   LOAD_TOKEN(mfs_ModemToken);
md                                      LOAD_TOKEN(mfs_ModemToken);
{opt}move                               LOAD_TOKEN(mfs_MoveToken);
{opt}mv                                 LOAD_TOKEN(mfs_MoveToken);
mux                                     LOAD_TOKEN(mfs_MuxToken);
mx                                      LOAD_TOKEN(mfs_MuxToken);
nevernotify                             LOAD_TOKEN(mfs_NeverNotifyToken);
nbnn                                    LOAD_TOKEN(mfs_NeverNotifyToken);
{opt}notify                             LOAD_TOKEN(mfs_NotifyToken);
{opt}n                                  LOAD_TOKEN(mfs_NotifyToken);
notifycompletion                        LOAD_TOKEN(mfs_NotifyCompletionToken);
nc                                      LOAD_TOKEN(mfs_NotifyCompletionToken);
immediatenotify                         LOAD_TOKEN(mfs_NotifyImmediateToken);
nbin                                    LOAD_TOKEN(mfs_NotifyImmediateToken);
regulatednotify                         LOAD_TOKEN(mfs_NotifyRegulatedToken);
nbrn                                    LOAD_TOKEN(mfs_NotifyRegulatedToken);
nx64kservice                            LOAD_TOKEN(mfs_Nx64kToken);
n64                                     LOAD_TOKEN(mfs_Nx64kToken);
observedevents                          LOAD_TOKEN(mfs_ObservedEventsToken);
oe                                      LOAD_TOKEN(mfs_ObservedEventsToken);
oneway                                  LOAD_TOKEN(mfs_OnewayToken);
ow                                      LOAD_TOKEN(mfs_OnewayToken);
onewayboth                              LOAD_TOKEN(mfs_OnewayBothToken);
owb                                     LOAD_TOKEN(mfs_OnewayBothToken);
onewayexternal                          LOAD_TOKEN(mfs_OnewayExternalToken);
owe                                     LOAD_TOKEN(mfs_OnewayExternalToken);
off                                     LOAD_TOKEN(mfs_OffToken);
on                                      LOAD_TOKEN(mfs_OnToken);
onoff                                   LOAD_TOKEN(mfs_OnOffToken);
oo                                      LOAD_TOKEN(mfs_OnOffToken);
orlgc                                   LOAD_TOKEN(mfs_OrAUDITselectToken);
otherreason                             LOAD_TOKEN(mfs_OtherReasonToken);
or                                      LOAD_TOKEN(mfs_OtherReasonToken);
outofservice                            LOAD_TOKEN(mfs_OutOfSvcToken);
os                                      LOAD_TOKEN(mfs_OutOfSvcToken);
packages                                LOAD_TOKEN(mfs_PackagesToken);
pg                                      LOAD_TOKEN(mfs_PackagesToken);
pending                                 LOAD_TOKEN(mfs_PendingToken);
pn                                      LOAD_TOKEN(mfs_PendingToken);
priority                                LOAD_TOKEN(mfs_PriorityToken);
pr                                      LOAD_TOKEN(mfs_PriorityToken);
profile                                 LOAD_TOKEN(mfs_ProfileToken);
pf                                      LOAD_TOKEN(mfs_ProfileToken);
reason                                  LOAD_TOKEN(mfs_ReasonToken);
re                                      LOAD_TOKEN(mfs_ReasonToken);
receiveonly                             LOAD_TOKEN(mfs_RecvonlyToken);
rc                                      LOAD_TOKEN(mfs_RecvonlyToken);
reply                                   LOAD_TOKEN(mfs_ReplyToken);
p                                       LOAD_TOKEN(mfs_ReplyToken);
reseteventsdescriptor                   LOAD_TOKEN(mfs_ResetEventsDescriptorToken);
rse                                     LOAD_TOKEN(mfs_ResetEventsDescriptorToken);
transactionresponseack                  LOAD_TOKEN(mfs_ResponseAckToken);
k                                       LOAD_TOKEN(mfs_ResponseAckToken);
restart                                 LOAD_TOKEN(mfs_RestartToken);
rs                                      LOAD_TOKEN(mfs_RestartToken);
remote                                  LOAD_TOKEN(mfs_RemoteToken);
r                                       LOAD_TOKEN(mfs_RemoteToken);
sparequestid                            LOAD_TOKEN(mfs_RequestIDToken);
requestid                               LOAD_TOKEN(mfs_RequestIDToken);
sparq                                   LOAD_TOKEN(mfs_RequestIDToken);
rq                                      LOAD_TOKEN(mfs_RequestIDToken);
reservedgroup                           LOAD_TOKEN(mfs_ReservedGroupToken);
rg                                      LOAD_TOKEN(mfs_ReservedGroupToken);
reservedvalue                           LOAD_TOKEN(mfs_ReservedValueToken);
rv                                      LOAD_TOKEN(mfs_ReservedValueToken);
sendonly                                LOAD_TOKEN(mfs_SendonlyToken);
so                                      LOAD_TOKEN(mfs_SendonlyToken);
sendreceive                             LOAD_TOKEN(mfs_SendrecvToken);
sr                                      LOAD_TOKEN(mfs_SendrecvToken);
services                                LOAD_TOKEN(mfs_ServicesToken);
sv                                      LOAD_TOKEN(mfs_ServicesToken);
servicestates                           LOAD_TOKEN(mfs_ServiceStatesToken);
si                                      LOAD_TOKEN(mfs_ServiceStatesToken);
{opt}servicechange                      LOAD_TOKEN(mfs_ServiceChangeToken);
{opt}sc                                 LOAD_TOKEN(mfs_ServiceChangeToken);
servicechangeaddress                    LOAD_TOKEN(mfs_ServiceChangeAddressToken);
ad                                      LOAD_TOKEN(mfs_ServiceChangeAddressToken);
servicechangeinc                        LOAD_TOKEN(mfs_ServiceChangeIncompleteToken);
sic                                     LOAD_TOKEN(mfs_ServiceChangeIncompleteToken);
signallist                              LOAD_TOKEN(mfs_SignalListToken);
sl                                      LOAD_TOKEN(mfs_SignalListToken);
signals                                 LOAD_TOKEN(mfs_SignalsToken);
sg                                      LOAD_TOKEN(mfs_SignalsToken);
signaltype                              LOAD_TOKEN(mfs_SignalTypeToken);
sy                                      LOAD_TOKEN(mfs_SignalTypeToken);
statistics                              LOAD_TOKEN(mfs_StatsToken);
sa                                      LOAD_TOKEN(mfs_StatsToken);
stream                                  LOAD_TOKEN(mfs_StreamToken);
st                                      LOAD_TOKEN(mfs_StreamToken);
{opt}{wild}subtract                     LOAD_TOKEN(mfs_SubtractToken);
{opt}{wild}s                            LOAD_TOKEN(mfs_SubtractToken);
synchisdn                               LOAD_TOKEN(mfs_SynchISDNToken);
sn                                      LOAD_TOKEN(mfs_SynchISDNToken);
terminationstate                        LOAD_TOKEN(mfs_TerminationStateToken);
ts                                      LOAD_TOKEN(mfs_TerminationStateToken);
test                                    LOAD_TOKEN(mfs_TestToken);
te                                      LOAD_TOKEN(mfs_TestToken);
timeout                                 LOAD_TOKEN(mfs_TimeOutToken);
to                                      LOAD_TOKEN(mfs_TimeOutToken);
topology                                LOAD_TOKEN(mfs_TopologyToken);
tp                                      LOAD_TOKEN(mfs_TopologyToken);
transaction                             LOAD_TOKEN(mfs_TransToken);
t                                       LOAD_TOKEN(mfs_TransToken);
v18                                     LOAD_TOKEN(mfs_V18Token);
v22                                     LOAD_TOKEN(mfs_V22Token);
v22b                                    LOAD_TOKEN(mfs_V22bisToken);
v32                                     LOAD_TOKEN(mfs_V32Token);
v32b                                    LOAD_TOKEN(mfs_V32bisToken);
v34                                     LOAD_TOKEN(mfs_V34Token);
v76                                     LOAD_TOKEN(mfs_V76Token);
v90                                     LOAD_TOKEN(mfs_V90Token);
v91                                     LOAD_TOKEN(mfs_V91Token);
version                                 LOAD_TOKEN(mfs_VersionToken);
v                                       LOAD_TOKEN(mfs_VersionToken);
({safechar})+                           LOAD_TOKEN(mfs_SafeChars);
                                        
<<EOF>>                                 {LOAD_SHORT_TOKEN(mfs_endOfMessage); BEGIN(INITIAL); yyterminate();}
<*>.|\n                                 {LOAD_TOKEN(mfs_IllegalChar); BEGIN(INITIAL); yyterminate();}

%%

/* MEGACO_LINENO_OR_TOKENCOUNTER
 * Note that this construction is intended to make it
 * possible to generate flex files that either reports
 * line-number or one that don't.
 * See MEGACO_YY_LINENO_OPTION and 
 *     MEGACO_DUMMY_DECL_YY_LINENO above.
 */
#define LINENO_OR_TOKENCNT yylineno

/* #define MFS_DEBUG true */    /* temporary */
#if defined(MFS_DEBUG)
#  define DBG( proto ) mfs_dbg proto
#  define DBG_BUF(func, bufName, buf, bufSz) mfs_dbg_buf_print(func, bufName, buf, bufSz)
#else
#  define DBG( proto ) ((void) 0)
#  define DBG_BUF(func, bufName, buf, bufSz) ((void) 0)
#endif /* if defined(MFS_DEBUG) */


#if defined(MFS_DEBUG)

#define MFS_LOG_FILE_NAME "megaco_flex_scanner_drv.log"
#define MFS_LOG_FILE_MODE "a"

#define CHUNK 16

static void mfs_dbg(char *s, ...) {
  FILE *f;
  va_list args;
  va_start(args, s); /* The first arg without name */
  f = fopen(MFS_LOG_FILE_NAME, MFS_LOG_FILE_MODE);
  vfprintf(f, s, args);
  fclose(f);
  va_end(args);
}

static void hexdump(FILE *out, unsigned char *buf, int bufsz)
{
  int i,j;
  int count;

  /* do this in chunks of CHUNK bytes */
  for (i=0; i<bufsz; i+=CHUNK) {
    /* show the offset */
    fprintf(out,"0x%06x  ", i);

    /* max of CHUNK or remaining bytes */
    count = ((bufsz-i) > CHUNK ? CHUNK : bufsz-i);
    
    /* show the bytes */
    for (j=0; j<count; j++) {
      if (j==CHUNK/2) fprintf(out," ");
      fprintf(out,"%02x ",buf[i+j]);
    }
    
    /* pad with spaces if less than CHUNK */
    for (j=count; j<CHUNK; j++) {
      if (j==CHUNK/2) fprintf(out," ");
      fprintf(out,"   ");
    }

    /* divider between hex and ascii */
    fprintf(out," ");
  
    for (j=0; j<count; j++) 
      fprintf(out,"%c",(isprint(buf[i+j]) ? buf[i+j] : '.'));
 
    fprintf(out,"\n");
  }
}

static void mfs_dbg_buf_print(char* func, char* bufName, char* buf, int len)
{
  FILE *f;
  f = fopen(MFS_LOG_FILE_NAME, MFS_LOG_FILE_MODE);
  fprintf(f, "%s -> %s (%d):\n", func, bufName, len);
  hexdump(f, (unsigned char*) buf, len);
  fclose(f);
}


#endif /* if defined(MFS_DEBUG) */


static void mfs_alloc_failed(char* msg, int sz)
{
  /*
   * Make sure we are not allready in error state
   */
  if (!mfs_error) {

    /* 
     * Make sure that there is room in the buffer:
     * length of msg + 10 chars for the ' of %d bytes'
     * + 10 chars for the size value...
     * This is really overkill since the msg string is never
     * longer then 50 chars, but sinze this function is 
     * called when we have run out of memory...
     */

    int msg_len = strlen(msg);
    if ((10 + 10 + msg_len) < sizeof(mfs_error_msg)) {
      if (0 >= sprintf(mfs_error_msg, "%s of %d bytes", msg, sz)) {
	mfs_fatal_error(msg);
      }
    } else {
      mfs_fatal_error(msg);
    }
    mfs_error = TRUE;
  }
}


static void mfs_ensure_term_spec(int size)
{
  /*
  DBG( ("mfs_ensure_term_spec -> entry with"
	"\n   size:       %d"
	"\nwhen"
	"\n   spec_index: %d"
	"\n   spec_size:  %d"
	"\n", size, mfs_term_spec_index, mfs_term_spec_size) );
  */

  /* OTP-4236 - BEGIN */
  if ((mfs_term_spec_index + size) >= mfs_term_spec_size) {
    void *tmp;

    DBG( ("mfs_ensure_term_spec -> allocate more memory when"
	  "\n   term_spec_index: %d"
	  "\n   term_spec_size:  %d\n", 
	  mfs_term_spec_index, mfs_term_spec_size) );

    mfs_term_spec_size = (mfs_term_spec_size * 2) + size;

    DBG( ("mfs_ensure_term_spec -> "
	  "term_spec is at 0x%X, new term_spec_size is %d\n", 
	  mfs_term_spec, mfs_term_spec_size) );

    tmp = REALLOC(mfs_term_spec, mfs_term_spec_size * sizeof(ErlDrvTermData));

    if (tmp == NULL) {
      /*
       * Ouch, we did'nt get any new memory.
       * Just give ut. I.e. free the memory we have (note that
       * the assign macro tests the buffer before assigning).
       */
      driver_free(mfs_term_spec);
      mfs_term_spec = NULL;

      mfs_alloc_failed("failed reallocating term spec buffer", 
		       mfs_term_spec_size * sizeof(ErlDrvTermData));

    } else {
      mfs_term_spec = tmp;
    }

    DBG( ("mfs_ensure_term_spec -> new term_spec is at 0x%X\n", 
	  mfs_term_spec) );
  }
  /* OTP-4236 - END */
}

static void mfs_short_load_token(ErlDrvTermData TokenTag)
{
  /* Build a {TokenTag, LineNumber} tuple */

  /*
  DBG( ("mfs_short_load_token -> entry with"
	"\n   TokenTag: %ld\n", TokenTag) );
  */

  mfs_ensure_term_spec(6); 
  mfs_token_counter++; 
  ASSIGN_TERM_SPEC(ERL_DRV_ATOM);
  ASSIGN_TERM_SPEC(TokenTag);
  ASSIGN_TERM_SPEC(ERL_DRV_INT);
  ASSIGN_TERM_SPEC(LINENO_OR_TOKENCNT);
  ASSIGN_TERM_SPEC(ERL_DRV_TUPLE);
  ASSIGN_TERM_SPEC(2);
}

static void mfs_octet_load_token(ErlDrvTermData TokenTag, int is_empty)
{
  /* Build a {TokenTag, LineNumber, String} tuple */

  DBG( ("mfs_octet_load_token -> entry with"
	"\n   TokenTag: %ld"
	"\n   is_empty: %ld\n", TokenTag, is_empty) );
  
  mfs_ensure_term_spec(9); 
  mfs_token_counter++; 
  ASSIGN_TERM_SPEC(ERL_DRV_ATOM);
  ASSIGN_TERM_SPEC(TokenTag);
  ASSIGN_TERM_SPEC(ERL_DRV_INT);
  ASSIGN_TERM_SPEC(LINENO_OR_TOKENCNT);
  ASSIGN_TERM_SPEC(ERL_DRV_STRING);

  if (is_empty) {
    *mfs_text_ptr = 0;
    ASSIGN_TERM_SPEC((ErlDrvTermData)mfs_text_ptr);
    mfs_text_ptr++;
    ASSIGN_TERM_SPEC(0);
  } else {
    strncpy(mfs_text_ptr, yytext, yyleng);

    DBG_BUF("mfs_octet_load_token", "mfs_text_ptr", 
	    mfs_text_ptr, yyleng);

    ASSIGN_TERM_SPEC((ErlDrvTermData)mfs_text_ptr);
    mfs_text_ptr += yyleng;
    ASSIGN_TERM_SPEC(yyleng);
  }
  ASSIGN_TERM_SPEC(ERL_DRV_TUPLE);
  ASSIGN_TERM_SPEC(3);
}

static void mfs_lower_load_token(ErlDrvTermData TokenTag)
{
  /* Build a {TokenTag, LineNumber, LowerCaseString} tuple */
  int i;

  /*
  DBG( ("mfs_lower_load_token -> entry with"
	"\n   TokenTag: %ld\n", TokenTag) );
  */

  mfs_ensure_term_spec(9); 
  mfs_token_counter++; 
  ASSIGN_TERM_SPEC(ERL_DRV_ATOM);
  ASSIGN_TERM_SPEC(TokenTag);
  ASSIGN_TERM_SPEC(ERL_DRV_INT);
  ASSIGN_TERM_SPEC(LINENO_OR_TOKENCNT);
  ASSIGN_TERM_SPEC(ERL_DRV_STRING);

  for ( i = 0; i < yyleng; ++i ) {
    mfs_text_ptr[i] = tolower(yytext[i]);
  }

  /*
  DBG_BUF("mfs_lower_load_token", "mfs_text_ptr", 
           mfs_text_ptr, yyleng);
  */

  ASSIGN_TERM_SPEC((ErlDrvTermData)mfs_text_ptr);
  mfs_text_ptr += yyleng;
  ASSIGN_TERM_SPEC(yyleng);
  ASSIGN_TERM_SPEC(ERL_DRV_TUPLE);
  ASSIGN_TERM_SPEC(3);
}

static void mfs_load_map_name()
{
    /* Copy digit map name as lower case */
    int i;

    for ( i = 0; i < yyleng; ++i ) {
      mfs_text_ptr[i] = tolower(yytext[i]);
    }

    mfs_digit_map_name_ptr = mfs_text_ptr;
    mfs_digit_map_name_len = yyleng;
    mfs_text_ptr += yyleng;
}

static void mfs_load_map_value()
{
    /* Copy digit map value as lower case */
    int i;

    for ( i = 0; i < yyleng; ++i ) {
      mfs_text_ptr[i] = tolower(yytext[i]);
    }

    mfs_digit_map_value_ptr = mfs_text_ptr;
    mfs_digit_map_value_len = yyleng;
    mfs_text_ptr += yyleng;
}

static void mfs_load_map_timer()
{
  /* The digit map timer consists of 3 or 4 characters:
   * z and Z are actually version 2 only
   * 0 - the kind of timer (t|T|s|S|l|L|z|Z)
   * 1 - a colon
   * 2 - mandatory digit
   * 3 - optional digit
   */
  
  int timer_len = yyleng - 2;

  /*
  DBG( ("mfs_load_map_timer -> entry when yyleng: %d\n", yyleng) );
  DBG( ("mfs_load_map_timer -> yytext: 0x%x\n", yytext) );

  DBG( ("mfs_load_map_timer -> yytext[0]: %u (%c)\n", yytext[0], yytext[0]) );
  DBG( ("mfs_load_map_timer -> yytext[1]: %u (%c)\n", yytext[1], yytext[1]) );
  DBG( ("mfs_load_map_timer -> yytext[2]: %u (%c)\n", yytext[2], yytext[2]) );
  DBG( ("mfs_load_map_timer -> yytext[3]: %u (%c)\n", yytext[3], yytext[3]) );
  */

  /* Pad with leading zero */

  if (timer_len == 1) {
    mfs_text_ptr[0] = '0';
    mfs_text_ptr[1] = yytext[2];
  } else if (timer_len == 2) {
    mfs_text_ptr[0] = yytext[2];
    mfs_text_ptr[1] = yytext[3];
  }

  /*
  DBG( ("mfs_load_map_timer -> mfs_text_ptr[0]: %u (%c)\n", 
	mfs_text_ptr[0], mfs_text_ptr[0]) );
  DBG( ("mfs_load_map_timer -> mfs_text_ptr[1]: %u (%c)\n", 
	mfs_text_ptr[1], mfs_text_ptr[1]) );

  DBG( ("mfs_load_map_timer -> mfs_text_ptr: 0x%x\n", 
	mfs_text_ptr) );
  */

  switch (yytext[0]) {
  case 't':
  case 'T':
    mfs_digit_map_start_ptr = mfs_text_ptr;
    break;;
  case 's':
  case 'S':
    mfs_digit_map_short_ptr = mfs_text_ptr;
    break;;
  case 'l':
  case 'L':
    mfs_digit_map_long_ptr = mfs_text_ptr;
    break;;
  case 'z':
  case 'Z':
    mfs_digit_map_duration_ptr = mfs_text_ptr;
    break;;
  }

  /* We pad when there is only one digit, so it will always be two */
  mfs_text_ptr += 2; 

}

static void load_timer_field(char* text)
{
  mfs_ensure_term_spec(2);    /* OTP-4236 */
  if (text == NULL) {
    ASSIGN_TERM_SPEC(ERL_DRV_ATOM);
    ASSIGN_TERM_SPEC(mfs_asn1_NOVALUE);
  } else {
    ASSIGN_TERM_SPEC(ERL_DRV_INT);
    ASSIGN_TERM_SPEC(((text[0] - '0') * 10) + (text[1] - '0'));
  }
}

static void mfs_load_map_token()
{
  /* 
   * Build a {'DigitMapDescriptorToken', LineNumber, 
   *          {'DigitMapDescriptor', DigitMapName, DigitMapValue}} tuple 
   */

  mfs_ensure_term_spec(20); 
  mfs_token_counter++; 
  ASSIGN_TERM_SPEC(ERL_DRV_ATOM);
  ASSIGN_TERM_SPEC(mfs_DigitMapDescriptorToken);
  ASSIGN_TERM_SPEC(ERL_DRV_INT);
  ASSIGN_TERM_SPEC(LINENO_OR_TOKENCNT);
  
  ASSIGN_TERM_SPEC(ERL_DRV_ATOM);
  ASSIGN_TERM_SPEC(mfs_DigitMapDescriptor);
  
  if (mfs_digit_map_name_ptr == 0) {
    ASSIGN_TERM_SPEC(ERL_DRV_ATOM);
    ASSIGN_TERM_SPEC(mfs_asn1_NOVALUE);
  } else {
    ASSIGN_TERM_SPEC(ERL_DRV_STRING);
    ASSIGN_TERM_SPEC((ErlDrvTermData)mfs_digit_map_name_ptr);
    ASSIGN_TERM_SPEC(mfs_digit_map_name_len);
    mfs_digit_map_name_ptr = NULL; 
  }
  
  if (mfs_digit_map_value_ptr == NULL) {
    ASSIGN_TERM_SPEC(ERL_DRV_ATOM);
    ASSIGN_TERM_SPEC(mfs_asn1_NOVALUE);
  } else {
    ASSIGN_TERM_SPEC(ERL_DRV_ATOM);
    ASSIGN_TERM_SPEC(mfs_DigitMapValue);
    
    /* Take care of timer values */
    load_timer_field(mfs_digit_map_start_ptr);
    mfs_digit_map_start_ptr = NULL;
    
    load_timer_field(mfs_digit_map_short_ptr);
    mfs_digit_map_short_ptr = NULL;
    
    load_timer_field(mfs_digit_map_long_ptr);
    mfs_digit_map_long_ptr = NULL;
    
    load_timer_field(mfs_digit_map_duration_ptr);
    mfs_digit_map_duration_ptr = NULL;
    
    ASSIGN_TERM_SPEC(ERL_DRV_STRING);
    ASSIGN_TERM_SPEC((ErlDrvTermData)mfs_digit_map_value_ptr);
    ASSIGN_TERM_SPEC(mfs_digit_map_value_len);
    mfs_digit_map_value_ptr = NULL; 
    ASSIGN_TERM_SPEC(ERL_DRV_TUPLE);
    ASSIGN_TERM_SPEC(6);
  }
  
  ASSIGN_TERM_SPEC(ERL_DRV_TUPLE);
  ASSIGN_TERM_SPEC(3);
  
  ASSIGN_TERM_SPEC(ERL_DRV_TUPLE);
  ASSIGN_TERM_SPEC(3);

}


DRIVER_INIT(mfs_drv)
{
  DBG( ("DRIVER_INIT(mfs_drv) -> entry\n") );

  return &mfs_entry;
}

static ErlDrvData mfs_start(ErlDrvPort port, char *buf)
{
  DBG( ("mfs_start -> entry\n") );

  mfs_port = port;

  mfs_AddToken = driver_mk_atom("AddToken");
  mfs_AndAUDITSelectToken = driver_mk_atom("AndAUDITSelectToken");
  mfs_AuditCapToken = driver_mk_atom("AuditCapToken");
  mfs_AuditToken = driver_mk_atom("AuditToken");
  mfs_AuditValueToken = driver_mk_atom("AuditValueToken");
  mfs_AuthToken = driver_mk_atom("AuthToken");
  mfs_BothToken = driver_mk_atom("BothToken");
  mfs_BothwayToken = driver_mk_atom("BothwayToken");
  mfs_BriefToken = driver_mk_atom("BriefToken");
  mfs_BufferToken = driver_mk_atom("BufferToken");
  mfs_COLON = driver_mk_atom("COLON");
  mfs_COMMA = driver_mk_atom("COMMA");
  mfs_ContextAttrToken = driver_mk_atom("ContextAttrToken");
  mfs_ContextAuditToken = driver_mk_atom("ContextAuditToken");
  mfs_ContextListToken = driver_mk_atom("ContextListToken");
  mfs_CtxToken = driver_mk_atom("CtxToken");
  mfs_DelayToken = driver_mk_atom("DelayToken");
  mfs_DeleteToken = driver_mk_atom("DeleteToken");
  mfs_DigitMapDescriptor = driver_mk_atom("DigitMapDescriptor");
  mfs_DigitMapDescriptorToken = driver_mk_atom("DigitMapDescriptorToken");
  mfs_DigitMapToken = driver_mk_atom("DigitMapToken");
  mfs_DigitMapValue = driver_mk_atom("DigitMapValue");
  mfs_DirectionToken = driver_mk_atom("DirectionToken");
  mfs_DiscardToken = driver_mk_atom("DiscardToken");
  mfs_DisconnectedToken = driver_mk_atom("DisconnectedToken");
  mfs_DurationToken = driver_mk_atom("DurationToken");
  mfs_EQUAL = driver_mk_atom("EQUAL");
  mfs_EmbedToken = driver_mk_atom("EmbedToken");
  mfs_EmergencyToken = driver_mk_atom("EmergencyToken");
  mfs_EmergencyOffToken = driver_mk_atom("EmergencyOffToken");
  mfs_EmergencyValueToken = driver_mk_atom("EmergencyValueToken");
  mfs_ErrorToken = driver_mk_atom("ErrorToken");
  mfs_EventBufferToken = driver_mk_atom("EventBufferToken");
  mfs_EventsToken = driver_mk_atom("EventsToken");
  mfs_ExternalToken = driver_mk_atom("ExternalToken");
  mfs_FailoverToken = driver_mk_atom("FailoverToken");
  mfs_ForcedToken = driver_mk_atom("ForcedToken");
  mfs_GREATER = driver_mk_atom("GREATER");
  mfs_GracefulToken = driver_mk_atom("GracefulToken");
  mfs_H221Token = driver_mk_atom("H221Token");
  mfs_H223Token = driver_mk_atom("H223Token");
  mfs_H226Token = driver_mk_atom("H226Token");
  mfs_HandOffToken = driver_mk_atom("HandOffToken");
  mfs_IEPSToken = driver_mk_atom("IEPSToken");
  mfs_IllegalChar = driver_mk_atom("IllegalChar");
  mfs_ImmAckRequiredToken = driver_mk_atom("ImmAckRequiredToken");
  mfs_InSvcToken = driver_mk_atom("InSvcToken");
  mfs_InactiveToken = driver_mk_atom("InactiveToken");
  mfs_InternalToken = driver_mk_atom("InternalToken");
  mfs_InterruptByEventToken = driver_mk_atom("InterruptByEventToken");
  mfs_InterruptByNewSignalsDescrToken = driver_mk_atom("InterruptByNewSignalsDescrToken");
  mfs_IntsigDelayToken = driver_mk_atom("IntsigDelayToken");
  mfs_IsolateToken = driver_mk_atom("IsolateToken");
  mfs_IterationToken = driver_mk_atom("IterationToken");
  mfs_KeepActiveToken = driver_mk_atom("KeepActiveToken");
  mfs_LBRKT = driver_mk_atom("LBRKT");
  mfs_LESSER = driver_mk_atom("LESSER");
  mfs_LSBRKT = driver_mk_atom("LSBRKT");
  mfs_LocalControlToken = driver_mk_atom("LocalControlToken");
  mfs_LocalDescriptorToken = driver_mk_atom("LocalDescriptorToken");
  mfs_LocalToken = driver_mk_atom("LocalToken");
  mfs_LockStepToken = driver_mk_atom("LockStepToken");
  mfs_LoopbackToken = driver_mk_atom("LoopbackToken");
  mfs_MediaToken = driver_mk_atom("MediaToken");
  mfs_MegacopToken = driver_mk_atom("MegacopToken");
  /* mfs_MessageSegmentToken = driver_mk_atom("MessageSegmentToken"); */
  mfs_MethodToken = driver_mk_atom("MethodToken");
  mfs_MgcIdToken = driver_mk_atom("MgcIdToken");
  mfs_ModeToken = driver_mk_atom("ModeToken");
  mfs_ModemToken = driver_mk_atom("ModemToken");
  mfs_ModifyToken = driver_mk_atom("ModifyToken");
  mfs_MoveToken = driver_mk_atom("MoveToken");
  mfs_MtpAddressToken = driver_mk_atom("MtpAddressToken");
  mfs_MuxToken = driver_mk_atom("MuxToken");
  mfs_NEQUAL = driver_mk_atom("NEQUAL");
  mfs_NotifyCompletionToken = driver_mk_atom("NotifyCompletionToken");
  mfs_NotifyImmediateToken = driver_mk_atom("NotifyImmediateToken");
  mfs_NotifyRegulatedToken = driver_mk_atom("NotifyRegulatedToken");
  mfs_NeverNotifyToken = driver_mk_atom("NeverNotifyToken");
  mfs_NotifyToken = driver_mk_atom("NotifyToken");
  mfs_Nx64kToken = driver_mk_atom("Nx64kToken");
  mfs_ObservedEventsToken = driver_mk_atom("ObservedEventsToken");
  mfs_OffToken = driver_mk_atom("OffToken");
  mfs_OnOffToken = driver_mk_atom("OnOffToken");
  mfs_OnToken = driver_mk_atom("OnToken");
  mfs_OnewayToken = driver_mk_atom("OnewayToken");
  mfs_OnewayBothToken = driver_mk_atom("OnewayBothToken");
  mfs_OnewayExternalToken = driver_mk_atom("OnewayExternalToken");
  mfs_OrAUDITselectToken = driver_mk_atom("OrAUDITselectToken");
  mfs_OtherReasonToken = driver_mk_atom("OtherReasonToken");
  mfs_OutOfSvcToken = driver_mk_atom("OutOfSvcToken");
  mfs_PackagesToken = driver_mk_atom("PackagesToken");
  mfs_PendingToken = driver_mk_atom("PendingToken");
  mfs_PriorityToken = driver_mk_atom("PriorityToken");
  mfs_ProfileToken = driver_mk_atom("ProfileToken");
  mfs_QuotedChars = driver_mk_atom("QuotedChars");
  mfs_RBRKT = driver_mk_atom("RBRKT");
  mfs_RSBRKT = driver_mk_atom("RSBRKT");
  mfs_ReasonToken = driver_mk_atom("ReasonToken");
  mfs_RecvonlyToken = driver_mk_atom("RecvonlyToken");
  mfs_RemoteDescriptorToken = driver_mk_atom("RemoteDescriptorToken");
  mfs_RemoteToken = driver_mk_atom("RemoteToken");
  mfs_ReplyToken = driver_mk_atom("ReplyToken");
  mfs_RequestIDToken = driver_mk_atom("RequestIDToken");
  mfs_ReservedGroupToken = driver_mk_atom("ReservedGroupToken");
  mfs_ReservedValueToken = driver_mk_atom("ReservedValueToken");
  mfs_ResetEventsDescriptorToken = driver_mk_atom("ResetEventsDescriptorToken");
  mfs_ResponseAckToken = driver_mk_atom("ResponseAckToken");
  mfs_RestartToken = driver_mk_atom("RestartToken");
  mfs_SEP = driver_mk_atom("SEP");
  mfs_SafeChars = driver_mk_atom("SafeChars");
  /* mfs_SegmentationCOmpleteToken = driver_mk_atom("SegmentationCOmpleteToken"); */
  mfs_SendonlyToken = driver_mk_atom("SendonlyToken");
  mfs_SendrecvToken = driver_mk_atom("SendrecvToken");
  mfs_ServiceChangeAddressToken = driver_mk_atom("ServiceChangeAddressToken");
  mfs_ServiceChangeIncompleteToken = driver_mk_atom("ServiceChangeIncompleteToken");
  mfs_ServiceChangeToken = driver_mk_atom("ServiceChangeToken");
  mfs_ServiceStatesToken = driver_mk_atom("ServiceStatesToken");
  mfs_ServicesToken = driver_mk_atom("ServicesToken");
  mfs_SignalListToken = driver_mk_atom("SignalListToken");
  mfs_SignalTypeToken = driver_mk_atom("SignalTypeToken");
  mfs_SignalsToken = driver_mk_atom("SignalsToken");
  mfs_StatsToken = driver_mk_atom("StatsToken");
  mfs_StreamToken = driver_mk_atom("StreamToken");
  mfs_SubtractToken = driver_mk_atom("SubtractToken");
  mfs_SynchISDNToken = driver_mk_atom("SynchISDNToken");
  mfs_TerminationStateToken = driver_mk_atom("TerminationStateToken");
  mfs_TestToken = driver_mk_atom("TestToken");
  mfs_TimeOutToken = driver_mk_atom("TimeOutToken");
  mfs_TimeStampToken = driver_mk_atom("TimeStampToken"); /* OTP-5042 */
  mfs_TopologyToken = driver_mk_atom("TopologyToken");
  mfs_TransToken = driver_mk_atom("TransToken");
  mfs_V18Token = driver_mk_atom("V18Token");
  mfs_V22Token = driver_mk_atom("V22Token");
  mfs_V22bisToken = driver_mk_atom("V22bisToken");
  mfs_V32Token = driver_mk_atom("V32Token");
  mfs_V32bisToken = driver_mk_atom("V32bisToken");
  mfs_V34Token = driver_mk_atom("V34Token");
  mfs_V76Token = driver_mk_atom("V76Token");
  mfs_V90Token = driver_mk_atom("V90Token");
  mfs_V91Token = driver_mk_atom("V91Token");
  mfs_VersionToken = driver_mk_atom("VersionToken");
  mfs_asn1_NOVALUE = driver_mk_atom("asn1_NOVALUE");
  mfs_endOfMessage = driver_mk_atom("endOfMessage");

  DBG( ("mfs_start -> exit\n") );

  return (ErlDrvData) 0;
}

static void mfs_stop(ErlDrvData handle)
{
  mfs_port = 0;

  DBG( ("mfs_stop -> exit\n") );

  return;
}

static void mfs_command(ErlDrvData handle, 
			char *buf, int buf_len)
{
  driver_failure_atom(mfs_port, "bad_usage");

  return;
}

static int mfs_control(ErlDrvData          handle, 
		       unsigned int        command,
		       char  *buf,     int buf_len, 
		       char **res_buf, int res_buf_len)
{
  YY_BUFFER_STATE state;

  DBG( ("mfs_control -> entry with"
	"\n   command:     %d"
	"\n   buf_len:     %d"
	"\n   res_buf_len: %d\n", command, buf_len, res_buf_len) );

  if (NULL == (mfs_text_buf = ALLOC(buf_len))) {
    int len;
    mfs_alloc_failed("failed allocating text buffer", buf_len);

    len = strlen(mfs_error_msg);

    if (res_buf_len < len) {
      /* 
       * Since we failed the memory allocation in the first place,
       * there is no point in trying to get more memory for the 
       * error code...
       */
      len = res_buf_len;
    }

    strncpy(*res_buf, mfs_error_msg, len);

    return len;
  }
  mfs_text_ptr = mfs_text_buf;


  mfs_term_spec_size  = 1000 + buf_len;       /* OTP-4237 */
  mfs_term_spec       = ALLOC(mfs_term_spec_size * sizeof(ErlDrvTermData));
  if (NULL == mfs_term_spec) {
    int len;
    mfs_alloc_failed("failed allocating term spec buffer", 
		     mfs_term_spec_size * sizeof(ErlDrvTermData));

    len = strlen(mfs_error_msg);

    if (res_buf_len < len) {
      /* 
       * Since we failed the memory allocation in the first place,
       * there is no point in trying to get more memory for the 
       * error code...
       */
      len = res_buf_len;
    }

    strncpy(*res_buf, mfs_error_msg, len);

    driver_free(mfs_text_buf);

    return len;    
  }
  mfs_term_spec_index = 0;

  mfs_token_counter   = 0;
  mfs_error           = FALSE;

  /* Prepare the first field in the {tokens, TokenList, LastLine} tuple */
  mfs_ensure_term_spec(2);
  ASSIGN_TERM_SPEC(ERL_DRV_ATOM);
  ASSIGN_TERM_SPEC(driver_mk_atom("tokens"));

  /* Perform the actual scan */
  yylineno = 1;
  state = yy_scan_bytes(buf, buf_len);
  yylex();
  yy_delete_buffer(state);

  if (!mfs_error) {

    /* 
     * Prepare the rest of the {tokens, TokenList, LastLine} tuple 
     * and send it as message top caller. 
     */
    mfs_ensure_term_spec(7);
    ASSIGN_TERM_SPEC(ERL_DRV_NIL);
    ASSIGN_TERM_SPEC(ERL_DRV_LIST);
    ASSIGN_TERM_SPEC(mfs_token_counter + 1);
    ASSIGN_TERM_SPEC(ERL_DRV_INT);
    ASSIGN_TERM_SPEC(LINENO_OR_TOKENCNT);
    ASSIGN_TERM_SPEC(ERL_DRV_TUPLE);
    ASSIGN_TERM_SPEC(3);
    
    DBG( ("mfs_control -> send the term when"
	  "\n   term_spec_index: %d"
	  "\n   term_spec_size:  %d\n", 
	  mfs_term_spec_index, mfs_term_spec_size) );

    driver_send_term(mfs_port, 
                     driver_caller(mfs_port),
                     mfs_term_spec, 
                     mfs_term_spec_index);
    
    if (mfs_text_buf  != NULL) driver_free(mfs_text_buf);
    if (mfs_term_spec != NULL) driver_free(mfs_term_spec);

    DBG( ("mfs_control -> done (0)\n") );

    return 0;

  } else {
    /* 
     * Return the error message 
     */
    int len = strlen(mfs_error_msg);

    /*
     * If we fail to realloc a bigger block of memory
     * we have to make do with what we got
     */
    if (res_buf_len < len) {
      void *tmp = REALLOC(*res_buf, len);
      if (tmp != NULL)
	*res_buf = tmp;
      else
	len = res_buf_len;
    }

    strncpy(*res_buf, mfs_error_msg, len);

    if (mfs_text_buf  != NULL) driver_free(mfs_text_buf);
    if (mfs_term_spec != NULL) driver_free(mfs_term_spec);

    DBG( ("mfs_control -> done (%d)\n", len) );

    return len;
  }
}

static void mfs_finish(void)
{
  return;
}

static void mfs_fatal_error(char* msg)
{
  if (!mfs_error) {
    int len = strlen(msg);

    if (len >= sizeof(mfs_error_msg))
      len = sizeof(mfs_error_msg) - 1;
      
    strncpy(mfs_error_msg, msg, len);
    mfs_error_msg[len] = '\0';
    mfs_error = TRUE;
  }
}
