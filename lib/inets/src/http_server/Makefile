#
# %CopyrightBegin%
# 
# Copyright Ericsson AB 2005-2009. All Rights Reserved.
# 
# The contents of this file are subject to the Erlang Public License,
# Version 1.1, (the "License"); you may not use this file except in
# compliance with the License. You should have received a copy of the
# Erlang Public License along with this software. If not, it can be
# retrieved online at http://www.erlang.org/.
# 
# Software distributed under the License is distributed on an "AS IS"
# basis, WITHOUT WARRANTY OF ANY KIND, either express or implied. See
# the License for the specific language governing rights and limitations
# under the License.
# 
# %CopyrightEnd%
#
#
include $(ERL_TOP)/make/target.mk
EBIN = ../../ebin
include $(ERL_TOP)/make/$(TARGET)/otp.mk


# ----------------------------------------------------
# Application version
# ----------------------------------------------------
include ../../vsn.mk

VSN = $(INETS_VSN)


# ----------------------------------------------------
# Release directory specification
# ----------------------------------------------------
RELSYSDIR = $(RELEASE_PATH)/lib/inets-$(VSN)


# ----------------------------------------------------
# Target Specs
# ----------------------------------------------------
MODULES = \
	httpd \
	httpd_acceptor \
	httpd_acceptor_sup \
	httpd_cgi \
	httpd_conf \
	httpd_example \
	httpd_esi \
	httpd_file\
	httpd_instance_sup \
	httpd_log \
	httpd_manager \
	httpd_misc_sup \
	httpd_request \
	httpd_request_handler \
	httpd_response \
        httpd_script_env \
        httpd_socket \
	httpd_sup \
	httpd_util \
	mod_actions \
	mod_alias \
	mod_auth \
	mod_auth_plain \
	mod_auth_dets \
	mod_auth_mnesia \
	mod_auth_server \
	mod_browser \
	mod_cgi \
	mod_dir \
	mod_disk_log \
	mod_esi \
	mod_get \
	mod_head \
	mod_htaccess \
	mod_include \
	mod_log \
	mod_range \
	mod_responsecontrol \
	mod_trace \
	mod_security \
	mod_security_server

HRL_FILES = httpd.hrl httpd_internal.hrl mod_auth.hrl 

ERL_FILES = $(MODULES:%=%.erl)

TARGET_FILES= $(MODULES:%=$(EBIN)/%.$(EMULATOR)) 


# ----------------------------------------------------
# INETS FLAGS
# ----------------------------------------------------
INETS_FLAGS = -D'SERVER_SOFTWARE="inets/$(VSN)"' 


# ----------------------------------------------------
# FLAGS
# ----------------------------------------------------
INETS_ERL_FLAGS += -I ../http_lib -I ../inets_app -pa ../../ebin

ERL_COMPILE_FLAGS += $(INETS_ERL_FLAGS) \
		     $(INETS_FLAGS) \
                     +'{parse_transform,sys_pre_attributes}' \
                     +'{attribute,insert,app_vsn,$(APP_VSN)}'


# ----------------------------------------------------
# Targets
# ----------------------------------------------------

debug opt: $(TARGET_FILES)

clean:
	rm -f $(TARGET_FILES)
	rm -f core

docs:


# ----------------------------------------------------
# Release Target
# ---------------------------------------------------- 
include $(ERL_TOP)/make/otp_release_targets.mk

release_spec: opt
	$(INSTALL_DIR) $(RELSYSDIR)/src
	$(INSTALL_DATA) $(HRL_FILES) $(ERL_FILES) $(RELSYSDIR)/src
	$(INSTALL_DIR) $(RELSYSDIR)/ebin
	$(INSTALL_DATA) $(TARGET_FILES) $(RELSYSDIR)/ebin

release_docs_spec:

info:
	@echo "INETS_DEBUG       = $(INETS_DEBUG)"
	@echo "INETS_FLAGS       = $(INETS_FLAGS)"
	@echo "ERL_COMPILE_FLAGS = $(ERL_COMPILE_FLAGS)"

