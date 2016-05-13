---
layout:     post
title:      Hacking on scalac &mdash; 0 to PR in an hour
author:     Miles Sabin
date:       '2016-05-13 12:00:00'
---

There were quite a few surprises along the way to the fix for [SI-2712][si2712] that I recently submitted as a [pull
request][pr5108] against the Scala compiler. One of the biggest was just how much easier working with the compiler
source tree is now than I remember it being the last time I attempted to do any serious work on it.
<span class="break"></span>In those days we had an Ant based build, and my recollection is of it being an incredibly
time consuming process. I recall the edit (the compiler source), compile (the compiler), test (using the newly
compiled compiler to build a test source file) cycle taking 5-10 minutes. This made the sort of exploratory
programming that a lot of us do when getting to know an unfamiliar codebase (you know what I mean, sprinkling
`println`'s and seeing what happens) at best tedious if not completely impractical. I believe that the compiler team
improved on this using Zinc (and, going further back, fsc), but for a casual Sunday afternoon compiler hacker it was
not at all obvious how to get these set up and operating effectively.

But times have changed for the better. We now have an SBT based build that makes working with the compiler tree
dramatically easier. On my laptop I get an edit/compile/test cycle in the single digit seconds &mdash; It's hard to
exaggerate just how much easier it is to make progress than it used to be!

I gave a rough outline of the trajectory of my fix for SI-2712 in [my talk][flatmap-talk] at [flatMap(Oslo)][flatmap]
at the beginning of May, and I promised then that I would post a more detailed write up of the mechanics ... this is
that post. Everything that follows is accurate as of the early May 2016 &mdash; I'll update it if things change, and
if you spot anything which is out of date, please let me know.

Herewith the walkthrough ...

### Fork the compiler on github and clone

The first thing to do is fork the compiler. Head to [scala/scala][scala-scala] and hit the "Fork" button. Then clone
from your fork locally (I'll assume a Unix-like shell, substitute your github userid for "milessabin" throughout),

```
miles@frege:writeup$ git clone git@github.com:milessabin/scala.git
Cloning into 'scala'...
remote: Counting objects: 332596, done.
remote: Compressing objects: 100% (2/2), done.
remote: Total 332596 (delta 0), reused 0 (delta 0), pack-reused 332594
Receiving objects: 100% (332596/332596), 82.89 MiB | 3.01 MiB/s, done.
Resolving deltas: 100% (225704/225704), done.
Checking connectivity... done.

miles@frege:writeup$ cd scala

miles@frege:scala (2.11.x)$ _
```

### Create and checkout a branch for your change

We're going to work relative to the main line of development for 2.12.x, and so we create and check out a new branch
starting from there,

```
miles@frege:scala (2.11.x)$ git checkout -b topic/pr-in-an-hour origin/2.12.x
Branch topic/pr-in-an-hour set up to track remote branch 2.12.x from origin by rebasing.
Switched to a new branch 'topic/pr-in-an-hour'
miles@frege:scala (topic/pr-in-an-hour)$ _
```

### Launch SBT

Now launch SBT ... it should be on your path. It'll take a minute or two to get to the SBT REPL,

```
miles@frege:scala (topic/pr-in-an-hour)$ sbt
[info] Loading project definition from /home/miles/tmp/scala/writeup/scala/project/project
[info] Updating {file:/home/miles/tmp/scala/writeup/scala/project/project/}scala-build-build...
[info] Resolving org.fusesource.jansi#jansi;1.4 ...
[info] Done updating.
[info] Loading project definition from /home/miles/tmp/scala/writeup/scala/project
[info] Updating {file:/home/miles/tmp/scala/writeup/scala/project/}scala-build...
[info] Resolving com.jsuereth#pgp-library_2.10;1.0.0 ...
[info] Updating {file:/home/miles/tmp/scala/writeup/scala/project/}scala-build...
[info] Resolving org.fusesource.jansi#jansi;1.4 ...
[info] Done updating.
[info] Resolving org.fusesource.jansi#jansi;1.4 ...
[info] Done updating.
[info] Compiling 11 Scala sources to /home/miles/tmp/scala/writeup/scala/project/target/scala-2.10/sbt-0.13/classes...
[info] *** Welcome to the sbt build definition for Scala! ***
[info] This build definition has an EXPERIMENTAL status. If you are not
[info] interested in testing or working on the build itself, please use
[info] the Ant build definition for now. Check README.md for more information.
> _
```

### Compile!

Before we start working, we need to compile the compiler. We're using SBT so we execute the `compile` task.
When we do we will see some SBT resolution messages and also some warnings of the form,

```
[warn] Binary version (2.12.0-SNAPSHOT) for dependency org.scala-lang#scala-library;2.12.0-SNAPSHOT
[warn]  in org.scala-lang#scala-compiler;2.12.0-SNAPSHOT differs from Scala binary version in project (2.12.0-M4).
```

these can be safely ignored. You might also see some errors relating to JLine and the REPL,

```
Error reading scala/tools/nsc/interpreter/jline/JLineHistory$JLineFileHistory$Entry$.class: null
Error reading scala/tools/nsc/interpreter/jline/JLineConsoleReader.class: null
Error reading scala/tools/nsc/interpreter/jline/JLineConsoleReader$$anon$1.class: null
...
```

towards the end. These can also be ignored.

The whole process takes about 5 minutes on my laptop, and the output (excluding the SBT resolution messages, the
binary version warnings and the JLine related errors) looks like this,

```
> compile
[info] Updating {file:/home/miles/tmp/scala/writeup/scala/}library...
[info] Updating {file:/home/miles/tmp/scala/writeup/scala/}root...
[info] Done updating.
[info] Resolving org.scala-lang#scala-library;2.10.6 ...
[info] Compiling 580 Scala sources and 168 Java sources to
/home/miles/tmp/scala/writeup/scala/build/quick/classes/library...
[warn] there were 118 deprecation warnings; re-run with -deprecation for details
[warn] one warning found
[info] Note: Some input files use unchecked or unsafe operations.
[info] Note: Recompile with -Xlint:unchecked for details.
[info] Compiling 157 Scala sources to /home/miles/tmp/scala/writeup/scala/build/quick/classes/reflect...
[warn] there were 24 deprecation warnings; re-run with -deprecation for details
[warn] there were two unchecked warnings; re-run with -unchecked for details
[warn] two warnings found
[info] Compiling 293 Scala sources to /home/miles/tmp/scala/writeup/scala/build/quick/classes/compiler...
[warn] there were 67 deprecation warnings; re-run with -deprecation for details
[warn] there were 32 unchecked warnings; re-run with -unchecked for details
[warn] two warnings found
[info] Compiling 28 Scala sources to /home/miles/tmp/scala/writeup/scala/build/quick/classes/interactive...
[info] Compiling 23 Scala sources to /home/miles/tmp/scala/writeup/scala/build/quick/classes/scalap...
[info] Compiling 44 Scala sources to /home/miles/tmp/scala/writeup/scala/build/quick/classes/scaladoc...
[warn] there were four deprecation warnings; re-run with -deprecation for details
[warn] there were two unchecked warnings; re-run with -unchecked for details
[warn] two warnings found
[info] Compiling 42 Scala sources and 1 Java source to /home/miles/tmp/scala/writeup/scala/build/quick/classes/repl...
[warn] there were two unchecked warnings; re-run with -unchecked for details
[warn] one warning found
[warn] there were 11 deprecation warnings; re-run with -deprecation for details
[warn] one warning found
[info] Compiling 4 Scala sources to /home/miles/tmp/scala/writeup/scala/build/quick/classes/repl-jline...
[info] Compiling 11 Scala sources and 1 Java source to
/home/miles/tmp/scala/writeup/scala/build/quick/classes/partest-extras...
[info] Compiling 119 Scala sources and 2 Java sources to
/home/miles/tmp/scala/writeup/scala/build/quick/classes/junit...
[warn] there were 21 deprecation warnings; re-run with -deprecation for details
[warn] one warning found
[success] Total time: 233s, completed 11-May-2016 22:44:31
> _
```

Note that the 5 minutes is the build time from clean. Subsequent incremental builds will be much quicker.

### Add a test case

The next thing to do is add a test case for the bug we want to fix, or the feature we want to add. There are several
categories of test cases most of which live under `test/files`. The ones we're most likely to be interested in adding
are positive tests, ie. things which we expect to compile successfully (these live under `test/files/pos`), negative
tests, ie. things which we exect to _not_ compile (these live under `test/files/pos`) and tests which as well as
compiling successfully we also want to run and verify their output (these live under `test/files/run`). The tests can
be either single `.scala` files or directories which can contain multiple `.scala`, `.java` and other files. If a
particular Scala source file `foo.scala` should be compiled with non-default compiler flags, then these can specified
in a correspondingly named `foo.flags` file. For `neg` and `run` tests we also need a `.check` file which contains the
expected output (compiler errors in the `neg` case, execution output in the `run` case).

Let's use the example reported in the [SI-2712 ticket][si2712]: create the file `test/files/pos/t2712-1.scala`
containing the following,

```
object Test {
  def meh[M[_], A](x: M[A]): M[A] = x
  meh{(x: Int) => x} // solves ?M = [X] Int => X and ?A = Int ...
}
```
We're adding this as a positive test, becuase we want it to compile successfully. Notice the convention that when
adding a test corresponding to a bug with a ticket number, the test source file is of the form `tNNNN.scala`. This
isn't essential, but it will make [Jason][retronym] happy.

### Run partest

Now we want to "run" this test. What that means here is that we want to compile this test source file with the
compiler that we've just built. The compiler project uses a tool called `partest` for this, and the SBT build has a
task especially to run it directly from the SBT prompt. Better still, it can be prefixed with a tilde, just like other
SBT tasks, causing the file to be recompiled each time we make a change to the source of the compiler!

Let's do that now. We'll see more of the binary version and JLine warnings that we saw eariler, and also some more SBT
resolution messages. Excluding those again we should see something like,

```
> partest --verbose test/files/pos/t2712-1.scala
[info] Packaging /home/miles/tmp/scala/writeup/scala/build/pack/lib/scala-partest-javaagent.jar ...
[info] Done packaging.
Partest version:
Compiler under test: $baseDir/compiler
Scala version is:    Scala compiler version 2.12.0-20160407-215932-d6f66ec -- Copyright 2002-2016, LAMP/EPFL
Scalac options are:
Compilation Path:    /home/miles/tmp/scala/writeup/scala/target/test/it-classes:...
Java binaries in:    /usr/java/jdk1.8.0_51/jre/bin
Java runtime is:     Java HotSpot(TM) 64-Bit Server VM (build 25.51-b03, mixed mode)
Java options are:    -Xmx1024M -Xms64M -XX:MaxPermSize=128M
baseDir:             /home/miles/tmp/scala/writeup/scala/build/quick/classes
sourceDir:           /home/miles/tmp/scala/writeup/scala/test/files

Selected 1 tests drawn from specified tests

# starting 1 test in pos
% scalac pos/t2712-1.scala
!! 1 - pos/t2712-1.scala                         [compilation failed]
# 0/1 passed, 1 failed in pos

##### Transcripts from failed tests #####

# partest /home/miles/tmp/scala/writeup/scala/test/files/pos/t2712-1.scala
% scalac t2712-1.scala
t2712-1.scala:8: error: no type parameters for method meh: (x: M[A])M[A] exist so that it can be applied to arguments (Int => Int)
 --- because ---
argument expression's type is not compatible with formal parameter type;
 found   : Int => Int
 required: ?M[?A]
  meh{(x: Int) => x} // solves ?M = [X] Int => X and ?A = Int ...
  ^
t2712-1.scala:8: error: type mismatch;
 found   : Int => Int
 required: M[A]
  meh{(x: Int) => x} // solves ?M = [X] Int => X and ?A = Int ...
               ^
two errors found


# Failed test paths (this command will update checkfiles)
partest --update-check \
  /home/miles/tmp/scala/writeup/scala/test/files/pos/t2712-1.scala

[error] Failed: Total 1, Failed 1, Errors 0, Passed 0
[error] Failed tests:
[error]         partest
[error] (test/it:testOnly) sbt.TestsFailedException: Tests unsuccessful
[error] Total time: 9 s, completed 11-May-2016 23:50:21
>
```

Notice that we've run `partest` with the `--verbose` switch so that we can see the compiler error output. If you
invoke `partest` with the `--help` switch it will list quite a few useful options. It also has tab completion. Beware
that it can be a little unforgiving: if you invoke it with a non-existent file path it will start running the entire
test suite which you will only be able to stop by hitting ctrl-C and restarting SBT.

The error is plain to see,

```
no type parameters for method meh: (x: M[A])M[A] exist so that it can be applied to arguments (Int => Int)
```

If you're familiar with the way that SI-2712 manifests itself you'll know that it's a direct reflection of the fact
that when inferring types to apply a polymorphic method the Scala compiler will only ever match types of the same
kinds or arities. In this case we're hoping to match the type `Int => Int`, which desugars to `Function1[Int, Int]`,
against `M[t]` &mdash; the concrete type has an outer type constructor which has two type arguments whereas the type
variable has a single type argument and because of that the compiler won't line those up for us (the technical term
for "lining up types" is _unification_). It's also helpful to think of the job the compiler is doing here as a
solving an equation &mdash; "solve for type variables `M[t]` and `A` such that `M[A]` is equal to `Function1[Int,
Int]`". With that in mind, the error message above is comprehensible, even if we'd like the compiler to try a bit
harder to find a solution.

### Explore with grep and println

In my talk I traced back from the error message that we saw in the compiler output ("no type parameters for")
by grepping for it in the compiler source tree until I eventually found myself [here][location] in the Scala
typechecker,

```scala
// In src/reflect/scala/reflect/internal/Types.scala
def unifyFull(tpe: Type): Boolean = {
  def unifySpecific(tp: Type) = {
    sameLength(typeArgs, tp.typeArgs) && {
      val lhs = if (isLowerBound) tp.typeArgs else typeArgs
      val rhs = if (isLowerBound) typeArgs else tp.typeArgs
      // This is a higher-kinded type var with same arity as tp.
      // If so (see SI-7517), side effect: adds the type constructor itself as a bound.
      isSubArgs(lhs, rhs, params, AnyDepth) && { addBound(tp.typeConstructor); true }
    }
  }
  // The type with which we can successfully unify can be hidden
  // behind singleton types and type aliases.
  tpe.dealiasWidenChain exists unifySpecific
}
```

If you would like a reconstruction of how that went please watch the [video][flatmap-talk] of the talk. Once there
it's fairly easy to spot the condition which is failing &mdash; the problem is that the compiler is refusing to unify
a type constructor with a type variable if the two have different numbers of type arguments, and you can see [right
here][arity-check] where that check is happening.

We can convice ourselves that this is the right place to be looking for a solution by adding a `println` (if that
makes you feel uncomfortable feel free to think of it as "instrumenting the compiler"),

```scala
// typeArgs are the args of the type variable and tp.typeArgs are the args of the
// type we're trying to unify that type variable with ...
if(sameLength(typeArgs, tp.typeArgs)) {
  ...
} else {
  // "this" is the enclosing object, which is the type variable ...
  println(s"Couldn't unify $this with $tp")
  false
}
```

Before you save that change, rerun the test with the tilde prefix so that we can see just how quickly the compiler
will be recompiled and the test rerun,

```
...
1. Waiting for source changes... (press enter to interrupt)
[info] Packaging /home/miles/tmp/scala/writeup/scala/build/pack/lib/scala-partest-javaagent.jar ...
[info] Done packaging.
[info] Compiling 1 Scala source to /home/miles/tmp/scala/writeup/scala/build/quick/classes/reflect...
Partest version:
Compiler under test: $baseDir/compiler
Scala version is:    Scala compiler version 2.12.0-20160407-215932-d6f66ec -- Copyright 2002-2016, LAMP/EPFL
Scalac options are:
Compilation Path:    /home/miles/tmp/scala/writeup/scala/target/test/it-classes:...
Java binaries in:    /usr/java/jdk1.8.0_51/jre/bin
Java runtime is:     Java HotSpot(TM) 64-Bit Server VM (build 25.51-b03, mixed mode)
Java options are:    -Xmx1024M -Xms64M -XX:MaxPermSize=128M
baseDir:             /home/miles/tmp/scala/writeup/scala/build/quick/classes
sourceDir:           /home/miles/tmp/scala/writeup/scala/test/files

