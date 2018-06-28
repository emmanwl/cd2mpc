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
#@(#) This is liboptwrapper, a wrapper for the libopt4shell API. It exposes the API entry points and
#@(#) provides the user with an extra indirection level for extending the default parsing behaviour.
#@(#) It's POSIX compliant providing POSIXLY_CORRECT is non-zero.

. "<__libtools__>/imports.sh" 2>/dev/null
__import_resource_or_fail "<__libdir__>/libopt4shell.sh"

# Mutators
__look_for_parsing_extensions=true
# Brief
# Main parser point of entry.
argp_parse() {
    local arg
    if ${__look_for_parsing_extensions}; then
       for arg; do
           if [ ! "${arg##/*}" ]; then
              case "${arg#/}" in
              help|\?) argp_parse_help
                       return 1 ;;
              esac 2>/dev/null
           else
              break
           fi
       done
       __look_for_parsing_extensions=false
    fi
    __argp_parse "$@"
}
# Brief
# Reset the whole parsing context
# so argp_parse can be reentrant.
argp_parse_reset() {
    __look_for_parsing_extensions=true
    __argp_parse_reset
}
# Brief
# Configured parser usage.
argp_parse_opts_help() {
    __argp_parse_opts_help
}
# Brief
# General parser usage.
argp_parse_help() {
less <<__help_information

This embeds libopt4shell, a shell API for parsing command line parameters. It handles
short/long options and features, noticeably, option bundling, option abbreviation to
uniqueness, option aliasing and argument type checking.

argp_parse accepts the following switches:
  - /options=<...>                 (mandatory): to set the options table
  - /callback-option-prefix=<...>  (optional) : to override the prefix of the
                                                place holders tracking the
						option/argument(s) currently 
						scanned, default is _opt
  - /parsing-strategy=<...>        (optional) : to set the parsing strategy,
                                                default is PERMUTE
  - /case-insensitive              (optional) : to allow the matching of long
                                                options independently from their
                                                case, default is case sensitive
  - /do-not-exit-on-error          (optional) : to handle parsing errors manually
                                                and not necessarily in a terminal
                                                way, see the example below
  - /long-only                     (optional) : to treat options prefixed with a
                                                single dash as regular long
                                                options (prefixed with a double dash)
  - /allow-posix-long-option       (optional) : to let the parser recognize:
                                                -W foo=bar and -Wfoo=bar as
                                                --foo=bar, foo denoting a
                                                mandatory option argument
  - /required-options=<...>        (optional) : to specify a coma-separated list
                                                of required options (each of which
                                                holding mandatory arguments)
  - /exclusive-options=<...>       (optional) : to specify a coma-separated list
                                                of mutually exclusive options
  - /argument-separator=<...>      (optional) : to specify how to split multiple
                                                option arguments
  - /filter-args-to-uniqueness                : to filter multiple options arguments
                                                to uniqueness
  - /help                                     : to print this help information

The /options=<argument> defines a line-oriented set of entries holding short/long
options to parse.
Short options refer to single alphanumeric characters prepended with a single dash.
Long options refer to words or multiple words, separated by an hypen, prepended with
a double dash.

Each entry is a colon-delimited string consisting of:
 - an option code identifying the entry and acting as well as a call back value
 - a pipe-delimited string holding long option aliases
 - a flag, namely the argument mandatoriness flag, being <0, 1, 2> which describes
   to which extend <forbidden, mandatory, optional> the option accepts argument(s)
 - a description text

The short option string points to the set options requiring a single leading dash.
Its description mimics the 'getOpt' style option declaration.
Given such an option character:
 - if bundled with no colon, the matched option doesn't allow an argument
 - if bundled with exactly one colon, the matched option requires an argument
 - if bundled with exactly two colons, the matched option can be provided with
   an optional argument

Optionally, "@<type>" can be appended to the mandatoriness flag so the option
arguments will be type-checked at parsing time.
That check relies on the implementation of the is_<type> interface where <type>
denotes the specified argument type. That function is expected to return 0 in case
of success and a different value else. A default implementation is provided for
common types such as 'string','integer', 'binary', 'number' and 'path'.
Last but not least, the is_<type> interface also exposes the 'key-value' type
(checked arguments must be of the form '<key>=<value>') as well as the compound
forms 'key-value-<type>' (checked arguments must be of the form '<key>=<value>'
and <value> must be of type <type>).
Note that the latter definition is not recursive: <value> can never be checked
against the 'key-value' type itself or one its nested form 'key-value-<type>'.
These type check routines are to be extended or overridden dynamically on a per
script basis.

Additionally, for any long option which doesn't allow an argument, the negated
option --no-<option>, or alternatively --no<option>, is handled automatically
if the alias string ends with the character '!'.
Similarly, long option arguments can be handled incrementally (upon each option
presentation, arguments are stored in a vector) provided that same alias string
ends with the character '@'.

Three scanning modes are implemented so the /parsing-strategy=<argument> can be
either:
  - 'PERMUTE' (default)
         This mode simulates the permutation of all non-option arguments by
         storing them, as they come, in a vector, allowing then subsequent
         parsing.
  - 'RETURN_IN_ORDER'
         This mode processes options as they come, each non-option argument
         being handled as if it was the argument of an option with code '1'
  - 'REQUIRE_ORDER'
         This fail-fast mode stops the option scanning when reaching the first
         non-option argument

At first call, argp_parse sets the option index to the index of the first option
word to scan. This option word is then splitted according its short or long option
nature. The resulting tokens are then matched as the option and its argument(s)
through the use of two callback variables. From call to call, those two configurable
placeholders (see the /callback-option-prefix=<argument> switch) expose the option
and argument(s) currently scanned.
If the option word doesn't match a long option, it will be tested to match a short
option or a group of options.
If that word effectively matches a short option (group), it is stripped from its
leading character and repeatedly for each matched short option that it embeds.
When all clustered options of that word have been scanned or if that word has been
matched as a long option, the option index is incremented by one.

If the matched option is a negated form of a known option, the callback option is set
to the latter's option code prepended with '!'. Similarly, if the matched option
is an incremental form of a known option, its option code is stored in a dedicated
vector and potential arguments are accumulated. Both are then emptied for the parser
to return 0.

When argp_parse run out of input, it will iterate over each accumulated option code in
the accumulated option string and will repeatedly set the callback option to the
concatenation of '@' and that option code. It will, as well, set the option argument to
the string holding the mapped option arguments accumulated so far. By default, the long
option matching is case-sensitive but this behaviour can be configured within the use of
the /case-insensitive switch. If all elements have been scanned or when argp_parse hits
the word '--', it will return 1, which will end the whole option scanning.

When argp_parse encounters an illegal or ambiguous option, it sets the callback option
to '?' and its argument to the empty string. If /do-not-exit-on-error is provided, the
callback option argument is set to the faulty option, otherwise the error is reported
on stderr.

When argp_parse encounters a missing/superfluous option argument or an option arg. that
is not of the expected type, it sets the callback option to '?' and its argument to the
empty string. If /do-not-exit-on-error is provided, it sets the callback option to ':'
and its argument to the faulty option, otherwise the error is reported on stderr.

For conformance with existing APIs, argp_parse can be provided with the /long-only switch.
This allows to treat options prefixed with a single dash as regular long options.
If no match is found during the long pass, argp_parse will fall-back to the short option
parsing heuristic.

The API can also handle POSIX(.2) style of options provided it has been configured with
the /allow-posix-long-option switch. Thus, if 'foo' is a long option holding a mandatory
argument, argp_parse will recognize -Wfoo=bar or -W foo=bar as --foo=bar.

The API offers a /required-options switch to specify a set of short or long options
(a coma-separated list of options codes) that can't be found, at the same time, on the
command line.
When a required option is reported as absent from the command line, argp_parse sets the
callback option to '?' and its argument to the empty string. If /do-not-exit-on-error is
provided, it sets the callback option to ',' and its argument to the first missing required
option (and repeatedly for each missing required option), otherwise the error is reported
on stderr.

The API also offers the /exclusive-options switch to define a set of mutually exclusive
options. That switch takes a list of options codes as argument and can be invoked multiple
times to specify multiple groups of mutually exclusive options. If two options within
the same group are to be found on the command line, argp_parse sets the callback option
to '?' and its argument to the empty string.
Similarly, if /do-not-exit-on-error is provided, it sets the callback option to '^' and
its argument to '<opt_a>/<opt_b>' where <opt_a>/<opt_b> denotes the conflicting option
pair. As usual, if /do-not-exit-on-error is not provided, the error is reported on stderr.

To specify which separator to use when accumulating multiple option arguments in a single
argument vector, the API provides the /argument-separator<argument> switch. Those arguments
can filtered to uniqueness if the parser is given the /filter-args-to-uniqueness switch.

At last, the API provides the argp_parse_opts_help function to report to the user the whole
usage information.

To process a new set of options, the caller has to reset explicitly any ongoing option
scanning by calling the argp_parse_reset function.

It's POSIX compliant providing POSIXLY_CORRECT is non-zero.

Example:

while argp_parse /options="h:help:0:Print this help
                           v:verbose!:0:...
                           i:increment@:1:...
                           a:arg:1@integer:..."\\
                 /callback-option-prefix=_opt \\
                 /do-not-exit-on-error \\
                 /long-only "\$@"
do
      case "\$_opt" in
           h) argp_parse_opts_help ;;
           v) echo set verbosity on ;;
         \!v) echo set verbosity off ;;
         \@i) echo accumulated arguments are \$_optarg ;;
           a) echo integer argument is \$_optarg ;;
          \?) echo illegal/ambiguous option \$_optarg ;;
          \:) echo argument for option \$_optarg is missing/superfluous or is not of the expected type ;;
          \,) echo option \${_optarg} is required but was not invoked ;;
          \^) echo option \${_optarg%/*} conflicts with option \${_optarg#*/} ;;
      esac
done
if [ \${_optindex} -ne 0 ]; then
   shift \$((\${_optindex} - 1))
fi

__help_information
}

