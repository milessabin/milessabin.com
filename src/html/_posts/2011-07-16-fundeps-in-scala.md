---
layout:     post
title:      Functional Dependencies in Scala
author:     Miles Sabin
date:       '2011-07-16 12:00:00'
---

[Functional dependencies][fundeps] are a near-standard extension to  Haskell (present in GHC and elsewhere) which
allow constraints on the type parameters of type classes to be expressed and then enforced by the compiler. They allow
the programmer to state that some of the type parameters of a multi-parameter type class are completely determined by
the others. <span class="break"></span> One particularly common application of this is allowing the result type of a
function to be a parameter but nevertheless determined by the type(s) of it's argument(s) --- the examples on the
Haskell wiki page that I linked to above illustrate that extremely well.

Does this have an equivalent in Scala? We certainly have the equivalent problem --- whenever we have multiple type
parameters (of a type or method) we might want to be able to express functional dependency-like constraints between
those type parameters and have those constraints checked by the compiler. And ideally we want that to get along well
with type-inference --- we would like the compiler to be able to infer any types which are determined by types
which it is already able to infer.

It turns out that there's a very simple translation of Haskell-style functional dependencies to Scala, but for some
reason this doesn't seem to have been commented on. Quite the opposite in fact --- I've seen it reported that encoding
fundeps in Scala is either impossible, or possible but not useful because of issues with type inference. What makes
this even more surprising is that a crucial feature of Scala's (now not so) new collections framework
([`CanBuildFrom`][cbf]) appears to be a perfect example of this encoding in practice ... strangely this isn't
advertised in [_Type Classes as Objects and Implicits_][tcoi] (Olivera, Odersky and Moors, 2010) either.

Maybe this has all been noticed before and assumed to be too obvious to mention, nevertheless, I think it's useful to
be able to make the connection. I'll illustrate the translation using the examples from the Haskell wiki. By the time
I'm done translating them into Scala the fact that `CanBuildFrom` is an instance of a fundep should be quite clear.

Let's start with the matrix/vector/scalar multiplication example. Here we want to express the fact that the result
type of the multiplication is fully determined by it's arguments,

```scala
        Matrix * Matrix => Matrix
        Matrix * Vector => Vector
        Matrix * Int    => Matrix
           Int * Matrix => Matrix
```

Here we have a triple of types where the first two (the argument types) determine the third (the result type). Lets
express this relationship directly via a trait with three type parameters accompanied by some implicit definitions
which capture the relationship we want to enforce,

```scala
trait Matrix // Dummy definitions for expository purposes
trait Vector

trait MultDep[A, B, C]
  
implicit object mmm extends MultDep[Matrix, Matrix, Matrix]
implicit object mvv extends MultDep[Matrix, Vector, Vector]
implicit object mim extends MultDep[Matrix, Int, Matrix]
implicit object imm extends MultDep[Int, Matrix, Matrix]
```

Given these definitions we can ask the compiler what is and what isn't allowed,

```scala
// OK: Matrix * Matrix -> Matrix
scala> implicitly[MultDep[Matrix, Matrix, Matrix]]
res0: MultDep[Matrix,Matrix,Matrix] = mmm$@1ddeda2

// OK: Matrix * Vector -> Vector
scala> implicitly[MultDep[Matrix, Vector, Vector]]
res1: MultDep[Matrix,Vector,Vector] = mvv$@1a8fb1b

// Error
scala> implicitly[MultDep[Matrix, Vector, Matrix]]
<console>:15: error: could not find implicit value for 
  parameter e: MultDep[Matrix,Vector,Matrix]
```

The first two cases are fine, because they both correspond to one of the implicit instances we provided earlier. The
third fails, quite rightly, because there is no instance corresponding to `Matrix * Vector -> Matrix`.

So, we've been able to capture the desired relationship between the type variables. Here's how we put that to use,

```scala
def mult[A, B, C](a: A, b: B)
  (implicit instance: MultDep[A, B, C]): C =
    error("TODO")

// Type annotations solely to verify that the correct result type
// has been inferred

val r1: Matrix = mult(new Matrix {}, new Matrix{}) // Compiles
val r2: Vector = mult(new Matrix {}, new Vector{}) // Compiles
val r3: Matrix = mult(new Matrix {}, 2)            // Compiles
val r4: Matrix = mult(2, new Matrix {})            // Compiles

// This next one doesn't compile ...
val r5: Matrix = mult(new Matrix {}, new Vector{}) 
```

Notice how the third type parameter, `C`, isn't used in the first (explicit) parameter list. If it weren't for its
appearance in the second (implicit) parameter list the compiler would normally infer it as `Nothing` --- not what we
want at all. But the combination of type inference and implicit search saves the day. The first two type parameters
`A` and `B` are inferred from the explicit arguments to `mult()`, then implicit search kicks in, attempting to locate
an implicit definition of `MultDep[_, _, _]` consistent with those two types. By construction, it will only ever find
one, and that is sufficient to uniquely determine `C` for use as the result type of the function.

