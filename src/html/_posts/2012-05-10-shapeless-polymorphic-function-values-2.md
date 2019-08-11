---
layout:     post
title:      First-class polymorphic function values in shapeless (2 of 3) &mdash; Natural Transformations in Scala
author:     Miles Sabin
date:       '2012-05-10 12:00:00'
---

[Last time][part1] we saw that Scala's standard function values weren't going to help us in our goal of mapping over
an `HList` because they're insufficiently polymorphic. In this article I'm going to start exploring how we can address
that problem. <span class="break"></span> The techniques I'm going to explain are fairly well known and extremely
useful where applicable, but ultimately they're not quite enough to get us all the way there --- however they will set
the scene for a solution which is.

As our running examples of polymorphic functions, let's take the `singleton` function from last time (which given an
argument of type `T` should return a single element `Set[T]` containing it), the `headOption` function (which given an
argument of type `List[T]` gives us back its head as an `Option[T]`), the `identity` function (which returns its
argument unchanged), and a generic `size` function which will compute an integer size appropriate to the type of its
argument (eg. the size of a `List` or a `String` will be its length).

This is how we expect them to behave in the REPL,

```scala
scala> singleton("foo")
res0: Set[String] = Set(foo)

scala> identity(1.0)
res1: Double = 1.0

scala> headOption(List(1, 2, 3))
res2: Option[Int] = Some(1)

scala> size("foo")
res3: Int = 3

scala> size(List(1, 2, 3, 4))
res4: Int = 4 
```

The function-like signatures for each of these are as follows,

|                |                             |
|----------------|-----------------------------|
| `singleton`    | `(∀T) T => Set[T]`          |
| `identity`     | `(∀T) T => T`               |
| `headOption`   | `(∀T) List[T] => Option[T]` |
| `size`         | `(∀T) T => Int`             |

I say "function-like" here because, of course, Scala can't directly express generic function value types of this form
--- that's the problem we're trying to solve.

### Polymorphism lost, polymorphism regained

Recall from the preceeding article that the explanation for Scala's function values being monomorphic is that the
polymorphism of the `FunctionN` traits is fixed at the point at which they're instantiated rather than the point at
which they're applied. This follows immediately from the position that their type parameters occur in their
definition. For example, for `Function1`,

```scala
trait Function1[-T, +R] { def apply(t: T): R }
```

As you can see, the argument and result type parameters are declared at the trait level and hence are fixed for each
invocation of the `apply` method.

The natural move at this point is try to shift the type parameters off `Function1` and onto the `apply` method making
it polymorphic independently of its enclosing trait --- as we saw last time, the combination of polymorphic methods
and call site eta-expansion gets us something that looks very much like a polymorphic function value.

We still want to be left with a first class type, values of which can be passed as arguments to higher-order
functions, so we have to keep an enclosing type of some sort. A first naive pass at this might look something like,

```scala
trait PolyFunction1 {
  def apply[T, R](t: T): R
}
```

But this won't do at all, as we discover as soon as we try to implement it.

The problem we immediately run up against is that the result type of the `apply` method of our `PolyFunction1` trait
is completely unconstrained. But the signatures we're trying to implement require that the result type be determined
by the argument type (`singleton`, `identity`, `headOption`) or constant (`size`). There's no way that we can map
those signatures into the form required for the common trait.

Unconstrained result type parameters are in any case problematic when it comes to type inference, as I discussed in an
[earlier article][fundeps], so let's start by focussing on the `singleton` case where it's easy to view the result
type as a simple function of the argument type. This leads us to a second pass at a polymorphic function trait which
captures that idea directly in terms of a higher-kinded trait-level type parameter --- the higher-kinded type
parameter is going act as a type-level function,

```scala
trait PolyFunction1[F[_]] {
  def apply[T](t: T): F[T]
}
```

We can now define `singleton` as follows,

```scala
object singleton extends PolyFunction1[Set] {
  def apply[T](t: T): Set[T] = Set(t)
}
```

and this behaves more or less as you'd expect --- in particular, note the inferred result types,

```scala
scala> singleton(23)
res0: Set[Int] = Set(23)

scala> singleton("foo")
res1: Set[String] = Set(foo)
```

