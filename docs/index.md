# lib.sh

## Script name

Scripts can ends with extension `.sh` or not, in any case the variable
*SHORTNAME* contains the name of the running script, without extension and
without the path.
This name is used in many defaults by the library, in example for the 
*LOCKFILE* that by default is `/var/lock/$SHORTNAME` or by the *LOGFILE*, by
default `/var/local/log/$SHORTNAME`.

## Self-checks
 
*ensure_bin <name>*

*ensure_user <name>* 

## Script configuration

*get_conf_path*

*include_conf* 

## Log mangement

*log*

*log_error*

*log_debug*

*setloglevel*

## Communication

*send_mail*

*slack*

## Multiple execution locking

*get_lock*

*unlock*

## Misc 

*get_cache_path*

*get_confirm*


