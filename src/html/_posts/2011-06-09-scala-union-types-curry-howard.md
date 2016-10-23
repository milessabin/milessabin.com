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

{% include comment-header.html %}

<div markdown="1">
##### Max Bolingbroke (<a href="https://twitter.com/mbolingbroke">@mbolingbroke</a>) -- Thu, 9th Jun 2011, 3:58pm GMT
<div class="comment-body" markdown="1">
Coming from Haskell I was a bit confused about how Scala was type checking your "match" statement, until I realised
that it isn't doing coverage or possibility tests for "match". So in particular you can define this,

```scala
def size[T](t : T)(implicit ev: (¬¬[T] <:< (Int ∨ String))): Int =
  t match {
    case i: Int => i
    case d: Double => d.toInt
  }
```

It doesn't complain. But when you try to find the size of a `String` you get an error, and the `Double` case of the
match is inaccessible.

(Coming from Haskell I was also confused about the use of the "boxed" terminology, as in Haskell a boxed data type is
one that is represented as a heap value. This Scala code clearly still represents `(Foo ∨ Bar)` as a heap value,
though it does avoid the extra layer of indirection imposed by `Either`.)
</div>
</div>

<div markdown="1">
##### Heiko Seeberger (<a href="https://twitter.com/hseeberger">@hseeberger</a>) -- Thu, 9th Jun 2011, 6:03pm GMT
<div class="comment-body" markdown="1">
Miles,

This is pure awesomeness! Please let the promised followups come.

One little imperfection, though. The following compiles,

```scala
def size[A: (Int |∨| String)#λ](a: A) = a match {
  case d: Double => -1
}
```

Cheers,

Heiko
</div>
</div>

<div markdown="1">
##### Ray Racine -- Thu, 9th Jun 2011, 6:24pm GMT
<div class="comment-body" markdown="1">
Interesting that Racket, generally considered a typeless scheme, has Union types.

```racket
(: size ((U Integer String) -> Integer))
(define (size x)
  (cond
    ((exact-integer? x) x)
    ((string? x) (string-length x))))

;; compiles and runs just fine
(size 3)
(size "ray")

;; fails TO COMPILE
(size 1.0)
```

</div>
</div>

<div markdown="1">
##### Ittay Dror (<a href="https://twitter.com/ittayd">@ittayd</a>) -- Thu, 9th Jun 2011, 7:13pm GMT
<div class="comment-body" markdown="1">
This post is awesome, probably one of the best I've read. Both the result, the way and the explanation.

However, at least for the example given, isn't using type classes better? It avoids the use of reflection to match the
type in the body of the function and is also more easily extensible to more than 2 types.

Again, blown away.
</div>
</div>

<div markdown="1">
##### Miles Sabin (<a href="https://twitter.com/milessabin">@milessabin</a>) -- Fri, 10th Jun 2011, 10:45am GMT
<div class="comment-body" markdown="1">
**@hseeberger**

Yes, it's a shame that the type constraint doesn't propagate into the method body so, within the body, `A` is viewed as
an unbounded type variable, and your case clause is accepted as possible.

OTOH, simple type constraints do seem to propagate into method bodies, eg.,

```scala
// Note that T is String in the body
def string[T](s : T)(implicit ev : T =:= String) = s.length
```

So maybe this is a compiler bug? Or possibly there's some special-casing in the compiler for `=:=` and `<:<`? Adriaan
would know.
</div>
</div>

<div markdown="1">
##### Mario Fusco (<a href="https://twitter.com/mariofusco">@mariofusco</a>) -- Fri, 10th Jun 2011, 10:34am GMT
<div class="comment-body" markdown="1">
Really an awesome and especially inspiring post!

I am trying to push it just a bit forward but I found a weird issue and I am not able to figure out in what I am wrong. I defined a function like that:

```scala
scala> def asString[T : (String |∨| Int)#λ](t : T)(f : T => String): String = f(t)
```

but when I try to use it as it follows:

```scala
scala> asString(23)(_ match {
|   case s: String => s
|   case i: Int => "" + i
| })
```

the REPL complains:

```
:12: error: scrutinee is incompatible with pattern type;
found : String
required: Int
case s: String => s
      ^
```

Any idea on what's wrong here?
</div>
</div>

<div markdown="1">
##### Miles Sabin (<a href="https://twitter.com/milessabin">@milessabin</a>) -- Fri, 10th Jun 2011, 10:38am GMT
<div class="comment-body" markdown="1">
**@mariofusco**

T will have been inferred as Int in the second parameter block, so the String case is correctly rejected by the
compiler as never applicable.
</div>
</div>