So far so good. Now, can we squeeze `identity` into the same mould? To do that we need to find a higher-kinded type
for the `F` type-argument to `PolyFunction1` such that `F[T] = T` --- a _type-level_ identity function in fact!
Scala's type aliases make such a type extremely straightforward to define --- it's just,

```scala
type Id[T] = T
```

Now we can define and apply the identity function like so,

```scala
object identity extends PolyFunction1[Id] {
  def apply[T](t: T): T = t
}

scala> identity(23)
res0: Int = 23

scala> identity("foo")
res1: java.lang.String = foo
```

Next up is `headOption`. In this case we have a signature that has constraints on its argument type as well, not just
on its result type as was the case for `singleton` and `identity`. Hopefully, though, it should be clear that we can
repeat the same trick, and view _both_ the argument type and the result type as functions of a common underlying type.
This leads us to a third pass at the polymorphic function trait which this time has two higher-kinded trait-level type
parameters --- one to constrain the argument type and one to constrain the result type,

```scala
trait PolyFunction1[F[_], G[_]] {
  def apply[T](f: F[T]): G[T]
}
```

And now we can define our first three functions as follows,

```scala
object singleton extends PolyFunction1[Id, Set] {
  def apply[T](t: T): Set[T] = Set(t)
}

object identity extends PolyFunction1[Id, Id] {
  def apply[T](t: T): T = t
}

object headOption extends PolyFunction1[List, Option] {
  def apply[T](l: List[T]): Option[T] = l.headOption
}

scala> singleton("foo")
res0: Set[java.lang.String] = Set(foo)

scala> identity(1.0)
res1: Double = 1.0

scala> headOption(List(1, 2, 3))
res2: Option[Int] = Some(1)
```

That just leaves the `size` function. Handling that entails making the constant result type `Int` take the form of a
higher-kinded type as well. We can do that with the help of a [type lambda][typelambda] representing a type-level
function from an arbitrary type `T` to some constant type `C`,

```scala
type Const[C] = {
  type λ[T] = C
}
```

For the particular case of type `Const[Int]`, it is a structural type with a higher-kinded type member `λ[_]` which is
equal to `Int` no matter what type argument it is applied to. So the type `Const[Int]#λ[T]` will be equal to type
`Int` whatever type we substitute for `T`. Here's short REPL session demonstrating that,

```scala
scala> implicitly[Const[Int]#λ[String] =:= Int]
res0: =:=[Int,Int] = <function1>

scala> implicitly[Const[Int]#λ[Boolean] =:= Int]
res1: =:=[Int,Int] = <function1>
```

