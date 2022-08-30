# Eltag - file tagging with symlinks

## TODO:
[ ] init
[ ] tag
[ ] untag
[ ] search
[ ] check
[ ] repair

# Subcommands:

## init

Creates the .eltag directory used to store tag info

## check

Checks if the checksums match the files they point to (prints out wrong ones and broken symlinks)

## repair

Relinks wrong checksums:
- If -s specified: by finding file with same hash
- If -p specified: by recalculating hash for file at the same location

## tag

Adds files to db and creates tag folders if necessary

## untag

Deletes links from tag folders and empty tag folders if last item is removed

## search

Uses fd/find to find files with given tags