Selected 1 tests drawn from specified tests

# starting 1 test in pos
% scalac pos/t2712-1.scala
Couldn't unify ?M[?A] with Int => Int
Couldn't unify ?M[?A] with AnyRef
Couldn't unify ?M[?A] with Object
...
!! 1 - pos/t2712-1.scala                         [compilation failed]
# 0/1 passed, 1 failed in pos

##### Transcripts from failed tests #####

# partest /home/miles/tmp/scala/writeup/scala/test/files/pos/t2712-1.scala
% scalac t2712-1.scala
t2712-1.scala:8: error: no type parameters for method meh: (x: M[A])M[A] exist so that it can be applied to arguments (Int => Int)
 --- because ---
...
two errors found


# Failed test paths (this command will update checkfiles)
partest --update-check \
  /home/miles/tmp/scala/writeup/scala/test/files/pos/t2712-1.scala

[error] Failed: Total 1, Failed 1, Errors 0, Passed 0
[error] Failed tests:
[error]         partest
[error] (test/it:testOnly) sbt.TestsFailedException: Tests unsuccessful
[error] Total time: 8s, completed 12-May-2016 00:07:35
```

Here you can see that SBT has recompiled the compiler and then used that to recompile our test case in a mere 8
seconds &mdash; this is several orders of magnitude faster than I remember it being!

We don't need to pay much attention to the details of the println debug output, but we can see that it confirms the
suspicion that this is a good area to explore for a fix. The line,

```
Couldn't unify ?M[?A] with Int => Int
```

is telling us that the type inferencer is failing to solve the type variables `M[_]` and `A` against the type
`Int => Int` and bailing out at exactly the point where we added the `println`.

### Make your change

This is where we [draw the rest of the owl][rest-of-the-owl] &mdash; this post is about the mechanics of hacking on
the compiler and it would take us too far afield to cover all the details of the fix. Nevertheless, the first cut was
very much simpler than I had expected,

```scala
def unifyFull(tpe: Type): Boolean = {
  def unifySpecific(tp: Type) = {
    if(sameLength(typeArgs, tp.typeArgs)) {
      val lhs = if (isLowerBound) tp.typeArgs else typeArgs
      val rhs = if (isLowerBound) typeArgs else tp.typeArgs
      // This is a higher-kinded type var with same arity as tp.
      // If so (see SI-7517), side effect: adds the type constructor itself as a bound.
      isSubArgs(lhs, rhs, params, AnyDepth) && { addBound(tp.typeConstructor); true }
    } else if(compareLengths(typeArgs, tp.typeArgs) <= 0) {
      val (prefix, suffix) = tp.typeArgs.splitAt(tp.typeArgs.length-typeArgs.length)
      val newSyms = typeArgs.map(_ => tp.typeSymbol.owner.
        newTypeParameter(currentFreshNameCreator.newName("Unify$")) setInfo TypeBounds.empty)
      val poly = PolyType(newSyms, appliedType(tp.typeConstructor, prefix ++ newSyms.map(_.tpeHK)))

      val lhs = if (isLowerBound) suffix else typeArgs
      val rhs = if (isLowerBound) typeArgs else suffix
      // This is a higher-kinded type var with same arity as tp.
      // If so (see SI-7517), side effect: adds the type constructor itself as a bound.
      isSubArgs(lhs, rhs, params, AnyDepth) && { addBound(poly.typeConstructor); true }
    } else
      false
  }
  // The type with which we can successfully unify can be hidden
  // behind singleton types and type aliases.
  tpe.dealiasWidenChain exists unifySpecific
}
```

If you compare with the original you'll see just three lines of significant changes. These lines implement the simple
algorithm suggested by [Paul Chiusano][pchiusano] in [his comment][paul-comment] on the ticket,

> Would it be any easier to just look for partial applications of existing type constructors in left-to-right order?
> Haskell does roughly this (actually, type constructors are just curried, see below), it is tractable, and people
> don't seem to have an issue with the limitation, though occasionally you do have to introduce a new type just to
> flip the  order of some type parameters.

In the code above this plays out as,

```scala
val (prefix, suffix) = tp.typeArgs.splitAt(tp.typeArgs.length-typeArgs.length)
val newSyms = typeArgs.map(_ => tp.typeSymbol.owner.
  newTypeParameter(currentFreshNameCreator.newName("Unify$")) setInfo TypeBounds.empty)
