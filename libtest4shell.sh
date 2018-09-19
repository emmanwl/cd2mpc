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
#@(#) This is libtest4shell, a shell script library for testing.

. "<__lib_dir__>/imports.sh" || exit ${E_IMPORT_FAILURE:=13}
__import_resource_or_fail "<__lib_dir__>/lib4shell.sh"
__import_resource_or_fail "<__lib_dir__>/liblog4shell.sh" --file-appender=/dev/null

# Shell name
__shell="$(__get_shell_name "$0")"
# Brief
# Convenient routine for emulating multiple consecutive function calls.
__call_function_a_certain_number_of_times() {
    local arg run_once=false f r=0
    for arg; do
        case "$arg" in /run-once) run_once=true ;;
                     /function=*) f="${arg#*=}" ;;
        esac
    done
    if ! type "$f" >/dev/null 2>&1; then
       logger_error "Function ${f} was not defined in current env, exiting."
       return ${E_END_OF_PARSING}
    fi 
    while :; do
	"$f" "$@"
        r=${?}
        if [ ${r} -ne 0 -o "$run_once" = "true" ]; then
           break
        fi
    done
    return ${r}
}
# Brief
# Run randomly all test functions defined in ${1}: functions whose name
# starts with "__should_" and ends with "_test".
__run_test_suite_randomly() {
    local test has_failed=false
    for test in $(__entry_points --prefix=should_ --suffix=_test --randomly --file="$1"); do
        if ! eval ${test}; then
           has_failed=true
        fi
    done
    ${has_failed} && return ${E_FAILURE} || return ${E_SUCCESS}
}
