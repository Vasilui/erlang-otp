%%------------------------------------------------------------
%%
%% Implementation stub file
%% 
%% Target: CosFileTransfer_FileTransferSession
%% Source: /ldisk/daily_build/otp_prebuild_r12b.2007-12-04_15/otp_src_R12B-0/lib/cosFileTransfer/src/CosFileTransfer.idl
%% IC vsn: 4.2.16
%% 
%% This file is automatically generated. DO NOT EDIT IT.
%%
%%------------------------------------------------------------

-module('CosFileTransfer_FileTransferSession').
-ic_compiled("4_2_16").


%% Interface functions
-export(['_get_protocols_supported'/1, '_get_protocols_supported'/2, set_directory/2]).
-export([set_directory/3, create_file/2, create_file/3]).
-export([create_directory/2, create_directory/3, get_file/2]).
-export([get_file/3, delete/2, delete/3]).
-export([transfer/3, transfer/4, append/3]).
-export([append/4, insert/4, insert/5]).
-export([logout/1, logout/2, oe_orber_create_directory_current/1]).
-export([oe_orber_create_directory_current/2, oe_orber_get_content/3, oe_orber_get_content/4]).
-export([oe_orber_count_children/2, oe_orber_count_children/3]).

%% Type identification function
-export([typeID/0]).

%% Used to start server
-export([oe_create/0, oe_create_link/0, oe_create/1]).
-export([oe_create_link/1, oe_create/2, oe_create_link/2]).

%% TypeCode Functions and inheritance
-export([oe_tc/1, oe_is_a/1, oe_get_interface/0]).

%% gen server export stuff
-behaviour(gen_server).
-export([init/1, terminate/2, handle_call/3]).
-export([handle_cast/2, handle_info/2, code_change/3]).

-include_lib("orber/include/corba.hrl").


%%------------------------------------------------------------
%%
%% Object interface functions.
%%
%%------------------------------------------------------------



%%%% Operation: '_get_protocols_supported'
%% 
%%   Returns: RetVal
%%
'_get_protocols_supported'(OE_THIS) ->
    corba:call(OE_THIS, '_get_protocols_supported', [], ?MODULE).

'_get_protocols_supported'(OE_THIS, OE_Options) ->
    corba:call(OE_THIS, '_get_protocols_supported', [], ?MODULE, OE_Options).

%%%% Operation: set_directory
%% 
%%   Returns: RetVal
%%   Raises:  CosFileTransfer::SessionException, CosFileTransfer::FileNotFoundException, CosFileTransfer::RequestFailureException, CosFileTransfer::IllegalOperationException
%%
set_directory(OE_THIS, New_directory) ->
    corba:call(OE_THIS, set_directory, [New_directory], ?MODULE).

set_directory(OE_THIS, OE_Options, New_directory) ->
    corba:call(OE_THIS, set_directory, [New_directory], ?MODULE, OE_Options).

%%%% Operation: create_file
%% 
%%   Returns: RetVal
%%   Raises:  CosFileTransfer::SessionException, CosFileTransfer::FileNotFoundException, CosFileTransfer::RequestFailureException, CosFileTransfer::IllegalOperationException
%%
create_file(OE_THIS, Name) ->
    corba:call(OE_THIS, create_file, [Name], ?MODULE).

create_file(OE_THIS, OE_Options, Name) ->
    corba:call(OE_THIS, create_file, [Name], ?MODULE, OE_Options).

%%%% Operation: create_directory
%% 
%%   Returns: RetVal
%%   Raises:  CosFileTransfer::SessionException, CosFileTransfer::FileNotFoundException, CosFileTransfer::RequestFailureException, CosFileTransfer::IllegalOperationException
%%
create_directory(OE_THIS, Name) ->
    corba:call(OE_THIS, create_directory, [Name], ?MODULE).

create_directory(OE_THIS, OE_Options, Name) ->
    corba:call(OE_THIS, create_directory, [Name], ?MODULE, OE_Options).

%%%% Operation: get_file
%% 
%%   Returns: RetVal
%%   Raises:  CosFileTransfer::SessionException, CosFileTransfer::FileNotFoundException, CosFileTransfer::RequestFailureException, CosFileTransfer::IllegalOperationException
%%
get_file(OE_THIS, Complete_file_name) ->
    corba:call(OE_THIS, get_file, [Complete_file_name], ?MODULE).

get_file(OE_THIS, OE_Options, Complete_file_name) ->
    corba:call(OE_THIS, get_file, [Complete_file_name], ?MODULE, OE_Options).