This is a type-level rendering of the value-level constant function that you might also know as the _K combinator_
from the [SKI calculus][ski] (or as a "Kestrel" if you're a [Ray Smullyan][smullyan] fan),

```scala
def const[T](t: T)(x: T) = t

scala> val const3 = const(3) _
const3: Int => Int = <function1>

scala> const3(23)
res6: Int = 3
```

With this in hand we can begin to define a size function that implements the same `PolyFunction1` trait as
`singleton`, `identity` and `headOption`,

```scala
object size extends PolyFunction1[Id, Const[Int]#λ] {
  def apply[T](t: T): Int = 0
}

scala> size(List(1, 2, 3, 4))
res0: Int = 0

scala> size("foo")
res1: Int = 0
```

We have the signature right, at least, but what about the implementation of the `apply` method? Just returning a
constant `0` isn't particularly interesting. Unfortunately we don't have much to work with --- the use of `Id` on the
argument side is what allows this function to be applicable to both `List` and `String`, but the direct consequence
of that generality is that within the body of the method we have no knowledge about the type of the argument, so we
have no immediate way of computing an appropriate result.

We can pattern match here of course, but as we'll see that's not a particularly desirable solution. For now let's just
go with that, and note a distinct lingering code smell,

```scala
object size extends PolyFunction1[Id, Const[Int]#λ] {
  def apply[T](t: T): Int = t match {
    case l: List[_] => l.length
    case s: String  => s.length
    case _ => 0
  }
}

scala> size(List(1, 2, 3, 4))
res0: Int = 4

scala> size("foo")
res1: Int = 3

scala> size(23)
res2: Int = 0
```

### A spoon full of sugar

Parenthetically, I'd like to flag up a small syntactic tweak that we can make to the `PolyFunction1` trait which takes
advantage of symbolic names in Scala and the ability to write types with two type arguments using an infix notation.
The latter allows us to write types of the form `T[X, Y]` as `X T Y`. And if we choose the name `T` carefully this can
give us a very syntactically elegant way of expressing the concept we're trying to render.

Here we're talking about the types of function-like things, so something which puns on Scala's function arrow symbol
`=>` is a good choice --- let's use `~>`. Our trait now looks like this,

```scala
trait ~>[F[_], G[_]] {
  def apply[T](f: F[T]): G[T]
}
```

and our definitions look a lot more visibly function-like,

```scala
object singleton extends (Id ~> Set) {
  def apply[T](t: T): Set[T] = Set(t)
}

object identity extends (Id ~> Id) {
  def apply[T](t: T): T = t
}

object headOption extends (List ~> Option) {
  def apply[T](l: List[T]): Option[T] = l.headOption
}

object size extends (Id ~> Const[Int]#λ) {
  def apply[T](t: T): Int = t match {
    case l: List[_] => l.length
    case s: String  => s.length
    case _ => 0
  }
}
```

### Function-<i>like</i>?

I've been careful to describe these things as "function-like" values rather than as functions to emphasize that they
don't and can't conform to Scala's standard `FunctionN` types. The immediate upshot of this is that they can't be
directly passed as arguments to any higher-order function which expects to receive an ordinary Scala function
argument. For example,

```scala
scala> List(1, 2, 3) map singleton
<console>:11: error: type mismatch;
 found   : singleton.type (with underlying type object singleton)
 required: Int => ?
```

We can fix this however --- whilst `~>` can't extend `Function1`, we can use an implicit conversion to do a job
similar to the one that eta-expansion does for polymorphic methods,

```scala
implicit def polyToMono[F[_], G[_], T]
  (f: F ~> G): F[T] => G[T] = f(_)
```

This is along the right lines, but unfortunately due to a current limitation in Scala's type inference this won't work
for functions like singleton that are parametrized with `Id` or `Const` because those types will never be inferred for
`F[_]` or `G[_]`. We can help out the Scala compiler with a few additional implicit conversions to cover all the
relevant permutations of those cases,

```scala
implicit def polyToMono2[G[_], T](f: Id ~> G): T => G[T] = f(_)
implicit def polyToMono3[F[_], T](f: F ~> Id): F[T] => T = f(_)
implicit def polyToMono4[T](f: Id ~> Id): T => T = f[T](_)
implicit def polyToMono5[G, T](f: Id ~> Const[G]#λ): T => G = f(_)
implicit def polyToMono6[F[_], G, T]
  (f: F ~> Const[G]# λ): F[T] => G = f(_)
```

With these in place we can map `singleton` over an ordinary Scala `List`,

```scala
scala> List(1, 2, 3) map singleton
res0: List[Set[Int]] = List(Set(1), Set(2), Set(3))
```

### Natural transformations and their discontents

This encoding of polymorphic function values in Scala has been around [for][scalauser] [quite][scaladebate]
[some][washburn] [time][apocalisp] --- in fact more or less from the point at which higher-kinded types arrived in the
language. And, as a representation of a [natural transformation][nattrans], it's been put to good use in
[scalaz][scalaz].

So we're done, right? Well, no, not really. Whilst function-like values of this form are undoubtedly useful, they have
a number of shortcomings which make them less than ideal in general. Let's have a look at some of them now.

The first problem we saw earlier in the implementation of the `size` function,

```scala
object size extends (Id ~> Const[Int]# λ) {
  def apply[T](t: T): Int = t match {
    case l: List[_] => l.length
    case s: String  => s.length
    case _ => 0
  }
}
```

Because the apply method's type parameter `T` is completely unconstrained, the type of the argument `t` within the
method body is effectively `Any`. In other words, the compiler knows nothing at all about its shape, specifically it
can't know that it has a `length` method yielding an `Int`.

We can pattern match to recover some type information as we've done above, but this is unsatisfactory for several
reasons. First, we have to be careful to handle all cases or risk being hit by a `MatchError` --- that forces us to
include a possibly artifical default case, or take our chances at runtime. It's also hopelessly non-modular --- if we
want to add cases for additional types then we have to modify this definition rather than adding orthogonal code to
handle the new cases. Not good.

Second we have to be aware of the limitations of pattern matching in the face of type erasure. For example, suppose we
had wanted to define the size of a `List[String]` as the sum of the lengths of its `String` elements. We might try
something like,

```scala
object size extends (Id ~> Const[Int]# λ) {
  def apply[T](t: T): Int = t match {
    case l: List[String] => l.map(_.length).sum
    case l: List[_] => l.length
    case s: String  => s.length
    case _ => 0
  }
}
```

We get a warning from this definition,

```scala
warning: non variable type-argument String in type pattern
  List[String] is unchecked since it is eliminated by erasure
```

but let's carry on regardless and try it out on the REPL,

```scala
scala> size(List("foo", "bar", "baz"))
res0: Int = 9
```

So far so good. But suppose we try with a list of non-`String`,

```scala
scala> size2(List(1, 2, 3))
java.lang.ClassCastException:
  java.lang.Integer cannot be cast to java.lang.String
```

Oops! --- that unchecked warning was telling us that Scala's pattern matching runtime infrastructure (or rather, the
parts of the JVM's runtime infrastructure which support Scala's pattern matching) is unable to verify the types of the
elements of a `List` because the element type is erased at runtime. Consequently the first case, `List[String]`, is
always selected, and this fails at runtime if handed a list of anything other than `String` elements. Also not good.

