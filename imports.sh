#@IgnoreInspection BashAddShebang
# Brief
# Source input resource in the
# current execution environment
# and fail if it was not found.
__import_resource_or_fail() {
   local resource="$1"
   shift
   if [ -f "$resource" ]; then
      . "$resource" "$@"
   else
      printf "Import failed: missing required dependency ${resource##*/} in ${resource%/*}, exiting\n" >&2
      exit 1
   fi
   return 0
}
# Brief
# Source input resource in the
# current execution environment.
__import_resource_if_exists() {
   local resource="$1"
   shift
   if [ -f "$resource" ]; then
      . "$resource" "$@"
   fi
   return 0
}
# Brief
# Retrieve a contextual shell name:
# the invoking shell path if it's
# a relative path else the invoking
# basename.
__get_calling_shell_name() {
   if [ ! "${1##\./*}" ]; then
      printf "%s" "$1"
   else
      basename -- "$1"
   fi
}