We have the signature of our `mult()` function sorted out, now for the implementation.  The (hopefully fairly obvious)
trick here is to make our `MultDep` instances provide the implementations of the different cases as well as the type
constraints,

```scala
implicit object mmm extends MultDep[Matrix, Matrix, Matrix] {
  def apply(m1: Matrix, m2: Matrix): Matrix = error("TODO")
}

implicit object mvv extends MultDep[Matrix, Vector, Vector] {
  def apply(m1: Matrix, v2: Vector): Vector = error("TODO")
}

implicit object mim extends MultDep[Matrix, Int, Matrix] {
  def apply(m1: Matrix, i2: Int): Matrix = error("TODO")
}

implicit object imm extends MultDep[Int, Matrix, Matrix] {
  def apply(i1: Int, m2: Matrix): Matrix = error("TODO")
}
```

(filling out the bodies of the dummy `apply()` methods is an exercise left for the reader). We can now complete the
definition of `mult()`,

```scala
def mult[A, B, C](a: A, b: B)
  (implicit instance: MultDep[A, B, C]): C = 
    instance(a, b)
```

And that's all there is to it. The implicit objects correspond exactly to the type class instances in the Haskell
original, and the combination of type inference and implicit search captures the functional dependency directly.

Here's the second example from Haskell wiki page, translated in the same way,

```scala
trait ExtractDep[A, B] {
  def apply(a: A): B
}
  
implicit def ep[A, B] = new ExtractDep[(A, B), A] {
  def apply(p: (A, B)): A = p._1
}
  
def extract[A, B](a: A)
  (implicit instance: ExtractDep[A, B]): B = instance(a)

// Type annotation solely to verify that the correct result type
// has been inferred
val c: Char = extract(('x', 3))
```

Of course, neither of these two examples are particularly exciting in Scala as they stand --- Scala has Java-style
overloading, which makes the matrix/vector/scalar example mostly redundant; and the second example is a little too
artificial to be compelling. Nevertheless, there are many situations where being able to express similar constraints
amongst type parameters can be extremely useful --- Scala embedded DSLs often have to deal with situations which are
equivalent to wanting a function result type to be determined by its argument types, and I know of a number of DSL
designers who've struggled with the problem of `Nothing` being inferred unhelpfully for unconstrained result types.

But the best widely known example of a fundep is right under our noses in the Scala standard library itself:
[CanBuildFrom][cbf].  Let's take a look at (a slight simplification of) of the part of its definition which expresses
type constraints,

```scala
trait CanBuildFrom[From, Elem, To] {
  def apply ...
}
```

Instances of this trait capture collection-type-specific constraints on whether or not a collection of type `To` with
elements of type `Elem` can be created from a collection of type `From`. For "regular" collection types (collections
which can hold elements of any type) the corresponding instance is equivalent to,

```scala
implicit def regularCanBuildFrom[CC[_], A] =
  new CanBuildFrom[CC[_], A, CC[A]] {
    def apply ...
  }
```

In effect this asserts that for a regular collection type it's possible to create a new collection of the same shape,
but with an arbitrarily substituted element type. We can ask the compiler about these relationships like so,

```scala
scala> import scala.collection.generic._
import scala.collection.generic._

scala> implicitly[CanBuildFrom[List[Int], String, List[String]]]
res0: CanBuildFrom[List[Int],String,List[String]] = ...

scala> implicitly[CanBuildFrom[Set[String], Double, Set[Double]]]
res1: CanBuildFrom[Set[String],Double,Set[Double]] = ...

// These two don't compile ...
scala> implicitly[CanBuildFrom[List[String], Int, List[Double]]]
<console>:11: error: ...

scala> implicitly[CanBuildFrom[List[String], Int, Set[Int]]]
<console>:11: error: ...
```

As you can see from these examples, the third type argument in `CanBuildFrom` is determined by its first two --- it
takes its type constructor from the first type argument and its element type from the second type argument. Any
attempt to deviate from that pattern results in a static compile time error. This should be sounding familiar ...

Now lets look at where this abstraction is used: the definition of [`TraversibleLike.map()`][travlike],

```scala
def map[B, That](f: A => B)
  (implicit bf: CanBuildFrom[Repr, B, That]): That = {
    val b = bf(repr)
    b.sizeHint(this) 
    for (x <- this) b += f(x)
    b.result
  }
```

It should be apparent that here, like the matrix/vector/scalar example, we have a method with a parametrized result
type which is not used in any of its explicit argument types, and hence which can't be inferred from its explicit
arguments. Just as in the earlier case, it's the implicit argument which is determining the otherwise unconstrained
result type via implicit search for a `CanBuildFrom` instance with type parameters `B` (determined by type inference
from the explicit parameter list) and `Repr` (effectively a constant). It should also be apparent that the implicit
argument is providing a significant component of the implementation of this method via the call `bf(repr)` --- this is
exactly analogous to the calls of `instance(a, b)` in the earlier example.