The conclusion to draw from this is that implementing a polymorphic function of this form via pattern matching is
unworkable if we want type safety, modularity or type-specific cases which are distinguished by particular type
arguments of a common type constructor.

If pattern matching is ruled out, then what can we do? Well, we can do anything which doesn't depend on the shape of
`T`. That's trivially the case for the `identity` function --- it simply returns it's argument unexamined. And it's
also the case for methods which are themselves polymorphic in the the same way that our `apply` method is. That's
what's happening in the definition of `singleton`. Here it is again with a little less syntactic sugar,

```scala
object singleton extends (Id ~> Set) {
  def apply[T](t: T): Set[T] = Set.apply[T](t)
}
```

The `apply` method (parametric in `T`) is implemented in terms of the `Set` companion object's `apply` method (also
parametric in `T`). No information is needed about the shape of `T` here because the `Set` factory method doesn't need
to examine its arguments, it just needs to wrap them in a fresh container.

Things like `headOption` are also fine, this time because we _do_ have a constraint on the type of the argument to the
`apply` method --- here we know that the outer type constructor is `List[_]`. That means that we can implement the
method in terms of any methods defined on `List` which don't themselves need to know anything about the shape of `T`
(this excludes methods like `sum` and `product` for example).

Clearly this gives us quite a bit to work with, and if you can manage with the constraints that
[parametricity](http://en.wikipedia.org/wiki/Parametricity) imposes, then it's definitely the way to go. But it's a
real constraint with sharp teeth --- we won't be able to implement polymorphic functions like `size` in this way.

The fact that our problems are caused by lacking information about the shape of `T` might encourage us to explore the
option of modifying the `~>` trait to add bounds on `T` (ordinary type bounds or view or context bounds). This is an
interesting exercise to attempt, but ultimately it adds a lot of complexity without solving the problem fully
generally. I encourage you to give it a try --- if you do, you'll very quickly find yourself wanting to be able to
abstract over function signatures more generally, and that's going to take us in a different direction as we'll see in
the next part of this series.

[part1]: /blog/2012/04/27/shapeless-polymorphic-function-values-1
[fundeps]: /blog/2011/07/16/fundeps-in-scala
[typelambda]: http://stackoverflow.com/questions/8736164
[ski]: http://en.wikipedia.org/wiki/SKI_combinator_calculus
[smullyan]: http://en.wikipedia.org/wiki/To_Mock_a_Mockingbird
[scalauser]: http://article.gmane.org/gmane.comp.lang.scala.user/697
[scaladebate]: http://scala-programming-language.1934581.n4.nabble.com/Higher-ranked-types-td2006150.html
[washburn]: http://existentialtype.net/2008/05/26/revisiting-higher-rank-impredicative-polymorphism-in-scala/
[apocalisp]: http://apocalisp.wordpress.com/2010/07/02/higher-rank-polymorphism-in-scala/
[nattrans]: http://en.wikipedia.org/wiki/Natural_transformation
[scalaz]: https://github.com/scalaz/scalaz/blob/master/core/src/main/scala/scalaz/Extras.scala#L8

{% include comment-header.html %}

<div markdown="1">
##### Reuben Doetsch (<a href="https://twitter.com/reubendoetsch">@reubendoetsch</a>) -- Sun, 20th May 2012, 12:54am GMT
<div class="comment-body" markdown="1">
Great article and thank you. For the issues with matching on size, couldn’t a scalaz like type class be used (which
defaults to 0 if no implicit conversion exists, either through type magic or creating a more generic implicit
conversion from `Any` to the typeclass) I don’t know if this is possible and you are the scala type guru.
</div>
</div>

<div markdown="1">
##### Miles Sabin (<a href="https://twitter.com/milessabin">@milessabin</a>) -- Sun, 20th May 2012, 12:56am GMT
<div class="comment-body" markdown="1">
You’re anticipating part three ... type classes are indeed a key part of the solution.
</div>
</div>

<div markdown="1">
##### Robbie Coleman (<a href="https://twitter.com/erraggy">@erraggy</a>) -- Fri, 16th May 2013, 10:30pm GMT
<div class="comment-body" markdown="1">
Is part three going to happen? I’m just desperately clinging to the cliff-hanger. :D
</div>
</div>

<div markdown="1">
##### Miles Sabin (<a href="https://twitter.com/milessabin">@milessabin</a>) -- Sat, 5th Oct 2013, 3:08pm GMT
<div class="comment-body" markdown="1">
Yes, I’m afraid this is turning into a bit of a Duke Nukem Forever ... I’ll try to get to it soon.
</div>
</div>

<!--- START COMMENT 3ad97e2e3b8fad33037e0a0d30bf1db3b1697785 -->

<div markdown="1">
#####  <a href="http://aravindh.io">aravindh</a> (<a href="https://twitter.com/hardvain">@hardvain</a>) -- Sun, 10th Jan 2016, 2:40am GMT
<div class="comment-body" markdown="1">
Hi Miles, I thoroughly enjoyed reading the article. What about the last part of the series?
</div>
</div>

<!--- END COMMENT 3ad97e2e3b8fad33037e0a0d30bf1db3b1697785 -->


<!--- START COMMENT 606b981cb3f044f75a67ee01aeb094fdd65bf57c -->

<div markdown="1">
##### Max -- Tue, 9th Feb 2016, 12:32am GMT
<div class="comment-body" markdown="1">
Great article! I'm looking forward to the last part, too.
</div>
</div>

<!--- END COMMENT 606b981cb3f044f75a67ee01aeb094fdd65bf57c -->


<!--- START COMMENT 25113e6ef83ad878423bd1fbf1bb905fb1497a6b -->

<div markdown="1">
##### jvliwanag (<a href="https://twitter.com/jan247">@jan247</a>) -- Wed, 30th Mar 2016, 4:39pm BST
<div class="comment-body" markdown="1">
Looks like 2016 is the year when at least one stumbles upon this article, thoroughly enjoys this, and sincerely hopes the third part does get written. ;)
</div>
</div>

<!--- END COMMENT 25113e6ef83ad878423bd1fbf1bb905fb1497a6b -->


<!--- START COMMENT f28fbf1b8f544b8dea525b86e4a34a77ca54aa3b -->

##### Alex Cole -- Sun, 11th Aug 2019, 9:16pm BST
<div class="comment-body" markdown="1">
So... how's part 3 coming?
</div>


<!--- END COMMENT f28fbf1b8f544b8dea525b86e4a34a77ca54aa3b -->






<!--
COMMENTS_END
-->

{% include comment-footer.html %}