val poly = PolyType(newSyms, appliedType(tp.typeConstructor, prefix ++ newSyms.map(_.tpeHK)))
```

We have too many type arguments in the concrete type, so we split off the excess on the left and do what is in effect
create an anonymous type alias roughly equivalent to `type Anon[t] = Int => t`. We can now express our original `Int
=> Int` as `Fn[Int]`, and this has the right arity to line up with the type variables `M[t]` and `A`, so the
unification can go through, solving `M[t]` as `Anon[t]` and `A` as `Int`.

Simple as it is, this is enough to allow our test case to pass &mdash; let's try it now,

```
> partest test/files/pos/t2712-1.scala
Picked up JAVA_TOOL_OPTIONS: -Dfile.encoding=UTF-8
Partest version:
Compiler under test: $baseDir/compiler
Scala version is:    Scala compiler version 2.12.0-20160407-215932-d6f66ec -- Copyright 2002-2016, LAMP/EPFL
Scalac options are:
Compilation Path:    /home/miles/tmp/scala/writeup/scala/target/test/it-classes:...
Java binaries in:    /usr/java/jdk1.8.0_51/jre/bin
Java runtime is:     Java HotSpot(TM) 64-Bit Server VM (build 25.51-b03, mixed mode)
Java options are:    -Xmx1024M -Xms64M -XX:MaxPermSize=128M
baseDir:             /home/miles/tmp/scala/writeup/scala/build/quick/classes
sourceDir:           /home/miles/tmp/scala/writeup/scala/test/files

