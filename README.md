# rtag - Rin's file tagging

The aim of this project is to create a tagging system that's easy to work with when synchronizing subdirectories and doesn't rely on filesystem-specific features.

## Cache format

Each line of the cache file contains the following:

- The file path ('\' and '\t' are escaped)
- The file tags separated by '\t'
