puki2doku
=========

PukiWiki => DokuWiki data convertor


Usage
-----

```
$ puki2doku.pl -s pukiwiki/wiki -d dokuwiki/data/page
              [-S/--font-size]  (fontsize plugin required)
              [-C/--font-color] (color plugin required)
              [-I/--indexmenu]  (indexmenu plugin required)
              [-N/--ignore-unknown-macro]
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

Attachment file conversion is not yet supported.

[Blog post](http://blog.1q77.com/2013/04/migrating-from-pukiwiki-to-dokuwiki/)
