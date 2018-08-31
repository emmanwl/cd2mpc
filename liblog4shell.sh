#@IgnoreInspection BashAddShebang
#@(#) Copyright (c) 2007, 2008, 2009, 2010, 2011, 2012, 2013, 2014, 2015, 2016, 2017, 2018 - E.de.Sars
#@(#) All rights reserved.
#@(#)
#@(#) Redistribution and use in source and binary forms, with or without modification, are permitted
#@(#) provided these redistributions must retain the above copyright, this condition and the following
#@(#) disclaimer.
#@(#)
#@(#) THIS SOFTWARE IS PROVIDED BY THE REGENTS AND CONTRIBUTORS ``AS IS'' AND ANY EXPRESS OR IMPLIED
#@(#) WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS
#@(#) FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE REGENTS AND CONTRIBUTORS BE LIABLE
#@(#) FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING
#@(#) PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTER-
#@(#) -RUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY,
#@(#) OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE,
#@(#) EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
#@(#)
#@(#) This is liblog4shell, a shell script library inspired by log4j.

. "<__libtools__>/imports.sh" 2>/dev/null
__import_resource_or_fail "<__libtools__>/lib4shell.sh"

# Shell name
__shell="$(__get_calling_shell_name "$0")"
#
# The standard output pattern layout is used to format each logger
# entry. This parameter must be made of a subset of the following
# specifiers shipped with a leading '%':
# - L (the logger level)
# - D (the logging timestamp "Y-m-d hour:min:sec")
# - F (the file where the logging event occurred)
# - H (the hostname)
# - M (the message)
# - P (the pid of the current process)
# - % (the literal percent sign '%')
#
__default_pattern_layout="%D - {%H} - [%L] - %F - %M"
__pattern_layout=
#
# The log level can be set to either <1:TRACE>, <2:DEBUG>, <3:INFO>,
# <4:WARN>, <5:ERROR> or <6:FATAL> so only messages having the same
# severity (or above) will be logged.
__log_level=
#
# Brief
# Zero-pad logger entries.
_pad() { printf "%0${1}i" "$2"; }
# Brief
# Inject in the pattern layout itself any error regarding
# an unrecognized specifier.
_err() { printf "%s" "illegal format symbol ${1}"; }
# Brief
# Get the logger format using the pattern layout ${1}.
__get_logger_format() {
    local layout="$1" expr fmt="+%Y-%d-%m %H:%M:%S" logger_format
    while [ ${#layout} -gt 0 ]; do
        case "$layout" in
             %*) layout="${layout#%}"
                 case "$layout" in
                       L*) expr="@{level%%_*}"                     ;;
                       D*) expr="@(date '${fmt}')"                 ;;
                       F*) expr="@{__shell}"                       ;;
                       H*) expr="@(hostname)"                      ;;
                       M*) expr="%s"                               ;;
                       P*) expr="@@"                               ;;
                       %*) expr="%%"                               ;;
                        *) expr=$(_err "${layout%%"${layout#?}"}") ;;
                 esac                                              ;;
              *) expr="${layout%"${layout#?}"}"
                 case "$expr" in
                           \)|\(|\|) expr="'${expr}'"              ;;
                                " ") expr=" "                      ;;
                 esac                                              ;;
        esac
        layout="${layout#?}"
        if [ "$logger_format" ]; then
           logger_format="${logger_format}${expr}"
        else
           logger_format="$expr"
        fi
    done
    if [ "$logger_format" ]; then
       printf "%s" "$logger_format"|sed "s/@/$/g"
    else
       printf "%%s"
    fi
}
#
# File appender
__file_appender=
__append_per_level=
#
# Console appender
__console_appender=
# Brief
# Get the file appender.
__get_file_appender() {
    local appender="${1:-"/dev/null"}"
    if [ -d "$appender" -a -w "$appender" ]; then
       appender="${appender}/${__shell}.log"
    elif [ -d "$(dirname "$appender")" -a -w "$(dirname "$appender")" ]; then
       if [ "${appender##*\.log}" ]; then
          appender="${appender}.log"
       elif [ -f "$appender" -a ! -w "$appender" ]; then
          appender="/dev/null"
       fi
    else
       appender="/dev/null"
    fi
    printf "%s" "$appender"
}
# Brief
# Get the console appender.
__get_console_appender() {
    local appender="${1:="/dev/null"}" term=$(tty)
    if [ "$appender" -eq "$appender" -a -t "$appender" -a "$appender" != "${term##*/}" ] 2>/dev/null
    then
       appender="${term%/*}/${appender}"
    else
       appender="/dev/null"
    fi
    printf "%s" "$appender"
}
# Brief
# Get a numerical debug level value.
__get_log_level() {
    local log_level="$1"
    case "$log_level" in
         [1-6])             ;;
         TRACE) log_level=1 ;; DEBUG) log_level=2 ;;
          INFO) log_level=3 ;;  WARN) log_level=4 ;;
         ERROR) log_level=5 ;; FATAL) log_level=6 ;;
             *) log_level=3 ;;
    esac
    printf "%s" "$log_level"
}
# Brief
# Log whenever.
logger_unconditionally() {
    __logger "TEST_32" "$@"
}
# Brief
# Trace logger.
logger_trace() {
    if [ ${__log_level} -eq 1 ]; then
       __logger "TRACE_35" "$@"
    fi
}
# Brief
# Debug logger.
logger_debug() {
    if [ ${__log_level} -le 2 ]; then
       __logger "DEBUG_32" "$@"
    fi
}
# Brief
# Info logger.
logger_info() {
    if [ ${__log_level} -le 3 ]; then
       __logger "INFO_34" "$@"
    fi
}
# Brief
# Warn logger.
logger_warn() {
    if [ ${__log_level} -le 4 ]; then
       __logger "WARN_35" "$@"
    fi
}
# Brief
# Error logger.
logger_error() {
    if [ ${__log_level} -le 5 ]; then
       __logger "ERROR_31" "$@"
    fi
}
# Brief
# Fatal logger.
logger_fatal() {
    if [ ${__log_level} -le 6 ]; then
       __logger "FATAL_31" "$@"
    fi
}
# Brief
# Stack trace in.
DEBUGIN() {
    logger_trace "<< [$1]"
}
# Brief
# Stack trace out.
DEBUGOUT() {
    logger_trace ">> [$1]"
    return "$2"
}
# Brief
# A dedicated wrapper function that embeds the logger and the appender(s).
__logger() {
    __logger_internal "${@}"| __append_once "${1%%_*}" "${1##*_}"
}
# Brief
# Report, according the log level, the input message to the standard output.
__logger_internal() {
    local level="$1" message="$2"
    shift 2
    while :; do case "$message" in \\n*) message="${message#\\n}" ;;
                                   *\\n) message="${message%\\n}" ;;
                                      *) break ;;
                esac
    done
    if [ ${#} -gt 0 ]; then
       message="$(printf "${message}\n${@}")"
    fi
    printf "$(eval echo "$__logger_format")\n" "$message"
    return 0
}
# Brief
# A dedicated wrapper that embeds both the file and the console appender
# (colourfully).
__append_once() {
    __append_to_file "$1"|__colorize "$2"|__append_to_console
}
# Brief
# Append to the selected file.
__append_to_file() {
    if ${__append_per_level:=false} && [ "$__file_appender" != "/dev/null" -a "$1" != "TEST" ]; then
       tee -a "$__file_appender" "${__file_appender}.${1}"
    else
       tee -a "$__file_appender"
    fi
}
# Brief
# Colorize the output accordingly.
__colorize() {
    local esc=$(printf "\033"); sed "s/.*/${esc}[${1}m&${esc}[0m/g"
}
# Brief
# Append to the selected console.
__append_to_console() {
    tee -a "$__console_appender" 2>/dev/null
}
#
__configure() {
    while [ ${#} -gt 0 ]; do
        case "${1%%=*}" in
           --console-appender) __console_appender="$(__get_console_appender "$(__first_not_empty "${1#*=}" "$2")")" ;;
              --file-appender) __file_appender="$(__get_file_appender "$(__first_not_empty "${1#*=}" "$2")")"       ;;
           --append-per-level) __append_per_level=true                                                              ;;
                  --log-level) __log_level="$(__get_log_level "$(__first_not_empty "${1#*=}" "$2")")"               ;;
              --logger-format) __logger_format="$(__get_logger_format "$(__first_not_empty "${1#*=}" "$2")")"       ;;
        esac
        shift
    done
}
__configure --console-appender="${__console_appender:="/dev/null"}" --file-appender="${__file_appender:="/dev/null"}" --log-level="${__log_level:="DEBUG"}" --logger-format="${__pattern_layout:="$__default_pattern_layout"}" "$@"