%%%% Operation: delete
%% 
%%   Returns: RetVal
%%   Raises:  CosFileTransfer::SessionException, CosFileTransfer::FileNotFoundException, CosFileTransfer::RequestFailureException, CosFileTransfer::IllegalOperationException
%%
delete(OE_THIS, File) ->
    corba:call(OE_THIS, delete, [File], ?MODULE).

delete(OE_THIS, OE_Options, File) ->
    corba:call(OE_THIS, delete, [File], ?MODULE, OE_Options).

%%%% Operation: transfer
%% 
%%   Returns: RetVal
%%   Raises:  CosFileTransfer::SessionException, CosFileTransfer::TransferException, CosFileTransfer::FileNotFoundException, CosFileTransfer::RequestFailureException, CosFileTransfer::IllegalOperationException
%%
transfer(OE_THIS, Src, Dest) ->
    corba:call(OE_THIS, transfer, [Src, Dest], ?MODULE).

transfer(OE_THIS, OE_Options, Src, Dest) ->
    corba:call(OE_THIS, transfer, [Src, Dest], ?MODULE, OE_Options).

%%%% Operation: append
%% 
%%   Returns: RetVal
%%   Raises:  CosFileTransfer::CommandNotImplementedException, CosFileTransfer::SessionException, CosFileTransfer::TransferException, CosFileTransfer::FileNotFoundException, CosFileTransfer::RequestFailureException, CosFileTransfer::IllegalOperationException
%%
append(OE_THIS, Src, Dest) ->
    corba:call(OE_THIS, append, [Src, Dest], ?MODULE).

append(OE_THIS, OE_Options, Src, Dest) ->
    corba:call(OE_THIS, append, [Src, Dest], ?MODULE, OE_Options).

%%%% Operation: insert
%% 
%%   Returns: RetVal
%%   Raises:  CosFileTransfer::CommandNotImplementedException, CosFileTransfer::SessionException, CosFileTransfer::TransferException, CosFileTransfer::FileNotFoundException, CosFileTransfer::RequestFailureException, CosFileTransfer::IllegalOperationException
%%
insert(OE_THIS, Src, Dest, Offset) ->
    corba:call(OE_THIS, insert, [Src, Dest, Offset], ?MODULE).

insert(OE_THIS, OE_Options, Src, Dest, Offset) ->
    corba:call(OE_THIS, insert, [Src, Dest, Offset], ?MODULE, OE_Options).

%%%% Operation: logout
%% 
%%   Returns: RetVal
%%
logout(OE_THIS) ->
    corba:call(OE_THIS, logout, [], ?MODULE).

logout(OE_THIS, OE_Options) ->
    corba:call(OE_THIS, logout, [], ?MODULE, OE_Options).

%%%% Operation: oe_orber_create_directory_current
%% 
%%   Returns: RetVal
%%   Raises:  CosFileTransfer::SessionException, CosFileTransfer::FileNotFoundException, CosFileTransfer::IllegalOperationException
%%
oe_orber_create_directory_current(OE_THIS) ->
    corba:call(OE_THIS, oe_orber_create_directory_current, [], ?MODULE).

oe_orber_create_directory_current(OE_THIS, OE_Options) ->
    corba:call(OE_THIS, oe_orber_create_directory_current, [], ?MODULE, OE_Options).

%%%% Operation: oe_orber_get_content
%% 
%%   Returns: RetVal
%%
oe_orber_get_content(OE_THIS, Complete_file_name, Parent) ->
    corba:call(OE_THIS, oe_orber_get_content, [Complete_file_name, Parent], ?MODULE).

oe_orber_get_content(OE_THIS, OE_Options, Complete_file_name, Parent) ->
    corba:call(OE_THIS, oe_orber_get_content, [Complete_file_name, Parent], ?MODULE, OE_Options).

%%%% Operation: oe_orber_count_children
%% 
%%   Returns: RetVal
%%
oe_orber_count_children(OE_THIS, Complete_file_name) ->
    corba:call(OE_THIS, oe_orber_count_children, [Complete_file_name], ?MODULE).

oe_orber_count_children(OE_THIS, OE_Options, Complete_file_name) ->
    corba:call(OE_THIS, oe_orber_count_children, [Complete_file_name], ?MODULE, OE_Options).

%%------------------------------------------------------------
%%
%% Inherited Interfaces
%%
%%------------------------------------------------------------
oe_is_a("IDL:omg.org/CosFileTransfer/FileTransferSession:1.0") -> true;
oe_is_a(_) -> false.

