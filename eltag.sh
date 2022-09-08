#!/bin/sh
set -eu
IFS="$(printf "\t\n")"

WORKDIR="$(pwd)"
VERBOSE="0"
# Verbosity:
# 0 - Log errors
# 1 - Log potentially useful info
# 2 - Log everything

# Utility functions {{{
sprint() {
    printf "%s\n" "$*"
}

log() {
    printf "%s\n" "$*" >&2
}
loginfo() {
    printf "[I]: %s\n" "$*" >&2
}
logerr() {
    printf "[E]: %s\n" "$*" >&2
}

mktmpfifo() {
    local FIFO; FIFO="$(mktemp -u)"
    [ -e "${FIFO}" ] && rm -f "${FIFO}"
    mkfifo -m0700 "${FIFO}"

    [ "${VERBOSE}" -ge 2 ] && loginfo "Created fifo: ${FIFO}" || :
    sprint "${FIFO}"
}

# Detect control characters
validate_name() {
    [ "$(printf "%s" "$1" | tr -d '[:cntrl:]')" != "$1" ] && {
        logerr "Illegal char in: \"$1\""
        exit 1
    } || :
}
# }}}

# Create an eltag folder
init() {
    [ -d "${WORKDIR}/.eltag" ] && { logerr "DB already exists!"; exit 1; }
    mkdir "${WORKDIR}/.eltag"

    [ "${VERBOSE}" -ge 2 ] && loginfo "Initialized db at: ${WORKDIR}/.eltag" || :
}

# Traverse filesystem to find db folder
find_db() { #{{{
    local CHECKDIR; CHECKDIR="${WORKDIR}"

    local FOUND; FOUND="0"
    while [ "${FOUND}" = "0" ]; do
        if [ -d "${CHECKDIR}/.eltag" ]; then
            FOUND="1"
        else
            # If no db found even on root, just exit
            [ -z "${CHECKDIR}" ] && { logerr "No eltag db found!"; exit 1; }

            # Traverse up
            CHECKDIR="${CHECKDIR%/*}"
        fi
    done

    [ "${VERBOSE}" -ge 2 ] && loginfo "Found db at: ${CHECKDIR}/.eltag" || :
    # Return the db path
    sprint "${CHECKDIR}/.eltag"
} #}}}

# Add a file with a tag to db
add_tag() { #{{{
    local DB; DB="$(find_db)"
    local  TAG;  TAG="$1"
    local FILE; FILE="$2"
    [ -z "${TAG}"  ] && { logerr "add_tag(): No tag specified!";  exit 1; }
    [ -z "${FILE}" ] && { logerr "add_tag(): No file specified!"; exit 1; }

    validate_name "${TAG}"

    [ -d "${DB}/${TAG}" ] || mkdir "${DB}/${TAG}"

    local RELNAME; RELNAME="$(realpath --relative-to="${DB%.eltag}" "${FILE}")"
    [ "$(sprint "${RELNAME}" | cut -c1-3)" = "../" ] && \
        { logerr "Can't go above db location: ${RELNAME}"; exit 1; }

    local TAGPATH; TAGPATH="${TAG}/$(sprint "${RELNAME}" | sha256sum | awk '{ print $1 }')"
    if [ -L "${DB}/${TAGPATH}" ]; then
        # Symbolic link exists
        [ "${VERBOSE}" -ge 1 ] && loginfo "File: ${FILE} already tagged with: ${TAG}" || :
    else
        # File not tagged with this tag yet, so tag it
        ln -s "../../${RELNAME}" "${DB}/${TAGPATH}"
        [ "${VERBOSE}" -ge 2 ] && loginfo "Tagged file: ${FILE} with: ${TAG}" || :
    fi
} #}}}

# Remove a tag from a file
remove_tag() { #{{{
    local DB; DB="$(find_db)"
    local  TAG;  TAG="$1"
    local FILE; FILE="$2"
    [ -z "${TAG}"  ] && { logerr "remove_tag(): No tag specified!";  exit 1; }
    [ -z "${FILE}" ] && { logerr "remove_tag(): No file specified!"; exit 1; }

    validate_name "${TAG}"

    [ -d "${DB}/${TAG}" ] || return 0 # Tag not in db, skip

    local RELNAME; RELNAME="$(realpath --relative-to="${DB%.eltag}" "${FILE}")"
    [ "$(sprint "${RELNAME}" | cut -c1-3)" = "../" ] && \
        { logerr "Can't go above db location: ${RELNAME}"; exit 1; }

    local TAGPATH; TAGPATH="${TAG}/$(sprint "${RELNAME}" | sha256sum | awk '{ print $1 }')"
    if [ -L "${DB}/${TAGPATH}" ]; then
        # Symbolic link exists
        unlink "${DB}/${TAGPATH}"
        [ "${VERBOSE}" -ge 2 ] && loginfo "Untagged file: ${FILE} with: ${TAG}" || :
    else
        # File not tagged
        [ "${VERBOSE}" -ge 1 ] && loginfo "File: ${FILE} not tagged with: ${TAG}" || :
    fi

    # Try to remove dir (will get removed if empty)
    rmdir "${DB}/${TAG}" || :
} #}}}

