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
#@(#) This is libopt4test, a test suite for the libopt4shell API.

. "<__libtools__>/imports.sh" 2>/dev/null
__import_resource_or_fail "<__libdir__>/libopt4shell.sh"
__import_resource_or_fail "<__libdir__>/liblog4shell.sh" --file-appender=/dev/null

# Shell name
__shell="${0##*/}"
# Brief
# Implementation for the type interface.
is_string() { __is_of_match "$1" "[[:print:]]+"; }
is_path() { __is_path "$1"; }
is_binary() { type "$1" >/dev/null 2>&1; }
is_integer() { test "$1" -eq "$1" 2>/dev/null; }
#
# Brief
# Test options set.
__err_negatable_option_definition_set() {
    local options="-m,u::0:
                   m:max!:1@integer:
                   X:extreme:0:
                   s:selection:1:
                   d:device:1:
                   t:template:1@path:
                   f:file@:1:
                   V:verbose!:0:
                   v:version:0:
                   h:help:0:"
    printf "%s" "$options"
}
#
__err_incremental_option_definition_set() {
    local options="-m,u::0:
                   m:max@:0:
                   X:extreme:0:
                   s:selection:1:
                   d:device:1:
                   t:template:1@path:
                   f:file@:1:
                   V:verbose!:0:
                   v:version:0:
                   h:help:0:"
    printf "%s" "$options"
}
#
__err_missing_type_check_function_set() {
    local options="float,u::0:
                   m:max@:1@float:
                   X:extreme:0:
                   s:selection:1:
                   d:device:1:
                   t:template:1@path:
                   f:file@:1:
                   V:verbose!:0:
                   v:version:0:
                   h:help:0:"
    printf "%s" "$options"
}
#
#
__err_duplicate_option_entry_set() {
    local options="m,u::0:
                   m:max@:1@integer:
                   m:max@:1@integer:
                   X:extreme:0:
                   s:selection:1:
                   d:device:1:
                   t:template:1@path:
                   f:file@:1:
                   V:verbose!:0:
                   v:version:0:
                   h:help:0:"
    printf "%s" "$options"
}
#
__options_set() {
    local options="u::0:
                   m:max@:1@integer:
                   X:extreme:0:
                   s:selection:1:
                   d:device:1:
                   t:template:1@path:
                   f:file@:1:
                   c:config:1@key-value-path:
                   V:verbose!:0:
                   v:version:0:
                   h:help:0:"
    printf "%s" "$options"
}
# Brief
# Convenient functions for emulating multiple consecutive calls.
___run_argp_parse_a_certain_number_of_times() {
    local arg run_once=false r=0
    for arg; do
       case "$arg" in /run-once) run_once=true; break ;; esac
    done
    while :; do
        __argp_parse "$@"
        r=${?}
        if [ ${r} -ne 0 -o "$run_once" = "true" ]; then
           break
        fi
    done
    return ${r}
}
#
__run_argp_parse() {
    ___run_argp_parse_a_certain_number_of_times /long-only \
                                                /run-once \
                                                /callback-option-prefix=_test "$@" 2>&1
}
__run_argp_parse_repeatedly() {
    ___run_argp_parse_a_certain_number_of_times /long-only \
                                                /callback-option-prefix=_test "$@" 2>&1
}
# Test launcher
__should_report_the_following() {
    local test_name="should_report_${1}" test_data="$2" error_message="$3"
    local expected="$(printf "$error_message" "${test_data%%,*}")" stdout
    stdout="$(__run_argp_parse_repeatedly "/options=${test_data#*,}")"
    if [ ! "${stdout%%*"${expected}"}" -a ${?} -eq ${E_BAD_ARGS} ]; then
       logger_unconditionally "test ${test_name} succeeds"
    else
       logger_error "test ${test_name} failed: expecting the test to report \`${expected}' but actual/error was \`${stdout}'"
       return 1
    fi
}
#
__should_report_wrong_negatable_option_definition_test() {
    __should_report_the_following "wrong_negatable_option_definition" "$(__err_negatable_option_definition_set)" "$__err_negatable_option_definition"
}
__should_report_wrong_incremental_option_definition_test() {
    __should_report_the_following "wrong_incremental_option_definition" "$(__err_incremental_option_definition_set)" "$__err_incremental_option_definition"
}
__should_report_missing_type_check_function_test() {
    __should_report_the_following "missing_type_check_function" "$(__err_missing_type_check_function_set)" "$__err_missing_type_check_function"
}
#
__should_build_optstring_accordingly_test() {
    local test_name=should_build_optstring_accordingly
    local expected="um:Xs:d:t:f:c:Vvh"
    local stdout
    stdout="$(__run_argp_parse_repeatedly /options="$(__options_set)"
              if [ "$__optstring" != "$expected" ]; then
                 echo "$__optstring"
                 return 1
              fi)"
    case "$?" in
       0) logger_unconditionally "test ${test_name} succeeds" ;;
       1) logger_error "test ${test_name} failed: expecting the short option string to be \`${expected}' but actual was \`${stdout}'"
          return 1 ;;
       *) logger_error "${test_name}: \`${stdout#*[[:space:]]}'"
          return 1 ;;
    esac
}
#
__should_report_illegal_options_test() {
    local test_name=should_report_illegal_options
    local expected="$(printf "$__err_unrecognized_option" "-z")"
    local r stdout
    stdout="$(__run_argp_parse_repeatedly /options="$(__options_set)" -z)"
    case "${r:="${?}"}" in
       1) if [ ! "${stdout%%*"${expected}"}" ]; then
             logger_unconditionally "test ${test_name} (short) succeeds"
          else
             logger_error "test ${test_name} failed: expecting the error string to contain \`${expected}' but actual error string was \`${stdout}'"
             return 1
          fi ;;
       *) logger_error "test ${test_name} failed: expecting the exit code to be \`1' but actual/error was \`${r}': ${stdout}"
          return 1 ;;
    esac
    #
    expected="$(printf "$__err_unrecognized_option" "--random")"
    stdout="$(__run_argp_parse_repeatedly /options="$(__options_set)" --random)"
    r="$?"
    case "$r" in
       1) if [ ! "${stdout%%*"${expected}"}" ]; then
             logger_unconditionally "test ${test_name} (long) succeeds"
          else
             logger_error "test ${test_name} failed: expecting the error string to contain \`${expected}' but actual error string was \`${stdout}'"
             return 1
          fi ;;
       *) logger_error "test ${test_name} failed: expecting the exit code to be \`1' but actual/error was \`${r}': ${stdout}"
          return 1 ;;
    esac
}
#
__should_report_missing_option_argument_test() {
    local test_name=should_report_missing_option_argument
    local expected="$(printf "$__err_required_option_argument" "-m")"
    local r stdout
    stdout="$(__run_argp_parse_repeatedly /options="$(__options_set)" -m)"
    case "${r:="${?}"}" in
       1) if [ ! "${stdout%%*"${expected}"}" ]; then
             logger_unconditionally "test ${test_name} succeeds"
          else
             logger_error "test ${test_name} failed: expecting the error string to contain \`${expected}' but actual error string was \`${stdout}'"
             return 1
          fi ;;
       *) logger_error "test ${test_name} failed: expecting the exit code to be \`1' but actual/error was \`${r}': ${stdout}"
          return 1 ;;
    esac
}
#
__should_report_conflicting_options_test() {
    local test_name=should_report_conflicting_options
    local expected="$(printf "$__err_conflicting_option" "-d" "-f")"
    local r stdout
    stdout="$(__run_argp_parse_repeatedly /options="$(__options_set)" /exclusive-options="d,f" -d /d/a -f /t/f)"
    case "${r:="${?}"}" in
       1) if [ ! "${stdout%%*"${expected}"}" ]; then
             logger_unconditionally "test ${test_name} succeeds"
          else
             logger_error "test ${test_name} failed: expecting the error string to contain \`${expected}' but actual error string was \`${stdout}'"
             return 1
          fi ;;
       *) logger_error "test ${test_name} failed: expecting the exit code to be \`1' but actual/error was \`${r}': ${stdout}"
          return 1 ;;
     esac
}
#
__should_report_required_options_declared_as_exclusive_from_one_another_test() {
    local test_name=should_report_required_options_declared_as_exclusive_from_one_another
    local r stdout expected="$(printf "$__err_required_and_exclusive_option_definition" "-f" "-d")"
    stdout="$(__run_argp_parse_repeatedly /options="$(__options_set)" /exclusive-options="t,d,f" /required-options="f,d" -d /d/a)"
    case "${r:="${?}"}" in
       0) logger_error "test ${test_name} failed: expecting the exit code to be a non zero value"
          return 1 ;;
       *) if [ ! "${stdout%%*"${expected}"}" -a ${r} -eq ${E_BAD_ARGS} ]; then
             logger_unconditionally "test ${test_name} succeeds"
          else
             logger_error "test ${test_name} failed: expecting the exit code to be \`${E_BAD_ARGS}' and the error string to be \`${expected}' but actual was \`${r}' and \`${stdout}' respectively"
             return 1
          fi ;;
     esac
}
#
__should_parse_required_options_test() {
    local test_name=should_parse_required_options
    local expected="$(printf "$__err_required_option_not_invoked" "-f")"
    local r stdout
    stdout="$(__run_argp_parse_repeatedly /options="$(__options_set)" /required-options="f" -d /d/a)"
    case "${r:="${?}"}" in
       1) if [ ! "${stdout%%*"${expected}"}" ]; then
             logger_unconditionally "test ${test_name} succeeds"
          else
             logger_error "test ${test_name} failed: expecting the error string to contain \`${expected}' but actual error string was \`${stdout}'"
             return 1
          fi ;;
       *) logger_error "test ${test_name} failed: expecting the exit code to be \`1' but actual/error was \`${r}': ${stdout}"
          return 1 ;;
    esac
}
#
__should_parse_incremental_options_test() {
    local test_name=should_parse_incremental_options
    local expected_arguments="/d/a,/d/b,/d/c"
    local expected_option_code="@f"
    local stdout
    stdout="$(__run_argp_parse_repeatedly /options="$(__options_set)" -f /d/a -f /d/b -f /d/c
              case "$_test" in
                 @f) echo "$_testarg" ;;
                  *) echo "$_test"
                     return 1 ;;
              esac)"
    case "$?" in
       0) if [ "$stdout" = "$expected_arguments" ]; then
             logger_unconditionally "test ${test_name} succeeds"
          else
             logger_error "test ${test_name} failed: expecting to get \`${expected_arguments}' but got \`${stdout}'"
             return 1
          fi ;;
       1) logger_error "test ${test_name} failed: expecting the returned option code to be \`${expected_option_code}' but actual was \`${stdout}'"
          return 1 ;;
       *) logger_error "${test_name}: \`${stdout#*[[:space:]]}'"
          return 1 ;;
    esac
 }
 #