%%------------------------------------------------------------
%%
%% Interface TypeCode
%%
%%------------------------------------------------------------
oe_tc('_get_protocols_supported') -> 
	{{tk_sequence,{tk_struct,"IDL:omg.org/CosFileTransfer/ProtocolSupport:1.0",
                                 "ProtocolSupport",
                                 [{"protocol_name",{tk_string,0}},
                                  {"addresses",
                                   {tk_sequence,{tk_string,0},0}}]},
                      0},
         [],[]};
oe_tc(set_directory) -> 
	{tk_void,[{tk_objref,"IDL:omg.org/CosFileTransfer/Directory:1.0",
                             "Directory"}],
                 []};
oe_tc(create_file) -> 
	{{tk_objref,"IDL:omg.org/CosFileTransfer/File:1.0","File"},
         [{tk_sequence,{tk_string,0},0}],
         []};
oe_tc(create_directory) -> 
	{{tk_objref,"IDL:omg.org/CosFileTransfer/Directory:1.0",
                    "Directory"},
         [{tk_sequence,{tk_string,0},0}],
         []};
oe_tc(get_file) -> 
	{{tk_struct,"IDL:omg.org/CosFileTransfer/FileWrapper:1.0",
                    "FileWrapper",
                    [{"the_file",
                      {tk_objref,"IDL:omg.org/CosFileTransfer/File:1.0",
                                 "File"}},
                     {"file_type",
                      {tk_enum,"IDL:omg.org/CosFileTransfer/FileType:1.0",
                               "FileType",
                               ["nfile","ndirectory"]}}]},
         [{tk_sequence,{tk_string,0},0}],
         []};
oe_tc(delete) -> 
	{tk_void,[{tk_objref,"IDL:omg.org/CosFileTransfer/File:1.0",
                             "File"}],
                 []};
oe_tc(transfer) -> 
	{tk_void,[{tk_objref,"IDL:omg.org/CosFileTransfer/File:1.0",
                             "File"},
                  {tk_objref,"IDL:omg.org/CosFileTransfer/File:1.0","File"}],
                 []};
oe_tc(append) -> 
	{tk_void,[{tk_objref,"IDL:omg.org/CosFileTransfer/File:1.0",
                             "File"},
                  {tk_objref,"IDL:omg.org/CosFileTransfer/File:1.0","File"}],
                 []};
oe_tc(insert) -> 
	{tk_void,[{tk_objref,"IDL:omg.org/CosFileTransfer/File:1.0",
                             "File"},
                  {tk_objref,"IDL:omg.org/CosFileTransfer/File:1.0","File"},
                  tk_long],
                 []};
oe_tc(logout) -> 
	{tk_void,[],[]};
oe_tc(oe_orber_create_directory_current) -> 
	{{tk_objref,"IDL:omg.org/CosFileTransfer/Directory:1.0",
                    "Directory"},
         [],[]};
oe_tc(oe_orber_get_content) -> 
	{{tk_sequence,
             {tk_struct,"IDL:omg.org/CosFileTransfer/FileWrapper:1.0",
                 "FileWrapper",
                 [{"the_file",
                   {tk_objref,"IDL:omg.org/CosFileTransfer/File:1.0","File"}},
                  {"file_type",
                   {tk_enum,"IDL:omg.org/CosFileTransfer/FileType:1.0",
                       "FileType",
                       ["nfile","ndirectory"]}}]},
             0},
         [{tk_sequence,{tk_string,0},0},
          {tk_objref,"IDL:omg.org/CosFileTransfer/Directory:1.0",
              "Directory"}],
         []};
oe_tc(oe_orber_count_children) -> 
	{tk_long,[{tk_sequence,{tk_string,0},0}],[]};
oe_tc(_) -> undefined.

oe_get_interface() -> 
	[{"oe_orber_count_children", oe_tc(oe_orber_count_children)},
	{"oe_orber_get_content", oe_tc(oe_orber_get_content)},
	{"oe_orber_create_directory_current", oe_tc(oe_orber_create_directory_current)},
	{"logout", oe_tc(logout)},
	{"insert", oe_tc(insert)},
	{"append", oe_tc(append)},
	{"transfer", oe_tc(transfer)},
	{"delete", oe_tc(delete)},
	{"get_file", oe_tc(get_file)},
	{"create_directory", oe_tc(create_directory)},
	{"create_file", oe_tc(create_file)},
	{"set_directory", oe_tc(set_directory)},
	{"_get_protocols_supported", oe_tc('_get_protocols_supported')}].