<div markdown="1">
##### Miles Sabin (<a href="https://twitter.com/milessabin">@milessabin</a>) -- Fri, 10th Jun 2011, 10:53am GMT
<div class="comment-body" markdown="1">
**@mbolingbroke**

See [my reply](#miles-sabin-milessabin--fri-10th-jun-2011-1045am-gmt) to @hseeberger for the within-body type
constraint issue.

On boxing, it's a relative thing. If you were to use Scala's `Either` you would have an additional boxing layer,
irrespective of the boxed-ness or otherwise of the underlying types.

And actually, this construction is perfectly compatible with Scala's specialization mechanism, so if you specialized
the `T` type parameter of the size method for `Int` you would have a completely unboxed representation for the `Int`
case.
</div>
</div>

<div markdown="1">
##### Mario Fusco (<a href="https://twitter.com/mariofusco">@mariofusco</a>) -- Fri, 10th Jun 2011, 11:20am GMT
<div class="comment-body" markdown="1">
Thanks for your prompt reply Miles, now I see my mistake. Do you think there is a way to use union types as parameters
of an higher order function as in my example? I cannot find how.
</div>
</div>

<div markdown="1">
##### Miles Sabin (<a href="https://twitter.com/milessabin">@milessabin</a>) -- Fri, 10th Jun 2011, 11:58am GMT
<div class="comment-body" markdown="1">
**@mariofusco**

The encoding works by transforming a union-type argument into an argument of type parameter with a constraint. So, I'm
afraid it's not going to be possible to directly represent a function value with a union-type argument, for the same
reason that it's not possible to directly represent a function value with a type parameter (ie. a polymorphic function
value). I've got quite a lot more to say on this, so watch this space.
</div>
</div>

<div markdown="1">
##### Ittay Dror (<a href="https://twitter.com/ittayd">@ittayd</a>) -- Fri, 10th Jun 2011, 1:29pm GMT
<div class="comment-body" markdown="1">
**@milessabin**: About `Either`: Instead of making the argument of type `Either`, you can define that it is viewable
as `Either`,

```scala
def size[T <% Either[Int, String]](t: T) = t match {
  case i: Int => i
  case s: String => s.length
}
```

