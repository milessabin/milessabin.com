---
layout:     post
title:      Hacking on scalac &mdash; 0 to PR in an hour
author:     Miles Sabin
date:       '2016-05-11 12:00:00'
---

There were quite a few surprises along the way to the fix for [SI-2712][si2712] that I recently submitted as a [pull
request][pr5108] against the Scala compiler. One of the biggest was just how much easier working with the compiler
source tree is now than I remember it being the last time I attempted to do any serious work on it.
<span class="break"></span>In those days we had an Ant based build, and my recollection is of it being an incredibly
time consuming process. I recall the edit (the compiler source), compile (the compiler), test (using the newly
compiled compiler to build a test source file) cycle taking 5-10 minutes. This made the sort of exploratory
programming that a lot of us do when getting to know an unfamiliar codebase (you know what I mean, sprinkling
`println`'s and seeing what happens) at best tedious if not completely impractical. I believe that the compiler team
improved on this using Zinc (and, going further back fsc), but for a casual Sunday afternoon compiler hacker it was
not at all obvious how to get these set up an operating effectively.

But times have changed for the better. We now have an SBT based build that makes working with the compiler tree
dramatically easier &mdash; on my fairly lightweight laptop I get an edit/compile/test cycle in the single digit
seconds. It's hard to exaggerate just how much easier it is to make progress than it used to be!

I gave a rough outline of the trajectory of my fix for SI-2712 in [my talk][flatmap-talk] at [flatMap][flatmap] at the
beginning of May, and I promised then that I would post a more detailed write up of the mechanics ... this is that
post. Everything that follows is accurate as of the early May 2016 ... I'll update it if things change and if you spot
anything which is out of date, please let me know.

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

Now we need to launch SBT ... it should be on your path. It will take a minute or two to get to the SBT REPL,

```
miles@frege:scala (topic/pr-in-an-hour)$ sbt
[info] Loading global plugins from /home/miles/.sbt/0.13/plugins
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

Before we start working, we need to compile the compiler. We're using SBT so this means executing the `compile` task.
When you do you will see some SBT resolution messages and also some warnings of the form,

```
[warn] Binary version (2.12.0-SNAPSHOT) for dependency org.scala-lang#scala-library;2.12.0-SNAPSHOT
[warn]  in org.scala-lang#scala-compiler;2.12.0-SNAPSHOT differs from Scala binary version in project (2.12.0-M4).
```

these can be safely ignored. You might also see some errors relating to the JLine and the REPL,

```
Error reading scala/tools/nsc/interpreter/jline/JLineHistory$JLineFileHistory$Entry$.class: null
Error reading scala/tools/nsc/interpreter/jline/JLineConsoleReader.class: null
Error reading scala/tools/nsc/interpreter/jline/JLineConsoleReader$$anon$1.class: null
...
```

towards the end. These can also be ignored.

The whole process takes about 15 minutes on my laptop, and the output (excluding the SBT resolution messages, the
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
[success] Total time: 856 s, completed 11-May-2016 22:44:31
> _
```

Note that the 15 minutes is the build time from clean. Subsequent incremental builds will be much quicker.

### Add a test case

The next thing to do is add a test case for the bug we want to fix, or the feature we want to add. There are several
categories of test cases most of which live under `test/files`. The ones we're most likely to be interested in adding
are positive tests, ie. things which we expect to compile successfully (these live under `test/files/pos`), negative
tests, ie. things which we exect to _not_ compile (these live under `test/files/pos`) and tests which as well as
compiling successfully we also want to run and verify their output (these live under `test/files/run`). The tests can
be either single `.scala` files or directories which can contain multiple `.scala`, `.java` and other files. If a
particular Scala source file `foo.scala` should be compiled with non-default compiler flags, then these can specified
in a correspondingly named `foo.flags` file ... we'll see an example later. For `neg` and `run` tests we also need a
`.check` file which contains the expected output (compiler errors in the `neg` case, execution output in the `run`
case) ... we'll see how to create that later.

Let's use the example reported in the [SI-2712 ticket][si2712] ... create the file `test/files/pos/t2712-1.scala`
containing the following,

```
object Test {
  def meh[M[_], A](x: M[A]): M[A] = x
  meh{(x: Int) => x} // solves ?M = [X] Int => X and ?A = Int ...
}
```
We're adding this as a positive test, becuase we _want_ it to compile successfully. Notice the convention that when
adding a test corresponding to a bug with a ticket number, the test source file is of the form `tNNNN.scala`. This
isn't essential, but it will make Jason happy.

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
Compilation Path:    /home/miles/tmp/scala/writeup/scala/target/test/it-classes:$baseDir/test:$baseDir/compiler:...
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

Notice that we've run `partest` with the `--verbose` switch so that we can see the compiler error output &mdash;
`partest` has quite a few useful options which are listed if you invoke it with the `--help` switch and it also has
tab completion. Beware that it can be a little unforgiving, and if you invoke it with a non-existent file path it will
start running the entire test suite which you will only be able to stop by hitting ctrl-C and restarting SBT.

The error is plain to see,
```
no type parameters for method meh: (x: M[A])M[A] exist so that it can be applied to arguments (Int => Int)
```
and if you're familiar with the problem you'll know that it's a direct reflection of the fact that when solving type
variables the Scala compiler will only ever match types of the same kinds or arities. In this case we're hoping to
match the type `Int => Int`, which desugars to `Function1[Int, Int]` against `M[t]` &mdash; the concrete type has an
outer type constructor which has two type arguments whereas the type variable has a single type argument and the
compiler won't line those up for us.

### Explore with grep and println

In my talk I traced back from the error message that we saw in the compiler output ("no type parameters for method")
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
here][] where that check is happening.

