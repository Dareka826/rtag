# Eltag - file tagging with symlinks

## TODO:
[ ] init
[ ] tag
[ ] untag
[ ] search
[ ] check

# Subcommands:

## init

Creates the .eltag directory used to store tag info

## check

Checks if the checksums match the files they point to (prints out wrong ones and broken symlinks)

## tag

Adds files to db and creates tag folders if necessary

## untag

Deletes links from tag folders and empty tag folders if last item is removed

## search

Uses fd/find to find files with given tags

# Data format

A directory called .eltag stores folders with the names of tags. The tag folders store symbolic links to files whose names are checksummed relative destinations of the links (to avoid issues with filename length).
