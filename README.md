# rtag - Rin's file tagging

WARNING: Project is not functional yet

The aim of this project is to create a tagging system that's easy to work with when synchronizing subdirectories and doesn't rely on filesystem-specific features. And also one that's easy to edit by hand when you don't have the script available.

## Cache format

Each line of the cache file contains the following:

- The file path ('\' and '\t' are escaped)
- The file tags separated by '\t'

## Usage

Specifying files:

```
-file <file>
-files <file1> <file2> --

-f <file>
-fm <file1> <file2> --
```

Adding tags:

```
-tag some_tag
-tags some_tag1 some_tag2

-t some_tag
-tm some_tag1 some_tag2
```

Removing tags:

```
-del_tag some_tag
-del_tags some_tag1 some_tag2

-d some_tag
-dm some_tag1 some_tag2
```

Cache creation (for search):

```
-build_cache <root_dir>

-b <root_dir>
```

Searching:

```
-cache_file <file>
-include tag_in
-include_multiple tag_in1 tag_in2 --
-exclude tag_ex
-exclude_multiple tag_ex1 tag_ex2 --
-file_list

-c <file>
-i tag_in
-im tag_in1 tag_in2 --
-e tag_ex
-em tag_ex1 tag_ex2 --
-l
```