We can convice ourselves that this is the right place to be looking for a solution by instrumenting the code in the
compiler with a `println`,

```scala
// typeArgs are the args of the type variable and tp.typeArgs are the args of the
// type we're trying to unify that type variable with ...
if(sameLength(typeArgs, tp.typeArgs)) {
  ...
} else {
  println(s"$this $tp")  // "this" is the enclosing object, ie. the type variable
  false
}
```
Before you save that change, make rerun the test with the tilde prefix so that we can see just how quickly the
compiler will be recompiled,

```
1. Waiting for source changes... (press enter to interrupt)
[info] Packaging /home/miles/tmp/scala/writeup/scala/build/pack/lib/scala-partest-javaagent.jar ...
[info] Done packaging.
[info] Compiling 1 Scala source to /home/miles/tmp/scala/writeup/scala/build/quick/classes/reflect...
Partest version:     
Compiler under test: $baseDir/compiler
Scala version is:    Scala compiler version 2.12.0-20160407-215932-d6f66ec -- Copyright 2002-2016, LAMP/EPFL
Scalac options are:  
Compilation Path:    /home/miles/tmp/scala/writeup/scala/target/test/it-classes:$baseDir/test:$baseDir/compiler:...
Java binaries in:    /usr/java/jdk1.8.0_51/jre/bin
Java runtime is:     Java HotSpot(TM) 64-Bit Server VM (build 25.51-b03, mixed mode)
Java options are:    -Xmx1024M -Xms64M -XX:MaxPermSize=128M
baseDir:             /home/miles/tmp/scala/writeup/scala/build/quick/classes
sourceDir:           /home/miles/tmp/scala/writeup/scala/test/files
    
Selected 1 tests drawn from specified tests

# starting 1 test in pos
% scalac pos/t2712-1.scala
?M[?A] Int => Int
?M[?A] AnyRef
?M[?A] Object
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
[error] Total time: 20 s, completed 12-May-2016 00:07:35
```
Here you can see that SBT has recompiled the compiler and then used that to recompile our test case in a mere 20
seconds &mdash; this is several orders of magnitude quicker than I remember it being!

We don't need to pay much attention to the details of the println debug output, but we can see that it confirms the
suspicion that this is a good area to explore for a fix. The output,
```
?M[?A] Int => Int
```
is telling us that the type inferencer is failing to solve the type variables `M[_]` and `A` against the type
`Int => Int` and bailing out at exactly the point where we added the `println`.

### Make your change

### Push and PR

### Publish locally while it's in the queue

### Acknowledgements

[si2712]: https://issues.scala-lang.org/browse/SI-2712
[pr5108]: https://github.com/scala/scala/pull/5102
[flatmap-talk]: https://github.com/milessabin/flatmap-si2712-2016
[flatmap]: http://2016.flatmap.no/
[scala-scala]: https://github.com/scala/scala
[location]: https://github.com/scala/scala/blob/d6f66ec0f38e42c19f79cbe9d32d29c65dee1e05/src/reflect/scala/reflect/internal/Types.scala#L3132-L3145

<!--
https://github.com/gkossakowski
Grzegorz Kossakowski

https://github.com/retronym
Jason Zaugg

https://github.com/szeiger
Stefan Zeiger

https://github.com/lrytz
Lukas Rytz

https://github.com/SethTisue
SethTisue

https://github.com/adriaanm
Adriaan Moors
-->

