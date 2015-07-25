---
layout:     post
title:      Unboxed union types in Scala via the Curry-Howard isomorphism
author:     Miles Sabin
date:       '2011-06-09 12:00:00'
---

Scala has a highly expressive type system, but it doesn't include everything you might find yourself hankering after
--- at least, not as primitives.  There are a few genuinely useful things which fall under this heading ---
higher-rank polymorphic function types and recursive structural types are two I'll talk about more in later posts.
Today I'm going to show how we can encode union types in Scala, in the course of which I'll have an opportunity to
shed a little light on the Curry-Howard isomorphism and show how it can be put to work for us.

<span class="break"></span>

So, first up, what is a union type? A union type is pretty much what you'd expect: it's the union of two (or more, but
I'll limit this discussion to just two) types. The values of that type are all of the values of each of the types that
it's the union of. An example will help to make this clear, but first a little notation --- for reasons which will
become apparent later I'll write the union of types `T` and `U` as `T ∨ U` (ie. the two types flanking the logical
'or' operator), and so we write the union of the types `Int` and `String` as `Int ∨ String`. The values of this union
type are all the values of type `Int` and all the values of type `String`.

What does this mean more concretely? It means that if we could express this type directly in Scala we would be able to
write,

```scala
def size(x: Int ∨ String) = x match {
  case i: Int => i
  case s: String => s.length
}

size(23) == 23   // OK
size("foo") == 3 // OK
size(1.0)        // Not OK, compile time error
```

In other words, the size method would accept arguments of either type `Int` or type `String` (and their subtypes,
`Null` and `Nothing`) and nothing else.

It's important to recognize the difference between this use of a union type and the similar use of Scala's standard
`Either`. `Either` is what's known as a sum type, the analog of union types in languages which don't support
subtyping.  Recasting our example in terms of `Either` we get,

```scala
def size(x: Either[Int, String]) = x match {
  case Left(i) => i
  case Right(s) => s.length
}

size(Left(23)) == 23    // OK
size(Right("foo")) == 3 // OK
```

`Either[Int, String]` can model the union type `Int ∨ String` because there is an isomorphism between the two types
and their values. But equally clearly the `Either` type manages this by way of a layer of boxed representation, rather
then by being an unboxed primitive feature of the type system. Can we do better than `Either`? Can we find a way of
representing union types in Scala which doesn't require boxing, and which provides all of the static guarantees we
would expect?

It turns out that we can, but to get there we have take a detour through first-order logic via the [Curry-Howard
isomorphism][curry-howard]. Curry-Howard tells us that the relationships between types in a type system can be viewed
as an image of the relationships between propositions in a logical system (and vice versa). There are various ways
that we can fill that claim out, depending on the type system we're talking about and the logical system we're working
with, but for the purposes of this discussion I'm going to ignore most of the details and focus on simple examples.

