[![Actions Status](https://github.com/Raku-L10N/L10N/actions/workflows/linux.yml/badge.svg)](https://github.com/Raku-L10N/L10N/actions) [![Actions Status](https://github.com/Raku-L10N/L10N/actions/workflows/macos.yml/badge.svg)](https://github.com/Raku-L10N/L10N/actions) [![Actions Status](https://github.com/Raku-L10N/L10N/actions/workflows/windows.yml/badge.svg)](https://github.com/Raku-L10N/L10N/actions)

NAME
====

L10N - support logic for all official localizations of Raku

SYNOPSIS
========

```raku
use L10N;

say L10N.localization-for-path("foo.kaas");  # NL
say L10N.role-for-localization("NL");  # (NL)
```

DESCRIPTION
===========

The `L10N` distribution provides support logic for all official localizations of the Raku Programming Language. It exports a `L10N` class on which various class methods can be called.

It also installs some helper scripts that help during the development and maintenance of localizations.

RUNTIME METHODS
===============

These methods are intended to be used during normal runtime of a program.

localization-for-path
---------------------

```raku
say L10N.localization-for-path("foo.kaas");  # NL
```

Return the localization for a given path (or an `IO::Path` object). Returns `Nil` if no localization could be found for the given path.

role-for-localization
---------------------

```raku
say L10N.role-for-localization("NL");  # (NL)
```

Return the `role` of the given localization (if it is installed), or `True` if no localization could be found.

Because grammars are type objects (and thus falsey), the value `True` is returned to be able to easily distinguish the fail case.

Alternately one could use e.g. the `without` command:

```raku
.say without L10N.role-for-localization("NL");  # (NL)
```

SETUP METHODS
=============

These methods are intended to be used for setting up translations for a localization.

fresh-distribution
------------------

```raku
say L10N.fresh-distribution("XX", "Xerxes");
```

Creates a fresh distribution for a localization in the given directory name (which can also be an IO object for a non-existing, or empty directory) and language name. It also accepts the following named arguments:

<table class="pod-table">
<thead><tr>
<th>name</th> <th>default</th>
</tr></thead>
<tbody>
<tr> <td>auth</td> <td>zef:l10n</td> </tr> <tr> <td>author</td> <td>$*USER.tclc</td> </tr> <tr> <td>copyright</td> <td>Raku Localization Team</td> </tr> <tr> <td>email</td> <td>l10n@raku.org</td> </tr> <tr> <td>executor</td> <td>first 3 characters of language lowercased, followed by &quot;ku&quot;</td> </tr> <tr> <td>localization</td> <td>basename of the directory specified</td> </tr> <tr> <td>year</td> <td>current year</td> </tr>
</tbody>
</table>

Returns `True` if successful. Expects "git" and `App::Mi6` to be installed.

fresh-translation
-----------------

```raku
say L10N.fresh-translation("Xerxes"); # This file contains the Xerxes...
```

Returns the text of a fresh translation file for the given localization.

fresh-translation-file
----------------------

```raku
L10N.fresh-translation-file("XX", "Xerxes");
say "XX.l10n".IO.e;  # True
```

Creates a fresh ".l10n" translation file with the given localization ID (usually a 2-letter ISO code) and name in the current directory.

fresh-executor
--------------

```raku
say L10N.fresh-executor("XX", "Xerxes"); # #!/usr/bin/env raku...
```

Returns the code of a fresh executor for the given localization and language name (in English).

fresh-executor-file
-------------------

```raku
L10N.fresh-executor-file("XX", "XerXes");
say "bin/xerku".IO.e;  # True
```

Creates a fresh executor file with the given localization ID (usually a 2-letter ISO code), the name of the language (in English), and an optional name of the executor to create (defaults to the first 3 letters of the language lowercased, followed by "ku").

UPDATE METHODS
==============

read-hash
---------

Low-level method that converts a localization file into a hash for inspection and manipulation.

```raku
my %core     := L10N.read-hash();
my %xlations := L10N.read-hash("XX.l10n");
my %mixed    := L10N.read-hash("XX.l10n", :core);
```

The first optional input parameter is the path (or an IO object) of the localization file. If not specified, the hash will be filled with the default (core) null-translation.

If a path is specified, an optional `:core` named parameter can be specified to fill in any missing translations with the default (core) null-translations.

missing-translations
--------------------

```raku
say L10N.missing-translations("XX.l10n").elems ~ " missing translations";
```

Given the path (or an IO object) of a localization file, returns a sorted list of translation keys that have not been translated yet.

write-hash
----------

```raku
L10N.write-hash("XX.l10n", %xlations);
```

Given the path (or an IO object) of a localization file, write the translations as found in the given hash to the file in the correct format, preserving any commented lines at the start of the file.

slangify
--------

```raku
my $ast := L10N.slangify("XX", %xlations);
```

Low-level method, mainly intended for internal purposes and debugging. Returns the AST of the `role` that needs to be mixed into the Raku grammar to activate a localization, given a localization ID and translation hash.

deparsify
---------

```raku
my $ast := L10N.deparsify("XX", %xlations);
```

Low-level method, mainly intended for internal purposes and debugging. Returns the AST of the `role` that needs to be mixed into the deparsing logic for a localization, given a localization ID and translation hash.

update-localization-modules
---------------------------

```raku
L10N.update-localization-modules("XX.l10n");
```

Given the path (or an IO object) of a localization file, will create / update the Raku module source code of the localization, specifically `lib/L10N/$id.rakumod` and `lib/RakuAST/Deparse/L10N/$id.rakumod`).

INFORMATIONAL METHODS
=====================

These methods are provided purely for informational purposes, for instance in a pull down menu to select from.

localizations
-------------

```raku
say L10N.localizations;  # (CY DE FR HU IT JA NL PT)
```

The localizations that are currently supported as 2-letter codes, in alphabetical order.

extensions
----------

```raku
say L10N.extensions;  # (churras denata deuku draig...
```

The filename extensions that are currently supported, in alphabetical order.

binaries
--------

```raku
say L10N.binaries;  # (churras denata deuku draig...
```

The binaries that are currently supported, in alphabetical order.

binaries-for-localization
-------------------------

```raku
say L10N.binaries-for-localization("NL");  # (kaas nedku)
```

The binaries that are available for a given localization in alphabetical order. Returns a `Failure` if the given localization is not supported.

extensions-for-localization
---------------------------

```raku
say L10N.extensions-for-localization("NL");  # (kaas nedku)
```

The filename extensions that are supported for a given localization in alphabetical order. Returns a `Failure` if the given localization is not supported.

translation-keys
----------------

```raku
say L10N.translation-keys;   # (adverb-pc-delete adverb-pc-exists ...
say +L10N.translation-keys;  # 643
```

Returns an alphabetically sorted list of translation keys, or can be used to find out the number of translation keys available.

info-for-translation-key
------------------------

```raku
say L10N.info-for-translation-key("block-for");
# - https://docs.raku.org/language/control#for
```

Returns any extra information available for a translation key, usually a URL to the Raku documentation.

SCRIPTS
=======

new-localization
----------------

    $ new-localization XX Xerxes

Create a directory with the given first argument for a new localization with the same name, and use the second argument as the name of the language (in English).

Takes these named arguments, with these default values:

<table class="pod-table">
<thead><tr>
<th>argument</th> <th>default</th>
</tr></thead>
<tbody>
<tr> <td>--auth</td> <td>zef:l10n</td> </tr> <tr> <td>--author</td> <td>$*USER.tclc</td> </tr> <tr> <td>--copyright</td> <td>Raku Localization Team</td> </tr> <tr> <td>--email</td> <td>l10n@raku.org</td> </tr> <tr> <td>--executor</td> <td>first 3 characters of language lowercased, followed by &quot;ku&quot;</td> </tr> <tr> <td>--localization</td> <td>basename of the directory specified</td> </tr> <tr> <td>--year</td> <td>current year</td> </tr>
</tbody>
</table>

update-localization
-------------------

    $ update-localization

The `update-localization` script should be run after any changes have been made to the translations

HISTORY
=======

This distribution originally served as a meta-distribution, installing all official localizations of Raku only. This function has now been taken over by the [L10N::Complete](https://raku.land/zef:l10n/L10N::Complete) distribution, which will also install this distribution.

The update methods were taken from the core `RakuAST::L10N` module, which will be removed in the 2025.08 release of Rakudo.

AUTHOR
======

Elizabeth Mattijsen <liz@raku.rocks>

COPYRIGHT AND LICENSE
=====================

Copyright 2023, 2025 Raku Localization Team

This library is free software; you can redistribute it and/or modify it under the Artistic License 2.0.