Hopefully the discussion above will have persuaded you that these are the hallmarks of a Haskell-like functional
dependency, right at the heart of the Scala collections framework. And in my book, that makes fundeps in Scala neither
impossible nor useless.

[fundeps]: http://www.haskell.org/haskellwiki/Functional_dependencies
[cbf]: http://www.scala-lang.org/api/current/index.html#scala.collection.generic.CanBuildFrom
[tcoi]: http://ropas.snu.ac.kr/~bruno/papers/TypeClasses.pdf
[travlike]: http://www.scala-lang.org/api/current/index.html#scala.collection.TraversableLike

{% include comment-header.html %}

<div markdown="1">
##### Lachlan O'Dea (<a href="https://twitter.com/quelgar">@quelgar</a>) -- Mon, 18th Jul 2011, 3:49am GMT
<div class="comment-body" markdown="1">
Another great post, thanks!
</div>
</div>

<div markdown="1">
##### Derek Wyatt (<a href="https://twitter.com/derekwyatt">@derekwyatt</a>) -- Tue, 19th Jul 2011, 8:59pm GMT
<div class="comment-body" markdown="1">
Really nice stuff. I thought, for a split second at the end of your post, that you wrote a book on Scala ... I was
disappointed when I clued in :)

Thanks a lot for the explanation.
</div>
</div>

<div markdown="1">
##### Sandipan Razzaque (<a href="https://twitter.com/srazzaque">@srazzaque</a>) -- Sun, 24th Jul 2011, 8:02am GMT
<div class="comment-body" markdown="1">
Great post! Thanks – just FYI I had to make the following change to the `MultDep` function in order to get it to
compile (I’m using 2.9.0-1),

```scala
trait MultDep[-A, -B, C] extends Function2[A, B, C]
```

Still not 100% sure on the underlying mechanics of why this was needed (I’m still learning, need to read up more on
Scala’s type system and variance I guess), but see [here](http://pastebin.com/4Kwm1EDv) for a working example.
</div>
</div>

<div markdown="1">
##### Miles Sabin (<a href="https://twitter.com/milessabin">@milessabin</a>) -- Sun, 24th Jul 2011, 9:21am GMT
<div class="comment-body" markdown="1">
**@srazzaque** Thanks for the heads up — yes, it does appear that it works on Scala trunk (ie. later than 2.9.0-1),
but that variance annotations are needed in the definition of `MultDep` for earlier versions. I’ve updated the post
accordingly.
</div>
</div>

<div markdown="1">
##### Hugo Sereno Ferreira (<a href="https://twitter.com/ferreira_hugo">@ferreira_hugo</a>) -- Wed, 9th May 2012, 5:45pm GMT
<div class="comment-body" markdown="1">
Thank for your article, it was very elucidative on the subject. Although, I’m wondering if the example (Matrixes)
clearly covers all the benefits in Functional Dependency. Couldn’t I achieve the same result through method
overloading?

```scala
class ... {
  def mult(a: Matrix, b: Matrix): Matrix = ...
  def mult(a: Matrix, b: Vector): Vector = ...
  def mult(a: Matrix, b: Int): Matrix = ...
  def mult(a: Int, b: Matrix): Matrix = ...
}
```
</div>
</div>

<div markdown="1">
##### Miles Sabin (<a href="https://twitter.com/milessabin">@milessabin</a>) -- Thu, 10th May 2012, 1:57pm GMT
<div class="comment-body" markdown="1">
**@ferreira_hugo** You’re quite right ... see my comments starting "Of course, neither of these two examples are
particularly exciting in Scala as they stand — Scala has Java-style overloading, which makes the matrix/vector/scalar
example mostly redundant ..." and the discussion from there on.
</div>
</div>

<div markdown="1">
##### Rahul Goma Phulore (<a href="https://twitter.com/missingfaktor">@missingfaktor</a>) -- Sat, 23rd Jun 2012, 4:44pm GMT
<div class="comment-body" markdown="1">
Let’s consider the ExtractDep example. Here, we want `B` to not be a free type variable (as says
[this page](http://www.haskell.org/haskellwiki/Functional_dependencies#Examples)). So I think, in Scala, it would be
better to express it as an abstract type instead of as a type parameter. That IMO makes this "dependent type" intent
more clear.

```scala
trait ExtractDep[A] {
  type B
  def apply(a : A) : B
}

implicit def ep[P, Q] = new ExtractDep[(P, Q)] {
  type B = P
  def apply(p : (P, Q)) : P = p._1
}

// etc
```
</div>
</div>







<!--
COMMENTS_END
-->

{% include comment-footer.html %}