To illustrate Curry-Howard (in the context of a type system with subtyping like Scala's), we can see that there is a
correspondence between intersection types (`A with B` in Scala) and logical conjunction (`A ∧ B`); between my
hypothetical union types (`A ∨ B`) and logical disjunction (also `A ∨ B`, as hinted earlier); and between subtyping
(`A <: B` in Scala) and logical implication (`A ⇒ B`). On the left hand side of each row in the table below we have a
subtype relationship which is valid in Scala (although, in the case of the union types at the bottom, not directly
expressible), and on the right hand side we have a logical formula which is obtained from the type relationship on the
left by simply rewriting (`with` to `∧` and `<:` to `⇒`) --- in each case the result of the rewriting is a logically
valid.

|                   |               |
|-------------------|---------------|
| `(A with B) <: A` | `(A ∧ B) ⇒ A` |
| `(A with B) <: B` | `(A ∧ B) ⇒ B` |
| `A <: (A ∨ B)`    | `A ⇒ (A ∨ B)` |
| `B <: (A ∨ B)`    | `B ⇒ (A ∨ B)` |

The essence of Curry-Howard is that this mechanical rewriting process (whichever direction you go in) will always
preserve validity --- valid type formulae will always rewrite to valid logical formulae, and vice versa. This
isn't only true for conjunction, disjunction and implication. We can also generalize the correspondence to logical
formulae which include negation (the key one for us here) and universal and existential quantification.

So what would it mean to add negation to the mix? The conjunction of two types (ie. `A with B`) has values which are
instances of both `A` and `B`, so similarly we should expect the negation of a type `A` (I'll write it as `¬[A]`) to
have as it's values everything which _isn't_ an instance of A. This is also something which can't be directly
expressed in Scala, but suppose it was?

If it was, then we would be able to crank on the Curry-Howard isomorphism and [De Morgan's laws][de-morgan] to give us
a definition of union types in terms of intersection types (`A with B`) and type negation. Here's how that might go
...

First recall the De Morgan equivalence,

```scala
(A ∨ B) ⇔ ¬(¬A ∧ ¬B)
```

Now apply Curry-Howard (using Scala's `=:=` type equality operator),

```scala
(A ∨ B) =:= ¬[¬[A] with ¬[B]]
```

If we could work out a way of expressing this in Scala, we'd be home and dry and have our union types. So can we
express type negation?

Unfortunately we can't. But what we can do is transform all of our types in a way which allows negation to be
expressed in the transformed context. We'll then need to work out how make that work for us back in the original
untransformed context.

Some readers might have been a little surprised earlier when I illustrated Curry-Howard using intersection types as
the correlate of conjunction, union types as the correlate of disjunction and the subtype relation as the correlate of
implication. That's not how it's normally done --- usually product types (ie. `(A, B)`) model conjunction, sum types
(ie. `Either[A, B]`) model disjunction and function types model implication. If we recast our earlier table in terms
of products, sums and functions we end up with this,

|                     |               |
|---------------------|---------------|
| `(A, B) => A`       | `(A ∧ B) ⇒ A` |
| `(A, B) => B`       | `(A ∧ B) ⇒ B` |
| `A => Either[A, B]` | `A ⇒ (A ∨ B)` |
| `B => Either[A, B]` | `B ⇒ (A ∨ B)` |

On the left hand side we're no longer looking for validity with respect to the subtype relation, instead we're looking
for evidence of the [principle of parametricity][parametricity], which allows us to determine if a function type is
implementable just by reading it's signature.  It's clear that all the function signatures on the left in the table
above can be implemented --- for the first two we have an `(A, B)` pair as our function argument, so we can easily
evalutate to either an `A` or a `B`, using `_1` or `_2`,

```scala
val conj1: ((A, B)) => A = p => p._1
val conj2: ((A, B)) => B = p => p._2
```

and for the last two we have either an `A` or a `B` as our function argument, so we can evalute to `Either[A, B]` (as
`Left[A]` or `Right[B]` respectively).

```scala
val disj1: A => Either[A, B] = a => Left(a)
val disj2: B => Either[A, B] = b => Right(b)
```

This is the form in which the Curry-Howard isomorphism is typically expressed for languages without subtyping. Because
this mapping doesn't reflect subtype relations it isn't going to be much direct use to us for expressing union types
which, like intersection types, are inherently characterized in terms of subtyping. But it can help us out with
negation, which is the missing piece that we need.

Either with or without subtyping, the bottom type (Scala's `Nothing` type) maps to logical falsehood, so for example,
the following equivalences all hold,

|                           |                   |
|---------------------------|-------------------|
| `A => Either[A, Nothing]` | `A ⇒ (A ∨ false)` |
| `B => Either[Nothing, B]` | `B ⇒ (false ∨ B)` |

because the function signatures on the left are once again all implementable, and the logical formulae on the right
are again all valid (see this [post][products] from James Iry for an explanation of why I haven't shown the
corresponding cases for products/conjunctions). Now we need to think about what a function signature like,

```scala
A => Nothing
```

corresponds to. On the logical side of Curry-Howard this maps to `A ⇒ false`, which is equivalent to `¬A`. This seems
fairly intuitively reasonable --- there are no values of type Nothing, so the signature `A => Nothing` can't be
implemented (other than by throwing an exception, which isn't allowed).

Let's see what happens if we take this as our representation of the negation of a type,

```scala
type ¬[A] = A => Nothing
```

and apply it back in the subtyping context that we started with to see if we can now use De Morgan's laws to get the
union types we're after,

```scala
type ∨[T, U] = ¬[¬[T] with ¬[U]]
```

We can test this using the Scala REPL, which will very quickly show us that we're not quite there yet,

```scala
scala> type ¬[A] = A => Nothing
defined type alias $u00AC

scala> type ∨[T, U] = ¬[¬[T] with ¬[U]]
defined type alias $u2228

scala> implicitly[Int <:< (Int ∨ String)]
<console>:11: error: Cannot prove that Int <:< 
  ((Int) => Nothing with (String) => Nothing) => Nothing.
       implicitly[Int <:< (Int ∨ String)]
```

The expression `implicitly[Int <:< (Int ∨ String)]` is asking the compiler if it can prove that `Int` is a subtype of
`Int ∨ String`, which it would be if we had succeeded in coming up with an encoding of union types.

So what's gone wrong? The problem is that we have transformed the types on the right hand side of the `<:<` operator
into function types so that we can make use of the encoding of type negation as `A => Nothing`. This means that the
union type is itself a function type. That's clearly not consistent with `Int` being a subtype of it --- as the error
message from the REPL shows. To make this work, then, we also need to transform the left hand side of the `<:<`
operator into a type which could possibly be a subtype of the type on the right. What could that transformation be?
How about double negation?

```scala
type ¬¬[A] = ¬[¬[A]]
```

Lets see what the compiler says now,

```scala
scala> type ¬¬[A] = ¬[¬[A]]
defined type alias $u00AC$u00AC

scala> implicitly[¬¬[Int] <:< (Int ∨ String)]
res5: <:<[((Int) => Nothing) => Nothing,
  ((Int) => Nothing with (String) => Nothing) => Nothing] =
    <function1>

scala> implicitly[¬¬[String] <:< (Int ∨ String)]
res6: <:<[((String) => Nothing) => Nothing,
  ((Int) => Nothing with (String) => Nothing) => Nothing] =
    <function1>
```

Bingo! `¬¬[Int]` and `¬¬[String]` are both now subtypes of `Int ∨ String`!

Let's just check that this isn't succeeding vacuously,

```scala
scala> implicitly[¬¬[Double] <:< (Int ∨ String)]
<console>:12: error: Cannot prove that
  ((Double) => Nothing) => Nothing <:<
    ((Int) => Nothing with (String) => Nothing) => Nothing.
```

We're almost there, but there's one remaining loose end to tie up --- we have subtype relationships which are
isomorphic to the ones we want (because `¬¬[T]` is isomorphic to `T`), but we don't yet have a way to express those
relationships with respect to the the untransformed types that we really want to work with.

We can do that by treating our `¬[T]`, `¬¬[T]` and `T ∨ U` as phantom types, using them only to represent the subtype
relationships on the underlying type rather that working directly with their values. Here's how that goes for our
motivating example,

```scala
def size[T](t: T)(implicit ev: (¬¬[T] <:< (Int ∨ String))) =
  t match {
    case i: Int => i
    case s: String => s.length
  }
```

This is using a generalized type constraint to require the compiler to be able to prove that any `T` inferred as the
argument type of the size method must be such that it's double negation is a subtype of `Int ∨ String`. That's only
ever true when `T` is `Int` or `T` is `String`, as this REPL session shows,

```scala
scala> def size[T](t: T)(implicit ev: (¬¬[T] <:< (Int ∨ String))) =
     |   t match {
     |     case i: Int => i
     |     case s: String => s.length
     |   }
size: [T](t: T)(implicit ev: <:<[((T) => Nothing) => Nothing,
  ((Int) => Nothing with (String) => Nothing) => Nothing])Int

scala> size(23)
res8: Int = 23

scala> size("foo")
res9: Int = 3

scala> size(1.0)
<console>:13: error: Cannot prove that
  ((Double) => Nothing) => Nothing <:<
    ((Int) => Nothing with (String) => Nothing) => Nothing.
```

One last little trick to finesse this slightly. The implicit evidence parameter is syntactically a bit ugly and
heavyweight, and we can improve things a little by converting it to a context bound on the type parameter `T` like so,

```scala
type |∨|[T, U] = { type λ[X] = ¬¬[X] <:< (T ∨ U) }

def size[T: (Int |∨| String)#λ](t: T) =
  t match {
    case i: Int => i
    case s: String => s.length
  }
```

And there you have it --- an unboxed, statically type safe encoding of union types in unmodified Scala!

Obviously it would be nicer if Scala supported union types as primitives, but at least this construction shows that
the Scala compiler has all the information it needs to be able to do that. Now we just need to pester Martin and
Adriaan to make it directly accessible.

[curry-howard]: http://en.wikipedia.org/wiki/Curry%E2%80%93Howard_correspondence
[de-morgan]: http://en.wikipedia.org/wiki/De_Morgan%27s_laws
[parametricity]: http://en.wikipedia.org/wiki/Parametricity
[products]: http://james-iry.blogspot.com/2011/05/why-eager-languages-dont-have-products.html

Comment by Miles Sabin
--------
This is a comment!

