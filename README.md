# Eltag - file tagging with symlinks

## TODO:
- [x] init
- [x] show
- [x] tag
- [ ] untag
- [ ] search

# Subcommands:

## init

Creates the .eltag directory used to store tag info

## show

Show the path of db used by commands

## tag

Adds files to db and creates tag folders if necessary.

## untag

Deletes links from tag folders and empty tag folders if the last item is removed.

## search

Uses `fd` (or `find` if not available) to find files with given tags.

# Tag specification

Tags are specified with a `:` (eg. `:music`).
To escape this behaviour (if the filename starts with a `:`) prepend the argument with a `\`.

# Data format

A directory called `.eltag` stores folders with the names of tags.
Each tag folder stores relative symbolic links to files.
The filenames are the checksummed destinations of the links (to avoid issues with filename length).
