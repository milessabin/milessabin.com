---
layout:     post
title:      macro-compat-1.0.4 released
author:     Miles Sabin
date:       '2015-10-29 12:00:00'
---

I've just published [macro-compat-1.0.4][macro-compat], which now supports [catalysts][catalysts]. Many thanks to
[Alistair Johnson][inthenow] and [Eugene Burmako][xenoby] for contributing.

Release notes follow ...

[macro-compat]: https://github.com/milessabin/macro-compat
[catalysts]: https://github.com/InTheNow/catalysts
[inthenow]: https://twitter.com/AlistairUSM
[xenoby]: https://twitter.com/xeno_by

<span class="break"></span>

This is the final release of [macro-compat-1.0.4][macro-compat].

These release notes provide a summary of changes since macro-compat 1.0.3.

* Added Symbol#isConstructor.

* Added Symbol#info and infoIn.

* Added Type#decl and Context#internal.enclosingOwner.

* Added compileTimeOnly annotation (thanks to [Alistair Johnson][inthenow]).

* On 2.11.x the @bundle annotation is now implemented as a macro annotation which leaves its annottees unchanged. This
  completely eliminates all traces of macro-compat on 2.11.x builds. Thanks to [Eugene Burmako][xenoby] for the
  suggestion.

Many thanks to everyone who has contributed ideas, enthusiasm and
encouragement.
