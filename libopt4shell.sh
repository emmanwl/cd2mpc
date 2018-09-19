#@IgnoreInspection BashAddShebang
#@(#) Copyright (c) 2007, 2008, 2009, 2010, 2011, 2012, 2013, 2014, 2015, 2016, 2017, 2018, 2019
#@(#) E.de.Sars - All rights reserved.
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
#@(#) This is libopt4shell, a shell API for parsing command line parameters. It handles short/long
#@(#) options and features option bundling, option abbreviation to uniqueness, option aliasing,
#@(#) negatable and incremental style of options as well as (option) argument type checking.
#@(#) It's POSIX compliant providing POSIXLY_CORRECT is non-zero.

. "<__lib_dir__>/imports.sh" || exit ${E_IMPORT_FAILURE:=13}
__import_resource_or_fail "<__lib_dir__>/lib4shell.sh"

# Shell name
__shell="$(__get_shell_name "$0")"
# Parser name
__parser=argp_parse
#
# ${_main_opts} is a line-oriented set of entries holding short/long options to parse.
# Short options refer to single alphanumeric characters prepended with a single dash.
# Long options refer to words (see ${__word_rgxp}) or multiple words, separated by an
# hypen (see ${__long_rgxp}), prepended with a double dash.
#
# Each ${_main_opts} entry is a colon-delimited string consisting of:
# - an option code identifying the entry and acting as well as a callback value
# - a pipe-delimited string holding long option aliases
# - a flag, namely the argument mandatoriness flag, being <0, 1, 2> which describes
#   to which extend <forbidden, mandatory, optional> the option accepts argument(s)
# - a description text
_main_opts=
__opt_code_rgxp="[[:alnum:]]+"
__true_false_rgxp="([tT][rR][uU][eE]|1|[fF][aA][lL][sS][eE]|0)"
__key_rgxp="[[:alpha:]][[:alnum:]]{1,}(_[[:alnum:]]+)*"
__word_rgxp="[[:alnum:]]{2,}(-[[:alnum:]]+)*"
__arg_type_rgxp="string|integer|binary|number|path|${__word_rgxp}"
__type_rgxp="((1|2)(@(key-value|${__arg_type_rgxp}|key-value-(${__arg_type_rgxp}))){0,1}|0)"
__long_rgxp="^${__opt_code_rgxp}:(${__word_rgxp}(\|(${__word_rgxp}))*(\!|@){0,1}){0,1}:${__type_rgxp}:.*"
#
# ${__optstring} points to the set of short options, see ${__shrt_rgxp}.
# Its description mimics the 'getOpt' style option declaration.
# Given an ${__optstring} character:
# - if bundled with no colon, the matched option doesn't allow an argument
# - if bundled with exactly one colon, the matched option requires an argument
# - if bundled with exactly two colons, the matched option can be provided with
#   an optional argument
__optstring=
__shrt_rgxp="^([[:alnum:]]+:{0,2})+$"
#
# Optionally, "@<type>" can be appended to the mandatoriness flag so the option
# arguments will be type-checked at parsing time.
# This check relies on the implementation of the is_<type> interface where <type>
# denotes the actual argument type. That function is expected to return 0 in case
# of success and a different value else. A default implementation is provided for
# common types such as 'string','integer', 'binary', 'number' and 'path'.
# Last but not least, the is_<type> interface also exposes the 'key-value' type
# (checked arguments must be of the form '<key>=<value>') as well as the compound
# forms 'key-value-<type>' (checked arguments must be of the form '<key>=<value>'
# and <value> must be of type <type>).
# Note that the latter definition is not recursive: <value> can never be checked
# against the 'key-value' type itself or one its nested form 'key-value-<type>'.
# These type check routines are to be extended or overriden dynamically on a per
# script basis.
#
# Additionally, for any long option which doesn't allow an argument, the negated
# option --no-<option>, or alternatively --no<option>, is handled automatically
# if the alias string ends with the character '!'.
# Similarly, long option arguments can be handled incrementally (upon each option
# presentation, arguments are stored in a vector) if that same alias string ends
# with the character '@'.
#
# At first call, argp_parse sets {__optindex} to the index of the first option word
# to scan, see {__optwrd}. This option word is then splitted according its short or
# long option nature. The resulting tokens are then matched as the option and its
# argument(s), {__opt} and {__optarg} respectively. From call to call, those expose
# the option and argument(s) currently scanned.
# If the option word doesn't match a long option, it will be tested to match a short
# option or a group of options.
# If that word effectively matches a short option (group), it is stripped from its
# leading character and repeatedly for each matched short option that it embeds.
# When all clustered options of that word have been scanned or if that word has been
# matched as a long option, the option index is incremented by one.
#
# If the matched option is a negated form of a known option, {__opt} is set to the
# latter's option code prepended with '!'. Similarly, if the matched option is an
# incremental form of a known option, ${__opt} is stored in ${__acc_opts} and its
# potential argument(s) are accumulated. Both are then emptied for the parser to
# return 0.
#
# When argp_parse run out of input, it will iterate over each accumulated option
# code in ${__acc_opts} and will repeatedly set {__opt} to the concatenation of '@'
# and that option code. It will, as well, set {__optarg} to the string holding the
# mapped option arguments accumulated so far.
# By default, the long option matching is case-sensitive but this behaviour can be
# configured within the use of the /case-insensitive switch.
# If all vector elements have been scanned or when argp_parse hits the word '--', it
# will return 1, which will end the whole option scanning.
__optindex=0
__optwrd=
__noptindex=0
__opt=
__optarg=
__acc_opts=
_case_sensitive=true
#
# Three scanning modes are implemented so {_parsing_strategy} can be either:
# - 'PERMUTE' (default)
#             This mode simulates the permutation of all non-option arguments by
#             storing them, as they come, in a vector, allowing then subsequent
#             parsing. See {__nonopt_argv}.
# - 'RETURN_IN_ORDER'
#             This mode processes options as they come, each non-option argument
#             being handled as if it was the argument of an option with code `1'
# - 'REQUIRE_ORDER'
#             This fail-fast mode stops the option scanning when reaching the
#             first non-option argument
__parsing_strategy_rgxp="^PERMUTE|RETURN_IN_ORDER|REQUIRE_ORDER$"
_parsing_strategy="PERMUTE"
__nonopt_argv=
#
# When argp_parse encounters and reports to stderr an illegal or ambiguous option,
# it sets {__opt} to '?' and {__optarg} to the empty string.
# However, if ${_exit_on_error} is false, no error is reported and {__optarg} is set
# to the faulty option.
# If argp_parse encounters and reports a missing/superfluous option argument or
# an option argument that is not of the expected type, it sets {__opt} to '?' and
# {__optarg} to the empty string. If ${_exit_on_error} is false, no error is reported:
# {__opt} is set to ':' and {__optarg} is set to the faulty option.
# When a required option is reported as absent from the command line, argp_parse sets
# {_opt} to '?' and {__optarg} to the empty string. If ${_exit_on_error} is false, no
# error is reported: {__opt} is set to ',' and {__optarg} is set to the first missing
# required option (and repeatedly for each missing required option).
# When argp_parse reports two conflicting options, it sets {__opt} to '?' and {__optarg}
# to the empty string. Similarly, if ${_exit_on_error} is false, no error is reported:
# {__opt} is set to '^' and {__optarg} is set to '<opt_a>/<opt_b>' where <opt_a>/<opt_b>
# denotes the conflicting option pair.
#
__err_code_illegal_opt="?"
__err_code_illegal_arg="?"
__err_code_expected_opt="?"
__err_code_conflict_opt="?"
_exit_on_error=true
#
# From the caller perspective, {__opt} and {__optarg} place holders can be consumed
# within two callback variables named "$_callback_opt" and "${_callback_opt}arg",
# see the /callback-option-prefix switch.
_callback_opt=_opt
#
# The boolean flag ${_long_only} instructs the parser to scan words prefixed with
# a single dash as if they were regular long options (options prefixed with '--').
_long_only=false
#
# The boolean flag ${_allow_posix_long_opt} instructs the parser to recognize
# -W foo=bar or -Wfoo=bar as --foo=bar. Note that this will supersede any other
# option recognition, being short (-W) or abbreviated (--W).
_allow_posix_long_opt=false
#
# {_req_opts} is a space free coma-separated list of options (option codes)
# holding mandatory arguments.
_req_opts=
#
# {_excl_opts} is a space free coma-separated list of options (option codes)
# that are mutually exclusive of each other.
_excl_opts=
#
# {_arg_sep} specifies how to join multiple option arguments in a single vector.
_arg_sep=","
# {_key_value_sep} specifies how to join multiple key-value option arguments in
# a single vector.
_key_value_sep="@"
# {_filter_option_arguments_to_uniqueness} specify how to capture multiple option arguments.
# If set to true, the argument is added to the argument vector provided it was
# not previously added.
_filter_option_arguments_to_uniqueness=false
#
# Configuration errors
__err_missing_long_alias="missing long alias(es) for entry \`%s'"
__err_duplicate_option_entry="duplicate option entry \`%s'"
__err_not_unique_long_alias="long alias \`%s' is not unique"
__err_short_option_syntax="bad syntax [%s], short option string expects syntax \`[<option_code>[:[:]]]+'"
__err_long_option_syntax="bad syntax [%s], long option set expects entries with syntax \`<option_code>:<long_aliases[!|@]>:<argument_flag[@<argument_type[string|integer|binary|number|path|key-value[-<argument_type>]|<custom_type>]>]>:<option_description>'"
__err_missing_type_check_function="missing function is_%s"
__err_negatable_option_definition="only argumentless options can be negatable, \`%s' is not such an option."
__err_incremental_option_definition="only options having mandatory arguments can be incremented, \`%s' is not such an option."
__err_unrecognized_option="unrecognized option \`%s'"
__err_ambiguous_option="option \`%s' is ambiguous"
__err_required_option_argument="option \`%s' requires an argument"
__err_not_allowed_option_argument="option \`%s' doesn't allow an argument"
__err_conflicting_option="option/option code \`%s' conflicts with option \`%s'"
__err_required_option_not_invoked="required option \`%s' was not invoked"
__err_invalid_option_argument_type="option \`%s' expects type \`%s' for argument \`%s'"
__err_invalid_parsing_stragegy="invalid parsing strategy \`%s'"
__err_missing_option_switch="missing required switch /options=<...>, see argp_parse_help for help"
__err_invalid_callback_option_prefix="invalid /callback-option-prefix argument, expecting a non-empty value"
__err_invalid_argument_separator="invalid /argument-separator symbol, expecting a single character symbol"
__err_required_and_exclusive_option_definition="options \`%s,%s' can't be required and mutually exclusive as well"
#
# Brief
# Print message to stdout/stderr.
trace() {
    local format
    if [ ${#} -ge 1 ]; then
       format="${__shell}: ${1}\n"
       shift
       printf "$format" "$@"
    fi
}
sysout() {
    trace "$@"
}
syserr() {
    trace "$@" >&2
}
# Brief
# Check whether ($@) hold each item only once.
has_unique_candidates() {
    local token1 token2
    set -- $(__split_tokens_accordingly " " "$@")
    for token1; do
        token1="$(lowerize_accordingly "$token1")"
        shift
        for token2; do
            token2="$(lowerize_accordingly "$token2")"
            if [ "$token1" = "$token2" ]; then
               syserr "$__err_not_unique_long_alias" "$token1"
               return 1
            fi
        done
    done
}
# Brief
# Read all columns from a colon-delimited string.
read_colon_separated_token() {
    __read_separator_delimited_token ":" "$@"
}
# Brief
# Strip input string from the ending symbol '@' or '!'.
strip_ending_option_symbol() {
    local string="$1"
    case "${string#"${string%?}"}" in
         \!|\@) string="${string%?}" ;;
    esac
    printf "%s" "$string"
}
# Brief
# Strip input string from the starting symbol '@' or '!'.
strip_starting_option_symbol() {
    local string="$1"
    case "${string%"${string#?}"}" in
         \!|\@) string="${string#?}" ;;
    esac
    printf "%s" "$string"
}
# Brief
# Check whether is_${1} denotes an existing implementation
# for the type interface.
is_implemented() {
   local arg_type="$1"
   if [ ! "${arg_type##key-value-*}" ]; then
      if ! type is_"$(__underscorize "${arg_type#key-value-}")"; then
         return 1
      fi
   elif ! type is_"$(__underscorize "$arg_type")"; then
      return 1
   fi >/dev/null 2>&1
}
# Brief
# Parse ${_main_opts} and build {__optstring}.
get_optstring() {
    local token long_tokens optstring short_tokens arg_type opt_code aliases arg_flag IFS="
"
    local mainopts="${_main_opts}
__end_main_opts"
    #
    for token in ${mainopts}; do
        token="$(__trim "$token")"
        if [ "$token" = "__end_main_opts" ]; then
           if ! has_unique_candidates "$long_tokens"; then
              return 1
           elif [ "$optstring" ]; then
              if ! __is_of_match "$optstring" "$__shrt_rgxp"; then
                 syserr "$__err_short_option_syntax" "$optstring"
                 return 1
              else
                 printf "%s" "$optstring"
              fi
           fi
           return 0
        elif ! __is_of_match "$token" "$__long_rgxp"; then
           syserr "$__err_long_option_syntax" "$token"
           return 1
        fi
        #
        read_colon_separated_token "$token" 1 opt_code aliases arg_flag
        if [ ! "$short_tokens" ]; then
           short_tokens="$opt_code"
        elif [ ! "${short_tokens##*"${opt_code}"*}" ]; then
           syserr "$__err_duplicate_option_entry" "$opt_code"
           return 1
        else
           short_tokens="${short_tokens} ${opt_code}"
        fi
        if [ ${#opt_code} -eq 1 ]; then
           case "$arg_flag" in
                1*) optstring="${optstring}${opt_code}:" ;;
                2*) optstring="${optstring}${opt_code}::" ;;
                 *) optstring="${optstring}${opt_code}" ;;
           esac
        fi
        #
        if [ ! "$aliases" -a ${#opt_code} -gt 1 ]; then
           syserr "$__err_missing_long_alias" "$opt_code"
           return 1
        elif [ "$aliases" -a ! "${aliases%%*!}" ]; then
           if [ ${arg_flag%%@*} -ne 0 ]; then
              syserr "$__err_negatable_option_definition" "$(get_readable_option_name "$opt_code")"
              return 1
           fi
        elif [ "$aliases" -a ! "${aliases%%*@}" ]; then
           if [ ${arg_flag%%@*} -ne 1 ]; then
              syserr "$__err_incremental_option_definition" "$(get_readable_option_name "$opt_code")"
              return 1
           fi
        fi
        if [ "$aliases" ]; then
           long_tokens="$(local args="$long_tokens" alternate IFS="|"
                          for alternate in ${aliases}; do
                              alternate="$(strip_ending_option_symbol "$alternate")"
                              if [ ! "$args" ]; then
                                 args="$alternate"
                              else
                                 args="${args} ${alternate}"
                              fi
                          done
                          printf "%s" "$args")"
        fi
        #
        case "$arg_flag" in [1-2]@*) arg_type="${arg_flag#?@}" ;;
                              [1-2]) arg_type="string" ;;
                                  *) arg_type= ;;
        esac
        if [ "$arg_type" ] && ! is_implemented "$arg_type"; then
           syserr "$__err_missing_type_check_function" "$(__underscorize "$arg_type")"
           return 1
        fi
    done
}
#
set_option_and_argument() {
    __opt="$1"
    __optarg="$2"
}
#
set_callback_option_and_argument() {
    read -r -- ${_callback_opt} ${_callback_opt}arg<<EOF
${1} ${2}
EOF
    set_option_and_argument "" ""
}
#
set_erroneous_option_and_argument() {
    local optarg
    decode optarg "$_exit_on_error" "" "$2"
    set_option_and_argument "$1" "$optarg"
}
#
alert_whenever() {
    if ${_exit_on_error}; then
       syserr "$@"
    fi
}
#
is_key_value() {
    __is_of_match "$1" "^${__key_rgxp}=[[:print:]]+$"
}
# Brief
# Check whether the option argument is of the given type:
# - if ${2} is like key-value-${type}, check that ${1}
#   is of type key-value and that ${1#*=} is of type ${type}.
# - else check that ${1} is of type ${2}
has_argument_proper_type() {
  local argument="$1" type="$2"
  if [ ! "${type##key-value-*}" ]; then
     if ! { is_key_value "$argument" && eval is_"$(__underscorize "${type#key-value-}")" "${argument#*=}"; }; then
        return 1
     fi
  elif ! eval is_"$(__underscorize "$type")" "$argument"; then
     return 1
  fi 2>/dev/null
}
# Brief
# Check whether the option argument is of the given type.
has_option_argument_proper_type_internal() {
  local argument="$1" type="$2" option="$3"
  if [ "$type" ] && ! has_argument_proper_type "$argument" "$type"; then
     alert_whenever "$__err_invalid_option_argument_type" "$option" "$type" "$argument"
     return 1
  fi
}
# Brief
# Check that the option argument(s) is of the proper type.
has_option_argument_proper_type() {
  has_option_argument_proper_type_internal "${__optarg:="$1"}" "$(eval echo '$'__"${__opt}"_argument_type)" "$2"
}
# Brief
# Simple if-then-else read routine: if ${1} is evaluated to true,
# return 0 else return 1.
_decode() {
    case "$1" in [tT][rR][uU][eE]|0) return 0 ;; *) return 1 ;; esac
}
# Brief
# Simple if-then-else read routine: if ${2} is evaluated to true,
# the variable whose name is ${1} is set to ${3}, otherwise it will
# be set to ${4}.
decode() {
    local arg r
    _decode "$2" && { r=0; arg="$3"; } || { r=1; arg="$4"; }
    read -r -- $1<<EOF
${arg}
EOF
    return ${r}
}
# Brief
# Routine for parsing short options.
argp_parse_short() {
    local parse_as_long="$1" opt_code="${__optwrd%"${__optwrd#?}"}" opt_context
    shift
    decode opt_context "$parse_as_long" "${1%%=*}" "-${opt_code}"
    if [ ! "$__optstring" ]; then
       set_erroneous_option_and_argument "$__err_code_illegal_opt" "$opt_context"
       alert_whenever "$__err_unrecognized_option" "$opt_context"
       return 0
    elif [ ! "${__optstring%%*"${opt_code}"::*}" ]; then
       has_conflicting_state "${__opt:="${opt_code}"}" && return 0
       if ! has_option_argument_proper_type "${__optwrd#?}" "$opt_context"; then
          set_erroneous_option_and_argument "$__err_code_illegal_arg" "$opt_context"
          return 0
       fi
       __optwrd=
       return 1
    elif [ ! "${__optstring%%*"${opt_code}":*}" ]; then
       has_conflicting_state "${__opt:="${opt_code}"}" && return 0
       if [ ! "${__optwrd#?}" ]; then
          if [ ${#} -eq 1 ]; then
             set_erroneous_option_and_argument "$__err_code_illegal_arg" "$opt_context"
             alert_whenever "$__err_required_option_argument" "$opt_context"
             return 0
          elif ! has_option_argument_proper_type "$2" "$opt_context"; then
             set_erroneous_option_and_argument "$__err_code_illegal_arg" "$opt_context"
             return 0
          fi
          __optwrd=
          accumulate_mandatory_option_and_arguments_if_necessary
          return 2
       elif ! has_option_argument_proper_type "${__optwrd#?}" "$opt_context"; then
          set_erroneous_option_and_argument "$__err_code_illegal_arg" "$opt_context"
          return 0
       fi
       __optwrd=
       accumulate_mandatory_option_and_arguments_if_necessary
       return 1
    elif [ ! "${__optstring%%*"${opt_code}"*}" ]; then
       has_conflicting_state "${__opt:="${opt_code}"}" && return 0
       __optwrd="${__optwrd#?}"
       if [ "$__optwrd" ]; then
          return 0
       fi
       return 1
    else
       set_erroneous_option_and_argument "$__err_code_illegal_opt" "$opt_context"
       syserr "$__err_unrecognized_option" "$opt_context"
    fi
    return 0
}
# Brief
# According to ${_case_sensitive}, put ${1} to lowercase.
lowerize_accordingly() {
    local string="$1"
    if ! ${_case_sensitive}; then
       string=$(__lowerize "$string")
    fi
    printf "%s" "$string"
}
# Brief
# Check that ${2} matches the fully-qualified option ${1}
# or one of its negated forms if relevant.
# Return:
# - the argument mandatoriness flag of the matched option
# - 5 in any other case.
match_long_option_name() {
    local opt_name="$(lowerize_accordingly "$(strip_ending_option_symbol "$1")")"
    local opt_to_match="$(lowerize_accordingly "$2")"
    local opt_code="$3" arg_flag="$4" _opt
    for _opt in "${opt_name}" "no-${opt_name}" "no${opt_name}"; do
        if [ ! "${_opt##"${opt_to_match}"*}" ]; then
           if [ ! "${1%%*!}" ]; then
              printf "%s" "!${opt_code}:${_opt}"
           else
              printf "%s" "${opt_code}:${_opt}"
           fi
           return "$arg_flag"
        fi
    done
    return 5
}
# Brief
# Retrieve the option code associated to the option matching ${1}.
# Return:
# - the argument mandatoriness flag of the matched option (if unique)
# - 3 if ${1}, specified as long, matches several options
# - 4 if ${1}, specified as long, doesn't match any option
# - 5 in any other case.
get_long_option_code() {
    local opt_to_match="$1" has_double_dash=false token matches=0 opt_code arg_flag
    local aliases result result_flag matched_code matched_flag matched_opt IFS="
"
    local mainopts="${_main_opts}
__end_main_opts"
    case "$opt_to_match" in --*) opt_to_match="${opt_to_match#--}"
                                 has_double_dash=true             ;;
                             -*) opt_to_match="${opt_to_match#-}" ;;
    esac
    for token in ${mainopts}; do
        token="$(__trim "$token")"
        if [ "$token" = "__end_main_opts" ]; then
           if [ ${matches} -eq 0 ]; then
              opt_code="$__err_code_illegal_opt"
              decode arg_flag "$has_double_dash" 4 5
           elif [ ${matches} -eq 1 ]; then
              opt_code="$matched_code"
              arg_flag="$matched_flag"
           else
              opt_code="$__err_code_illegal_opt"
              decode arg_flag "$has_double_dash" 3 5
           fi
        else
           read_colon_separated_token "$token" 1 opt_code aliases arg_flag
           if [ "$aliases" ]; then
              result="$(local alternate r IFS="|"
                       for alternate in ${aliases}; do
                           match_long_option_name "$alternate" "$opt_to_match" "$opt_code" "${arg_flag%@*}"
                           r="$?"
                           if [ ${r} -ne 5 ]; then
                              return ${r}
                           fi
                       done
                       return 5)"
              result_flag="$?"
              if [ "$result" ]; then
                 matches=$((${matches} + 1))
                 read_colon_separated_token "$result" 1 matched_code matched_opt
                 matched_flag="$result_flag"
                 if [ ${#opt_to_match} -eq ${#matched_opt} ]; then
                    opt_code="$matched_code"; arg_flag="$matched_flag"
                    break
                 fi
              fi
           fi
        fi
    done
    #
    printf "%s" "$opt_code"
    return "$arg_flag"
}
# Brief
# Check whether ${1} must be parsed as a long option.
argp_pre_parse() {
    local _parse_as_long="$1" warg
    shift
    if [ ! "$__optwrd" ]; then
       case "$1" in
          -) return 1 ;;
         --) return $((${E_END_OF_PARSING} + 1)) ;;
        --*) read_colon_separated_token true 1 ${_parse_as_long} ;;
         -*) case "${1#-}" in
               W*) if ${_allow_posix_long_opt}; then
                      if [ ! "${1#-W}" ]; then
                         if [ ${#} -ge 2 -a "${2##-*}" -a ! "${2##*=*}" ]
                         then
                            warg="$2"; shift 2
                            argp_parse_long "--${warg}" "$@"
                            return 2
                         fi
                      elif [ "${1##-W-*}" -a ! "${1##*=*}" ]
                      then
                         warg="${1#-W}"; shift
                         argp_parse_long "--${warg}" "$@"
                         return 1
                      fi
                   fi ;;
             esac
             __optwrd="${1#-}"
             read_colon_separated_token ${_long_only} 1 ${_parse_as_long} ;;
          *) case "$_parsing_strategy" in
                   REQUIRE_ORDER) return ${E_END_OF_PARSING} ;;
                 RETURN_IN_ORDER) set_option_and_argument "1" "$1"
                                  return 1 ;;
                         PERMUTE) if [ "$__nonopt_argv" ]; then
                                     __nonopt_argv="${__nonopt_argv} ${1}"
                                  else
                                     __nonopt_argv="$1"
                                  fi
                                  return 1 ;;
             esac ;;
       esac
    else
       read_colon_separated_token false 1 ${_parse_as_long}
    fi
}
# Brief
# Routine for parsing long options.
argp_parse_long() {
   local opt_code
   opt_code="$(get_long_option_code "${1%%=*}")"
   case "$?" in
     0) __opt="$opt_code"
        has_conflicting_state "$(strip_starting_option_symbol "$opt_code")" && return 0
        if [ ! "${1##*=*}" ]; then
           set_erroneous_option_and_argument "$__err_code_illegal_arg" "${1%%=*}"
           alert_whenever "$__err_not_allowed_option_argument" "${1%%=*}"
           return 0
        fi
        __optwrd=
        return 1 ;;
     1) __opt="$opt_code"
        has_conflicting_state "$(strip_starting_option_symbol "$opt_code")" && return 0
        if [ ! "${1##*=*}" ]; then
           if ! has_option_argument_proper_type "${1#*=}" "${1%%=*}"; then
              set_erroneous_option_and_argument "$__err_code_illegal_arg" "${1%%=*}"
              return 0
           fi
           __optwrd=
           accumulate_mandatory_option_and_arguments_if_necessary
           return 1
        elif [ ${#} -gt 1 ]; then
           if ! has_option_argument_proper_type "$2" "$1"; then
              set_erroneous_option_and_argument "$__err_code_illegal_arg" "$1"
              return 0
           fi
           __optwrd=
           accumulate_mandatory_option_and_arguments_if_necessary
           return 2
        else
           set_erroneous_option_and_argument "$__err_code_illegal_arg" "$1"
           alert_whenever "$__err_required_option_argument" "$1"
           return 0
        fi ;;
     2) __opt="$opt_code"
        has_conflicting_state "$(strip_starting_option_symbol "$opt_code")" && return 0
        if [ ! "${1##*=*}" ]; then
           if ! has_option_argument_proper_type "${1#*=}" "${1%%=*}"; then
              set_erroneous_option_and_argument "$__err_code_illegal_arg" "${1%%=*}"
              return 0
           fi
        fi
        __optwrd=
        return 1 ;;
     3) set_erroneous_option_and_argument "$opt_code" "${1%%=*}"
        alert_whenever "$__err_ambiguous_option" "${1%%=*}"
        return 0 ;;
     4) set_erroneous_option_and_argument "$opt_code" "${1%%=*}"
        alert_whenever "$__err_unrecognized_option" "${1%%=*}"
        return 0 ;;
   esac
   return 5
}
# Brief
# Routine for parsing long/short options. The current behaviour is to
# fallback to the short options parsing routine if no error is raised
# during the initial long pass.
argp_parse_internal() {
    local parse_as_long r
    argp_pre_parse parse_as_long "$@" || return
    #
    if ${parse_as_long}; then
       argp_parse_long "$@"
       r="$?"
       if [ ${r} -lt 5 ]; then
          return ${r}
       fi
    fi
    #
    argp_parse_short "$parse_as_long" "$@"
}
# Brief
# Read parser configuration once.
read_parser_configuration_arguments() {
    local cmd="s/^[[:space:]]\{0,\}//g" noptindex=0
    while [ ${#} -gt 0 -a ! "${1##/*}" ]; do
        case "${1#/}" in
                                  options=*) _main_opts=$(printf "%s" "${1#*=}"|sed "$cmd")                            ;;
                   callback-option-prefix=*) _callback_opt="$(__trim_globally "${1#*=}")"                              ;;
                         parsing-strategy=*) _parsing_strategy="${1#*=}"                                               ;;
                           case-insensitive) _case_sensitive=false                                                     ;;
                                  long-only) _long_only=true                                                           ;;
                    allow-posix-long-option) _allow_posix_long_opt=true                                                ;;
                       do-not-exit-on-error) _exit_on_error=false                                                      ;;
                         required-options=*) _req_opts="$(__append "$(__trim_globally "${1#*=}")" "$_req_opts" ",")"   ;;
                        exclusive-options=*) _excl_opts="$(__append "$(__trim_globally "${1#*=}")" "$_excl_opts" "@")" ;;
                       argument-separator=*) _arg_sep="$(__trim_globally "${1#*=}")"                                   ;;
        trim-option-arguments-to-uniqueness) _filter_option_arguments_to_uniqueness=true                               ;;
        esac
        noptindex=$((${noptindex} + 1))
        shift
    done
    if _decode "$POSIXLY_CORRECT"; then
       _allow_posix_long_opt=true
       _parsing_strategy="REQUIRE_ORDER"
    fi
    return ${noptindex}
}
# Brief
# Get the option code matching ${1} if ${1} matches a short option.
# Return the matched option argument flag, 3 otherwise.
get_short_option_code() {
    local opt="$1"
    if [ ! "$__optstring" ]; then
       return 3
    elif [ ! "${__optstring##*"${opt}::"*}" ]; then
       printf "%s" "$opt"
       return 2
    elif [ ! "${__optstring##*"${opt}:"*}" ]; then
       printf "%s" "$opt"
       return 1
    elif [ ! "${__optstring##*"${opt}"*}" ]; then
       printf "%s" "$opt"
       return 0
    else
       return 3
    fi
}
# Brief
# Map silently all required options to their option code.
map_required_options() {
    local opt opt_code req_opts
    for opt in $(__split_tokens_accordingly "," "$_req_opts"); do
        if [ ${#opt} -eq 1 ]; then
           opt_code="$(get_short_option_code "$opt")"
        else
           opt_code="$(get_long_option_code "$opt")"
        fi
        case "$?" in
             1) req_opts="$(__append "$opt_code" "$req_opts" ",")" ;;
        esac
    done && _req_opts="$req_opts"
}
# Brief
# Map silently all exclusive options to their option code.
map_exclusive_options() {
    local opt_grp exclopts opt opt_code excl_opts IFS opta optb
    for opt_grp in $(__split_tokens_accordingly "@" "$_excl_opts"); do
        exclopts=
        for opt in $(__split_tokens_accordingly "," "$opt_grp"); do
            if [ ${#opt} -eq 1 ]; then
               opt_code="$(get_short_option_code "$opt")"
            else
               opt_code="$(get_long_option_code "$opt")"
            fi
            case "$?" in
               [0-2]) exclopts="$(__append "$opt_code" "$exclopts" ",")" ;;
            esac
        done
        if [ "$exclopts" ]; then
           excl_opts="$(__append "$exclopts" "$excl_opts" "@")"
        fi
    done && _excl_opts="$excl_opts"
    #
    for opt_grp in $(__split_tokens_accordingly "@" "$_excl_opts"); do
        set -- $(__split_tokens_accordingly "," "$opt_grp")
        for opta; do
            shift
            for optb; do
                if [ "$opta" != "$optb" ]; then
                   map_exclusive_options_pair "$opta" "$optb"
                fi
            done
        done
    done
}
# Brief
# Check whether required options are not exclusive of one another.
map_required_versus_exclusive_options() {
    local opta optb conflicts conflict
    set -- $(__split_tokens_accordingly "," "$_req_opts")
    for opta; do
        conflicts="$(eval echo '$'__get_conflicting_options_with_"${opta}")"
        shift
        if [ "$conflicts" ]; then
           for optb; do
               for conflict in $(__split_tokens_accordingly "," "$conflicts"); do
                   if [ "$conflict" = "$optb" ]; then
                      syserr "$__err_required_and_exclusive_option_definition" "$(get_readable_option_name "$opta")" "$(get_readable_option_name "$optb")"
                      return 1
                   fi
               done
           done
        fi
    done
}
#
configure_parser() {
    if ! __is_of_match "$_parsing_strategy" "$__parsing_strategy_rgxp"; then
       syserr "$__err_invalid_parsing_stragegy" "$_parsing_strategy"
       return 1
    elif [ ! "$_main_opts" ]; then
       syserr "$__err_missing_option_switch"
       return 1
    elif ! __optstring="$(get_optstring)"; then
       return 1
    elif [ ! "$_callback_opt" ]; then
       syserr "$__err_invalid_callback_option_prefix"
       return 1
    elif [ "$_req_opts" ] && ! map_required_options; then
       return 1
    elif [ "$_excl_opts" ] && ! map_exclusive_options; then
       return 1
    elif [ "$_excl_opts" -a "$_req_opts" ] && ! map_required_versus_exclusive_options
    then
       return 1
    elif [ ${#_arg_sep} -gt 1 ]; then
       syserr "$__err_invalid_argument_separator"
       return 1
    elif [ ${#_key_value_sep} -gt 1 ]; then
       syserr "$__err_invalid_argument_separator"
       return 1
    fi
    decode __err_code_illegal_arg "$_exit_on_error" "?" ":"
    decode __err_code_expected_opt "$_exit_on_error" "?" ","
    decode __err_code_conflict_opt "$_exit_on_error" "?" "^"
    return 0
}
# Brief
# Routine for initializing option mutators.
init_option_mutators() {
    local token opt_code aliases arg_flag arg_type IFS="
"
    for token in ${_main_opts}; do
        token="$(__trim "$token")"
        read_colon_separated_token "$token" 1 opt_code aliases arg_flag
        case "$arg_flag" in [1-2]@*) arg_type="${arg_flag#?@}" ;;
                              [1-2]) arg_type="string" ;;
                                  *) arg_type= ;;
        esac
        eval "__has_opt_code_${opt_code}_been_scanned=false"\
             "__get_conflicting_options_with_${opt_code}="\
             "__${opt_code}_argument_type=${arg_type}"
        if [ ! "${aliases%%*@}" ]; then
           eval "__has_${opt_code}_accumulator=true" "__${opt_code}_arguments="
        else
           eval "__has_${opt_code}_accumulator=false"
        fi
    done
}
# Brief
# Strip entry ${1} from a ${3}-delimited string, namely ${2}, and assign the
# result to the placeholder ${4}.
remove_entry_from_string_with_separator() {
    local entry="$1" options="$2" separator="$3" result="$4"
    local opt_code _options has_entry=false
    if [ "$options" ]; then
       for opt_code in $(__split_tokens_accordingly "$separator" "$options"); do
           if [ "$opt_code" != "$1" ]; then
              if [ ! "$_options" ]; then
                 _options="$opt_code"
              else
                 _options="${_options}${separator}${opt_code}"
              fi
           else
              has_entry=true
           fi
       done
       if ${has_entry}; then
          read -r -- "$result"<<EOF
${_options}
EOF
          return 1
       fi
    fi
}
# Brief
# Remove ${1} from the required options set if ${1} does match such
# an option.
remove_entry_from_required_options_if_necessary() {
    remove_entry_from_string_with_separator "$1" "$_req_opts" "," _req_opts
    return 0
}
# Brief
# Remove ${1} from the accumulated options if ${1} does match such
# an option.
remove_entry_from_accumulated_options_if_necessary() {
    remove_entry_from_string_with_separator "$1" "$__acc_opts" ":" __acc_opts
    if [ ${?} -eq 1 ]; then
       eval "__has_${opt_code}_accumulator=false" "__${opt_code}_arguments="
    fi
}
# Brief
# Remove the first entry of the required options and, if necessary,
# from the accumulated options as well.
remove_current_entry_from_required_and_accumulated_options() {
    remove_entry_from_required_options_if_necessary "$1"
    remove_entry_from_accumulated_options_if_necessary "$1"
}
# Brief
# Check whether ${1} must be added to vector ${2} (${3} denoting the 
# element separator).
must_1_be_added_to_2_using_3_as_separator() {
    if ! ${_filter_option_arguments_to_uniqueness}; then
       return 0
    elif  ! __is_1_contained_in_2_using_3_as_separator "$1" "$2" "$3"; then
       return 0
    fi
    return 1
}
# Brief
# Compute the accumulated argument vector __${1}_arguments depending
# on _${1}_argument_type.
get_accumulated_argument_vector() {
    local opt="$1" optarg="$2" optargs="$(eval echo '$'__"${1}"_arguments)"
    local key_value _optargs matched=false
    if [ ! "$optargs" ]; then
       _optargs="$optarg"
    else
       case "$(eval echo '$'__"${opt}"_argument_type)" in
          key-value*) for key_value in $(__split_tokens_accordingly ${_key_value_sep} "$optargs"); do
                          if [ "${key_value%%=*}" = "${optarg%%=*}" ]; then
                             matched=true
                             if [ ! "$_optargs" ]; then
                                _optargs="${key_value}${_arg_sep}${optarg#*=}"
                             elif must_1_be_added_to_2_using_3_as_separator "${optarg#*=}" "${_optargs#*=}" "$_arg_sep"; then
                                _optargs="${_optargs}${_key_value_sep}${key_value}${_arg_sep}${optarg#*=}"
                             fi
                          elif [ ! "$_optargs" ]; then
                             _optargs="$key_value"
                          else
                             _optargs="${_optargs}${_key_value_sep}${key_value}"
                          fi
                      done
                      ${matched} || _optargs="${_optargs}${_key_value_sep}${optarg}" ;;
                   *) if must_1_be_added_to_2_using_3_as_separator "$optarg" "$_optargs" "$_arg_sep"; then
                         _optargs="${optargs}${_arg_sep}${optarg}"
                      fi                                                             ;;
       esac
    fi
    printf "%s" "$_optargs"
}
# Brief
# Accumulate incremental option ${1} in ${__acc_opts} and, at the
# same time, its argument(s) in ${__${1}_arguments}.
accumulate_option_and_arguments() {
    local opt="$1" optarg="$2"
    if [ ! "$__acc_opts" ]; then
       __acc_opts="$opt"
    else
       local opt_code has_entry=false
       for opt_code in $(__split_tokens_accordingly ":" "$__acc_opts")
       do
           if [ "$opt_code" = "$opt" ]; then
              has_entry=true
              break
           fi
       done
       if ! ${has_entry}; then
          __acc_opts="${__acc_opts}:${opt}"
       fi
    fi
    eval "__${opt}_arguments=$(get_accumulated_argument_vector "$opt" "$optarg")"
}
#
accumulate_mandatory_option_and_arguments_if_necessary() {
    remove_entry_from_required_options_if_necessary "$__opt"
    if test "$(eval echo '$'__has_"${__opt}"_accumulator)" = "true"
    then
       accumulate_option_and_arguments "$__opt" "$__optarg"
       set_option_and_argument "" ""
    fi
}
# Brief
# Retrieve the first long alias for ${1} if ${1} does have aliases
# else return ${1}.
get_readable_option_name() {
    local alias="$(eval echo '$'__${1}_first_long_alias)"
    if [ "$alias" ]; then
       printf "%s" "--${alias}"
    else
       printf "%s" "-${1}"
    fi
}
# Brief
# Check whether ${1} conflicts with any previously scanned option.
has_conflicting_state() {
    eval "__has_opt_code_${1}_been_scanned=true"
    local opt conflicts="$(eval echo '$'__get_conflicting_options_with_"${1}")"
    if [ "$conflicts" ]; then
       for opt in $(__split_tokens_accordingly "," "$conflicts"); do
           if test "$(eval echo '$'__has_opt_code_"${opt}"_been_scanned)" = "true"
           then
              set_erroneous_option_and_argument "$__err_code_conflict_opt" "${opt}/${1}"
              alert_whenever "$__err_conflicting_option" "$(get_readable_option_name "$opt")" "$(get_readable_option_name "$1")"
              return 0
           fi
       done
    fi
    return 1
}
# Brief
# Enrich the existing conflicts base with two new conflicts involving
# ${1} and ${2}.
map_exclusive_options_pair() {
    local opt conflict conflicts
    for opt in ${1} ${2}; do
        if [ "$opt" = "$1" ]; then
           conflict="$2"
        else
           conflict="$1"
        fi
        conflicts="$(eval echo '$'__get_conflicting_options_with_"${opt}")"
        if conflicts="$(__append "$conflict" "$conflicts" ",")"; then
           eval "__get_conflicting_options_with_${opt}=${conflicts}"
        fi
    done
}
# Brief
# Set the index ($1) of the positional parameter from which the parsing
# is to be done.
argp_parse_set_index() {
    __optindex="$1"
    eval "${_callback_opt}index=${1}"
}
# Brief
# Build a valid option argument vector avoiding breaking spaces.
get_option_arguments() {
    local opt="$1" argument_type="$(eval echo '$'__"${1}"_argument_type)"
    if [ "$(eval echo '$'__has_${opt}_accumulator)" = "true" -a "$argument_type" -a ! "${argument_type##key-value*}" ]; then
       eval printf "%s" '$'__${opt}_arguments|sed "s/${_key_value_sep}/ /g"
    else
       eval printf "%s" '$'__${opt}_arguments
    fi
}
# Brief
# Parse incremental options with their arguments and set the callback
# state.
argp_parse_incremental_options() {
    if [ "$__acc_opts" ]; then
       set_callback_option_and_argument "@${__acc_opts%%:*}" "$(get_option_arguments "${__acc_opts%%:*}")"
       remove_entry_from_accumulated_options_if_necessary "${__acc_opts%%:*}"
       return 0
    fi
    return 1
}
# Brief
# Parse required/accumulated options with their arguments and set the
# callback state.
argp_parse_accumulated_options() {
    if [ "$_req_opts" ]; then
       if ${_exit_on_error}; then
           syserr  "$__err_required_option_not_invoked" "$(get_readable_option_name "${_req_opts%%,*}")"
           exit 1
       else
           set_callback_option_and_argument "$__err_code_expected_opt" "${_req_opts%%,*}"
           remove_current_entry_from_required_and_accumulated_options "${_req_opts%%,*}"
           return 0
       fi
    else
       argp_parse_incremental_options
    fi
}
# Brief
# Internal stateful parsing routine.
__argp_parse() {
    local r="$E_END_OF_PARSING"
    if [ ${__optindex} -eq 0 ]; then
       __optindex=1
       __optwrd=
       __acc_opts=
       _parsing_strategy="PERMUTE"
       __nonopt_argv=
       _case_sensitive=true
       _callback_opt=_opt
       _long_only=false
       _allow_posix_long_opt=false
       _exit_on_error=true
       _req_opts=
       _excl_opts=
       read_parser_configuration_arguments "$@"
       __noptindex="$?"
       init_option_mutators
       configure_parser || exit ${E_BAD_ARGS}
    fi
    #
    shift $((${__optindex} + ${__noptindex} - 1))
    if [ ${#} -ne 0 ]; then
       argp_parse_internal "$@"
       r="$?"
    fi
    argp_parse_set_index $((${__optindex} + ${r} % ${E_END_OF_PARSING}))
    #
    if [ ${r} -ge ${E_END_OF_PARSING} ]; then
       argp_parse_accumulated_options
       return
    fi
    #
    case "$__opt" in :|\?|^) ${_exit_on_error} && exit 1 ;; esac
    set_callback_option_and_argument "$__opt" "$__optarg"
    return 0
}
# Brief
# Reset the parser state internally.
__argp_parse_reset() {
    argp_parse_set_index 0
}
# Brief
# Build a readable option argument description.
get_printable_option_argument_description() {
    local arg_flag="$1" arg_type
    case "$arg_flag" in [1-2]@*) arg_type="${arg_flag#?@}"
                                 case "${arg_flag%%@*}" in
                                    1) arg_flag="<${arg_type}.arg>"          ;;
                                    2) arg_flag="<optional.${arg_type}.arg>" ;;
                                 esac ;;
                          [1-2]) arg_type="string"
                                 case "$arg_flag" in
                                    1) arg_flag="<${arg_type}.arg>"          ;;
                                    2) arg_flag="<optional.${arg_type}.arg>" ;;
                                 esac ;;
                              *) arg_type=""; arg_flag=""                    ;;
    esac
    printf "%s" "$arg_flag"
}
# Brief
# Build help output (printf) format
get_help_output_format() {
    local token opt_code opt_code_max_length="${#1}"
    local aliases alias_max_length="${#2}"
    local arg_flag arg_type arg_flag_max_length="${#3}"
    local desc desc_max_length="${#4}" unread
    local mainopts="${_main_opts}
__end_main_opts" IFS="
"
    local alternate pad
    for token in ${mainopts}; do
        if [ "$token" != "__end_main_opts" ]; then
           read_colon_separated_token "$token" 1 opt_code aliases arg_flag desc unread
           if [ "$unread" ]; then
              desc="${desc}:${unread}"
           fi
           if [ ${opt_code_max_length} -lt ${#opt_code} ]; then
              opt_code_max_length="${#opt_code}"
           fi
           if [ "$aliases" ]; then
              if [ ! "${aliases%%*!}" ]; then
                 pad=3
              else
                 pad=0
              fi
              IFS="|"
              for alternate in ${aliases}; do
                  alternate="$(strip_ending_option_symbol "$alternate")"
                  if [ ${alias_max_length} -lt $((${#alternate} + ${pad})) ]; then
                     alias_max_length=$((${#alternate} + ${pad}))
                  fi
              done
           fi
           arg_flag="$(get_printable_option_argument_description "$arg_flag")"
           if [ ${arg_flag_max_length} -lt ${#arg_flag} ]; then
              arg_flag_max_length="${#arg_flag}"
           fi
           if [ ${desc_max_length} -lt ${#desc} ]; then
              desc_max_length="${#desc}"
           fi
        else
           if [ ${opt_code_max_length} -eq 1 ]; then
              opt_code_max_length=2
           fi
           if [ ${alias_max_length} -ge ${#2} ]; then
              alias_max_length=$((${alias_max_length} + 2))
           fi
           printf "%%-${opt_code_max_length}s  %%-${alias_max_length}s  %%-${arg_flag_max_length}s  %%-${desc_max_length}s"
        fi
    done
}
# Brief
# Print a description of the available short/long options.
__argp_parse_opts_help() {
    local token opt_code aliases arg_flag arg_type desc unread IFS="
"
    local fmt="$(get_help_output_format short long argument description)\n"
    {
      printf "\n%s\n\n" "Help usage: ${__shell} [options] <arguments> with the following option(s):"
      for token in ${_main_opts}; do
         read_colon_separated_token "$token" 1 opt_code aliases arg_flag desc unread
         if [ "$unread" ]; then
            desc="${desc}:${unread}"
         fi
         if [ ${#opt_code} -eq 1 ]; then
            opt_code="-${opt_code}"
         else
            opt_code=""
         fi
         arg_flag="$(get_printable_option_argument_description "$arg_flag")"
         if [ "$aliases" ]; then
            if [ ! "${aliases%%*!}" ]; then
               (local alternate IFS="|"
                for alternate in ${aliases}; do
                    alternate="$(strip_ending_option_symbol "$alternate")"
                    printf "$fmt" "" "--no-${alternate}" "$arg_flag" "Similar to --no${alternate}, negate --${alternate}"
                done)
            else
               printf "$fmt" "$opt_code" "--$(strip_ending_option_symbol "$aliases")" "$arg_flag" "$desc"
            fi
         else
            printf "$fmt" "$opt_code" "" "$arg_flag" "$desc"
         fi
      done
      printf "\n"
    } >&2
}

