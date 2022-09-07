#!/bin/sh
set -eu
WORKDIR="$(pwd)"
VERBOSE="0"

# Utility functions {{{
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

    printf "%s\n" "${FIFO}"
}
# }}}

# Create an eltag folder
init() {
    [ -d "${WORKDIR}/.eltag" ] && { logerr "DB already exists!"; exit 1; }
    mkdir "${WORKDIR}/.eltag"
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

    # Return the db path
    printf "%s\n" "${CHECKDIR}/.eltag"
} #}}}

# Add a file with a tag to db
add_tag() { #{{{
    local DB; DB="$(find_db)"
    local  TAG;  TAG="$1"
    local FILE; FILE="$2"
    [ -z "${TAG}"  ] && { logerr "add_tag(): No tag specified!";  exit 1; }
    [ -z "${FILE}" ] && { logerr "add_tag(): No file specified!"; exit 1; }

    [ -d "${DB}/${TAG}" ] || mkdir "${DB}/${TAG}"

    local RELNAME; RELNAME="$(realpath --relative-to="${DB%.eltag}" "${FILE}")"
    [ "$(printf "%s\n" "${RELNAME}" | cut -c1-3)" = "../" ] && \
        { logerr "Can't go above db location: ${RELNAME}"; exit 1; }

    local TAGPATH; TAGPATH="${TAG}/$(printf "%s\n" "${RELNAME}" | sha256sum | awk '{ print $1 }')"
    if [ -L "${DB}/${TAGPATH}" ]; then
        # Symbolic link exists
        [ "${VERBOSE}" != 0 ] && loginfo "File already tagged" || :
    else
        # File not tagged with this tag yet, so tag it
        ln -s "../../${RELNAME}" "${DB}/${TAGPATH}"
    fi
} #}}}

# Remove a tag from a file
remove_tag() { #{{{
    local DB; DB="$(find_db)"
    local  TAG;  TAG="$1"
    local FILE; FILE="$2"
    [ -z "${TAG}"  ] && { logerr "remove_tag(): No tag specified!";  exit 1; }
    [ -z "${FILE}" ] && { logerr "remove_tag(): No file specified!"; exit 1; }

    [ -d "${DB}/${TAG}" ] || return 0 # Tag not in db, skip

    local RELNAME; RELNAME="$(realpath --relative-to="${DB%.eltag}" "${FILE}")"
    [ "$(printf "%s\n" "${RELNAME}" | cut -c1-3)" = "../" ] && \
        { logerr "Can't go above db location: ${RELNAME}"; exit 1; }

    local TAGPATH; TAGPATH="${TAG}/$(printf "%s\n" "${RELNAME}" | sha256sum | awk '{ print $1 }')"
    if [ -L "${DB}/${TAGPATH}" ]; then
        # Symbolic link exists
        unlink "${DB}/${TAGPATH}"
    else
        # File not tagged
        [ "${VERBOSE}" != 0 ] && loginfo "File: ${FILE} not tagged with: ${TAG}" || :
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

    for arg in "$@"; do
        # Check the type of arg
        if [ "$(printf "%s\n" "${arg}" | cut -c1)" = ":" ]; then
            # Tag
            TAGS_SUPPLIED="1"
            local TAG; TAG="$(printf "%s\n" "${arg}" | cut -c2-)"

            printf "T: %s\n" "${TAG}" >"${TAGS_FIFO}" &

        else
            # File
            FILES_SUPPLIED="1"
            local FILE; FILE="${arg}"

            # Remove prefix if escaping a filename
            [ "$(printf "%s\n" "${FILE}" | cut -c1,2)" = '\:' ] && \
                FILE="$(printf "%s\n" "${FILE}" | cut -c2-)"

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
    log "$(printf "%s\n"  "${TAGS}" | sed 's/^T: /  /')"
    log "On files:"
    log "$(printf "%s\n" "${FILES}" | sed 's/^F: /  /')"

    # Return
    printf "%s\n" "${TAGS}"
    printf "%s\n" "${FILES}"
} # }}}

# Add tags to files
add_tags() { #{{{
    [ -z "$1" ] && { logerr "No arguments!"; exit 1; }

    local TAG_FILE_INFO; TAG_FILE_INFO="$(parse_tags_files "$@")"
    local  TAGS;  TAGS="$(printf "%s\n" "${TAG_FILE_INFO}" | sed '/^F: /d;s/^T: //')"
    local FILES; FILES="$(printf "%s\n" "${TAG_FILE_INFO}" | sed '/^T: /d;s/^F: //')"

    # Loop over files and each tag
    local  TAGS_FIFO;  TAGS_FIFO="$(mktmpfifo)"
    local FILES_FIFO; FILES_FIFO="$(mktmpfifo)"

    printf "%s\n" "${FILES}" >"${FILES_FIFO}" &
    while IFS= read -r FILE; do

        printf "%s\n" "${TAGS}" >"${TAGS_FIFO}" &
        while IFS= read -r TAG; do

            add_tag "${TAG}" "${FILE}"
            [ "${VERBOSE}" != "0" ] && loginfo "Tagging: ${FILE} with: ${TAG}" || :

        done <"${TAGS_FIFO}"
    done <"${FILES_FIFO}"

    rm "${TAGS_FIFO}" "${FILES_FIFO}"
} #}}}

# Remove tags from files
remove_tags() { #{{{
    [ -z "$1" ] && { logerr "No arguments!"; exit 1; }

    local TAG_FILE_INFO; TAG_FILE_INFO="$(parse_tags_files "$@")"
    local  TAGS;  TAGS="$(printf "%s\n" "${TAG_FILE_INFO}" | sed '/^F: /d;s/^T: //')"
    local FILES; FILES="$(printf "%s\n" "${TAG_FILE_INFO}" | sed '/^T: /d;s/^F: //')"

    # Loop over files and each tag
    local  TAGS_FIFO;  TAGS_FIFO="$(mktmpfifo)"
    local FILES_FIFO; FILES_FIFO="$(mktmpfifo)"

    printf "%s\n" "${FILES}" >"${FILES_FIFO}" &
    while IFS= read -r FILE; do

        printf "%s\n" "${TAGS}" >"${TAGS_FIFO}" &
        while IFS= read -r TAG; do

            remove_tag "${TAG}" "${FILE}"
            [ "${VERBOSE}" != "0" ] && loginfo "Untagging: ${FILE} with: ${TAG}" || :

        done <"${TAGS_FIFO}"
    done <"${FILES_FIFO}"

    rm "${TAGS_FIFO}" "${FILES_FIFO}"
} #}}}

main() {
    [ "$1" = "-v" ] && { VERBOSE="1"; shift 1; }
    [ "$1" ] || exit 1

    case "$1" in
         "init") init ;;
         "show") find_db ;;
        "parse") shift 1; parse_tags_files "$@" >/dev/null ;;
          "tag") shift 1; add_tags "$@" ;;
        "untag") shift 1; remove_tags "$@" ;;
        #"search") ;;
        # "check") check_tags ;;
    esac
    exit 0
}

main "$@"
