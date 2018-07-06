#! /usr/bin/env sh
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
#@(#) cd2mpc is a ripping tool designed for converting audio CDs into either musepack, flac or mp3.
#@(#) The latest version can be found at: https://github.com/emmanwl/cd2mpc. Type cd2mpc --help for
#@(#) a full usage information.
CD2MPC_VERSION=15.0

E_SUCCESS=0
E_FAILURE=1
E_SIG_INT=128

. "<__libtools__>/imports.sh" 2>/dev/null
__import_resource_or_fail "<__libdir__>/liboptwrapper.sh"
__import_resource_or_fail "<__libdir__>/liblog4shell.sh"
stty -echo 2>/dev/null

# Shell name
__shell="$(__get_calling_shell_name "$0")"
# Implementation for the type interface.
is_string() { __is_of_match "$1" "[[:print:]]+"; }
is_path() { __is_path "$1"; }
is_binary() { type "$1" >/dev/null 2>&1; }
is_integer() { test "$1" -eq "$1" 2>/dev/null; }
# Brief
# Initialize working context.
initialize_working_context() {
   DEBUGIN initialize_working_context
   WORKING_CONTEXT=$(umask 077 && mktemp -d "${TMPDIR:-/tmp}/cd2mpcXXXXXX" 2>/dev/null) || {\
      logger_fatal "Couln't create working context in ${TMPDIR:-/tmp}"
      return ${E_FAILURE}
   }
   DEBUGOUT initialize_working_context ${E_SUCCESS}
}
# Brief
# Inspect script options.
inspect_options() {
    DEBUGIN inspect_options
    inspect_device_options && inspect_encoding_options && inspect_cddb_options
    DEBUGOUT inspect_options $?
}
# Brief
# Inspect device options.
inspect_device_options() {
    DEBUGIN inspect_device_options
    if ! __is_of_match "${CDROM_DEVICE:=/dev/cd0}" "/dev/(a{0,1}cd[[:digit:]]|cdrom)"; then
       logger_fatal "Couldn't stat device '${CDROM_DEVICE}'"
       return ${E_FAILURE}
    fi
    logger_info "Cdrom device: '${CDROM_DEVICE}'"
    #
    if ! is_binary "${CDID:=cd-discid}"; then
       logger_fatal "No such utility '${CDID}' found/installed"
       return ${E_FAILURE}
    elif ! is_binary "${RIPPER:=cdparanoia}"; then
       logger_fatal "No such utility '${RIPPER}' found/installed"
       return ${E_FAILURE}
    elif __is_in "^${CDROM_DEVICE}" "${CDROM_DEVICE_LOCK:=${HOME}/.device.lock}"; then
       logger_fatal "'${CDROM_DEVICE}' currently being used, exiting"
       return ${E_FAILURE}
    elif [ "${ENCODING_MODE:=batch}" = "single" ]; then
       RIPPER_OPTS="-d ${CDROM_DEVICE} -W -X"
    else
       RIPPER_OPTS="-d ${CDROM_DEVICE} -W -X -B"
    fi
    logger_info "Registering device '${CDROM_DEVICE}' as being used"
    echo "${CDROM_DEVICE}_$$" >>"$CDROM_DEVICE_LOCK"
    DEBUGOUT inspect_device_options ${E_SUCCESS}
}
# Brief
# Inspect encoding options.
inspect_encoding_options() {
    DEBUGIN inspect_encoding_options
    if ! __is_of_match "${OVERWRITE_BEHAVIOUR:=prompt}" "^(prompt|skip|force)$"
    then
       logger_error "Unknown overwriting mode '${OVERWRITE_BEHAVIOUR}', falling back to skip"
       OVERWRITE_BEHAVIOUR="skip"
    fi
    logger_info "File overwrite behaviour: '${OVERWRITE_BEHAVIOUR}'"
    #
    local ext encoder
    for ext in ${ENCODING_VECTOR:=mpc}; do
        case "$ext" in mpc) encoder="mpcenc" ;; flac) encoder="flac" ;; mp3) encoder="lame" ;; esac
        if ! is_binary "$encoder"; then
           logger_error "Couldn't find suitable '${ext}' encoder ('${encoder}'), removing it from the encoding vector"
           __remove "$ext" ENCODING_VECTOR
        fi
    done
    if [ ! "$ENCODING_VECTOR" ]; then
       logger_fatal "None of the expected encoder(s) found for the selected format(s), exiting"
       return ${E_FAILURE}
    fi
    #
    local rgxp mask sep="([[:blank:]]*([[:blank:]]|-|_)[[:blank:]]*)"
    case "${ENCODING_MODE:=batch}" in
         single) rgxp="(%A|%T|%Y|%G)"
                 mask="${SINGLE_MASK:-%T - %A - %Y}" ;;
              *) rgxp="(%A|%T|%N|%Y|%G)"
                 mask="${BATCH_MASK:-%N}" ;;
    esac
    if ! __is_of_match "${TAG_MASK:=${mask}}" "^${rgxp}(${sep}${rgxp})*$"; then
       logger_fatal "Couldn't parse naming mask '${TAG_MASK}'"
       return ${E_FAILURE}
    fi
    logger_info "Naming mask set to: '${TAG_MASK}'"
    #
    if ! __is_of_match "${MAX_PROCESS:=1}" "^[1-9][[:digit:]]{0,1}$"; then
       logger_error "Illegal max simultaneous encoding value, falling back to 1"
       MAX_PROCESS=1
    fi
    logger_info "Max concurrent encoding jobs: '${MAX_PROCESS}'"
    DEBUGOUT inspect_encoding_options ${E_SUCCESS}
}
# Brief
# Inspect cddb options.
inspect_cddb_options() {
    DEBUGIN inspect_cddb_options
    if ! is_binary "${CDDB_QUERY:=cddb_query}"; then
       logger_fatal "No such utility '${CDDB_QUERY}' found/installed"
       return ${E_FAILURE}
    fi
    if ! __is_of_match "${CDDB_PROTOCOL:=cddbp}" "^(http|cddbp|proxy)$"; then
       logger_error "Illegal protocol value '${CDDB_PROTOCOL}', falling back to cddbp"
       CDDB_PROTOCOL="cddbp"
    fi
    if ! __is_of_match "${CDDB_PORT:=888}" "^[1-9][[:digit:]]{2,4}$"; then
       logger_error "Illegal port value '${CDDB_PORT}', falling back to 888"
       CDDB_PORT=888
    fi
     if ! is_path "${CDDB_CACHE_LOCATION:=${HOME}/.cddbslave}"; then
       logger_fatal "Invalid cache directory '${CDDB_CACHE_LOCATION}'"
       return ${E_FAILURE}
    fi
    CDDB_QUERY_OPTS="-e UTF-8 -D ${CDDB_CACHE_LOCATION} -s ${CDDB_SERVER:=freedb.org} -P ${CDDB_PROTOCOL} -p ${CDDB_PORT}"
    logger_info "Cddb connection configured using: '${CDDB_SERVER}/${CDDB_PROTOCOL}/${CDDB_PORT}'"
    #
    local category
    for category in ${CDDB_VECTOR:="folk jazz misc rock country blues newage reggae classical soundtrack"}
    do
       case "$category" in
            folk|jazz|misc|rock|country|blues|newage|reggae|classical|soundtrack) ;;
            *) logger_error "Illegal cddb category '${category}', removing it from the cddb categories lookup"
               __remove "$category" CDDB_VECTOR ;;
       esac
    done
    if [ ! "$CDDB_VECTOR" ]; then
       logger_fatal "No suitable CDDB categories set for the disc lookup, exiting"
       return ${E_FAILURE}
    fi
    logger_info "Cddb categories lookup: '${CDDB_VECTOR}'"
    DEBUGOUT inspect_cddb_options ${E_SUCCESS}
}
# Brief
# Get cd info.
acquire_cd_info() {
    DEBUGIN acquire_cd_info
    local file="info"
    read_cd_metadata "$file" && decode_selection && query_cddb_categories "$file" && get_cddb_data "$file" && parse_cddb_data
    DEBUGOUT acquire_cd_info $?
}
# Brief
# Read cd metadata (disc id, track count, track offsets).
read_cd_metadata() {
    DEBUGIN read_cd_metadata
    if ! ${CDID} ${CDROM_DEVICE} >"${WORKING_CONTEXT}/${1}" 2>/dev/null; then
       logger_fatal "No disc sensed using '${CDROM_DEVICE}'"
       return ${E_FAILURE}
    fi
    read -- DISC_ID TRACK_COUNT TRACK_OFFSETS <"${WORKING_CONTEXT}/${1}"
    DEBUGOUT read_cd_metadata ${E_SUCCESS}
}
# Brief
# Decode selection.
decode_selection() {
    DEBUGIN decode_selection
    local width
    if ! __is_of_match "$TRACK_SELECTION" "^[1-9][[:digit:]]{0,1}(-|-[1-9][[:digit:]]{0,1}){0,1}$"; then
       logger_fatal "Invalid/empty selection format '${TRACK_SELECTION}'"
       return ${E_FAILURE}
    elif [ ! "${TRACK_SELECTION%%*-}" ]; then
       TRACK_SELECTION="${TRACK_SELECTION%-*}-${TRACK_COUNT}"
    fi
    local x=${TRACK_SELECTION%-*} y=${TRACK_SELECTION#*-}
    if [ ${x} -le ${y} -a ${y} -le ${TRACK_COUNT} ]; then
       width=$((${y} - ${x} + 1))
       if [ ${MAX_PROCESS:=1} -gt ${width} ]; then
          MAX_PROCESS=${width}
       fi
    else
       logger_fatal "Invalid selection format '${TRACK_SELECTION}'"
       return ${E_FAILURE}
    fi
    DEBUGOUT decode_selection ${E_SUCCESS}
}
# Brief
# Match cddb categories referencing a ${DISC_ID} entry.
query_cddb_categories() {
    DEBUGIN query_cddb_categories
    if ! { ${USE_LOCAL_CACHE:=false} && fetch_cddb_categories_accordingly "only" "$1"; }
    then
       fetch_cddb_categories_accordingly "off" "$1"
    fi
    DEBUGOUT query_cddb_categories $?
}
# Brief
# Fetch matching cddb categories according to the input cache option ${1} (only/off).
fetch_cddb_categories_accordingly() {
    DEBUGIN fetch_cddb_categories_accordingly
    local cddbcat
    for cddbcat in ${CDDB_VECTOR} edits; do
        {
         case "$cddbcat" in
           edits) if [ "$1" != "off" -a -s "${CDDB_CACHE_LOCATION}/.${DISC_ID}" ] ; then
                     cat "${CDDB_CACHE_LOCATION}/.${DISC_ID}"
                  fi ;;
               *) ${CDDB_QUERY} ${CDDB_QUERY_OPTS} -c ${1} read ${cddbcat} ${DISC_ID} ;;
         esac 2>/dev/null
        }|sed "N;s/.*:[[:blank:]]*\(.*\)\n.*:[[:blank:]]*\(.*\)/\2\/\1 (${cddbcat})/;q"
    done|sort -fu -k1,2 >"${WORKING_CONTEXT}/${2}"
    test -s "${WORKING_CONTEXT}/${2}"
    DEBUGOUT fetch_cddb_categories_accordingly $?
}
# Brief
# Read data (${CDDB_CATEGORY} and ${CDDB_DATA}) from previously fetched cddb entries.
get_cddb_data() {
    DEBUGIN get_cddb_data
    local cddbfile="${WORKING_CONTEXT}/${1}" cnt choices sel
    logger_info "Reading cddb info"

    cnt=$(awk 'END {print NR}' "$cddbfile")
    if [ ${cnt} -eq 0 ]; then
       generate_editable_cddb_template_if_necessary "${CDDB_CACHE_LOCATION}/.${DISC_ID}"
       until ! __is_in "(ARTIST|GENRE|ALBUM|YEAR|TITLE_[0-9][0-9])" "${CDDB_CACHE_LOCATION}/.${DISC_ID}"; do
           logger_info "Entering edit mode, fill in template accordingly..."
           sleep 2
           ${EDITOR:=vim} "${CDDB_CACHE_LOCATION}/.${DISC_ID}"
       done
       CDDB_CATEGORY="edits"
    elif [ ${cnt} -eq 1 ]; then
       CDDB_CATEGORY="$(sed -n "1s/.*(\(.*\))$/\1/p" "$cddbfile")"
    else
       choices="$(sed = "$cddbfile"|sed "N;s/\n/) /")"
       logger_unconditionally "Found ${cnt} CDDB entrie(s):" "$choices"
       logger_unconditionally "Select: [1-${cnt}]|abort(a)?"
       #
       while :; do read -- sel
             case "$sel" in
                  a|A) logger_fatal "Aborting..."
                       return ${E_FAILURE} ;;
             [1-9]|10) CDDB_CATEGORY="$(sed -n "${sel}s/.*(\(.*\))$/\1/p" "$cddbfile")"
                       case "$CDDB_CATEGORY" in
                            edits) CDDB_DATA="$(cat "${CDDB_CACHE_LOCATION}/.${DISC_ID}" 2>/dev/null)" ;;
                                *) CDDB_DATA="$(${CDDB_QUERY} ${CDDB_QUERY_OPTS} -c "off" read ${CDDB_CATEGORY} ${DISC_ID})" ;;
                       esac
                       logger_unconditionally "Entry details:" "$CDDB_DATA"
                       logger_unconditionally "Select: continue(c)|previous(p)|abort(a)?"
                       while :; do read -- sel
                           case "$sel" in
                              p|P) continue 2 ;;
                              c|C) break 2 ;;
                              a|A) logger_fatal "Aborting..."
                                   return ${E_FAILURE} ;;
                                *) logger_unconditionally "Select: continue(c)|previous(p)|abort(a)?" ;;
                           esac
                       done ;;
                    *) logger_unconditionally "Select: [1-${cnt}]|abort(a)?" ;;
             esac
       done
    fi
    #
    case "$CDDB_CATEGORY" in
       edits) CDDB_DATA="$(cat "${CDDB_CACHE_LOCATION}/.${DISC_ID}" 2>/dev/null)" ;;
           *) CDDB_DATA="$(${CDDB_QUERY} ${CDDB_QUERY_OPTS} -c "on" read ${CDDB_CATEGORY} ${DISC_ID})" ;;
    esac
    DEBUGOUT get_cddb_data ${E_SUCCESS}
}
# Brief
# Generate an editable cddb template.
generate_editable_cddb_template_if_necessary() {
    DEBUGIN generate_editable_cddb_template_if_necessary
    local track ptrack
    [ ! -s "$1" ] && {\
      exec 3>&1 1>"$1"
      echo "Artist:   \${ARTIST}"
      echo "Title:    \${ALBUM}"
      echo "Genre:    \${GENRE}"
      echo "Year:     \${YEAR}"
      echo "${TRACK_COUNT} tracks"
      for track in $(seq 1 ${TRACK_COUNT}); do
          ptrack=$(__pad ${track})
          echo "  [${ptrack}] '$(echo '$'TITLE_${ptrack})'"
      done
      exec 1>&3 3>&-
    }
    DEBUGOUT generate_editable_cddb_template_if_necessary ${E_SUCCESS}
}
# Brief
# Parse and retrieve disc info from ${CDDB_DATA}.
parse_cddb_data() {
    DEBUGIN parse_cddb_data
    local def
    local IFS="
"
    for def in $(echo "$CDDB_DATA"|sed -n "s/^A.*:[[:blank:]]*\(.*\)/ARTIST=\"\1\"/p;
                                           s/^Y.*:[[:blank:]]*\(.*\)/YEAR=\"\1\"/p;
                                           s/^T.*:[[:blank:]]*\(.*\)/ALBUM=\"\1\"/p;
                                           s/^G.*:[[:blank:]]*\(.*\)/GENRE=\"\1\"/p;
                                           s/\"//g;s/[[:blank:]]*\[\([[:digit:]]\{2\}\)\][[:blank:]]*'\(.*\)'.*/TITLE_\1=\"\2\"/p")
    do
        eval "$def"
    done 2> /dev/null || {\
      logger_fatal "Couldn't parse all disc info '${CDDB_DATA}'"
      return ${E_FAILURE}
    }
    DEBUGOUT parse_cddb_data ${E_SUCCESS}
}
# Brief
# Extract and encode the selection.
rip_and_encode() {
    DEBUGIN rip_and_encode
    local file="hash"
    rip "$file" && encode "$file"
    DEBUGOUT rip_and_encode $?
}
# Brief
# Extract the selected tracks.
rip() {
    DEBUGIN rip
    make_output_directory && \
    {
      if ! ${DO_ENCODE_ON_THE_FLY:=false}; then
         extract "$1"
      fi
    }
    DEBUGOUT rip $?
}
# Brief
# Make output directory.
make_output_directory() {
    DEBUGIN make_output_directory
    mkdir -p "${OUTPUT_DIRECTORY:=${HOME}/encodes}" 2>/dev/null
    if [ ! -e "$OUTPUT_DIRECTORY" ]; then
       logger_fatal "Couldn't create output directory '${OUTPUT_DIRECTORY}'"
       return ${E_FAILURE}
    fi
    logger_info "Created output directory '${OUTPUT_DIRECTORY}'"
    DEBUGOUT make_output_directory ${E_SUCCESS}
}
# Brief
# Extract the user selection (batch mode).
extract() {
    DEBUGIN extract
    local process="${RIPPER} ${RIPPER_OPTS}" track ptrack file sum
    ${EXTRA_VERBOSITY:=false} || process="${process} >/dev/null 2>&1"

    for track in $(seq ${TRACK_SELECTION%-*} ${TRACK_SELECTION#*-}); do
          ptrack=$(__pad ${track})
          file="${WORKING_CONTEXT}/track${ptrack}.cdda.wav"
          logger_info "Ripping track ${track}"
          (
            if eval ${process} ${track} "${WORKING_CONTEXT}/"; then
               fsum "$file" "$ptrack">>"${WORKING_CONTEXT}/${1}"
               logger_info "Track [${track}] extracted."
               return ${E_SUCCESS}
            else
               logger_fatal "Failed to extract track [${track}]."
               return ${E_FAILURE}
            fi
          )&
          wait || return ${E_FAILURE}
    done
    DEBUGOUT extract ${E_SUCCESS}
}
# Brief
# Prepend hash prints with track number ${2}.
fsum() { cksum "$1"|sed "s/.*/${2} &/g"; }
# Brief
# Encode the selection.
encode() {
    DEBUGIN encode
    make_sound_directory && \
    {
      if ${DO_ENCODE_ON_THE_FLY}; then
         eval fast_encode_${ENCODING_MODE}
      else
         transcode "$1"
      fi
    }
    DEBUGOUT encode $?
}
# Brief
# Make sound directory.
make_sound_directory() {
    DEBUGIN make_sound_directory
    SOUND_DIRECTORY="${OUTPUT_DIRECTORY}/disc_${DISC_ID}_${CDDB_CATEGORY}"
    mkdir -p "$SOUND_DIRECTORY" 2>/dev/null
    if [ ! -e "$SOUND_DIRECTORY" ]; then
       logger_fatal "Couldn't create sound directory '${SOUND_DIRECTORY}'"
       return ${E_FAILURE}
    fi
    logger_info "Created output sound directory '${SOUND_DIRECTORY}'"
    DEBUGOUT make_sound_directory ${E_SUCCESS}
}
# Brief
# Encode, in batch mode, cdparanoia data piped to stdin.
fast_encode_batch() {
    DEBUGIN fast_encode_batch
    local ext process='read_write ${ext}' track oputname
    ${EXTRA_VERBOSITY:=false} || process="${process} 2>/dev/null"

    logger_info "Writing to disc_${DISC_ID}_${CDDB_CATEGORY}"
    for track in $(seq ${TRACK_SELECTION%-*} ${TRACK_SELECTION#*-}); do

          TRACK=$(__pad ${track})
          TITLE="$(eval echo '$'TITLE_${TRACK})"

          for ext in ${ENCODING_VECTOR}; do
              oputname="${SOUND_DIRECTORY}/${TRACK}. $(__munge "$(get_name)").${ext}"
              skip_interactively "$oputname" && continue
              logger_info "Encoding track(s) ${track} to ${ext}"
              (
                if ! eval ${process} - \""${oputname}\""; then
                   logger_fatal "Failed to encode track [${track}] (${ext})."
                   return ${E_FAILURE}
                fi
              )&
              wait || return ${E_FAILURE}
              logger_info "Track [${track}] encoded (${ext})."
          done
    done
    DEBUGOUT fast_encode_batch ${E_SUCCESS}
}
# Brief
# Encode to the input format while reading stdin.
read_write() {
    DEBUGIN read_write_${1}
    ${RIPPER} ${RIPPER_OPTS} ${TRACK} - | eval wav2${1} "$2" "$3"
    DEBUGOUT read_write_${1} $?
}
# Brief
# Encode the input wave file into mpc(musepack) and set tags using ape v2.0.
wav2mpc() {
    DEBUGIN wav2mpc
    mpcenc ${MPC_OPTS} --overwrite\
 --tag album="${ALBUM}"\
 --tag artist="${ARTIST}"\
 --tag title="${TITLE}"\
 --tag track="${TRACK#0}"\
 --tag genre="${GENRE}"\
 --tag year="${YEAR}"\
 --tag comment="Produced with cd2mpc v${CD2MPC_VERSION} using the musepack encoder"\
 "$1"\
 "$2"
    DEBUGOUT wav2mpc $?
}
# Brief
# Encode the input wave file into flac and set tags using ape v2.0.
wav2flac() {
    DEBUGIN wav2flac
    flac ${FLAC_OPTS} --force\
 --tag="ALBUM=${ALBUM}"\
 --tag="ARTIST=${ARTIST}"\
 --tag="TITLE=${TITLE}"\
 --tag="TRACKNUMBER=${TRACK#0}"\
 --tag="GENRE=${GENRE}"\
 --tag="DATE=${YEAR}"\
 --tag="COMMENT=Produced with cd2mpc v${CD2MPC_VERSION} using the flac encoder"\
 "$1"\
 --output-name "$2"
    DEBUGOUT wav2flac $?
}
# Brief
# Encode the input wave file into mp3 and set tags using id3(v2).
wav2mp3() {
    DEBUGIN wav2mp3
    lame ${LAME_OPTS}\
 --tl "$ALBUM"\
 --ta "$ARTIST"\
 --tt "$TITLE"\
 --tn "${TRACK#0}"\
 --tg "$GENRE"\
 --ty "$YEAR"\
 --tc "Produced with cd2mpc v${CD2MPC_VERSION} using the lame encoder"\
 "$1"\
 "$2"
    DEBUGOUT wav2mp3 $?
}
# Brief
# Format names of files to encode.
get_name() { eval echo $(echo "$TAG_MASK"|sed "s/%A/\${ARTIST}/g;s/%T/\${ALBUM}/g;s/%N/\${TITLE}/g;s/%Y/\${YEAR}/g;s/%G/\${GENRE}/g"); }
# Brief
# Remove/skip files interactively.
skip_interactively() {
    local ans
    if [ -e "$1" ]; then
       case "$OVERWRITE_BEHAVIOUR" in
            skip) logger_info "${1##*/} exists, skipping"
                  return ${E_SUCCESS} ;;
          prompt) logger_unconditionally "${1##*/} exists, select: write(w)|skip(s)?"
                  while :; do read -- ans
                        case "$ans" in
                             w|W) logger_info "Removing file ${1##*/}..."
                                  rm -f "$1"
                                  break ;;
                             s|S) logger_info "Skipping encoding of ${1##*/}..."
                                  return ${E_SUCCESS} ;;
                               *) logger_unconditionally "Select: write(w)|skip(s)?" ;;
                        esac
                  done ;;
       esac
    fi
    return ${E_FAILURE}
}
# Brief
# Encodes in single mode, cdparanoia data piped to stdin.
fast_encode_single() {
    DEBUGIN fast_encode_single
    local ext process='read_write ${ext}' oputname
    ${EXTRA_VERBOSITY:=false} || process="${process} 2>/dev/null"

    TRACK="${TRACK_SELECTION%-*}-${TRACK_SELECTION#*-}"
    TITLE="Album Image ${TRACK}"

    logger_info "Writing to disc_${DISC_ID}_${CDDB_CATEGORY}"
    for ext in ${ENCODING_VECTOR}; do
        oputname="${SOUND_DIRECTORY}/${TRACK}. $(__munge "$(get_name)").${ext}"
        skip_interactively "$oputname" && continue
        if [ "$ext" = "flac" -a ${TRACK_SELECTION%-*} -eq 1 ]; then
           if write_cue "${SOUND_DIRECTORY}/img.cue"; then
              FLAC_OPTS="${FLAC_OPTS} --cuesheet=${SOUND_DIRECTORY}/img.cue"
           else
              logger_fatal "Couldn't generate cuesheet file"
              return ${E_FAILURE}
           fi
        fi
        logger_info "Encoding track(s) ${TRACK} to ${ext}"
        (
          if ! eval ${process} - \""${oputname}\""; then
             logger_fatal "Failed to encode track(s) [${TRACK}] (${ext})."
             return ${E_FAILURE}
          fi
        )&
        wait || return ${E_FAILURE}
        logger_info "Track(s) [${TRACK}] encoded (${ext})."
    done
    DEBUGOUT fast_encode_single ${E_SUCCESS}
}
# Brief
# Generate embedable cuesheets.
write_cue() {
    DEBUGIN write_cue
    local indexes="$(${RIPPER} -d ${CDROM_DEVICE} -Q 2>&1|sed -n "s/^[[:blank:]]*[[:digit:]]\{1,\}.*\[\(.*\)\.\(.*\)\].*/\1:\2/p")"
    local track ptrack
    [ "$indexes" ] && {\
      exec 3>&1 1>"$1"
      echo REM GENRE ${GENRE}
      echo REM DATE ${YEAR}
      echo REM DISC_ID ${DISC_ID}
      echo REM COMMENT \"Generated by cd2mpc v${CD2MPC_VERSION} using the flac encoder\"
      echo PERFORMER \"${ARTIST}\"
      echo TITLE \"${ALBUM}\"
      echo FILE \"1-${TRACK_SELECTION#*-}. $(get_name).flac\" WAVE
      for track in $(seq ${TRACK_SELECTION%-*} ${TRACK_SELECTION#*-}); do ptrack=$(__pad ${track})
            echo "  "TRACK ${ptrack} AUDIO
            echo "    "TITLE \""$(eval echo '$'TITLE_${ptrack})"\"
            echo "    "PERFORMER \"${ARTIST}\"
            echo "    "INDEX 01 "$(echo "$indexes"|sed -n "${track}p")"
      done
      exec 1>&3 3>&-
    }
    DEBUGOUT write_cue $?
}
# Brief
# Transcode each selected track into the selected formats.
transcode() {
    DEBUGIN transcode
    local ext process='wav2${ext}' track file oputname pids pool_size=0
    local end=${ENCODING_VECTOR##*[ ]} pid
    ${EXTRA_VERBOSITY:=false} || process="${process} 2>/dev/null"

    logger_info "Writing to disc_${DISC_ID}_${CDDB_CATEGORY}"
    for track in $(seq ${TRACK_SELECTION%-*} ${TRACK_SELECTION#*-}); do
        TRACK=$(__pad ${track})
        TITLE="$(eval echo '$'TITLE_${TRACK})"
        file="${WORKING_CONTEXT}/track${TRACK}.cdda.wav"
        if [ ! -e "$file" ]; then
           logger_error "Skipping encoding of missing file ${file}"
           continue
        elif ! __is_in "^$(fsum "$file" "$TRACK")$" "${WORKING_CONTEXT}/${1}"
        then
           logger_error "File checksum mismatch, skipping"
           continue
        fi
        for ext in ${ENCODING_VECTOR}; do
            oputname="${SOUND_DIRECTORY}/${TRACK}. $(__munge "$(get_name)").${ext}"
            skip_interactively "$oputname" && continue
            logger_info "Encoding track ${TRACK} to ${ext}"
            (
              if eval ${process} "$file" \""${oputname}\""; then
                 logger_info "Track [${TRACK}] encoded (${ext})."
                 return ${E_SUCCESS}
              else
                 logger_fatal "Failed to encode track [${TRACK}] (${ext})."
                 return ${E_FAILURE}
              fi
            )&
            __accumulate "$!" pids
            pool_size=$((${pool_size} + 1))
            if [ ${track} -eq ${TRACK_SELECTION#*-} -a "$ext" = "$end" ]; then
               wait
            elif [ ${pool_size} -ge ${MAX_PROCESS} ]; then
               for pid in ${pids}; do
                   wait ${pid}
                   __remove "$pid" pids
                   pool_size=$((${pool_size} - 1))
                   break
               done 2>/dev/null
            fi
        done
    done
    DEBUGOUT transcode ${E_SUCCESS}
}
# Brief
# Generate a m3u playlist.
m3ulist() {
    DEBUGIN m3ulist
    local ext file
    if ${CREATE_PLAYLIST:=true}; then
       for ext in ${ENCODING_VECTOR}; do
           for file in "${SOUND_DIRECTORY}"/*.${ext}; do
               if [ -e "$file" ]; then
                  printf "%s\n" "${file##*/}"
               fi
           done >"${SOUND_DIRECTORY}/playlist.${ext}.m3u"
       done 2>/dev/null
    fi
    DEBUGOUT m3ulist ${E_SUCCESS}
}
# Brief
# Remove cd from tray.
eject_cd() {
    DEBUGIN eject_cd
    if is_binary eject && ${EJECT_FROM_TRAY:=false}; then
       eject -f ${CDROM_DEVICE}
    fi
    DEBUGOUT eject_cd ${E_SUCCESS}
}
# Brief
# Release stty echo, cdrom-drive lock and resources becoming useless.
release_resources() {
    DEBUGIN release_resources
    stty echo 2>/dev/null
    if [ -e "${CDROM_DEVICE_LOCK:=${HOME}/.device.lock}" ]; then
       perl -i -ne "print unless m;^${CDROM_DEVICE:=/dev/cd0}_$$$;" "$CDROM_DEVICE_LOCK"
       if [ ! -s "$CDROM_DEVICE_LOCK" ]; then
          rm -f "$CDROM_DEVICE_LOCK"
       fi
    fi
    if [ -e "$WORKING_CONTEXT" ]; then
       rm -rf "$WORKING_CONTEXT"
    fi
    DEBUGOUT release_resources ${E_SUCCESS}
}
# Brief
# Control user interruptions.
upon_interrupt() {
    DEBUGIN upon_interrupt
    local file
    logger_info "Aborting, waiting for task(s) to complete..."
    wait
    DEBUGOUT upon_interrupt ${E_SIG_INT}
}
# Brief
# Print version information.
print_info() {
cat <<version >&2

This is ${__shell} v${CD2MPC_VERSION}.
cd2mpc is a shell script utility capable of audio extraction, batch
/single file tagging/encoding using either musepack(mpc), flac(flac)
or lame(mp3). It features caching (for CDDB retrieval), parallelized
encoding as well as encoding on the fly.
It also generates embeded cuesheets when producing flac images.

Example:
       ${__shell} --flac --mp3 --low-disk-use --selection=1-5

Type ${__shell} -h or ${__shell} --help for the usage information.

version
}
# Set interceptors
trap 'upon_interrupt; exit' TERM INT QUIT
trap 'release_resources' EXIT
#
# Parse options
[ -f "<__cd2mpcrc__>" ] && . "<__cd2mpcrc__>"
while argp_parse /options="u:use-local-cddb:0:Use cddb cache
                           j:max-proc:1@integer:Specify max allowed encoding processes
                           E:eject:0:Eject cd from tray when done
                           w:over-existing:1:Specify over-writing mode: <skip,prompt,force>
                           s:selection:1:Select a dash separated track range
                           l:low-disk-use:0:Minimize disk i/o and space used
                           d:device:1:Specify a preferred cdrom device
                           c:config:1@path:Select an alternate configuration file
                           mpc:mpc:0:Use the musepack encoder <mpc>
                           mp3:mp3:0:Use the lame encoder <mp3>
                           flac:flac:0:Use the flac encoder <flac>
                           o:output-dir:1@path:Set the output sound directory
                           B:batch:0:Encode in separate files
                           S:single:0:Encode in a single file
                           n:naming-mask:1:Specify the naming mask to use
                           V:verbose:0:Increase log verbosity
                           h:help:0:Print the help information and exit
                           v:version:0:Print version information and exit"\
                 /long-only \
                 /callback-option-prefix=_opt \
                 /exclusive-options="j,l" \
                 /exclusive-options="j,S" "$@"
do
      case "$_opt" in
           u) USE_LOCAL_CACHE=true    ;;
           j) MAX_PROCESS="$_optarg"  ;;
           E) EJECT_FROM_TRAY=true    ;;
           w) OVERWRITE_BEHAVIOUR="$_optarg"
              ;;
           s) TRACK_SELECTION="$_optarg"
              ;;
           l) DO_ENCODE_ON_THE_FLY=true
              ;;
           d) CDROM_DEVICE="$_optarg" ;;
           c) . "$_optarg"            ;;
mpc|mp3|flac) __accumulate_once "$_opt" ENCODING_VECTOR
              ;;
           o) OUTPUT_DIRECTORY="$_optarg"
              ;;
           B) ENCODING_MODE="batch"
              ;;
           S) ENCODING_MODE="single"
              DO_ENCODE_ON_THE_FLY=true
              ;;
           n) TAG_MASK="$_optarg"     ;;
           V) EXTRA_VERBOSITY=true    ;;
           h) argp_parse_opts_help
              exit ${E_SUCCESS}       ;;
           v) print_info
              exit ${E_SUCCESS}       ;;
 \?|\:|\^|\,) exit ${E_BAD_ARGS}      ;;
      esac
done

if [ ${_optindex} -ne 0 ]; then
   shift $((${_optindex} - 1))
fi

initialize_working_context && inspect_options && \
{
  acquire_cd_info && rip_and_encode && \
  {
    m3ulist && eject_cd
  }
}
exit