# Split command arguments into files and tags
parse_tags_files() { # {{{
    # Arguments: `file` `:tag` `\:file`
    [ -z "$1" ] && { logerr "parse_tags_files(): No arguments!"; exit 1; }

    local  TAGS_FIFO;  TAGS_FIFO="$(mktmpfifo)"
    local FILES_FIFO; FILES_FIFO="$(mktmpfifo)"

    local  TAGS_SUPPLIED;  TAGS_SUPPLIED="0"
    local FILES_SUPPLIED; FILES_SUPPLIED="0"

    local arg
    for arg in "$@"; do
        # Check the type of arg
        if [ "$(sprint "${arg}" | cut -c1)" = ":" ]; then
            # Tag
            TAGS_SUPPLIED="1"
            local TAG; TAG="$(sprint "${arg}" | cut -c2-)"

            [ "${VERBOSE}" -ge 2 ] && loginfo "Parsed tag: ${TAG}" || :
            printf "T: %s\n" "${TAG}" >"${TAGS_FIFO}" &

        else
            # File
            FILES_SUPPLIED="1"
            local FILE; FILE="${arg}"

            # Remove prefix if escaping a filename
            [ "$(sprint "${FILE}" | cut -c1,2)" = '\:' ] && \
                FILE="$(sprint "${FILE}" | cut -c2-)"

            [ "${VERBOSE}" -ge 2 ] && loginfo "Parsed file: ${FILE}" || :
            printf "F: %s\n" "${FILE}" >"${FILES_FIFO}" &
        fi
    done

    if [ "${TAGS_SUPPLIED}" = "0" ] || [ "${FILES_SUPPLIED}" = 0 ]; then
        # Either tags of files not supplied, cleanup
        if [  "${TAGS_SUPPLIED}" = "0" ]; then
            logerr "No tags supplied!"
        else
            cat "${TAGS_FIFO}" >/dev/null
        fi

        if [ "${FILES_SUPPLIED}" = "0" ]; then
            logerr "No files supplied!"
        else
            cat "${FILES_FIFO}" >/dev/null
        fi

        rm "${TAGS_FIFO}" "${FILES_FIFO}"
        exit 1
    fi

    local  TAGS;  TAGS="$(cat  "${TAGS_FIFO}")"
    local FILES; FILES="$(cat "${FILES_FIFO}")"
    rm "${TAGS_FIFO}" "${FILES_FIFO}"

    # Log the results
    log "Using tags:"
    log "$(sprint  "${TAGS}" | sed 's/^T: /  /')"
    log "On files:"
    log "$(sprint "${FILES}" | sed 's/^F: /  /')"

    # Return
    sprint "${TAGS}"
    sprint "${FILES}"
} # }}}

# Add tags to files
add_tags() { #{{{
    [ -z "$1" ] && { logerr "No arguments!"; exit 1; }

    local TAG_FILE_INFO; TAG_FILE_INFO="$(parse_tags_files "$@")"
    local  TAGS;  TAGS="$(sprint "${TAG_FILE_INFO}" | sed '/^F: /d;s/^T: //')"
    local FILES; FILES="$(sprint "${TAG_FILE_INFO}" | sed '/^T: /d;s/^F: //')"

    # Loop over files and each tag
    local  TAGS_FIFO;  TAGS_FIFO="$(mktmpfifo)"
    local FILES_FIFO; FILES_FIFO="$(mktmpfifo)"

    local FILE TAG
    sprint "${FILES}" >"${FILES_FIFO}" &
    while IFS= read -r FILE; do

        sprint "${TAGS}" >"${TAGS_FIFO}" &
        while IFS= read -r TAG; do

            add_tag "${TAG}" "${FILE}"
            [ "${VERBOSE}" -ge 1 ] && loginfo "Tagging: ${FILE} with: ${TAG}" || :

        done <"${TAGS_FIFO}"
    done <"${FILES_FIFO}"

    rm "${TAGS_FIFO}" "${FILES_FIFO}"
} #}}}