Selected 1 tests drawn from specified tests

# starting 1 test in pos
ok 1 - pos/t2712-1.scala

[info] Passed: Total 1, Failed 0, Errors 0, Passed 1
[success] Total time: 10 s, completed 13-May-2016 10:37:29
> _
```

Success!

### Push and PR &mdash; victory!

Now that we have our fix, we commit, push back to our fork, and submit a [pull request][pr5108] to scala/scala and
declare victory!

Of course the devil is in the details and the eventual fix, after lots of review and assistance from Jason and others,
is a little more elaborate. Even so the [end result][final-diff] isn't so very far from the first cut &mdash; I hope
I've been able to convey that getting to this point for a non-trivial issue isn't impossibly out of reach.

Who would have thought that the infamous SI-2712 would turn out to be such low hanging fruit! What other long
standing supposedly intractable issues might succumb just as swifty?

If you want to be a part of shaping the future of Scala you should try and find out!

### Acknowledgements

[Adriaan][adriaanm], [Grzegorz][gkossakowski], [Jason][retronym], [Lukas][lrytz], [Stefan][szeiger] and
[Seth][SethTisue] deserve our deep gratitude for the fantastic work they've done on the SBT build. I belive that it's
a game changer and will massively increase the amount of community involvement in developing the Scala compiler.

[si2712]: https://issues.scala-lang.org/browse/SI-2712
[pr5108]: https://github.com/scala/scala/pull/5102
[flatmap-talk]: https://github.com/milessabin/flatmap-si2712-2016
[flatmap]: http://2016.flatmap.no/
[scala-scala]: https://github.com/scala/scala
[location]: https://github.com/scala/scala/blob/d6f66ec0f38e42c19f79cbe9d32d29c65dee1e05/src/reflect/scala/reflect/internal/Types.scala#L3132-L3145
[arity-check]: https://github.com/scala/scala/blob/d6f66ec0f38e42c19f79cbe9d32d29c65dee1e05/src/reflect/scala/reflect/internal/Types.scala#L3134
[rest-of-the-owl]: http://29.media.tumblr.com/tumblr_l7iwzq98rU1qa1c9eo1_500.jpg
[pchiusano]: https://twitter.com/pchiusano
[paul-comment]: https://issues.scala-lang.org/browse/SI-2712?focusedCommentId=61270
[final-diff]: https://github.com/milessabin/scala/blob/141662307543603a8b3db44f8a2fc691688ed8f6/src/reflect/scala/reflect/internal/Types.scala#L3132-L3186
[adriaanm]: https://github.com/adriaanm
[gkossakowski]: https://github.com/gkossakowski
[retronym]: https://github.com/retronym
[lrytz]: https://github.com/lrytz
[szeiger]: https://github.com/szeiger
[SethTisue]: https://github.com/SethTisue
