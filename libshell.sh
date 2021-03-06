#@IgnoreInspection BashAddShebang
# Brief
# Define error codes to use in return/exit
# statements.
E_SUCCESS=0
E_FAILURE=1
E_BAD_ARGS=65
E_END_OF_PARSING=127
E_SIG_INT=128
# Brief
# Print message to stdout/stderr.
__trace() {
    local format
    if [ ${#} -ge 1 ]; then
       format="${__shell}: ${1}\n"
       shift
       printf "$format" "$@"
    fi
}
__sysout() {
    __trace "$@"
}
__syserr() {
    __trace "$@" >&2
}
# Brief
# Accumulate all but last positional tokens
# before assigning the accumulation to the
# to the last parameter.
__accumulate() {
    local name value values
    for name in ${@}; do :; done
    values="$(eval echo '$'"${name}")"
    while [ ${#} -gt 1 ]; do
        if [ ! "$values" ]; then
           eval "${name}='${1}'"
        else
           eval "${name}='${values} ${1}'"
        fi
        values="$(eval echo '$'"${name}")"
        shift
    done
} 
# Accumulate tokens as above but use ${1}
# as the accumulation separator.
__accumulate_with_separator() {
    local separator="$1" name value values
    shift
    for name in ${@}; do :; done
    values="$(eval echo '$'"${name}")"
    while [ ${#} -gt 1 ]; do
        if [ ! "$values" ]; then
           eval "${name}='${1}'"
        else
           eval "${name}='${values}${separator}${1}'"
        fi
        values="$(eval echo '$'"${name}")"
        shift
    done
}
# Brief
# Accumulate tokens as above but make sure
# that each token is accumulated only once.
__accumulate_once() {
    local name value values token matched
    for name in ${@}; do :; done
    values="$(eval echo '$'"${name}")"
    while [ ${#} -gt 1 ]; do
        if [ ! "$values" ]; then
           eval "${name}='${1}'"
        else
           matched=false
           for token in $(__split_tokens_accordingly " " "$values"); do
               if [ "$token" = "${1%%=*}" ]; then
                  matched=true
                  break
               fi
           done
           if ! ${matched}; then
              eval "${name}='${values} ${1}'"
           fi
        fi
        values="$(eval echo '$'"${name}")"
        shift
    done
}
# Brief
# Remove token ${1} from ${2}.
__remove() {
    local token="$1" name="$2" value values
    for value in $(eval echo '$'"${name}"); do
        if [ "$value" != "$token" ]; then
           if [ ! "$values" ]; then
              values="$value"
           else
              values="${values} ${value}"
           fi
        fi
    done
    eval "${name}='${values}'"
}
# Brief
# Expand all positional parameters but one
# using ${1} as IFS and print them to stdout.
__split_tokens_accordingly() {
    local IFS="$1" item
    shift
    for item in ${@}; do
        echo "$item"
    done
}
# Brief
# Append ${1} to a ${3}-separated accumulation
# of tokens ${2} only if ${2} doesnt already
# contain ${1}.
__append() {
    local token tokens="$2"
    if [ ! "$tokens" ]; then
       printf "%s" "$1"
    else
       for token in $(__split_tokens_accordingly "$3" "$tokens"); do
           if [ "$token" = "$1" ]; then
              printf "%s" "$tokens"
              return ${E_FAILURE}
           fi
       done
       printf "%s" "${tokens}${3}${1}"
    fi
}
# Brief
# Left pad ${1} with zeros.
__pad() { printf "%02i" "${1#0}"; }
# Brief
# Check whether ${1} matches the regular
# expression that follows.
__is_of_match() { printf "%s" "$1"|grep -Ew -- "$2" >/dev/null 2>&1; }
# Brief
# Check whether the ascii resource denoted
# by ${2} holds references to pattern ${1}.
__is_in() { grep -E -- "$1" "$2" >/dev/null 2>&1 ; }
# Brief
# Check whether ${1} is contained in ${2}
# which is a ${3}-separated accumulation.
__is_1_contained_in_2_using_3_as_separator() {
    [ "$1" = "$2" ] || [ "$2" -a ! "${2##"${1}${3}"*}" ] || [ "$2" -a ! "${2##*"${3}${1}${3}"*}" ] || [ "$2" -a ! "${2##*"${3}${1}"}" ]
}
# Brief
# Check whether ${1} denotes a valid path
__is_path() { __is_of_match "$1" "^(/+((\.){0,1}[[:alnum:]]+((-|_)*[[:alnum:]]+)*){0,1})+$"; }
# Brief
# Sanitize ${1}.
__munge() { printf "%s" "$1"|sed -e "s/\/\{1,\}/_/g;s/@/_/g"|tr -d ";?[:cntrl:]"; }
# Brief
# Remove, on the fly, all leading and trailing
# ${2} characters from ${1}.
__trim_char() {
    local string="$1" char="$2"
    while [ "${string%"${string#?}"}" = "$char" ]; do
        string="${string#"${char}"}"
    done
    while [ "${string#"${string%?}"}" = "$char" ]; do
        string="${string%"${char}"}"
    done
    printf "%s" "$string"
}
# Brief
# Remove, on the fly, all leading and trailing
# space characters from ${1}.
__trim() {
    __trim_char "$1" " "
}
# Brief
# Remove, on the fly, all space characters.
__trim_globally() {
    local string="$1" left right
    while :; do
        right="${string#*[[:space:]]}"
        if [ "$string" = "$right" ]; then
           break
        fi
        left="${string%"${right}"}"
        string="${left%?}${right}"
    done
    printf "%s" "$string"
}
# Brief
# Read fields from a ${1}-delimited string ${2}, 
# starting at position ${3}, and assign content
# (respectively) to the remaining positional
# parameters.
__read_separator_delimited_token() {
    local separator="$1" token="$2" index="$3" last
    while [ ${index} -gt 1 ]; do
          token="${token#*"${separator}"}"
          index=$((${index} - 1))
    done
    local IFS="$separator"
    shift 3
    read -- "$@" last<<EOF
${token}
EOF
    return ${E_SUCCESS}
}
# Brief
# Replace, on the fly, each hyphen contained in
# ${1} with an underscore.
__underscorize() {
    local right string="$1" left
    while :; do
        right="${string#*-}"
        if [ "$string" = "$right" ]; then
           break
        fi
        left="${string%"${right}"}"
        string="${left%?}_${right}"
    done
    printf "%s" "$string"
}
# Brief
# Print ${1} to lowercase.
__lowerize() {
    local string="$1" left lower right
    while :; do
        right="${string#*[[:upper:]]}"
        if [ "$string" = "$right" ]; then
           break
        fi
        left="${string%"${right}"}"
        case "${left#"${left%?}"}" in
           B) lower=b;; C) lower=c;;
           D) lower=d;; E) lower=e;;
           F) lower=f;; G) lower=g;;
           H) lower=h;; I) lower=i;;
           J) lower=j;; K) lower=k;;
           L) lower=l;; M) lower=m;;
           N) lower=n;; O) lower=o;;
           P) lower=p;; Q) lower=q;;
           R) lower=r;; S) lower=s;;
           A) lower=a;; T) lower=t;;
           U) lower=u;; V) lower=v;;
           W) lower=w;; X) lower=x;;
           Y) lower=y;; Z) lower=z;;
        esac
        string="${left%?}${lower}${right}"
    done
    printf "%s" "$string"
}
#
__get_entry_points_rgxp() {
    printf "%s" "^\(${1}[[:alnum:]]\{1,\}\(_[[:alnum:]]\{1,\}\)\{0,\}${2}\)[[:space:]]\{0,\}([[:space:]]\{0,\}).*"
}
__first_not_empty() {
    printf  "%s" "${1:-"${2:-""}"}"
}
# Brief
# List functions declarations whose name starts
# with <prefix> and/or ends with <suffix>.
__entry_points() {
    local file prefix suffix randomize=false entry_points entry
    while [ ${#} -gt 0 ]; do
        case "${1%%=*}" in
               --prefix) prefix="$(__first_not_empty "${1#*=}" "__should")" ;;
               --suffix) suffix="$(__first_not_empty "${1#*=}" "_test")"    ;;
             --randomly) randomize=true                                     ;;
                 --file) file="$(__first_not_empty "${1#*=}" "$2")"         ;;
             --append=*) entry_points="${1#*=}"                             ;;
        esac
        shift
    done
    if [ ! -s "$file" ]; then
       return ${E_FAILURE}
    fi
    #
    {
      sed -n "s/$(__get_entry_points_rgxp "$prefix" "$suffix")/\1/p" "$file"
      if [ "$entry_points" ]; then
         for entry in ${entry_points}; do
             printf "%s\n" "$entry"
         done
      fi
    } |\
    {
      if ${randomize}; then
         sort -R
      else
         sort
      fi
    } | uniq
    return ${E_SUCCESS}
}