If you supply the implicit conversions in scope, then you can avoid boxing (because all it says is T can be converted
to Either. it isn't really converted). See
[here](http://cleverlytitled.blogspot.com/2009/03/disjoint-bounded-views-redux.html).

I think that if you invent your own type, say `Or[A, B]`, then the companion object can hold all conversions, so
there's no need for the client to import anything. Furthermore, by using the `Or` (or `Either`) type you can store the
parameter for later use.
</div>
</div>

<div markdown="1">
##### Miles Sabin (<a href="https://twitter.com/milessabin">@milessabin</a>) -- Fri, 10th Jun 2011, 2:58pm GMT
<div class="comment-body" markdown="1">
**@ittayd**

Yes, that works too. The principle of using phantom types (`Either` in your case) to impose type constraints on a base
type is a very powerful one.
</div>
</div>

<div markdown="1">
##### Mark Harrah -- Fri, 10th Jun 2011, 3:35pm GMT
<div class="comment-body" markdown="1">
Nice work and neat post.

In [your reply](#miles-sabin-milessabin--fri-10th-jun-2011-1045am-gmt) to @hseeberger, `s` is of type `T`, so it
doesn't statically have a length member. `T =:= String` is a subtype of `T => String` and because it is implicit, the
compiler uses it to convert s to String in order to call `length`. As far as I know, the compiler knows nothing about
`=:=` and `<:<`, so they are only constraints in the sense that they provide implicit conversions and arguments.

Related to `=:=` being implemented completely as library code, see the implementation of `Predef.conforms` for why I
expect a bit more work is needed to actually make this solution less boxed than a solution based on `Either`.
</div>
</div>

<div markdown="1">
##### Miles Sabin (<a href="https://twitter.com/milessabin">@milessabin</a>) -- Fri, 10th Jun 2011, 5:32pm GMT
<div class="comment-body" markdown="1">
Mark, try that in the REPL ... `s` does have a length member within the method body, despite `T` being unbounded and
only being `=:=` String. I'm guessing there must be compiler magic here.
</div>
</div>

<div markdown="1">
##### Mark Harrah -- Fri, 10th Jun 2011, 6:49pm GMT
<div class="comment-body" markdown="1">
I'm not saying it won't compile. It will, but that is because the compiler uses the implicit `=:=` instance to convert
`T` to a `String` just like it would with any other implicit function parameter. Look at the generated bytecode and
you can see it invokes `apply` on `ev`.
</div>
</div>

<div markdown="1">
##### Miles Sabin (<a href="https://twitter.com/milessabin">@milessabin</a>) -- Fri, 10th Jun 2011, 8:59pm GMT
<div class="comment-body" markdown="1">
Mark, oh blimey ... yes of course.
</div>
</div>

<div markdown="1">
##### <a href="http://lavadip.com">HRJ</a> -- Sat, 18th Jun 2011, 12:34pm GMT
<div class="comment-body" markdown="1">
Awesome.

About @ittayd's [comment](#ittay-dror-ittayd--fri-10th-jun-2011-129pm-gmt), is the viewable construct amenable to
specialisation too?
</div>
</div>

<div markdown="1">
##### Miles Sabin (<a href="https://twitter.com/milessabin">@milessabin</a>) -- Sat, 18th Jun 2011, 12:47pm GMT
<div class="comment-body" markdown="1">
**@HRJ**

Yes, a view bounded type variable will get along just fine with specialization.
</div>
</div>

<div markdown="1">
##### Richard -- Wed, 13th Jul 2011, 12:45am GMT
<div class="comment-body" markdown="1">
Using this union type, how would one declare a variable, i.e., something like,

```scala
var intOrString: Union(Int & String) = 4
intOrString = "four"
```

</div>
</div>

<div markdown="1">
##### Vlad Patryshev (<a href="https://twitter.com/vpatryshev">@vpatryshev</a>) -- Thu, 21st Jul 2011, 6:17am GMT
<div class="comment-body" markdown="1">
This is ingenious; I loved it a lot.

But wait, how come you throw in double negation into Curry-Howard isomorphism? Double negation is not an identity in
an intuitionist logic; so you cannot seriously count on using de Morgan laws. I believe. I could not find yet where's
the error, but if Curry-Howard is correct, then there should be one, I think.
</div>
</div>

<div markdown="1">
##### Miles Sabin (<a href="https://twitter.com/milessabin">@milessabin</a>) -- Thu, 21st Jul 2011, 9:11am GMT
<div class="comment-body" markdown="1">
**@Richard** There's not currently any way of expressing a union type as anything other than a context or view bound on a
type variable so, no, you can't do that just yet.

However, there are (tentative) plans to expose the implicit resolution mechanism (in a future version of Scala) which
would enable that -- with the proposal currently on the table it would look something like,

```scala
var intOrString : Solve[(Int |∨| String)#λ, Any] = 4
```

If you're feeling brave you could give this a try by checking out and building the `topic/implicits_solve` branch of
Adriaan Moors github mirror of the Scala toolchain.

That said, by the time this arrives in a released version of Scala we might have first class union types in the
language anyway.
</div>
</div>

<div markdown="1">
##### Miles Sabin (<a href="https://twitter.com/milessabin">@milessabin</a>) -- Thu, 21st Jul 2011, 9:20am GMT
<div class="comment-body" markdown="1">
**@vpatryshev** I agree that the Curry-Howard isomorphism is normally presented in an intuitionistic setting, but I
don't think it's invalid in classical logic. Alternatively, maybe the use of double negation here means that I've
(pretty much accidentally) helped myself to the [Gödel-Gentzen double negation embedding of classical into
intuitionistic logic](https://en.wikipedia.org/wiki/Double-negation_translation). That would be lovely given that the
inspiration for this post struck me while I was rereading Geoffrey Washburns article on [encoding higher-ranked types
in Scala](http://existentialtype.net/2008/03/09/higher-rank-impredicative-polymorphism-in-scala/), which also uses a
double negation encoding (though expressed very differently, using continuations).

I'd delighted if someone with more logical sophistication than me could shed some light on this.
</div>
</div>

<div markdown="1">
##### Rex Kerr (<a href="https://twitter.com/_ichoran_">@_ichoran_</a>) -- Fri, 22nd Jul 2011, 9:57pm GMT
<div class="comment-body" markdown="1">
This is lovely, but I think your explanation emphasizes the isomorphism too much, or provides too limited of an
encoding scheme to really match the isomorphism. There is a simpler explanation for why the scheme works, which is
that the argument of a function is contravariant.

Let `Z[-T]` be contravariant, meaning that if `R <: S`, then `Z[S] <: Z[R]`. Now let `A` and `B` be any pair of types.
Since `(A with B) <: A`, and `(A with B) <: B`, it follows that `Z[B] <: Z[A with B]` and `Z[A] <: Z[A with B]`.
That's all we need.

Thus, if you define,

```scala
trait Contra[-A] {}
def f[A](a: A)(implicit ev: Contra[A] <:< Contra[Int with String]) = a match {
  case s: String => s
  case i: Int => i.toString
}
```

you get your union type with less work:

```scala
scala> f(5)
res2: String = 5

scala> f("Wish")
res3: String = Wish

scala> f(Some(false))
:10: error: Cannot prove that Contra[Some[Boolean]] <:< Contra[String with Int].
f(Some(false))
```

As a further improvement, you can skip the encoding entirely and just use `<:<` (or, rather, let `<:<`'s encoding,
which includes a contravariant first parameter, do the work for you):

```scala
def g[A](a: A)(implicit ev: (Int with String) <:< A) = ...
```

The Howard-Curry isomorphism encoding, although true, is something of a red herring because you cannot (AFAICT) encode
type negation in a usable way, at least not easily.
</div>
</div>

<div markdown="1">
##### Miles Sabin (<a href="https://twitter.com/milessabin">@milessabin</a>) -- Sun, 24th Jul 2011, 10:04am GMT
<div class="comment-body" markdown="1">
Nice, but actually, what you've shown is that contravariance provides yet another mechanism for encoding negation in
type systems with subtyping.
</div>
</div>

<div markdown="1">
##### Seth Tisue (<a href="https://twitter.com/SethTisue">@SethTisue</a>) -- Wed, 3rd Aug 2011, 11:04pm GMT
<div class="comment-body" markdown="1">
Rex,

It seems to me that neither of your shorter solutions is quite correct.

The problem is that `(Int with String)` has several valid supertypes besides Int and String, namely Any, AnyRef, and
AnyVal. So I can pass any value, of any class whatsoever, to your functions f and g as long as the compiler doesn't
know anything about that value except that it's one of those types. So for example `f(Some(5): Any)` gets past the
compiler, which defeats the purpose.

Miles's code doesn't have this problem.
</div>
</div>

<div markdown="1">
##### Rex Kerr (<a href="https://twitter.com/_ichoran_">@_ichoran_</a>) -- Sat, 13th Aug 2011, 5:58pm GMT
<div class="comment-body" markdown="1">
Seth,

Good point. Somehow I'd missed that. You do need the double negation to get the types right; you just don't need a
function because it's only the contravariant parameter that matters.

So I retract my original comment: although the reason the code works is slightly less obvious than it could be, the
double negation motivated by the HC isomorphism is key if you want a strict union type. Except as implemented it's not
really negation but reverse implication.
</div>
</div>

<div markdown="1">
##### Derek Wyatt (<a href="https://twitter.com/derekwyatt">@derekwyatt</a>) -- Thu, 18th Aug 2011, 1:31pm GMT
<div class="comment-body" markdown="1">
Interesting stuff, thanks.

What's the advantage of union types over function overloading? I can't think of a "slam dunk" reason here. Given the
union type we have to pattern match, and given overloading we have to dispatch dynamically. One could say that
overloading allows for smaller functions, but perhaps unions provide an opportunity for exhaustive compiler checks on
the pattern match (?)
</div>
</div>

<div markdown="1">
##### Derek Wyatt (<a href="https://twitter.com/derekwyatt">@derekwyatt</a>) -- Thu, 18th Aug 2011, 2:15pm GMT
<div class="comment-body" markdown="1">
Oh hell, scratch that question... :) I was only thinking about implementation of decisions like "size" and the like
but clearly it's got usages way beyond that that nobody else needs to describe since it should have been obvious.
</div>
</div>

<div markdown="1">
##### A B -- Tue, 23rd Aug 2011, 2:29pm GMT
<div class="comment-body" markdown="1">
Is this still supposed to work when you use type union as generic parameters for collections? (Because it doesn't seem
to work at all for me in Scala 2.9.....)
</div>
</div>

<div markdown="1">
##### Miles Sabin (<a href="https://twitter.com/milessabin">@milessabin</a>) -- Tue, 23rd Aug 2011, 4:18pm GMT
<div class="comment-body" markdown="1">
A B, This only works as a bound on a type parameter, so it's definition-site, rather than use site (the latter is what
you're trying to do).
</div>
</div>

<div markdown="1">
##### A B -- Tue, 23rd Aug 2011, 8:13pm GMT
<div class="comment-body" markdown="1">
**@milessabin** Does this mean that there is no way to achieve something like,

```scala
val collec = new scala.collection.mutable.HashSet[_ <: (String ∨ Int)]
collec.add("banana")
collec.add(7)
```

?
</div>
</div>

<div markdown="1">
##### Miles Sabin (<a href="https://twitter.com/milessabin">@milessabin</a>) -- Tue, 23rd Aug 2011, 9:11pm GMT
<div class="comment-body" markdown="1">
A B, No, I'm afraid not.
</div>
</div>

<div markdown="1">
##### Ittay Dror (<a href="https://twitter.com/ittayd">@ittayd</a>) -- Tue, 13th Sep 2011, 4:04am GMT
<div class="comment-body" markdown="1">
**@milessabin** Is there a way of defining that `A` is not of a certain type? In particular, that `A` is not a
function?  Something like:

```scala
def foo[A, B, C](a: A)(implicit ev: ¬¬[A] <: C])
```

</div>
</div>

<div markdown="1">
##### Miles Sabin (<a href="https://twitter.com/milessabin">@milessabin</a>) -- Tue, 13th Sep 2011, 10:15am GMT
<div class="comment-body" markdown="1">
**@ittayd** Yes it is possible, but it takes a slightly different encoding of negation which really deserves a blog
post of its own. Here's the general idea,

```scala
def unexpected : Nothing = sys.error("Unexpected invocation")

// Encoding for "A is not a subtype of B"
trait <:!<[A, B]

// Uses ambiguity to rule out the cases we're trying to exclude
implicit def nsub[A, B] : A <:!< B = null
implicit def nsubAmbig1[A, B >: A] : A <:!< B = unexpected
implicit def nsubAmbig2[A, B >: A] : A <:!< B = unexpected

// Type alias for context bound
type |¬|[T] = {
  type λ[U] = U <:!< T
}

def notFn[T: |¬|[_ => _]#λ](t : T) = t

val nfn1 = notFn(23)                // OK
val nfn2 = notFn("foo")             // OK
val nfn3 = notFn((x : Int) => x+1)  // Does not compile
```

Nb. as defined this only excludes functions of one argument.
</div>
</div>

<div markdown="1">
##### Ittay Dror (<a href="https://twitter.com/ittayd">@ittayd</a>) -- Tue, 13th Sep 2011, 11:45am GMT
<div class="comment-body" markdown="1">
**@milessabin** This is the solution I eventually
[used](http://web.archive.org/web/20130129061119/http://www.tikalk.com/java/blog/avoiding-nothing), but the error
message is totally incomprehensible if someone is not familiar with the trick (unlike the "could not prove that..."
message for missing implicits).
</div>
</div>

<div markdown="1">
##### Shelby Moore III -- Sun, 18th Sep 2011, 9:09am GMT
<div class="comment-body" markdown="1">
I am thinking that the first class disjoint type is a sealed supertype, with the alternate subtypes, and implicit
conversions to/from the desired types of the disjunction to these alternative subtypes.

I assume this addresses comments above, so the first class type that can be employed at the use site, but I didn't
test it.

```scala
sealed trait IntOrString
case class IntOfIntOrString(v: Int) extends IntOrString
case class StringOfIntOrString(v: String) extends IntOrString
implicit def IntToIntOfIntOrString(v: Int) = new IntOfIntOrString(v)
implicit def StringToStringOfIntOrString(v: String) = new StringOfIntOrString(v)

object Int {
  def unapply(t: IntOrString): Option[Int] = t match {
    case v: IntOfIntOrString => Some( v.v )
    case _ => None
  }
}

object String {
  def unapply(t: IntOrString): Option[String] = t match {
    case v: StringOfIntOrString => Some( v.v )
    case _ => None
  }
}

def size(t: IntOrString) = t match {
  case Int(i) => i
  case String(s) => s.length
}

scala> size("test")
res0: Int = 4
scala> size(2)
res1: Int = 2
```

One problem is Scala will not employ in case matching context, an implicit conversion from `IntOfIntOrString` to `Int`
(and `StringOfIntOrString` to `String`), so must define extractors and use `case Int(i)` instead of `case i : Int`.
</div>
</div>

<div markdown="1">
##### Miles Sabin (<a href="https://twitter.com/milessabin">@milessabin</a>) -- Sun, 18th Sep 2011, 9:26am GMT
<div class="comment-body" markdown="1">
Shelby, maybe I'm missing something, but it looks like you've just replicated (a special case of) Scala's standard
`Either` type -- ie. a boxed union type. The point of the article is to show that we can encode union types without
any boxing.
</div>
</div>

<div markdown="1">
##### Shelby Moore III -- Sun, 18th Sep 2011, 10:02am GMT
<div class="comment-body" markdown="1">
Maybe also I am missing something, but seems there are several improvements over `Either`,

1. It extends to more than 2 types, without any additional noise at the use or definition site.
2. Arguments are boxed implicitly, e.g. don't need `size(Left(2))` or `size(Right("test"))`.
3. The syntax of the pattern matching is implicitly unboxed.
4. The boxing and unboxing may be optimized away by the JVM hotspot.
5. The syntax could be the one adopted by a future first class union type, so migration could perhaps be seamless?

Perhaps it would be better to use `V` instead of `Or`, e.g. `IntVString`, or `Int |v| String`?
</div>
</div>

<div markdown="1">
##### Miles Sabin (<a href="https://twitter.com/milessabin">@milessabin</a>) -- Sun, 18th Sep 2011, 10:11am GMT
<div class="comment-body" markdown="1">
Shelby, I'm afraid you're missing the point: the aim of this article is precisely to show the derivation of an unboxed
union type -- anything else, however interesting it might be in it's own right, is off-topic.
</div>
</div>

<div markdown="1">
##### Shelby Moore III -- Sun, 18th Sep 2011, 10:17am GMT
<div class="comment-body" markdown="1">
Okay apologies. In my mind, it is for all practical purposes an unboxed solution, because the boxing and unboxing is
implicit and maybe optimized away. But I can also appreciate your point, and there may be more corner cases (in
addition to the one I noted) lurking with my method? Thanks for accepting my comments in spite of them being off
topic.
</div>
</div>

<div markdown="1">
##### Lars Hupel (<a href="https://twitter.com/larsr_h">@larsr_h</a>) -- Mon, 14th Nov 2011, 5:31pm GMT
<div class="comment-body" markdown="1">
I was wondering whether one could generalize this to n-ary unions. Here's my first approach for n = 3,

```scala
implicitly[¬¬[¬¬[Int]] <:< ((Int ∨ String) ∨ (Float ∨ Float))]
```

Works so far, but you have to extend it to a power of two, which is not too useful.

Can we do better? We can.

```scala
trait Disj[T] { 
  type or[S] = Disj[T with ¬[S]]
  type apply = ¬[T]
}

// for convenience
type disj[T] = { type or[S] = Disj[¬[T]]#or[S] }


type T = disj[Int]#or[Float]#or[String]#apply
implicitly[¬¬[Int] <:< T] // works
implicitly[¬¬[Double] <:< T] // doesn't work
```

</div>
</div>

<div markdown="1">
##### Miles Sabin (<a href="https://twitter.com/milessabin">@milessabin</a>) -- Tue, 15th Nov 2011, 12:47am GMT
<div class="comment-body" markdown="1">
I like it ... nicely done.
</div>
</div>

<div markdown="1">
##### Paolo G. Giarrusso (<a href="https://twitter.com/Blaisorblade">@Blaisorblade</a>) -- Sun, 5th Feb 2012, 2:17pm GMT
<div class="comment-body" markdown="1">
1. Just to understand the discussion with Rex Kerr -- this code seems to work without problems, and it seems that you
   already agreed on that, right?

   ```scala
   def f[A](a: A)(implicit ev: Contra[Contra[A]] <:< Contra[Contra[Int with String]]) = a match {
     case s: String => s
     case i: Int => i.toString
   }
   ```

2. What is the runtime cost of constructing and passing all these proof terms? When implementing dependently-typed
   languages, people work hard to erase all of them -- the literature suggests (implicitly) that not having erasure
   would be a significant problem, and it sounds quite reasonable. Now, erasure would not happen in Scala; on the
   contrary implicits are not just passed around but also used as conversion functions (as commented above); that
   could be avoided if the compiler knew that `<:<` and `=:=` are just identities. Either we make them built-ins, or
   we introduce GHC's user-specified rewrite rules for optimization in Scala, too.
</div>
</div>

<div markdown="1">
##### Paolo G. Giarrusso (<a href="https://twitter.com/Blaisorblade">@Blaisorblade</a>) -- Sun, 5th Feb 2012, 2:26pm GMT
<div class="comment-body" markdown="1">
A correction: actually `<:<` and `=:=` are just identities, but for slightly more complex reasons.  Given erasure of
generics, probably `<:<` and `=:=` are identity functions but some of their calls will produce a cast in the caller
(just as `l.get()` where `l: List[Int]` produces a cast to `Int`). Since the cast is in the caller, removing the
function call _after the cast is inserted_ should be no problem.
</div>
</div>

<div markdown="1">
##### Miles Sabin (<a href="https://twitter.com/milessabin">@milessabin</a>) -- Sun, 5th Feb 2012, 2:38pm GMT
<div class="comment-body" markdown="1">
**@Blaisorblade**

On 1) ... yes, correct.

On 2), you're quite right that these proof terms exist at runtime. I haven't benchmarked to see what the runtime costs
are, although I suspect that a sufficiently recent JVM would do a reasonably good job of inlining (and eliminating)
some of them. In practice I haven't found this to be a problem, but in general I agree with you that currently the
Scala compiler isn't going to do as good a job of code generation for these kinds of things as languages like Agda
which are designed from the ground up for this purpose.
</div>
</div>

<div markdown="1">
##### Shelby Moore III -- Wed, 15th Feb 2012, 5:21pm GMT
<div class="comment-body" markdown="1">
Negation of the disjunction (i.e. all types not in the disjunction) employing Miles's ambiguity rule,

```scala
type ¬|∨|[T, U] = { type λ[X] = ¬¬[X] <:!< (T ∨ U) }
def size[T : (Int ¬|∨| String)#λ](t : T) = t match {
  case d : Double => d
}

scala> size(0)
error: ambiguous implicit values:
 both method nsubAmbig2 in object $iw of type [A,B >: A]<:!<[A,B]
 and method nsubAmbig1 in object $iw of type [A,B >: A]<:!<[A,B]
 match expected type <:!<[((Int) => Nothing) => Nothing,((Int) => Nothing with
  (java.lang.String) => Nothing) => Nothing]
       size(0)
           ^

scala> size(5.0)
res1: Double = 5.0
```

Extensible disjunction type values employing Lar's recursive trait,

```scala
type ∨[T, U] = T with ¬[U]
class Disj[T <: (_ ∨ _)] { type or[U] = Disj[T ∨ U] }
def size[T, D <: (_ ∨ _)](t : T, d : Disj[D])(implicit ev : (¬¬[T] <:< ¬[D])) =
  t match {
    case i : Int => i
    case s : String => s.length
    case d : Double => d
  }
type T = disj[Int]#or[String]

scala> size(0, new T)
res0: Double = 0.0

scala> size("", new T)
res1: Double = 0.0

scala> size(5.0, new T)
error: could not find implicit value for parameter ev:
  <:<[((Double) => Nothing) => Nothing,
            ((Int) => Nothing with (String) => Nothing) => Nothing]
       size(5.0,new T)
           ^

scala> size(5.0,new T#or[Double])
res3: Double = 5.0
```

Compose them,

```scala
def size[T, D <: (_ ∨ _)](t : T, d : Disj[D])(implicit ev : (¬¬[T] <:!< ¬[D])) =
  t match {
    case i : Int => i
    case s : String => s.length
    case d : Double => d
  }

scala> size(0, new T)
error: ambiguous implicit values:
 both method nsubAmbig2 in object $iw of type [A,B >: A]<:!<[A,B]
 and method nsubAmbig1 in object $iw of type [A,B >: A]<:!<[A,B]
 match expected type <:!<[((Int) => Nothing) => Nothing,
  ((Int) => Nothing with (String) => Nothing) => Nothing]
       size(0,new T)
           ^

scala> size(5.0, new T)
res5: Double = 5.0
```

One use case is to statically type check the list of unique types for a list of values (one per unique type) added to
a collection (the collection's type will subsume to Any).

```scala
def addTypeToDisj[T, D <: (_ ∨ _)](t : T, d : Disj[D])
  (implicit ev : (¬¬[T] <:!< ¬[D])) = new Disj[D]#or[T]

scala> addTypeToDisj(0, new T)
error: ambiguous implicit values:
 both method nsubAmbig2 in object $iw of type [A,B >: A]<:!<[A,B]
 and method nsubAmbig1 in object $iw of type [A,B >: A]<:!<[A,B]
 match expected type <:!<[((Int) => Nothing) => Nothing,
  ((Int) => Nothing with (String) => Nothing) => Nothing]
       addTypeToDisj(0,new T)
                    ^

scala> addTypeToDisj(5.0, new T)
res5: Disj[(Int) => Nothing with
           (String) => Nothing with
           (Double) => Nothing] = Disj@df61ca
```

Note, I needed this for some dependently-typed kungfu where I statically type the keys of a hash map and want to
statically (at compile-time) prevent duplicate operations (within each event handler function) on the state object
hash map.
</div>
</div>

<div markdown="1">
##### Miles Sabin (<a href="https://twitter.com/milessabin">@milessabin</a>) -- Thu, 16th Feb 2012, 1:02am GMT
<div class="comment-body" markdown="1">
Shelby, interesting looking stuff! You might also be interested in the (dependently typed) encoding of extensible
records in shapeless.
</div>
</div>

<div markdown="1">
##### Shelby Moore III -- Mon, 20th Feb 2012, 5:29pm GMT
<div class="comment-body" markdown="1">
**@milessabin** Thanks I will have a look. To eliminate `¬¬`,

```scala
type ∨[T, U] = ¬[T] with ¬[U]
def size[T](t : T)(implicit ev : ((Int ∨ String) <:< ¬[T])) = t match {
  case i : Int => i
  case s : String => s.length
}

scala> size(5.0 : Any)
error: could not find implicit value for parameter
  ev: <:<[?[Int,String],(Any) => Nothing]
       size(5.0 : Any)
           ^
```

Note the function type `¬[A] = A => Nothing` is necessary so that we don't otherwise get the supertype of each type in
the disjunction as follows,

```scala
def size[T](t : T)(implicit ev : ((Int with String) <:< T)) = t match {
  case i : Int => i
  case s : String => s.length
  case d : Double => d
}

scala> size(5.0 : Any)
res8: Double = 5.0

scala> size(5.0)
error: could not find implicit value for parameter ev: <:<[Int with String,Double]
       size(5.0)
           ^
```
</div>
</div>

<div markdown="1">
##### Eduardo Pareja Tobes (<a href="https://twitter.com/eparejatobes">@eparejatobes</a>) -- Thu, 22nd Mar 2012, 4:59pm GMT
<div class="comment-body" markdown="1">
I don't see how,

> because `¬¬[T]` is isomorphic to `T`

In general (as Vlad says [above](#vlad-patryshev-vpatryshev--thu-21st-jul-2011-617am-gmt)) that's only true for a
Boolean algebra. Assuming that Scala types with subtyping is a Heyting algebra, one always has `T <: ¬¬[T]`. This will
not work directly, this does not compile,

```scala
implicitly[Int <:< ¬¬[Int]]
```

but, moving to implicit conversions,

```scala
// x to  ¬¬[x]
implicit def toDoubleNeg[X](x: X): Function1[Function1[X,Nothing], Nothing] =
  new Function1[Function1[X,Nothing], Nothing] {
    def apply(not_X: Function1[X,Nothing]): Nothing = not_X.apply(x)
  }

// works:
implicitly[Int <%< ¬¬[Int]]
```

Concerning `¬¬[T] <: T`, I don't see how you can get this.
</div>
</div>

<div markdown="1">
##### Miles Sabin (<a href="https://twitter.com/milessabin">@milessabin</a>) -- Thu, 22nd Mar 2012, 5:30pm GMT
<div class="comment-body" markdown="1">
**@eparejatobes** I think all I need for isomorphism here is that `T <: U` iff `¬¬[T] <: ¬¬[U]` and that does hold.
</div>
</div>

<div markdown="1">
##### Eduardo Pareja Tobes (<a href="https://twitter.com/eparejatobes">@eparejatobes</a>) -- Thu, 22nd Mar 2012, 6:37pm GMT
<div class="comment-body" markdown="1">
**@milessabin**

If any of this resembles double negation, what you state is equivalent to `¬¬[U] <: U`. In,

```scala
T <: U iff ¬¬[T] <: ¬¬[U]
```

take `T = ¬¬[U]` and you get,

```scala
¬¬[U] <: U iff ¬¬¬¬[U] <: ¬¬[U] 
```

which (should) reduce to,

```scala
¬¬[U] <: U iff ¬¬[U] <: ¬¬[U] 
```

because every monad in Poset is idempotent, and double negation is a monad.
</div>
</div>

<div markdown="1">
##### Miles Sabin (<a href="https://twitter.com/milessabin">@milessabin</a>) -- Thu, 22nd Mar 2012, 6:51pm GMT
<div class="comment-body" markdown="1">
**@eparejatobes** It looks to me as though you're asking for something much stronger than what I need here. In
particular, I don't think your reduction step is necessary. It would be if I was claiming that `¬[T]` (resp. `¬¬[T]`)
actually was negation (resp. double negation), but I'm not, and I don't think I need that for the purposes of this
article.
</div>
</div>

<div markdown="1">
##### Eduardo Pareja Tobes (<a href="https://twitter.com/eparejatobes">@eparejatobes</a>) -- Thu, 22nd Mar 2012, 7:52pm GMT
<div class="comment-body" markdown="1">
**@milessabin** of course you don't need any of this for the purpose of your (really nice!) article. I'm not saying
that anything of what you wrote is wrong or something.

It's just that I'd like to understand up to which point useful analogies like `A => Nothing = ¬[T]` can be made
precise.

Anyway, I don't see how `T <: U` iff `¬¬[T] <: ¬¬[U]` holds; maybe it's just me :)

cheers
</div>
</div>

<div markdown="1">
##### Miles Sabin (<a href="https://twitter.com/milessabin">@milessabin</a>) -- Thu, 22nd Mar 2012, 8:16pm GMT
<div class="comment-body" markdown="1">
**@eparejatobes** `¬¬[A]` is `(A => Nothing) => Nothing`, which is `Function1[Function1[A, Nothing], Nothing]`.
`Function1` is contravariant in it's first type argument, so `Function1[Function1[A, Nothing], Nothing]` is covariant
in `A`, hence if `A <: B` then `Function1[Function1[A, Nothing], Nothing] <: Function1[Function1[B, Nothing],
Nothing]` so `¬¬[A] <: ¬¬[B]`.

Going back the other way is an exercise left for the reader ;-)
</div>
</div>











<!--
COMMENTS_END
-->

{% include comment-footer.html %}



