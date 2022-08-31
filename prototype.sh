#!/bin/sh
WORKDIR="$(pwd)"

# Utility functions
logerr() {
    printf "%s\n" "$*" >&2
}

# Create an eltag folder
init() {
    [ -d "${WORKDIR}/.eltag" ] && { logerr "[E]: DB already exists!"; exit 1; }
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
            [ -z "${CHECKDIR}" ] && { logerr "[E]: No eltag db found!"; exit 1; }

            # Traverse up
            CHECKDIR="${CHECKDIR%/*}"
        fi
    done

    # Probably not necessary
    [ "${FOUND}" = "0" ] && exit 1

    # Return the db path
    printf "%s\n" "${CHECKDIR}/.eltag"
} #}}}

# Add a file with a tag to db
add_tag() { #{{{
    local DB; DB="$(find_db)"
    TAG="$1"; FILE="$2"
    [ -z "${TAG}"  ] && { logerr "[E]: No tag specified!";  exit 1; }
    [ -z "${FILE}" ] && { logerr "[E]: No file specified!"; exit 1; }

    [ -d "${DB}/${TAG}" ] || \
        mkdir "${DB}/${TAG}"

    local LNAME; LNAME="$(realpath --relative-to="${WORKDIR}" "${FILE}")"
    [ "$(printf "%s\n" "${LNAME}" | cut -c1-3)" = "../" ] && { logerr "[E]: Can't go above db location!"; exit 1; }

    local TAGPATH; TAGPATH="${TAG}/$(printf "%s\n" "${LNAME}" | sha256sum | awk '{ print $1 }')"
    [ -f "${DB}/${TAGPATH}" ] || {
        # File not tagged with this tag yet, so tag it
        ln -s "../../${LNAME}" "${DB}/${TAGPATH}"
    }
} #}}}

# Parse tags and files
add_tags() { #{{{
    [ -z "$1" ] && { logerr "[E]: No arguments!"; exit 1; }

    local  TAGS_FIFO;  TAGS_FIFO="$(mktemp -u)"
    local FILES_FIFO; FILES_FIFO="$(mktemp -u)"
    mkfifo -m0700  "${TAGS_FIFO}"
    mkfifo -m0700 "${FILES_FIFO}"

    local  TAGS_SUPPLIED; TAGS_SUPPLIED="0"
    local FILES_SUPPLIED; FILES_SUPPLIED="0"

    for arg in "$@"; do
        # Check the type of arg
        local TYPE; TYPE=""

        if [ "$(printf "%s\n" "${arg}" | cut -c1)" = ":" ]; then
            TYPE="tag"
            TAGS_SUPPLIED="1"

            local TAG; TAG="$(printf "%s\n" "${arg}" | cut -c2-)"
            printf "%s\n" "${TAG}" >"${TAGS_FIFO}" &
        else
            TYPE="file"
            FILES_SUPPLIED="1"

            local FILE; FILE="${arg}"
            # Remove prefix if escaping a filename
            [ "$(printf "%s\n" "${FILE}" | cut -c1,2)" = '\:' ] && \
                FILE="$(printf "%s\n" "${FILE}" | cut -c3-)"

            printf "%s\n" "${FILE}" >"${FILES_FIFO}" &
        fi
    done

    [  "${TAGS_SUPPLIED}" = "0" ] && { logerr "[E]: No tags supplied!";  exit 1; }
    [ "${FILES_SUPPLIED}" = "0" ] && { logerr "[E]: No files supplied!"; exit 1; }

    local  TAGS;  TAGS="$(cat  "${TAGS_FIFO}")"
    local FILES; FILES="$(cat "${FILES_FIFO}")"
    rm "${TAGS_FIFO}" "${FILES_FIFO}"

    # Loop over files and tags
    mkfifo -m0700  "${TAGS_FIFO}"
    mkfifo -m0700 "${FILES_FIFO}"
    printf "%s\n" "${TAGS}"  >"${TAGS_FIFO}"  &

    while IFS= read -r TAG; do
        printf "%s\n" "${FILES}" >"${FILES_FIFO}" &

        while IFS= read -r FILE; do
            add_tag "${TAG}" "${FILE}"
        done <"${FILES_FIFO}"
    done <"${TAGS_FIFO}"
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
