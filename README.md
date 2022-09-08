# Eltag - file tagging with symlinks

# Subcommands:

## init

Creates an `.eltag` directory used to store tag info

## show

Show the path of db used by commands

## tag

Adds files to db and creates tag folders if necessary.

## untag

Deletes links from tag folders and empty tag folders if the last item is removed.

## search

Finds files with specified tag rules (include, exclude)

# Additional Subcommands:

## dump

Print database contents as parseable text data. Can be used with grep or other tools to achieve more advanced tag filtering than the search subcommand.

# csumg

Generate checksummed paths for passed files

# csumf

Find file path from checksum in db

## parse

Used for testing whether differentiating between tag and file arguments works as intended.

# Tag specification

Tags are specified with a `:` (eg. `:music`).
To escape this behaviour (if the filename starts with a `:`) prepend the argument with a `\` (in most shells the `\` will need to be escaped).

# Data format

A directory called `.eltag` stores folders with the names of tags.
Each tag folder stores relative symbolic links to files.
The filenames are the checksummed destinations of the links (to avoid issues with filename length).
