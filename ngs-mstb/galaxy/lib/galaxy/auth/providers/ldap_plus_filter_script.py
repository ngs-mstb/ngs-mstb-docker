"""
Created on 29/07/2018

@author: Andrey Tovchigrechko
"""
import logging
import subprocess

from .ldap_ad import LDAP

log = logging.getLogger(__name__)


class LDAP_and_filter_script(LDAP):
    """Authenticator that first uses LDAP, and on success additionally
    runs a shell script to test that the user is allowed to login.

    The shell filter script must be defined in the auth_conf.xml options
    for this plugin type. If undefined, the pluging simply works like
    the LDAP plugin.

    If the script exits with a non-zero status, this plugin returns None
    as the first element of the result tuple, which means that no other
    methods should be tried. The assumption here is that since the script
    is only called, after the LDAP auth has succeeded, a negative result
    from the script means that the user should not be able to login under
    any method.
    """
    plugin_type = 'ldap_and_filter_script'


    def _call_filter_script(self,base_ret,username,options,fail_ret):
        filter_script = options.get("filter-script",None)
        filter_script_stdout = ""
        if not filter_script:
            log.debug("User: %s, LDAP_and_filter_script: filter_script is not defined in config, returning base LDAP results" % (username,))
            return base_ret
        try:
            log.debug("User: %s, LDAP_and_filter_script: Calling filter_script: %s" % (username,filter_script))
            filter_script_stdout = subprocess.check_output([filter_script,username],stderr=subprocess.STDOUT)
        except subprocess.CalledProcessError as e:
            log.exception("LDAP_and_filter_script: a call to auth filter script failed for user name: {} with output: {}".format(username,e.output))
            return fail_ret
        except Error:
            log.exception("LDAP_and_filter_script: unexpected exception in a call to auth filter script for user name: {}".format(username))
            return fail_ret
        log.debug("User: %s, LDAP_and_filter_script - call to filter_script %s succeeded with stdout/stderr as '%s'. Returning: %s" % \
            (username,filter_script,filter_script_stdout,base_ret))
        return base_ret

    def authenticate(self, email, username, password, options):
        """
        See abstract method documentation.
        """
        base_ret = super(LDAP_and_filter_script,self).authenticate(email, username, password, options)
        if not base_ret[0]:
            log.debug("User: %s, LDAP_and_filter_script.authenticate; LDAP stage failed: %s; returning." % (email,base_ret))
            return base_ret
        return self._call_filter_script(base_ret=base_ret,username=base_ret[2],options=options,fail_ret=(None,'',''))

    def authenticate_user(self, user, password, options):
        """
        See abstract method documentation.
        """
        ## super will call this authenticate anyway, but we do it here again in case the
        ## base class implementation changes.
        base_ret = super(LDAP_and_filter_script,self).authenticate_user(user, password, options)
        if not base_ret:
            log.debug("User: %s, LDAP_and_filter_script.authenticate_user; LDAP stage failed: %s; returning." % (user.email,base_ret))
            return base_ret
        return self._call_filter_script(base_ret=base_ret,username=user.username,options=options,fail_ret=None)


__all__ = ('LDAP_and_filter_script', )