__should_parse_multiple_option_arguments_test() {
    local test_name=should_parse_multiple_option_arguments
    local expected_arguments="/d/a#/d/b#/d/c#/d/d"
    local expected_option_code="@f"
    local stdout
    stdout="$(__run_argp_parse_repeatedly /options="$(__options_set)" /argument-separator="#" -f "/d/a" -f "/d/b" -f "/d/c" -f "/d/d"
              case "$_test" in
                 @f) echo "$_testarg" ;;
                  *) echo "$_test"
                     return 1 ;;
              esac)"
    case "$?" in
       0) if [ "$stdout" = "$expected_arguments" ]; then
             logger_unconditionally "test ${test_name} succeeds"
          else
             logger_error "test ${test_name} failed: expecting to get \`${expected_arguments}' but got \`${stdout}'"
             return 1
          fi ;;
       1) logger_error "test ${test_name} failed: expecting the returned option code to be \`${expected_option_code}' but actual was \`${stdout}'"
          return 1 ;;
       *) logger_error "${test_name}: \`${stdout#*[[:space:]]}'"
          return 1;;
    esac
}
#
__should_parse_negatable_options_test() {
    local test_name=should_parse_negatable_options
    local expected_option_code="!V"
    local stdout
    stdout="$(__run_argp_parse_repeatedly /options="$(__options_set)" --no-verbose
              if [ "$_test" != "$expected_option_code" ]; then
                 echo "$_test"
                 return 1
              fi)"
    case "$?" in
       0) logger_unconditionally "test ${test_name} (first form) succeeds" ;;
       1) logger_error "test ${test_name} failed: expecting the returned option code to be \`${expected_option_code}' but actual was \`${stdout}'"
          return 1 ;;
       *) logger_error "${test_name} (first form): \`${stdout#*[[:space:]]}'"
          return 1 ;;
    esac
    #
    stdout="$(__run_argp_parse_repeatedly /options="$(__options_set)" --noverbose
              if [ "$_test" != "$expected_option_code" ]; then
                 echo "$_test"
                 return 1
              fi)"
    case "$?" in
       0) logger_unconditionally "test ${test_name} (second form) succeeds" ;;
       1) logger_error "test ${test_name} failed: expecting the returned option code to be \`${expected_option_code}' but actual was \`${stdout}'"
          return 1 ;;
       *) logger_error "${test_name} (second form): \`${stdout#*[[:space:]]}'"
          return 1 ;;
    esac
}
#
__should_parse_options_performing_case_insensitive_comparison_test() {
    local test_name=should_parse_options_performing_case_insensitive_comparison
    local expected_option_code="s"
    local expected_argument="/d/a"
    local stdout
    stdout="$(__run_argp_parse_repeatedly /options="$(__options_set)" /case-insensitive --SeLeCtIoN /d/a
              case "$_test" in
                 s) if [ "$_testarg" != "$expected_argument" ]; then
                       echo "$_testarg"
                       return 1
                    fi ;;
                 *) echo "$_test"
                    return 2 ;;
              esac)"
    case "$?" in
       0) logger_unconditionally "test ${test_name} succeeds" ;;
       1) logger_error "test ${test_name} failed: expecting the callback option argument to be \`${expected_argument}' but actual was \`${stdout}'"
          return 1 ;;
       2) logger_error "test ${test_name} failed: expecting the returned option code to be \`${expected_option_code}' but actual was \`${stdout}'"
          return 1 ;;
       *) logger_error "${test_name}: \`${stdout#*[[:space:]]}'"
          return 1 ;;
    esac
}
#
__should_report_abbreviated_options_test() {
    local test_name=should_report_abbreviated_options
    local expected_option_code="s"
    local expected_argument="/d/a"
    local stdout
    stdout="$(__run_argp_parse_repeatedly /options="$(__options_set)" /case-insensitive -sel=/d/a
              case "$_test" in
                 s) if [ "$_testarg" != "$expected_argument" ]; then
                       echo "$_testarg"
                       return 1
                    fi ;;
                 *) echo "$_test"
                    return 2 ;;
              esac)"
    case "$?" in
       0) logger_unconditionally "test ${test_name} succeeds" ;;
       1) logger_error "test ${test_name} failed: expecting the callback option argument to be \`${expected_argument}' but actual was \`${stdout}'"
          return 1 ;;
       2) logger_error "test ${test_name} failed: expecting the returned option code to be \`${expected_option_code}' but actual was \`${stdout}'"
          return 1 ;;
       *) logger_error "${test_name}: \`${stdout#*[[:space:]]}'"
          return 1 ;;
    esac
}
#
__should_parse_posix_long_options_test() {
    local test_name=should_parse_posix_long_options
    local expected_option_code="d"
    local expected_argument="/d/a"
    local stdout
    stdout="$(__run_argp_parse_repeatedly /options="$(__options_set)" /allow-posix-long-option -W device=/d/a
              case "$_test" in
                 d) if [ "$_testarg" != "$expected_argument" ]; then
                       echo "$_testarg"
                       return 1
                    fi ;;
                 *) echo "$_test"
                    return 2 ;;
              esac)"
    case "$?" in
       0) logger_unconditionally "test ${test_name} succeeds" ;;
       1) logger_error "test ${test_name} failed: expecting the callback option argument to be \`${expected_argument}' but actual was \`${stdout}'"
          return 1 ;;
       2) logger_error "test ${test_name} failed: expecting the returned option code to be \`${expected_option_code}' but actual was \`${stdout}'"
          return 1 ;;
       *) logger_error "${test_name}: \`${stdout#*[[:space:]]}'"
          return 1 ;;
    esac
}
#
__should_parse_multiple_posix_long_options_test() {
    local test_name=should_parse_multiple_posix_long_options
    local expected_option_codes="1, d, t, X, u, V, m or s"
    local expected_arguments="/d/a /tmp, 1 or 1-3"
    local expected_index="23"
    local stdout
    stdout="$(while __run_argp_parse /case-insensitive /parsing-strategy="RETURN_IN_ORDER" /do-not-exit-on-error /options="$(__options_set)" /allow-posix-long-option -Wdevice=/d/a -W template=/tmp first second -W selection=1 third -Wselection=1 first -Wsele=1 -W templ=/tmp -X -VVVV first -u -W sElE=1 first -W S=1; do
                    case "$_test" in
                X|u|V|1) ;;
                      d) if [ "${_testarg##/d/a*}" ]; then
                            echo "$_testarg"
                            return 1
                         fi ;;
                      t) if [ "$_testarg" != "/tmp" ]; then
                            echo "$_testarg"
                            return 1
                         fi ;;
                      s) if [ "$_testarg" != "1" -a "$_testarg" ]; then
                            echo "$_testarg"
                            return 1
                         fi ;;
                      *) echo "$_test"
                         return 2 ;;
                    esac
              done
              echo "$_testindex")"
    case "$?" in
       0) if [ ${stdout} -eq ${expected_index} ]; then
             logger_unconditionally "test ${test_name} succeeds"
          else
             logger_error "test ${test_name} failed: expecting the option index to be \`${expected_index}' but actual was \`${stdout}'"
             return 1
          fi ;;
       1) logger_error "test ${test_name} failed: expecting the callback option argument to be \`${expected_arguments}' but actual was \`${stdout}'"
          return 1 ;;
       2) logger_error "test ${test_name} failed: expecting the returned option code to be \`${expected_option_codes}' but actual was \`${stdout}'"
          return 1 ;;
       *) logger_error "${test_name}: \`${stdout#*[[:space:]]}'"
          return 1 ;;
    esac
}
#
__should_report_ambiguous_options_test() {
    local test_name=should_report_ambiguous_options
    local expected="$(printf "$__err_ambiguous_option" "--ver")"
    local r stdout
    stdout="$(__run_argp_parse_repeatedly /options="$(__options_set)" --ver)"
    case "${r:="${?}"}" in
       1) if [ ! "${stdout%%*"${expected}"}" ]; then
             logger_unconditionally "test ${test_name} succeeds"
          else
             logger_error "test ${test_name} failed: expecting the error string to contain \`${expected}' but actual error string was \`${stdout}'"
             return 1
          fi ;;
       0) logger_error "test ${test_name} failed: expecting the exit code to be \`1' but actual was \`${r}'"
          return 1 ;;
       *) logger_error "${test_name}: \`${stdout#*[[:space:]]}'"
          return 1 ;;
    esac
}
#
__should_permute_non_option_arguments_test() {
    local test_name=should_permute_non_option_arguments
    local expected_arguments="first second third"
    local expected_index="8"
    local r stdout
    stdout="$(local s
              __run_argp_parse_repeatedly /options="$(__options_set)" /parsing-strategy="PERMUTE" -u first second -d /d/a third -- four
              case "${s:="${?}"}" in
                 1) if [ "${__nonopt_argv}/${_testindex}" != "${expected_arguments}/${expected_index}" ]; then
                       echo "${__nonopt_argv}/${_testindex}"
                       return 1
                    fi ;;
                 *) echo "$s"
                    return 2 ;;
              esac)"
    case "${r:="${?}"}" in
       0) logger_unconditionally "test ${test_name} succeeds" ;;
       1) logger_error "test ${test_name} failed: expecting the non-option arguments/current option index to be \`${expected_arguments}/${expected_index}' but actual was \`${stdout}'"
          return 1 ;;
       2) logger_error "test ${test_name} failed: expecting the exit code to be \`1' but actual was \`${r}'"
          return 1 ;;
       *) logger_error "${test_name}: \`${stdout#*[[:space:]]}'"
          return 1 ;;
    esac
}
#
__should_return_non_option_arguments_in_order_test() {
    local test_name=should_return_non_option_arguments_in_order
    local expected_arguments="first second third"
    local r stdout
    stdout="$(local arg args s
              while __run_argp_parse /options="$(__options_set)" /parsing-strategy="RETURN_IN_ORDER" -u first second -d /d/a third -- four; do
                    case "$_test" in
                      1) if [ "$args" ]; then
                            args="${args} ${_testarg}"
                         else
                            args="$_testarg"
                         fi ;;
                    u|d) continue ;;
                      *) return 2 ;;
                   esac
              done
              if [ "$args" != "$expected_arguments" ]; then
                 echo "$args"
                 return 1
              fi)"
    case "${r:="${?}"}" in
       0) logger_unconditionally "test ${test_name} succeeds" ;;
       1) logger_error "test ${test_name} failed: expecting the non-option arguments to be \`${expected_arguments}' but actual was \`${stdout}'"
          return 1 ;;
       2) logger_error "test ${test_name} failed: expecting the exit code to be \`0' but actual was \`${r}'"
          return 1 ;;
       *) logger_error "${test_name}: \`${stdout#*[[:space:]]}'"
          return 1 ;;
    esac
}
#
__should_stop_parsing_non_option_arguments_when_requiring_order_test() {
    local test_name=should_stop_parsing_non_option_arguments_when_requiring_order
    local expected_arguments="first second third"
    local expected_index="2"
    local r stdout
    stdout="$(local arg args s
              __run_argp_parse_repeatedly /options="$(__options_set)" /parsing-strategy="REQUIRE_ORDER" -u first second -d /d/a third -- four
              case "$_test" in
                 u) if [ ${_testindex} -ne ${expected_index} ]; then
                       echo "$_testindex"
                       return 1
                    fi ;;
                 *) return 2 ;;
              esac)"
    case "${r:="${?}"}" in
       0) logger_unconditionally "test ${test_name} succeeds" ;;
       1) logger_error "test ${test_name} failed: expecting the option parsing index to be \`${expected_index}' but actual was \`${stdout}'"
          return 1 ;;
       2) logger_error "test ${test_name} failed: expecting the exit code to be \`0' but actual was \`${r}'"
          return 1 ;;
       *) logger_error "${test_name}: \`${stdout#*[[:space:]]}'"
          return 1 ;;
    esac
}
#
__should_report_invalid_regular_option_argument_type_test() {
    local test_name=should_report_invalid_regular_option_argument_type
    local expected="$(printf "$__err_invalid_option_argument_type" "-m" "integer" "string")"
    local r stdout
    stdout="$(__run_argp_parse_repeatedly /options="$(__options_set)" /argument-separator="%" -m123 -m string)"
    case "${r:="${?}"}" in
       1) if [ ! "${stdout%%*"${expected}"}" ]; then
             logger_unconditionally "test ${test_name} succeeds"
          else
             logger_error "test ${test_name} failed: expecting the error string to contain \`${expected}' but actual error string was \`${stdout}'"
             return 1
          fi ;;
       0) logger_error "test ${test_name} failed: expecting the exit code to be \`1' but actual was \`${r}'"
          return 1 ;;
       *) logger_error "${test_name}: \`${stdout#*[[:space:]]}'"
          return 1 ;;
    esac
}
#
__should_report_invalid_key_value_option_argument_type_test() {
    local test_name=should_report_invalid_key_value_option_argument_type
    local expected="$(printf "$__err_invalid_option_argument_type" "-c" "key-value-path" "key=value")"
    local r stdout
    stdout="$(__run_argp_parse_repeatedly /options="$(__options_set)" /argument-separator="%" -c key=value)"
    case "${r:="${?}"}" in
       1) if [ ! "${stdout%%*"${expected}"}" ]; then
             logger_unconditionally "test ${test_name} succeeds"
          else
             logger_error "test ${test_name} failed: expecting the error string to contain \`${expected}' but actual error string was \`${stdout}'"
             return 1
          fi ;;
       0) logger_error "test ${test_name} failed: expecting the exit code to be \`1' but actual was \`${r}'"
          return 1 ;;
       *) logger_error "${test_name}: \`${stdout#*[[:space:]]}'"
          return 1 ;;
    esac
}
#
__should_parse_mixed_long_and_short_options_test() {
    local test_name=should_parse_mixed_long_and_short_options
    local expected_index="37"
    local r stdout
    stdout="$(while __run_argp_parse /options="$(__options_set)" /argument-separator="%" /parsing-strategy="RETURN_IN_ORDER" -u first -X -d /d/a first -max 12 -t ~ first -m78 -u first -X -d /d/a first -max 34 -t ~ first -m78 -u first -X -d /d/a first -max 56 -t ~ first -m78; do
                    case "$_test" in
                    u|X) ;;
                      1) if [ "${_testarg##first*}" ]; then
                            return 1
                         fi ;;
                      d) if [ "${_testarg##/d/a*}" ]; then
                            return 1
                         fi ;;
                     @m) if [ "${_testarg##12%78%34%78%56%78*}" ]; then
                            return 1
                         fi ;;
                      t) if [ "$_testarg" != ~ ]; then
                            return 1
                         fi ;;
                      *) if [ "$_test" -o "$_testarg" ]; then
                            return 1
                         fi ;;
                    esac
              done
              echo "$_testindex")"
    case "${r:="${?}"}" in
       0) if [ ${stdout} -eq ${expected_index} ]; then
             logger_unconditionally "test ${test_name} succeeds"
          else
             logger_error "test ${test_name} failed: expecting the option index to be \`${expected_index}' but actual was \`${stdout}'"
             return 1
          fi ;;
       1) logger_error "test ${test_name} failed: expecting the exit code to be \`0' but actual was \`${r}'"
          return 1 ;;
       *) logger_error "${test_name}: \`${stdout#*[[:space:]]}'"
          return 1 ;;
    esac
}
# Brief
# Run randomly all test functions defined here: functions whose
# name start with "__should_" and end with "_test".
__run_test_suite_randomly() {
    local test has_failed=false
    for test in $(__entry_points --prefix=__should_ --suffix=_test --randomly --file="libopt4test.sh"); do
        if ! eval ${test}; then
           has_failed=true
        fi
    done
    ${has_failed} && return 1 || return 0
}

__run_test_suite_randomly