%%------------------------------------------------------------
%%
%% Object server implementation.
%%
%%------------------------------------------------------------


%%------------------------------------------------------------
%%
%% Function for fetching the interface type ID.
%%
%%------------------------------------------------------------

typeID() ->
    "IDL:omg.org/CosFileTransfer/FileTransferSession:1.0".


%%------------------------------------------------------------
%%
%% Object creation functions.
%%
%%------------------------------------------------------------

oe_create() ->
    corba:create(?MODULE, "IDL:omg.org/CosFileTransfer/FileTransferSession:1.0").

oe_create_link() ->
    corba:create_link(?MODULE, "IDL:omg.org/CosFileTransfer/FileTransferSession:1.0").

oe_create(Env) ->
    corba:create(?MODULE, "IDL:omg.org/CosFileTransfer/FileTransferSession:1.0", Env).

oe_create_link(Env) ->
    corba:create_link(?MODULE, "IDL:omg.org/CosFileTransfer/FileTransferSession:1.0", Env).

oe_create(Env, RegName) ->
    corba:create(?MODULE, "IDL:omg.org/CosFileTransfer/FileTransferSession:1.0", Env, RegName).

oe_create_link(Env, RegName) ->
    corba:create_link(?MODULE, "IDL:omg.org/CosFileTransfer/FileTransferSession:1.0", Env, RegName).

%%------------------------------------------------------------
%%
%% Init & terminate functions.
%%
%%------------------------------------------------------------

init(Env) ->
%% Call to implementation init
    corba:handle_init('CosFileTransfer_FileTransferSession_impl', Env).

terminate(Reason, State) ->
    corba:handle_terminate('CosFileTransfer_FileTransferSession_impl', Reason, State).


%%%% Operation: '_get_protocols_supported'
%% 
%%   Returns: RetVal
%%
handle_call({OE_THIS, OE_Context, '_get_protocols_supported', []}, _, OE_State) ->
  corba:handle_call('CosFileTransfer_FileTransferSession_impl', '_get_protocols_supported', [], OE_State, OE_Context, OE_THIS, false);

%%%% Operation: set_directory
%% 
%%   Returns: RetVal
%%   Raises:  CosFileTransfer::SessionException, CosFileTransfer::FileNotFoundException, CosFileTransfer::RequestFailureException, CosFileTransfer::IllegalOperationException
%%
handle_call({OE_THIS, OE_Context, set_directory, [New_directory]}, _, OE_State) ->
  corba:handle_call('CosFileTransfer_FileTransferSession_impl', set_directory, [New_directory], OE_State, OE_Context, OE_THIS, false);

%%%% Operation: create_file
%% 
%%   Returns: RetVal
%%   Raises:  CosFileTransfer::SessionException, CosFileTransfer::FileNotFoundException, CosFileTransfer::RequestFailureException, CosFileTransfer::IllegalOperationException
%%
handle_call({OE_THIS, OE_Context, create_file, [Name]}, _, OE_State) ->
  corba:handle_call('CosFileTransfer_FileTransferSession_impl', create_file, [Name], OE_State, OE_Context, OE_THIS, false);

%%%% Operation: create_directory
%% 
%%   Returns: RetVal
%%   Raises:  CosFileTransfer::SessionException, CosFileTransfer::FileNotFoundException, CosFileTransfer::RequestFailureException, CosFileTransfer::IllegalOperationException
%%
handle_call({OE_THIS, OE_Context, create_directory, [Name]}, _, OE_State) ->
  corba:handle_call('CosFileTransfer_FileTransferSession_impl', create_directory, [Name], OE_State, OE_Context, OE_THIS, false);

%%%% Operation: get_file
%% 
%%   Returns: RetVal
%%   Raises:  CosFileTransfer::SessionException, CosFileTransfer::FileNotFoundException, CosFileTransfer::RequestFailureException, CosFileTransfer::IllegalOperationException
%%
handle_call({OE_THIS, OE_Context, get_file, [Complete_file_name]}, _, OE_State) ->
  corba:handle_call('CosFileTransfer_FileTransferSession_impl', get_file, [Complete_file_name], OE_State, OE_Context, OE_THIS, false);

