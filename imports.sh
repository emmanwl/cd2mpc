#@IgnoreInspection BashAddShebang
# Brief
# Get last file function declaration.
__get_last_function_declaration() {
   grep -hoE "^[[:space:]]*__[[:lower:]]+(_[[:lower:]]+)*[[:space:]]*" "$1" 2>/dev/null | tail -1
}
# Brief
# Source the input file in the current
# shell and fail if the resource was
# not found.
__import_resource_or_fail() {
   local resource="$1" funct
   shift
   if [ -f "$resource" ]; then
      funct="$(__get_last_function_declaration "$resource")"
      if ! type "$funct" >/dev/null 2>&1; then
         . "$resource" "$@"
      fi
   else
      printf "Import failed: missing required dependency ${resource##*/} in ${resource%/*}, exiting.\n" >&2
      exit 1
   fi
   return 0
}
# Brief
# Source the input file in the current
# shell but silently.
__import_resource() {
   local resource="$1" funct
   shift
   if [ -f "$resource" ]; then
      . "$resource" "$@"
   fi
   return 0
}
# Brief
# Retrieve a contextual shell name:
# the calling shell path if it's
# a relative path else the invoked
# basename.
__get_shell_name() {
   if [ ! "${1##\./*}" ]; then
      printf "%s" "$1"
   else
      basename -- "$1"
   fi
}
