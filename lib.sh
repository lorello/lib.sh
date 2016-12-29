#!/bin/bash
# vim: autoindent tabstop=4 shiftwidth=4 expandtab softtabstop=4 filetype=bash fileencoding=utf-8
#
# Common library functions
#
# Include in any script as follows:
# . $(dirname $(readlink -f $0))/../lib/bash/lib.sh || exit
#

# Safe bash execution: https://sipb.mit.edu/doc/safe-shell/
set -e
#o pipefail 

# General variables
SCRIPT="$(readlink -f $0)"
SCRIPTNAME="$(basename $SCRIPT)"
SCRIPTPATH="$(dirname $SCRIPT)"
SHORTNAME=$(basename ${SCRIPTNAME%.sh})
LOGLEVEL_DEBUG=3
LOGLEVEL_NORMAL=2
LOGLEVEL_ERROR=1
LOGLEVEL_QUIET=0


# Default values for logging
#
# If LOGDIR default value could result in a non-writeable path
# for user running your script, override it before library include,
# this way the sanity checks on the LOGDIR (existent & writeable) 
# are done inside the library on the right path
: ${LOGLEVEL:=2}
: ${LOGDIR:="/var/local/log"}
: ${LOGFILE:="$LOGDIR/$SHORTNAME.log"}

# Default values for cacheing
: ${CACHEDIR:="/var/cache/${SHORTNAME}"}

# Default values for script configuration
: ${CONFDIR:=$(readlink -f $SCRIPTPATH/../etc)}
: ${CONFFILENAME:="$SHORTNAME.conf"}

# Default values for locks
: ${LOCKDIR:='/var/lock'}
: ${LOCKFILE:="$LOCKDIR/${SHORTNAME}.lock"}

# Default values for email delivery
: ${MAILFROM:=$SHORTNAME}
: ${MAILFROM:='nobody'}
: ${MAILTO:="root@localhost"}

#Umask
# useful setup for shared environments: when a host is used by more than one users
# that share a group, it's useful have write permission for group on files and directories
# so this lib alter the default UMASK to permit this behaviour
umask 0002

# CONFIGURAZIONE
# carica la configurazione degli script: puo' essere richiesta una conf particolare oppure
# vengono scelti dei path standard dove noi mettiamo la configurazione.
# nel caso esistano più file di configurazione viene scelta sempre quella più vicina
# all'utente e in seconda battuta più vicina allo script
#
# Ad esempio se lancio questa funzione senza parametri nello script /root/scripts/mirror/mirror.sh
# vengono cercati nell'ordine i seguenti file:
#   ~/.mirror.conf
#   /root/scripts/mirror/mirror.conf
#   /root/scripts/etc/mirror.conf
#   /usr/local/etc/mirror.conf
#   /etc/mirror.conf
function include_conf() {

    USER_CONF="~/.$CONFFILENAME"                        # configurazione personale dell'utente
    OLD_STYLE_CONF="$SCRIPTPATH/$CONFFILENAME"          # configurazione nella stessa dir dello script
    RELATIVE_CONF="$CONFDIR/$CONFFILENAME"              # nuovo stile, unix stile ../etc/$myname.conf

    # Se siamo costretti a mettere lo script in qualche posto strano, non LSB-compliant
    # possiamo comunque usare i path standard per la conf
    LOCAL_CONF="/usr/local/etc/$CONFFILENAME"
    ROOT_CONF="/etc/$CONFFILENAME"

    # Qui si decide la priorità con cui si caricano le configurazioni
    CONF_OPTIONS="$USER_CONF $OLD_STYLE_CONF $RELATIVE_CONF $LOCAL_CONF $ROOT_CONF"

    if [ -z "$1" ]; then
        log_debug "Searching conf..."
        for ITEM in $CONF_OPTIONS; do
            if [ -f "$ITEM" -a -r "$ITEM" ]; then
                CONF_CHOOSEN=$ITEM;
                log_debug "Found configfile '$ITEM', stop searching"
                # TODO: dovrebbe fermarsi dopo aver trovato il primo file
            else
                log_debug "Conf '$ITEM' not found"
            fi
        done
    else
        # file di conf. custom (con o senza il ".conf" finale)
        CONF_CHOOSEN="${1%.conf}.conf"
        log_debug "Custom conf requested '$CONF_CHOOSEN'"
    fi

    if [ -z "$CONF_CHOOSEN" ]; then
        log "No configuration found"
        return 0
    fi

    if [ ! -f $CONF_CHOOSEN ]; then
        log_error "Choosen config file '$CONF_CHOOSEN' does not exists!"
        return 0
    else
        # risolve i link simbolici
        . $CONF_CHOOSEN || exit
        log_debug "Successfully loaded $FILENAME"
    fi
}