%%%% Operation: delete
%% 
%%   Returns: RetVal
%%   Raises:  CosFileTransfer::SessionException, CosFileTransfer::FileNotFoundException, CosFileTransfer::RequestFailureException, CosFileTransfer::IllegalOperationException
%%
handle_call({OE_THIS, OE_Context, delete, [File]}, _, OE_State) ->
  corba:handle_call('CosFileTransfer_FileTransferSession_impl', delete, [File], OE_State, OE_Context, OE_THIS, false);

%%%% Operation: transfer
%% 
%%   Returns: RetVal
%%   Raises:  CosFileTransfer::SessionException, CosFileTransfer::TransferException, CosFileTransfer::FileNotFoundException, CosFileTransfer::RequestFailureException, CosFileTransfer::IllegalOperationException
%%
handle_call({OE_THIS, OE_Context, transfer, [Src, Dest]}, _, OE_State) ->
  corba:handle_call('CosFileTransfer_FileTransferSession_impl', transfer, [Src, Dest], OE_State, OE_Context, OE_THIS, false);

%%%% Operation: append
%% 
%%   Returns: RetVal
%%   Raises:  CosFileTransfer::CommandNotImplementedException, CosFileTransfer::SessionException, CosFileTransfer::TransferException, CosFileTransfer::FileNotFoundException, CosFileTransfer::RequestFailureException, CosFileTransfer::IllegalOperationException
%%
handle_call({OE_THIS, OE_Context, append, [Src, Dest]}, _, OE_State) ->
  corba:handle_call('CosFileTransfer_FileTransferSession_impl', append, [Src, Dest], OE_State, OE_Context, OE_THIS, false);

%%%% Operation: insert
%% 
%%   Returns: RetVal
%%   Raises:  CosFileTransfer::CommandNotImplementedException, CosFileTransfer::SessionException, CosFileTransfer::TransferException, CosFileTransfer::FileNotFoundException, CosFileTransfer::RequestFailureException, CosFileTransfer::IllegalOperationException
%%
handle_call({OE_THIS, OE_Context, insert, [Src, Dest, Offset]}, _, OE_State) ->
  corba:handle_call('CosFileTransfer_FileTransferSession_impl', insert, [Src, Dest, Offset], OE_State, OE_Context, OE_THIS, false);

%%%% Operation: logout
%% 
%%   Returns: RetVal
%%
handle_call({OE_THIS, OE_Context, logout, []}, _, OE_State) ->
  corba:handle_call('CosFileTransfer_FileTransferSession_impl', logout, [], OE_State, OE_Context, OE_THIS, false);

%%%% Operation: oe_orber_create_directory_current
%% 
%%   Returns: RetVal
%%   Raises:  CosFileTransfer::SessionException, CosFileTransfer::FileNotFoundException, CosFileTransfer::IllegalOperationException
%%
handle_call({OE_THIS, OE_Context, oe_orber_create_directory_current, []}, _, OE_State) ->
  corba:handle_call('CosFileTransfer_FileTransferSession_impl', oe_orber_create_directory_current, [], OE_State, OE_Context, OE_THIS, false);

%%%% Operation: oe_orber_get_content
%% 
%%   Returns: RetVal
%%
handle_call({OE_THIS, OE_Context, oe_orber_get_content, [Complete_file_name, Parent]}, _, OE_State) ->
  corba:handle_call('CosFileTransfer_FileTransferSession_impl', oe_orber_get_content, [Complete_file_name, Parent], OE_State, OE_Context, OE_THIS, false);

%%%% Operation: oe_orber_count_children
%% 
%%   Returns: RetVal
%%
handle_call({OE_THIS, OE_Context, oe_orber_count_children, [Complete_file_name]}, _, OE_State) ->
  corba:handle_call('CosFileTransfer_FileTransferSession_impl', oe_orber_count_children, [Complete_file_name], OE_State, OE_Context, OE_THIS, false);



%%%% Standard gen_server call handle
%%
handle_call(stop, _, State) ->
    {stop, normal, ok, State};

handle_call(_, _, State) ->
    {reply, catch corba:raise(#'BAD_OPERATION'{minor=1163001857, completion_status='COMPLETED_NO'}), State}.


%%%% Standard gen_server cast handle
%%
handle_cast(stop, State) ->
    {stop, normal, State};

handle_cast(_, State) ->
    {noreply, State}.


%%%% Standard gen_server handles
%%
handle_info(Info, State) ->
    corba:handle_info('CosFileTransfer_FileTransferSession_impl', Info, State).


code_change(OldVsn, State, Extra) ->
    corba:handle_code_change('CosFileTransfer_FileTransferSession_impl', OldVsn, State, Extra).