# Remove tags from files
remove_tags() { #{{{
    [ -z "$1" ] && { logerr "No arguments!"; exit 1; }

    local TAG_FILE_INFO; TAG_FILE_INFO="$(parse_tags_files "$@")"
    local  TAGS;  TAGS="$(sprint "${TAG_FILE_INFO}" | sed '/^F: /d;s/^T: //')"
    local FILES; FILES="$(sprint "${TAG_FILE_INFO}" | sed '/^T: /d;s/^F: //')"

    # Loop over files and each tag
    local  TAGS_FIFO;  TAGS_FIFO="$(mktmpfifo)"
    local FILES_FIFO; FILES_FIFO="$(mktmpfifo)"

    local FILE TAG
    sprint "${FILES}" >"${FILES_FIFO}" &
    while IFS= read -r FILE; do

        sprint "${TAGS}" >"${TAGS_FIFO}" &
        while IFS= read -r TAG; do

            remove_tag "${TAG}" "${FILE}"
            [ "${VERBOSE}" -ge 1 ] && loginfo "Untagging: ${FILE} with: ${TAG}" || :

        done <"${TAGS_FIFO}"
    done <"${FILES_FIFO}"

    rm "${TAGS_FIFO}" "${FILES_FIFO}"
} #}}}

# Print database in parsable format
dump() { # {{{
    local DB; DB="$(find_db)"
    local file

    find "${DB}" -type l -exec basename '{}' \; | sort | uniq \
        | while read -r file; do
            printf "%s/" "${file}"
            find "${DB}" -name "${file}" | sed 's/.*\.eltag\///;s/^\(.*\)\/\([0-9a-f]\+\)$/\1/' | tr '\n' '/'
            printf "\n"
        done
} # }}}

# Find files by tags
search_tags() { # {{{
    # Arguments: 'tag' '-tag' '\-tag'
    local INCLUDE_FIFO; INCLUDE_FIFO="$(mktmpfifo)"
    local EXCLUDE_FIFO; EXCLUDE_FIFO="$(mktmpfifo)"

    local INCLUDE_TAGS_EXIST; INCLUDE_TAGS_EXIST="0"
    local EXCLUDE_TAGS_EXIST; EXCLUDE_TAGS_EXIST="0"

    local tag
    for tag in "$@"; do
        if [ "$(sprint "${tag}" | cut -c1)" = '-' ]; then
            # Exclude
            sprint "${tag}" | cut -c2- >"${EXCLUDE_FIFO}" &
            EXCLUDE_TAGS_EXIST="1"
        else
            [ "$(sprint "${tag}" | cut -c1,2)" = '\-' ] && \
                tag="$(sprint "${tag}" | cut -c2-)"

            # Include
            sprint "${tag}" >"${INCLUDE_FIFO}" &
            INCLUDE_TAGS_EXIST="1"
        fi
    done

    [ "${INCLUDE_TAGS_EXIST}" = "0" ] && printf "\n" >"${INCLUDE_FIFO}" &
    [ "${EXCLUDE_TAGS_EXIST}" = "0" ] && printf "\n" >"${EXCLUDE_FIFO}" &

    local INCLUDE_TAGS; INCLUDE_TAGS="$(cat "${INCLUDE_FIFO}")"
    local EXCLUDE_TAGS; EXCLUDE_TAGS="$(cat "${EXCLUDE_FIFO}")"
    rm "${INCLUDE_FIFO}" "${EXCLUDE_FIFO}"

    # Filter based on tags
    log "Included tags:"
    log "$(sprint "${INCLUDE_TAGS}" | sed 's/^\(.*\)$/  \1/')"
    log "Excluded tags:"
    log "$(sprint "${EXCLUDE_TAGS}" | sed 's/^\(.*\)$/  \1/')"

    local DB_DUMP; DB_DUMP="$(dump)"

    local TAG
    local FILTER_FIFO; FILTER_FIFO="$(mktmpfifo)"

    sprint "${INCLUDE_TAGS}" >"${FILTER_FIFO}" &
    while IFS= read -r TAG; do
        DB_DUMP="$(sprint "${DB_DUMP}" | grep "/${TAG}/")"
    done <"${FILTER_FIFO}"

    sprint "${EXCLUDE_TAGS}" >"${FILTER_FIFO}" &
    while IFS= read -r TAG; do
        DB_DUMP="$(sprint "${DB_DUMP}" | grep -v "/${TAG}/")"
    done <"${FILTER_FIFO}"

    rm "${FILTER_FIFO}"

    sprint "${DB_DUMP}" | grep -Eo '^[0-9a-f]+'
} # }}}

main() {
    # Calculate verbosity level
    while [ "$1" = "-v" ]; do
        VERBOSE="$((VERBOSE + 1))"
        shift 1
    done
    [ "$1" ] || exit 1

    # Abort on any control characters in filenames/tags
    local arg
    for arg in "$@"; do validate_name "${arg}"; done
    # Now we can guarantee that linewise operations will work

    case "$1" in
          "init") init ;;
          "show") find_db ;;
         "parse") shift 1; parse_tags_files "$@" >/dev/null ;;
           "tag") shift 1; add_tags "$@" ;;
         "untag") shift 1; remove_tags "$@" ;;
          "dump") dump ;;
        "search") shift 1; search_tags "$@" ;;
    esac
    exit 0
}

main "$@"
