---
layout:     post
title:      First-class polymorphic function values in shapeless (1 of 3) &mdash; Function values in Scala
author:     Miles Sabin
date:       '2012-04-27 12:00:00'
---

One of the distinguishing features of the [`HList`][hlist] (a data structure which combines the characteristics of
both sequences and tuples) implementation in [shapeless][shapeless] is its support for a `map()` higher-order function
which, superficially at least, appears to operate very similarly to the one defined on ordinary Scala collection types
like `List`,

<span class="break"></span>

```scala
scala> import shapeless._ ; import HList._

// List[Int]
scala> List(1, 2, 3) map singleton
res0: List[Set[Int]] = List(Set(1), Set(2), Set(3))

// List[String]
scala> List("foo", "bar", "baz") map singleton
res1: List[Set[String]] = List(Set(foo), Set(bar), Set(baz))

// HList
scala> (23 :: "foo" :: false :: HNil) map singleton
res2: Set[Int] :: Set[String] :: Set[Boolean] :: HNil =
      Set(23)  :: Set(foo)    :: Set(false)   :: HNil
```

(here `singleton()` is a function which makes a single element `Set` from its argument).

Arranging for things to work out this smoothly involves quite a bit of hidden sophistication, and in this short series
of articles I'll explain what that sophistication is and why it's necessary.

The first observation to make about the REPL transcript above is that the `singleton()` function is an argument to the
`map()` higher-order functions defined for `List` and `HList`. This is part and parcel of Scala making good on its
claim to blend object-oriented and functional programming styles by representing functions as values.

The second observation to make is that this function is being applied to arguments of several different types ---
`Int`, `String`, and `Boolean`. In other words, the function is _polymorphic_ in its argument type.

Given that there's nothing at all unusual looking about the first two uses of `map` above (over the vanilla lists) you
might put these two observations together and quite reasonably conclude that Scala directly supports polymorphic
function values.

That's not the case, however. Appearances to the contrary, all Scala values (and hence Scala _function_ values in
particular) are monomorphic (in the sense relevant here, see qualifications below), and representing polymorphic
functions requires some work.

Before we get to that, we need to understand method-level parametric polymorphism in Scala. And we need to understand
the differences between between Scala's methods and Scala's function values. With that in hand we'll be able to see
why Scala's standard function values can only be monomorphic. That will set the stage for our exploration of ways to
encode polymorphic function values in parts 2 and 3 of this series.

### Method-level parametric polymorphism

The best way to get to grips with method-level parametric polymorphism is to compare the definitions and uses of a
monomorphic and a polymorphic method. At the point of definition the constrast is simply between those methods with
arguments of fixed types and those with arguments which have a type that is bound by a method-level type parameter.
So, for example,

```scala
// Monomorphic methods have type parameter-free signatures
def monomorphic(s: String): Int = s.length

monomorphic("foo") 

// Polymorphic methods have type parameters in their signatures
def polymorphic[T](l: List[T]): Int = l.length

polymorphic(List(1, 2, 3))
polymorphic(List("foo", "bar", "baz"))
```

