#@IgnoreInspection BashAddShebang
# Brief
# Source input resources in the
# current execution environment.
__import_resource_or_fail() {
   local resource="$1"
   shift
   if [ -f "$resource" ]; then
      . "$resource" "$@"
   else
      printf "Import failed: missing required dependency ${resource##*/} in ${resource%/*}, exiting\n" >&2
      stty echo 2>/dev/null
      exit 1
   fi
   return 0
}
