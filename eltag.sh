#!/bin/sh
set -eu
WORKDIR="$(pwd)"

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
    TAG="$1"; FILE="$2"
    [ -z "${TAG}"  ] && { logerr "No tag specified!";  exit 1; }
    [ -z "${FILE}" ] && { logerr "No file specified!"; exit 1; }

    [ -d "${DB}/${TAG}" ] || \
        mkdir "${DB}/${TAG}"

    local LNAME; LNAME="$(realpath --relative-to="${WORKDIR}" "${FILE}")"
    [ "$(printf "%s\n" "${LNAME}" | cut -c1-3)" = "../" ] && { logerr "Can't go above db location!"; exit 1; }

    local TAGPATH; TAGPATH="${TAG}/$(printf "%s\n" "${LNAME}" | sha256sum | awk '{ print $1 }')"
    [ -f "${DB}/${TAGPATH}" ] || {
        # File not tagged with this tag yet, so tag it
        ln -s "../../${LNAME}" "${DB}/${TAGPATH}"
    }
} #}}}

parse_tags_files() {
    # TODO: Move functionality from add_tags here to reuse for untagging
    :
}

# Parse tags and files
add_tags() { #{{{
    [ -z "$1" ] && { logerr "No arguments!"; exit 1; }

    local  TAGS_FIFO;  TAGS_FIFO="$(mktmpfifo)"
    local FILES_FIFO; FILES_FIFO="$(mktmpfifo)"

    local  TAGS_SUPPLIED; TAGS_SUPPLIED="0"
    local FILES_SUPPLIED; FILES_SUPPLIED="0"

    for arg in "$@"; do
        # Check the type of arg
        if [ "$(printf "%s\n" "${arg}" | cut -c1)" = ":" ]; then
            # Tag
            TAGS_SUPPLIED="1"

            local TAG; TAG="$(printf "%s\n" "${arg}" | cut -c2-)"
            printf "%s\n" "${TAG}" >"${TAGS_FIFO}" &
        else
            # File
            FILES_SUPPLIED="1"

            local FILE; FILE="${arg}"
            # Remove prefix if escaping a filename
            [ "$(printf "%s\n" "${FILE}" | cut -c1,2)" = '\:' ] && \
                FILE="$(printf "%s\n" "${FILE}" | cut -c3-)"

            printf "%s\n" "${FILE}" >"${FILES_FIFO}" &
        fi
    done

    [  "${TAGS_SUPPLIED}" = "0" ] && { logerr "No tags supplied!";  exit 1; }
    [ "${FILES_SUPPLIED}" = "0" ] && { logerr "No files supplied!"; exit 1; }

    local  TAGS;  TAGS="$(cat  "${TAGS_FIFO}")"
    local FILES; FILES="$(cat "${FILES_FIFO}")"
    rm "${TAGS_FIFO}" "${FILES_FIFO}"

    # Loop over files and tags
    local  TAGS_READ_FIFO;  TAGS_READ_FIFO="$(mktmpfifo)"
    local FILES_READ_FIFO; FILES_READ_FIFO="$(mktmpfifo)"
    printf "%s\n" "${TAGS}"  >"${TAGS_READ_FIFO}"  &

    while IFS= read -r TAG; do
        printf "%s\n" "${FILES}" >"${FILES_READ_FIFO}" &

        while IFS= read -r FILE; do
            add_tag "${TAG}" "${FILE}"
        done <"${FILES_READ_FIFO}"
    done <"${TAGS_READ_FIFO}"
} #}}}

main() {
    [ "$1" ] || exit 1

    case "$1" in
          "init") init ;;
           "tag") shift 1; add_tags "$@" ;;
          "show") find_db ;;
        # "untag") remove_tag ;;
        #"search") ;;
        # "check") check_tags ;;
    esac
    exit 0
}

main "$@"