Monomorphic methods can only be applied to arguments of the fixed types specified in their signatures (and their
subtypes, I'll come back to this in a moment), whereas polymorphic methods can be applied to arguments of any types
which correspond to acceptable choices for their type parameters --- in the example just given we can apply
`monomorphic()` to values of type `String` only, but we can apply `polymorphic()` to values of type `List[Int]` or
`List[String]` or ... `List[T]` for any type `T`.

Of course, Scala is both an object-oriented and a functional programming language, so as well as parametric
polymorphism (ie. polymorphism captured by type parameters) it also exhibits subtype polymorphism. That means that the
methods that I've been calling monomorphic are only monomorphic in the sense of parametric polymorphism and they can
in fact be polymorphic in the traditional object-oriented way. For instance,

```scala
trait Base { def foo: Int }
class Derived1 extends Base { def foo = 1 }
class Derived2 extends Base { def foo = 2 }

def subtypePolymorphic(b: Base) = b.foo

subtypePolymorphic(new Derived1) // OK: Derived1 <: Base
subtypePolymorphic(new Derived2) // OK: Derived2 <: Base
```

Here the method `subtypePolymorphic()` has no type parameters, so it's parametrically monomorphic. Nevertheless, it
can be applied to values of more than one type as long as those types stand in a subtype relationship to the fixed
`Base` type which is specified in the method signature --- in other words, this method is _both_ parametrically
monomorphic _and_ subtype polymorphic.

It's parametric polymorphism that I'll be talking about in the remainder of this article and the sequel --- I won't be
mentioning subtype polymorphism again, and from now on I'll just talk about methods and functions being monomorphic or
polymorphic without a "parametric" qualifier.

### Methods vs. function values

So far I've been talking about Scala methods ... now we need to understand how they differ from Scala function values.
Scala methods are exactly like Java methods: they're components of classes or traits and aren't first-class values in
their own right. Scala function values, on the other hand, are first-class values and are represented by JVM-level
classes rather than being components of some other class. It's the first-class value nature of Scala function values
which allows them to be passed as arguments to the higher-order functions and methods which give Scala it's functional
flavour.

Nevertheless, Scala methods can have a very function-like feel, particularly when they're defined on Scala objects
used as modules, or nested inside other method or function definitions. In these cases they appear to be free
floating, lacking the implicit left-hand-side "receiver" argument characteristic of object-oriented methods. And in
many cases they can be used in applications of higher-order functions without any visible additional ceremony. For
example,

```scala
scala> object Module {
     |   def stringSingleton(s: String) = Set(s)
     | }
defined module Module

scala> import Module._
import Module._

scala> stringSingleton("foo")
res0: Set[String] = Set(foo)

scala> List("foo", "bar", "baz") map stringSingleton
res1: List[Set[String]] = List(Set(foo), Set(bar), Set(baz))
```

The `stringSingleton()` method of the `Module` object appears to be indistinguishable from a first-class function
value. But the appearances are deceptive. The method isn't free-standing: we could have used `this` in its body and it
would have referred to the `Module` singleton object, even after the import. And it's not the method which is passed
to `map` --- instead a transient function value is implicitly created to invoke the `stringSingleton()` method (this
is a process known as eta-expansion) and it's that function-value which is passed to `map`.

Fortunately these mechanics are completely invisible most of the time, but they're relevant to us now, so let's make
them a bit more visible. We can ask explicitly for the Scala compiler to give us the eta-expanded function value,
allowing us to give it a name and discover its type. We do this using Scala's multipurpose "\_" --- in this
manifestation it's acting as a function-value-forming operator,

```scala
scala> val stringSingletonFn = stringSingleton _
stringSingletonFn: (String) => Set[String] = <function1>

scala> stringSingletonFn("foo")
res2: Set[String] = Set(foo)

scala> List("foo", "bar", "baz") map stringSingletonFn
res3: List[Set[String]] = List(Set(foo), Set(bar), Set(baz))
```

This sequence is exactly equivalent to what we had before, but now we can see that a new function value of type
`(String) => Set[String]` has been created --- it's this which is passed to `map`.

In this instance both the method and the eta-expanded function value are monomorphic. Let's see what happens if we try
to do the same thing with a polymorphic method,

```scala
scala> def singleton[T](t: T) = Set(t)
singleton: [T](t: T)Set[T]

scala> singleton("foo")
res4: Set[java.lang.String] = Set(foo)

scala> singleton(23)
res5: Set[Int] = Set(23)
```

So far so good --- our method can be applied at arbitrary types as expected. Now let's try explicitly eta-expanding
this, as we did in the monomorphic case,

```scala
scala> val singletonFn = singleton _
singletonFn: (Nothing) => Set[Nothing] = <function1>

scala> singletonFn("foo")
<console>:14: error: type mismatch;
 found   : java.lang.String("foo")
 required: Nothing
       singletonFn("foo")
                   ^

scala> singletonFn(23)
<console>:14: error: type mismatch;
 found   : Int(23)
 required: Nothing
       singletonFn(23)
                   ^
```

Ouch! Something's gone badly wrong here. Look at the type inferred for singletonFn! In the earlier monomorphic case,
the type of our eta expanded function was quite straightforward and unsurprising: `(String) => Set[String]`. But here
we have `(Nothing) => Set[Nothing]` --- where has this `Nothing` come from? And what's happened to the
polymorphism of the underlying method? To see what's going on we'll need to dig a little deeper into Scala's function
types and how function values are represented.

### Scala function types

One of the joys of Scala's mixed object-functional design is that there's nothing particularly special about function
types: `(String) => Set[String]` is simply syntactic sugar for one of a family of `FunctionN` traits, one for each
function arity between 0 and (somewhat arbitrarily) 22. In this particular case we have a function with a single
argument, so the function value is an instance of the [`Function1`][function1] trait. Simplifying a little, that trait
and the implementation of the `stringSingletonFn` instance of it looks like this,

```scala
trait Function1[-T, +R] {
  def apply(v: T): R
}

val stringSingletonFn = new Function1[String, Set[String]] {
  def apply(v: String): Int = Module.stringSingleton(v)
}
```
 
The crucial thing to notice is that the function's argument and result type parameters are all declared at the trait
level. This has two consequences. The first is that when we create an instance of `Function1` we (or the compiler)
must choose the argument and result types at that point. In the eta-expansion expression above we haven't explicitly
specified the argument type, so the compiler is left to infer it, and since there is no useful information for it to
work with, it fills the argument type in as `Nothing`.

The second is an immediate consequence of the first --- because we (or the compiler) must choose the argument and
result types at the point at which the function value is created they are fixed, once and for all, from that point on.
This means that even if we were to eliminate `Nothing` by specifying an argument type we would still have a problem,

```scala
scala> val singletonFn: String => Set[String] = singleton _
singletonFn: (String) => Set[String] = <function1>

scala> singletonFn("foo")
res6: Set[String] = Set(foo)

scala> singletonFn(23)
<console>:14: error: type mismatch;
 found   : Int(23)
 required: String
       singletonFn(23)
                   ^
```

Having specified that we want our function value instantiated to accept `String` arguments we are stuck with that
choice forever after. Or, in other words, we have completely lost the polymorphism of the underlying method.

Returning to our example from the introduction --- where we have an ordinary Scala `List`, if we take the above
polymorphic method definition of `singleton()` we get an appearance of polymorphic function values,

```scala
scala> def singleton[T](t: T) = Set(t)
singleton: [T](t: T)Set[T]

// eta-expanded to Int => Set[Int]
scala> List(1, 2, 3) map singleton
res0: List[Set[Int]] = List(Set(1), Set(2), Set(3))

// eta-expanded to String => Set[String] 
scala> List("foo", "bar", "baz") map singleton
res1: List[Set[String]] = List(Set(foo), Set(bar), Set(baz))
```

This is because the polymorphic _method_ is eta-expanded _each time_ it's used as an argument to `map()`, first with
`T` instantiated as `Int` and then with it instantiated as `String`. But in both cases the resulting function value
has a fixed argument type, ie. is monomorphic. And that's just fine, because each particular `List` only has elements
of one fixed type as well.

But now consider the `HList` case --- here we have only _one_ application of `map()`, hence we only have one
opportunity for eta-expansion. This can only deliver _one_ standard Scala function value, and that function value can
be applied to arguments of just _one_ fixed type. But we need _more than one_ ... Oops!

So here we have the crux of the problem --- we can have first-class monomorphic function values and we can have
second-class polymorphic methods, but we can't have first-class polymorphic function values ... at least we can't with
the standard Scala definitions. And yet it's first-class polymorphic function values that we need to map over an
`HList` ... what to do?

In the next article in this series I'll start explaining how we can get the best of both worlds ...

[hlist]: https://github.com/milessabin/shapeless/blob/master/core/src/main/scala/shapeless/hlists.scala
[shapeless]: https://github.com/milessabin/shapeless
[function1]: http://www.scala-lang.org/api/current/index.html#scala.Function1


<!--- START COMMENT cb9159a88836685a4d9ae4cd3dcb76da870f965c -->

##### Armin Keyvanloo -- Wed, 6th Jul 2016, 11:20pm BST
Miles, really well written and easy to follow.  Thanks 

---


<!--- END COMMENT cb9159a88836685a4d9ae4cd3dcb76da870f965c -->


<!--- START COMMENT 9fdef479613a3a53b51076713ccdb249b86c59d2 -->

##### Bart Jenkins (<a href="https://twitter.com/picoforge">@picoforge</a>) -- Thu, 14th Jul 2016, 2:50pm BST
Excellent article - Really clear and easy to follow with no magical hand-waving! One thing, I think I see a typo:
Under the section of Scala function types shouldn’t:
```val stringSingletonFn = new Function1[String, Set[String]] {
def apply(v: String): Int = Module.stringSingleton(v)
}```
be
```val stringSingletonFn = new Function1[String, Set[String]] {
def apply(v: String): Set[String] = Module.stringSingleton(v)
}
```

---


<!--- END COMMENT 9fdef479613a3a53b51076713ccdb249b86c59d2 -->






