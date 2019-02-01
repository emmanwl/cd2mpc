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
#@(#) This is libconfigure, a makefile generator tool.
LIBCONFIGURE_VERSION=1.0

. "<__lib_dir__>/imports.sh" || exit ${E_IMPORT_FAILURE:=13}
__import_resource_or_fail "<__lib_dir__>/liboptparse.sh"

# Shell name
__shell="$(__get_shell_name "$0")"
# **
# * Implementation for the type interface.
# * @param ${1} the candidate string to check
# */
is_string() { __is_of_match "$1" "[[:print:]]+"; }
is_path() { __is_path "$1"; }
is_real_path() { realpath "$1" >/dev/null 2>&1; }
# Define options set.
options_set() {
    local options="r:resources-dir:1@real-path:Specify the directory where to look for *.sh and *rc files
                   I:install-dir:1@path:Specify the directory for installing found executables, *.sh resources
                   i:install@:1@real-path:Specify additively an executable shell to install in <install-dir>
                   t:test@:1@real-path:Specify additively an executable test to run in the test phase
                   c:dot-file:1@key-value-path:Install, as a dot-file, the file whose basename is <KEY> to the location denoted by <VALUE> within a key/value pair (<KEY>=<VALUE>)
                   s:search-replace:1@key-value:Specify a search/replacement pattern (<__KEY__>; is replaced by <VALUE>) within a key/value pair (<KEY>=<VALUE>)
                   m:man-page-dir:1@path:Specify the man page directory where to copy man pages
                   D:define@:1@key-value:Specify additively a key/value mapping within key/values (<KEY>=<VALUE1,VALUE2,...>)
                   v:version:0:Print version information and exit
                   h:help:0:Print help information and exit"
    printf "%s" "$options"
}
# **
# * Print version information.
# */
print_version() {
cat <<version >&2

This is ${__shell#\./} v${LIBCONFIGURE_VERSION}, a command-line tool that automates test/install/check/document
tasks for Shell projects.

The tool aims at testing/deploying Shell projects in a centralized way: it parses any flat collection of scripts
(*.sh) or configuration files (*rc) referencing parametrized paths to be valorized at configuration time.
When invoked, a makefile whose goals match those predefined test/install/check/document tasks is produced.

These resources are filtered so patterns like '<__KEY__>' are replaced with values communicated within the
--search-replace KEY=<VALUE> switch. '*rc' resources can be marked as dot-files within the special switch
--dot-file <KEY>=<VALUE> where <KEY> denotes the actual file basename (minus the leading '.') and <VALUE>
the targeted directory path.

Type ${__shell} -h for configuration options.

Example:

Given { script.sh, scriptrc, libscript1.sh, libscript2.sh, libscript1test.sh, libscript2test.sh, script.sh.manpage.gz },
the command: ${__shell} --resources-dir=. 
                         --install-dir ${HOME}/bin
                         --test libscript1test.sh
                         --test libscript2test.sh
                         --install script.sh
                         --dot-file scriptrc=${HOME}
                         --man-page-dir ${HOME}/.local/share/man
would generate a makefile from which:

- 'make install' will build the following file tree:
  {
    ~/bin/script.sh
    ~/.scriptrc
    ~/libscript/libscript1.sh
    ~/libscript/libscript2.sh
    ~/.local/share/man/man1/script.sh.manpage.gz
  }

- 'make check' would span a new shell to run shellcheck on script.sh in a best-effort mode

- 'make test' would spawn a new shell to run libscript1test.sh and libscript2test.sh

- 'make doc' would deploy script man page (script.sh.manpage.gz) to the man pages user directory

- 'make clean' would wipe out any created temporary resource before removing the makefile itself.

version
}
# **
# * Retrieve the first value associated to the given key.
# * @param ${1} the key to look for
# * @param ${2,} the remaining key/value associations
# * @print the value associated to the key in ${2,}
# * @return ${E_SUCCESS} if the key was found else ${E_FAILURE}
# */
get_key_value() {
    local key="$(__lowerize "$1")" entry value
    shift
    for entry in ${@}; do
        if [ "$(__lowerize "${entry%%=*}")" = "$key" ]; then
           for value in $(__split_tokens_accordingly "," "${entry#*=}"); do
               echo "$value"
           done
           return ${E_SUCCESS}
        fi
    done
    return ${E_FAILURE}
}
# **
# * Build a search/replace expression to use within source files to replace each key parameter with its value.
# * @param ${@} the whole argument vector
# * @print the search/replace expression
# */
source_replace_expression() {
    local entry expression
    for entry in ${@}; do
        if [ ! "${entry##__*__=*}" ]; then
           if [ "$expression" ]; then
              expression="${expression};s#<${entry%%=*}>#${entry#*=}#g"
           else
              expression="s#<${entry%%=*}>#${entry#*=}#g"
           fi
        fi
    done
    printf "%s" "${expression};s#/\{2,\}#/#g"
}
# **
# * Build a search/replace expression to use within test files to replace each key parameter with its value.
# * @param ${@} the whole argument vector
# * @print the search/replace expression
# */
test_replace_expression() {
    local entry expression wrkdir="$(get_key_value "WORKING_DIR" "$@")"
    for entry in ${@}; do
        if [ ! "${entry##__*__=*}" ]; then
           if [ "$expression" ]; then
              if [ ! "${entry##*\.*}" ]; then
                 expression="${expression};s#<${entry%%=*}>#${wrkdir}/test/${entry##*/\.}#g"
              else
                 expression="${expression};s#<${entry%%=*}>#${wrkdir}/test#g"
              fi
           elif [ ! "${entry##*\.*}" ]; then
              expression="s#<${entry%%=*}>#${wrkdir}/test/${entry##*/\.}#g"
           else
              expression="s#<${entry%%=*}>#${wrkdir}/test#g"
           fi
        fi
    done
    printf "%s" "${expression};s#/\{2,\}#/#g"
}
# **
# * Retrieve shell/rc filenames in the resource directory.
# * @param ${@} the whole argument vector
# * @param ${1} an option indicating whether to exclude or not test (*test.sh) files in the current lookup
# * @print the filenames matching either the mask *.sh or *rc
# */
list_files_accordingly() {
    local exclude_tests=false file test match=false
    local resources_dir="$(get_key_value "RESOURCES_DIR" "$@")"
    local tests="$(get_key_value "TEST" "$@")"
    case "$1" in
       --exclude-tests) exclude_tests=true; shift ;;
    esac
    for file in ${resources_dir}/*.sh ${resources_dir}/*rc; do
        if [ "$file" != "${resources_dir}/*.sh" -a "$file" != "${resources_dir}/*rc" ]; then
           match=false
           for test in ${tests}; do
               if [ "$test" = "$(basename "$file")" ]; then
                  match=true
                  break
               fi
           done
           if ${match}; then
              ${exclude_tests} || echo "$file"
           else
              echo "$file"
           fi
        fi
    done
}
# **
# * Copy resources to the target directory.
# * @param ${@} the whole argument vector
# */
copy_resources() {
    list_files_accordingly "$@" | xargs -I{} install -c -m 644 {} "$(get_key_value "TARGETDIR" "$@")"
}
# **
# * Copy source files, excluding tests *test.sh, to the target directory.
# * @param ${@} the whole argument vector
# */
copy_sources_only() {
    copy_resources --exclude-tests "$@"
}
# **
# * Copy source files, including tests, to the target directory.
# * @param ${@} the whole argument vector
# */
copy_resources_for_test() {
    copy_resources "$@"
}
# **
# * Edit in place source files to substitute specified patterns with their corresponding values.
# * @param ${@} the whole argument vector
# */
filter_sources() {
    local wrkdir="$(get_key_value "WORKING_DIR" "$@")" f k
    perl -i -pe "$(source_replace_expression "$@")" "${wrkdir}/install/"* 2>/dev/null
    for f in "${wrkdir}/install/"*; do
        if [ "$f" != "${wrkdir}/install/*" -a "$(basename "$f")" != "libconfigure.sh" ]; then
           k="$(perl -ne "print if s#.*<__(.*?)__>.*#\1#g" "$f" 2>/dev/null | head -n1)"
           if [ "$k" ]; then
              printf "configure.bootstrap:filter_sources failed: found at least one unresolved pattern: <__${k}__>; reconfigure with --search-replace ${k}=<VALUE>\n" >&2
              return ${E_FAILURE}
           fi
        fi
    done
    return ${E_SUCCESS}
}
# **
# * Edit in place test files to substitute specified patterns with their corresponding values.
# * @param ${@} the whole argument vector
# */
filter_tests() {
    local wrkdir="$(get_key_value "WORKING_DIR" "$@")" f k
    perl -i -pe "$(test_replace_expression "$@")" "${wrkdir}/test/"* 2>/dev/null
    for f in "${wrkdir}/test/"*; do
        if [ "$f" != "${wrkdir}/test/*" -a "$(basename "$f")" != "libconfigure.sh" ]; then
           k="$(perl -ne "print if s#.*<__(.*?)__>.*#\1#g" "$f" 2>/dev/null | head -n1)"
           if [ "$k" ]; then
              printf "configure.bootstrap:filter_tests failed: found at least one unresolved pattern: <__${k}__>; reconfigure with --search-replace ${k}=<VALUE>\n" >&2
              return ${E_FAILURE}
           fi
        fi
    done
    return ${E_SUCCESS}
}
# **
# * Print resources paths imported in filtered *.sh files
# * @param ${@} the whole argument vector
# * @print a list of paths, one per line
# */
print_imported_resources_paths() {
    local wrkdir="$(get_key_value "WORKING_DIR" "$@")"
    perl -ne "print if s#^[[:space:]]*(?:__import_resource_or_fail|\.)[[:space:]]+\"(.*?)\".*#\1#g" "${wrkdir}/install/"* 2>/dev/null | awk '!commands[$0]++'
}
# **
# * Evaluate paths, doing required search/replace patterns operations, before sorting them to uniqueness.
# * @param ${@} the whole argument vector
# * @print the evaluated paths, one per line, sorted to uniqueness
# */
render_paths() { sed "$(source_replace_expression "$@")" | sort -u ; }
# **
# * Build the target directory layout.
# * @param ${@} the whole argument vector
# */
install() {
    local wrkdir="$(get_key_value "WORKING_DIR" "$@")" resource install_dir="$(get_key_value "INSTALL_DIR" "$@")"
    #
    {
     print_imported_resources_paths "$@" | while read resource
     do 
         if [ -e "${wrkdir}/install/$(basename ${resource})" ]; then
            echo -m 755 -d "$(dirname ${resource})"
            echo -m 644 "${wrkdir}/install/$(basename ${resource})" "$resource"
         fi
     done
     for resource in $(get_key_value "INSTALL" "$@"); do
         echo -m 755 -d "$install_dir"
         if [ -e "$resource" ]; then
            echo -m 755 "${wrkdir}/install/${resource}" "${install_dir}/${resource%\.sh}"
	 fi
     done
     #
     local entry file
     for entry in ${@}; do
         if [ ! "${entry##__*rc__=*}" ]; then
            file="$(__trim_char "${entry%%=*}" "_")"
            if [ -e "$file" ];  then
               echo -m 755 -d "$(dirname "${entry##*=}")"
               echo -m 644 "${wrkdir}/install/${file}" "${entry##*=}"
	    fi
         fi
    done
    } | xargs -t -n4 install -c
}
# **
# * Install man pages in a directory, default is ~/.local/share/man.
# * @param ${@} the whole argument vector
# */
doc() {
    local man_page_dir="$(get_key_value "MAN_PAGE_DIR" "$@")"
    local shell shells="$(get_key_value "INSTALL" "$@")"
    if [ "$shells" ]; then
       for shell in ${shells}; do
           if [ -s "${shell}.manpage.gz" ]; then
              if [ ! -e "${man_page_dir:="${HOME}/.local/share/man"}/man1" ]; then
                 echo -m 755 -d "${man_page_dir}/man1"
              fi
              echo -m 644 "${shell}.manpage.gz" "${man_page_dir}/man1/${shell%\.sh}.1.gz"
           fi
       done | awk '!commands[$0]++' | xargs -t -n4 install -c
    fi
}
# **
# * Run linter checks against executable shells.
# * @param ${@} the whole argument vector
# */
check() {
    local wrkdir="$(get_key_value "WORKING_DIR" "$@")" value r
    if ! type shellcheck >/dev/null 2>&1; then
       printf "configure.bootstrap:check: a shell check was planed but shellcheck is not installed\n" >&2
    else
       for value in $(get_key_value "INSTALL" "$@"); do
           if [ -f "$value" ]; then
              shellcheck -x ${wrkdir}/install/${value}
              if [ ${r:=${?}} -ne 0 ]; then
                 printf "configure.bootstrap:check: shellcheck exited with status ${r} when processing ${value}\n" >&2
              fi
           fi
       done
    fi
    return ${r:=0}
}
# **
# * Generate launchers for all tests.
# * @param ${@} the whole argument vector
# */
generate_tests_launchers() {
    local wrkdir="$(get_key_value "WORKING_DIR" "$@")" value r
    for value in $(get_key_value "TEST" "$@"); do
        if [ -f "$value" ]; then
           printf "\t@printf \"Running tests in ${value}\\\n\"; sh ${wrkdir}/test/${value} || printf \"configure.bootstrap:test: Test ${value} failed\\\n\" >&2\n"
        fi
    done | sort -uR
}
# **
# * Generate in the current directory a makefile configured with user options.
# * @param ${@} the whole argument vector
# * @return 0 if the generated makefile is not empty else a non-zero value
# */
makefile() {
    local value resource basename associate
    {
      printf "# Generated by libconfigure version ${LIBCONFIGURE_VERSION}.\n"
      printf "CONFIGURE_ARGS = $@\n"
      printf "WORKING_DIR = "$(get_key_value "WORKING_DIR" "$@")"\n"
      printf "RESOURCES_DIR = "$(get_key_value "RESOURCES_DIR" "$@")"\n"
      printf "INSTALL_DIR = "$(get_key_value "INSTALL_DIR" "$@")"\n"
      printf "MAN_PAGE_DIR = "$(get_key_value "MAN_PAGE_DIR" "$@")"\n"
      printf "INSTALL = /usr/bin/install -c\n"
      printf "\n"
      printf "target:\n"
      printf "\t@\$(INSTALL) -d -m 755 \$(WORKING_DIR)\n"
      printf "\n"
      printf "bootstrap: target\n"
      printf "\t@sh -c '. ./bootstrap; bootstrap_libconfigure \$(WORKING_DIR) \$(CONFIGURE_ARGS)'\n"
      printf "\n"
      printf "install_directory: bootstrap\n"
      printf "\t@\$(INSTALL) -d -m 755 \$(WORKING_DIR)/install\n"
      printf "\n"
      printf "test_directory: bootstrap\n"
      printf "\t@\$(INSTALL) -d -m 755 \$(WORKING_DIR)/test\n"
      printf "\n"
      printf "copy_sources_only: install_directory\n"
      printf "\t@sh -c '. \$(WORKING_DIR)/libconfigure.sh; copy_sources_only TARGETDIR=\$(WORKING_DIR)/install \$(CONFIGURE_ARGS)'\n"
      printf "\n"
      printf "copy_resources_for_test: test_directory\n"
      printf "\t@sh -c '. \$(WORKING_DIR)/libconfigure.sh; copy_resources_for_test TARGETDIR=\$(WORKING_DIR)/test \$(CONFIGURE_ARGS)'\n"
      printf "\n"
      printf "copy: copy_sources_only copy_resources_for_test\n"
      printf "\n"
      printf "filter_sources: copy_sources_only\n"
      printf "\t@sh -c '. \$(WORKING_DIR)/libconfigure.sh; filter_sources \$(CONFIGURE_ARGS)'\n"
      printf "\n"
      printf "filter_tests: copy_resources_for_test\n"
      printf "\t@sh -c '. \$(WORKING_DIR)/libconfigure.sh; filter_tests \$(CONFIGURE_ARGS)'\n"
      printf "\n"
      printf "filter: filter_sources filter_tests\n"
      printf "\n"
      printf "check: filter_sources\n"
      printf "\t@sh -c '. \$(WORKING_DIR)/libconfigure.sh; check \$(CONFIGURE_ARGS)'\n"
      printf "\n"
      printf "test: filter_tests\n"
      generate_tests_launchers "$@"
      printf "\n"
      printf "doc:\n"
      printf "\t@sh -c '. \$(WORKING_DIR)/libconfigure.sh; doc \$(CONFIGURE_ARGS)'\n"
      printf "\n"
      printf "install: filter_sources doc\n"
      printf "\t@sh -c '. \$(WORKING_DIR)/libconfigure.sh; install \$(CONFIGURE_ARGS)'\n"
      printf "\n"
      printf "clean:\n"
      printf "\t@rm -rf makefile \$(WORKING_DIR)\n"
    } > makefile 2>/dev/null
    test -s makefile 2>/dev/null
}
# **
# * Parse command line arguments.
# * @print a vector holding user configured options
# */
parse_options() {
    local argv
    while __opt_parse /options="$(options_set)" /trim-option-arguments-to-uniqueness /callback-option-prefix=_opt /required-options="r,I,i" "$@"
    do
        case "$_opt" in
                    r) __accumulate_once "RESOURCES_DIR=$(realpath "$_optarg")" argv             ;;
                    I) __accumulate_once "INSTALL_DIR=${_optarg}" argv                           ;;
                  \@i) __accumulate_once "INSTALL=${_optarg}" argv                               ;;
                  \@t) __accumulate_once "TEST=${_optarg}" argv                                  ;;
                    c) __accumulate_once "__${_optarg%%=*}__=${_optarg#*=}/.${_optarg%%=*}" argv ;;
                    s) __accumulate_once "__${_optarg%%=*}__=${_optarg#*=}" argv                 ;;
                    m) __accumulate_once "MAN_PAGE_DIR=${_optarg}" argv                          ;;
                  \@D) __accumulate_once "$_optarg" argv                                         ;;
                    h) __opt_parse_opts_help
                       return ${E_END_OF_PARSING}                                                ;;
                    v) print_version
                       return ${E_END_OF_PARSING}                                                ;;
        esac
    done
    printf "%s" "$argv"
}
# **
# * Script payload.
# * @param ${@} the whole argument vector
# * @return ${E_SUCCESS} if called with a terminal option (-h, -v or alternatively --help, --version) or if the makefile was properly generated, else ${E_FAILURE}
# */
__configure () {
    local argv r
    argv="$(parse_options "$@")"
    if [ ${r:=${?}} -eq ${E_END_OF_PARSING} ]; then
       return ${E_SUCCESS}
    elif [ ${r} -ne ${E_SUCCESS} ]; then
       return ${E_FAILURE}
    elif ! makefile "$argv"; then
       printf "Configure failed: could not generate makefile.\n" >&2
       return ${E_FAILURE}
    fi
    return ${E_SUCCESS}
}

