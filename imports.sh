#@IgnoreInspection BashAddShebang
# Brief
# Define error codes to use in return/exit
# statements.
E_SUCCESS=0
E_FAILURE=1
# Brief
# Source the input file in the current
# shell but silently.
__import_resource() {
   local resource="$1"
   shift
   if [ -f "$resource" ]; then
      . "$resource" "$@"
      return ${E_SUCCESS}
   fi
   return ${E_FAILURE}
}
# Brief
# Source the input file in the current
# shell and fail if the resource was
# not found.
__import_resource_or_fail() {
   if ! __import_resource "$@"; then
      printf "Import failed: missing required dependency ${resource##*/} in ${resource%/*}, exiting.\n" >&2
      exit ${E_FAILURE}
   fi
   return ${E_SUCCESS}
}
# Brief
# Retrieve a contextual shell name.
__get_shell_name() {
   if [ ! "${1##\./*}" ]; then
      printf "%s" "$1"
   else
      basename -- "$1"
   fi
}
