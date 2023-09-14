# rtag - Rin's file tagging

WARNING: Project is not functional yet

Aims of this project:
- easy synchronization of tags
- no filesystem-specific features
- human readable and editable

## Cache format

Each line of the cache file contains the following:

- The file path ('\' and '\t' are escaped)
- The file tags separated by '\t'
- A '\t' at the end of line for easier grepping

## Usage

### Modifying tags:

Specify files:

```
-file <file>
-files <file1> <file2> --

-f <file>
-fm <file1> <file2> --
```

Add tags:

```
-tag some_tag
-tags some_tag1 some_tag2

-t some_tag
-tm some_tag1 some_tag2
```

Remove tags:

```
-del_tag some_tag
-del_tags some_tag1 some_tag2

-d some_tag
-dm some_tag1 some_tag2
```

### Build cache for searching:

```
-build_cache <root_dir>

-b <root_dir>
```

### Searching:

```
-cache_file <file>
-include tag_in
-include_multiple tag_in1 tag_in2 --
-exclude tag_ex
-exclude_multiple tag_ex1 tag_ex2 --
-show_tags

-c <file>
-i tag_in
-im tag_in1 tag_in2 --
-e tag_ex
-em tag_ex1 tag_ex2 --
-s
```
