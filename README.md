puki2doku
=========

PukiWiki => DokuWiki data convertor


Usage
-----

Convert wiki page
```
$ puki2doku.pl -s pukiwiki/wiki -d dokuwiki/data/page
              [-S/--font-size]  (fontsize plugin required)
              [-C/--font-color] (color plugin required)
              [-I/--indexmenu]  (indexmenu plugin required)
              [-N/--ignore-unknown-macro]
              [-v/--verbose]
              [-O/--do-not-overwrite]
              [-D/--decode]
              [-A/--attach]
              [-H/--use-heading]
              [-P pagename.txt(encoded)/--page=pagename.txt(encoded)]
              [-E utf8/--encoding=utf8]
```
--font-size option is not recommended.
fontsize plugin does not support nested text decoration.

Convert attached files
```
$ puki2doku.pl -A [-v] -s pukiwiki/attach -d dokuwiki/data/media
```

After data converson. You need rebuild search index using following command.

```
$ cd dokuwiki/bin
$ php indexer.php
```

DokuWiki Plugin
---------------

 * [fontsize](https://www.dokuwiki.org/plugin:fontsize)
 * [color](https://www.dokuwiki.org/plugin:color)
 * [indexmenu](https://www.dokuwiki.org/plugin:indexmenu)
 * [definitions](https://www.dokuwiki.org/plugin:definitions)


Note
----

[Blog post](http://blog.1q77.com/2013/04/migrating-from-pukiwiki-to-dokuwiki/)