# SYSTEM CHECKS
# Deprecated function
function check_binaries() {
    for BIN in $BINS; do
        if [ ! -x $BIN ]; then
            # esce con stato di errore al primo eseguibile che non riesce a trovare
            echo "Errore: $BIN non trovato o non eseguibile. Uscita"
            exit 1
        fi
    done
}

# controlla presenza di un binario passato come parametro e ritorna errore se non c'e'
# e' diverso rispetto a check_binaries probabilmente lo potra' sostituire
# ritorna 0 se l'eseguibile c'e' ed e' eseguibile dall'utente, 1 altrimenti
function ensure_bin()
{
    FILENAME=$1
    MSG="File '${FILENAME}' required to continue"
    FILE=$(which ${FILENAME})
    if [ -z "$FILE" ]; then
        log_error "${MSG}: file missing"
        return 1
    fi

    echo $FILE

    # TODO: questo controllo fallisce... boh, per ora commento
    #if [ -x "${FILE}" ]; then
    #    log_error "${MSG}: file not executable"
    #    return 1
    #fi

    return 0
}

# chiede conferma prima di continuare
function get_confirm() {
    local FN="get_confirm"
    local MSG=$1

    if [ $# -ne 1 ]; then
        echo "Usage: $FN msg" 1>&2
        exit 1
    fi

    echo $MSG
    read ANSWER

    if [ "$ANSWER" != "S" -a "$ANSWER" != "s" ]
    then
        log "Esecuzione interrotta dall'utente"
        exit 1
    fi
}

# controllo sull'utente

# removed function, throw an error if used
function if_user() {
    log_error "function deprecated, use 'ensure_user'"
}

function ensure_user () {
    local FN="ensure_user"
    local XUSER=$1

    if [ $# -ne 1 ]; then
        echo "Usage: $FN username" 1>&2
        exit 1
    fi

    if [ "$(whoami)" != "$XUSER" ]; then
        echo "You must to be $XUSER to run this script" 1>&2
        exit 1
    fi
}

# Testa se l'esecuzione avviene come root
function check_root_uid(){
    if [ $UID != 0 ]; then
        echo "You don't have sufficient privileges to run this script. Use root or sudo"
        exit 1
    fi
}

# CACHEDIR
# if not existent it will be created on first request
#
# Usage:
#   PATH=$(get_cache_path)
#
function get_cache_path()
{
    if [ ! -d $CACHEDIR ]; then
        mkdir -p $CACHEDIR
        if [ ! -d $CACHEDIR ]; then
            echo "Cannot create cache dir '$CACHEDIR', parent directory is not writeable for '$USER'"
            return 1
        fi
    fi
    echo $CACHEDIR
}

# Config path dello script, se non esiste la creo alla prima richiesta
# PATH=$(get_conf_path)
function get_conf_path()
{
    if [ ! -d $CONFDIR ]; then
        if [ ! -w $(basename $CONFDIR) ]; then
            echo "Cannot create cache dir '$CONFDIR', parent directory is not writeable for '$USER'"
            exit 1
        fi
        mkdir -p $CONFDIR
    fi
    echo $CONFDIR
}


# GESTIONE DEL LOGGING
# crea la directory per i log nel caso in cui non esista
if [ ! -d ${LOGDIR} ]; then
    if [ ! -w $(basename ${LOGDIR}) ] && [ $USER != 'root' ]; then
        echo "Cannot create log dir '$LOGDIR', parent directory is not writeable for '$USER'"
        exit 1
    fi
    mkdir -p $LOGDIR
fi

touch ${LOGFILE} 2> /dev/null

if [ ! -w ${LOGFILE} ]; then
  echo "Cannot write log file '${LOGFILE}'"
  echo "Directory ${LOGDIR} is not writeable for '$USER'"
  exit 1
fi

# DESCRIPTION
#
# send a message to slack if slack is configured
#
# PARAMETERS
#
# $1 : the message to send
# $2 : channel to send message to
#
# REQUIRES
#   SLACK_URL variable in /usr/local/etc/slack.conf
function slack()
{
  CURL=$(ensure_bin 'curl') || return 1
  # SLACK_URL variable is secret, is not inside the library, it must be created on server in a different way
  [ -f /usr/local/etc/slack.conf ] || return 1
  . /usr/local/etc/slack.conf
  [ -z "$SLACK_URL" ] && return 1
  if [ -n "$1" ]; then
    CHANNEL=${2:-'#OPS'}
    if [ $LOGLEVEL -ge $LOGLEVEL_DEBUG ]; then
      echo "`date "+%Y-%m-%d %T"` [$$] INFO: Updating channel $CHANNEL on Slack"
    fi
    TEXT="*$USER@$HOSTNAME:$SCRIPT*\n\`\`\`$1\`\`\`"
    PAYLOAD="payload={\"channel\": \"$CHANNEL\", \"text\": \"$TEXT\"}"
    $CURL --silent -X POST --data-urlencode "$PAYLOAD" "$SLACK_URL"
  fi
}

# default: stampa sempre su file e su std output se richiesto
function log()
{
  if [ -n "$1" ] && [ $LOGLEVEL -ge $LOGLEVEL_NORMAL ]; then
    echo "`date "+%Y-%m-%d %T"` [$$] INFO: $1"
  fi
  echo "`date "+%Y-%m-%d %T"` [$$] INFO: $1" >> $LOGFILE
}

# errori: stampa su stderr se richiesto e SEMPRE su file
function log_error()
{
  if [ -n "$1" ] && [ $LOGLEVEL -ge $LOGLEVEL_ERROR ]; then
    echo -e "`date "+%Y-%m-%d %T"` [$$] ERR: $1" 1>&2
    slack "$1"
  fi
  echo -e "`date "+%Y-%m-%d %T"` [$$] ERR: $1" >> $LOGFILE
}

# debug: stampa su stdout e su file se il livello è abbastanza alto
function log_debug()
{
  if [ -n "$1" ] && [ $LOGLEVEL -ge $LOGLEVEL_DEBUG ]; then
    echo -e "`date "+%Y-%m-%d %T"` [$$] DEBUG: $1"
    echo -e "`date "+%Y-%m-%d %T"` [$$] DEBUG: $1" >> $LOGFILE
  fi
}

# livello di verbosità dello script
function setloglevel()
{
  local LEVEL=2
  [ -n "$1" ] && LEVEL=$1

  LOGLEVEL=$LEVEL
}

# invio e-mail
function send_mail()
{
  [ -x /usr/sbin/sendmail ] || return 1

  local FN="send_mail"
  local TMPFILE="/tmp/$(basename $0).$$.$RANDOM"
  local SUBJECT="$1"
  local BODY="$2"

  if [ $# -ne 2 ]; then
    echo "Usage: $FN subject body" 1>&2
    exit 1
  fi

  cat << EOF >> $TMPFILE
From: $MAILFROM
To: $MAILTO
Subject: $SUBJECT

${BODY}
EOF
  cat "$TMPFILE" | /usr/sbin/sendmail -f $MAILFROM $MAILTO
  rm "$TMPFILE"
}

# GESTIONE DEL LOCK

function get_lock()
{
  FLOCK=$(ensure_bin 'flock') || exit 1

  exec 1000>$LOCKFILE
  if $FLOCK -n -x 1000; then
    return
  else
    log_error "impossibile acquisire il lock. Uscita"
    exit 1
  fi
}

function unlock()
{
  log_debug "removing lockfile $LOCKFILE"
  [ -f $LOCKFILE ] && rm -f $LOCKFILE
  exit 0
}

# SIGNAL HANDLINGS
# tutti i segnali generano una exit, la exit esegue se esiste la funzione clean
function sig_exit 
{
  log_debug "running exit routine"

  unlock

  # richiama la funzione 'clean', se esiste (pulizia file temporanei)
  if type clean 2>/dev/null | grep -q function; then
    clean
  fi
}

function sig_int
{
  log_debug "WARNING: SIGINT caught"
  exit 1002
}

function sig_quit
{
  log_debug "SIGQUIT caught"
  exit 1003
}

function sig_term
{
  log_debug "WARNING: SIGTERM caught"
  exit 1015
}

trap sig_exit EXIT    # SIGEXIT
trap sig_int INT      # SIGINT
trap sig_quit QUIT    # SIGQUIT
trap sig_term TERM    # SIGTERM

# UTILITY

# Given a string as parameter representing a Variable name, returns 0 if the variable is defined AND has a value, 1 elsewhere
function has_value()
{
  if [[ ${!1-X} == ${!1-Y} ]]; then
    if [[ -n ${!1} ]]; then
      return 0
    fi
  fi
  return 1
}

# Given a string as parameter representing a Variable name, returns 0 if the variable is defined AND has an INTEGER value 
function is_integer()
{
  if has_value ${!1} && [ ! -z "${!1##*[!0-9]*}" ]; then
    return 0
  fi
  return 1
}


# stampa una variabile dato il suo nome
function print_var() 
{
  echo $(eval echo \$$1)
}

# funzione generica per creare una directory o riaggiustarne i permessi/proprietario
# TODO aggiungere check
function ensure_dir()
{
  if [ $# -ne 1 ]; then
    log_error "${fn} usage: ${fn} <dirname>"
    return 1
  fi

  local DIR=$1
  local PERMS=$2
  local OWNER=$3
  local GROUP=$4

  # se la directory specificata e' un link, skippa
  if [ -L ${DIR} ]; then
    log_error "${DIR} is a symlink. Exiting function"
    return
  fi

  # se non esiste la directory la crea opportunamente
  if [ ! -d ${DIR} ]; then
    mkdir -p ${DIR}
    log_debug "Created ${DIR}"
  fi

  # se la directory esiste ma ha i permessi fuori posto li sistema
  if [ -n "$PERMS" ]; then
    if [ $(stat --printf %a ${DIR}) != ${PERMS} ]; then
      chmod ${PERMS} ${DIR}
      log_debug "Set ${PERMS} as permissions of ${DIR}"
    fi
  fi
  # se la directory esiste ma il proprietario/gruppo e' sbagliato li reimposta
  if [ -n "$OWNER" ]; then
    if [ $(stat --printf %U ${DIR}) != ${OWNER} ]; then
      chown ${OWNER} ${DIR}
      log_debug "Set ${OWNER} as owner of ${DIR}"
    fi
  fi
  if [ -n "$GROUP" ]; then
    if [ $(stat --printf %G ${DIR}) != ${GROUP} ]; then
      chgrp ${GROUP} ${DIR}
      log_debug "Set ${GROUP} as owner of ${DIR}"
    fi
  fi
}


# Controllo sul load average:
#
# aspetta fino a che il load5 non scende sotto MAX_LOAD, ritestando ogni WAIT_TIME secondi
# il valore di load5
# Se passano MAX_WAIT secondi senza che il load scenda sotto il valore richiesto
# restituisce 1, se invece il valore di load è sufficiente basso restituisce 0
#
# Parametri:
#   $1  MAX_LOAD    il load oltre il quale lo script resta in attesa senza fare nulla
#                   default: 2xCPU
#   $2  MAX_WAIT    il tempo massimo in secondi che lo script resta in attesa a causa del load
#                   default: 7200s
#   $3  WAIT_TIME   il numero di secondi tra un tentativo e il successivo
#                   default: 60s
#
# quando si usa questa funzione assicurarsi di usare anche il lock già presente nella libreria
# altrimenti si rischia di far partire più volte lo script se la macchina è mediamente carica
#
# Esempio di utilizzo:
# if ! wait_for_low_load; then
#        log_debug "waited too long for low load"
#        continue
# fi
# log_debug "load is ok, do what you want"
#
function wait_for_low_load()
{
  CPU_NUM=$(cat /proc/cpuinfo |egrep "^processor"|wc -l)
  ((DEFAULT_MAX_LOAD = CPU_NUM * 2 + 1))

  # get parameters or set default
  MAX_LOAD=${1:-$DEFAULT_MAX_LOAD}
  MAX_WAIT=${2:-7200}
  WAIT_TIME=${3:-60}

  START_TS=$(date +%s)
  ((MAX_TS = START_TS + MAX_WAIT))
  CURRENT_TS=$(date +%s)

  while [ $CURRENT_TS -lt $MAX_TS ]; do
    CURR_LOAD=$(cat /proc/loadavg | awk '{ printf "%d", $1 }')
    if [ -z "${CURR_LOAD}" ]; then
      log_error "Can't check load average"
      continue
    fi

    if [ ${CURR_LOAD} -ge ${MAX_LOAD} ] ; then
      log "Current load is '${CURR_LOAD}', sleeping for ${WAIT_TIME} seconds until '${MAX_WAIT}' seconds has passed or load goes under '${MAX_LOAD}'"
      sleep $WAIT_TIME
    else
      log_debug "Current load is '${CURR_LOAD}', under '${MAX_LOAD}' so we can stop waiting"
      return 0
    fi

    CURRENT_TS=$(date +%s)
  done

  log "Maximum time waited ('$MAX_WAIT' seconds), the load is too high, continue at your own risk"
  return 1
}

# DRBD is Primary?
# Questa funzione ritorna 0 se la risorsa DRBD e' Primary,
#  altrimenti ritorna 1
#
# Keywords arguments:
#   $1  --  DRBD resource name
#
# Utilizzo:
#   if (drbd_is_primary ${RESOURCE_NAME}); then
#       echo "DRBD is Primary"
#       fai_qualcosa
#   else
#       echo "${RESOURCE} is NOT Primary"
#       exit N
#   fi
#
function drbd_is_primary()
{
  local resource=$1
  local fn='drbd_is_primary'
  local drbdadm_binary='drbdadm'

  if [ $# -ne 1 ]; then
    log_error "${fn} usage: ${fn} resource_name"
    return 1
  fi

  DRBDADM=$(ensure_bin drbdadm) || return 1

  RESOURCE_STATE=$($DRBDADM state ${resource} | awk -F / '{ print $1 }')

  if [ "x$RESOURCE_STATE" == 'xPrimary' ]; then
  	return 0
  else
  	return 1
  fi
}

# ssh_exec
# Questa funzione esegue, tramite SSH, un comando remoto e
#  ritorna lo exit-status del comando
#
# Keywords arguments:
#   $1  --  remote_host
#   $2  --  cmd
#   $3  --  user    (default root)
#   $4  --  verbose (default noverbose)
#
# Utilizzo:
#   if (ssh_exec aspaloNN "ls -l"); then
#       echo 'ok'
#   else
#       echo 'error'
#   fi
#
function ssh_exec()
{
  local host="$1"
  local cmd="$2"
  local user=${3:-root}
  local verbose=${4:-noverbose}
  local fn_name="ssh_exec()"
  local help="Usage: $fn_name cmd host [user] [verbose]"

  if [ $# -lt 2 ]; then
    log_error ${help}
    return 1
  fi

  SSH=$(ensure_bin ssh) || return 1

  if [ "x${verbose}" == "xverbose" ]; then
    $SSH -l ${user} ${host} "${cmd}"
  else
    $SSH -l ${user} ${host} "${cmd} >/dev/null 2>&1";
  fi

  return $?
}


# Requirements for the library
WHOAMI=$(ensure_bin whoami)


