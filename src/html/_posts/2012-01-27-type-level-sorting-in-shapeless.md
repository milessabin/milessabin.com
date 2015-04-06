---
layout:     post
title:      Type-level selection sort in shapeless
author:     Miles Sabin
date:       '2012-01-27 12:00:00'
---

To celebrate my talk on [shapeless][shapeless] being selected for this year's [Northeast Scala
Symposium][nescala] in Boston, I thought I'd share something entertaining (and slightly whimsical) with you ---
compile time selection sort at the type-level!

<span class="break"></span>

[Selection sort][selsort] is just about the simplest possible sorting algorithm --- select the least element from your
unsorted list as the first element of the sorted list, then recursively sort the remainder --- so I'll take it as a
given, and focus on the interesting bit ... how can this _possibly_ be done at the type-level?

The first thing we need is a type-level representation of lists of sortable things. For that, we're going to use an
[`HList][hlist] of type-level [natural numbers][nat].

```scala
import shapeless._
import Nat._
import HList._

def typed[T](t: => T) {}

val unsorted = _3 :: _1 :: _4 :: _0 :: _2 :: HNil
typed[_3 :: _1 :: _4 :: _0 :: _2 :: HNil](unsorted)
```

Here `unsorted` is a list of `Nat` values, and we can see that its structure is exactly mirrored in its type --- in
shapeless each `Nat` value (`_0`, `_1`, ...) has a corresponding `Nat` type with the same name (`_0`, `_1`, ...). We
use the `typed` function here to verify the type of `unsorted` rather than use a type annotation on its val
declaration to ensure that the act of verifying the inferred type doesn't itself contribute to type inference.

Now we need a way of capturing order over `Nat` at the type level. We do that using a type class that witnesses the
relationship at the type level,

```scala
trait LTEq[A <: Nat, B <: Nat]

object LTEq {
  import Nat._0

  type <=[A <: Nat, B <: Nat] = LTEq[A, B]

  implicit def ltEq1 = new <=[_0, _0] {}
  implicit def ltEq2[B <: Nat] = new <=[_0, Succ[B]] {}
  implicit def ltEq3[A <: Nat, B <: Nat](implicit lt: A <= B) =
    new <=[Succ[A], Succ[B]] {}
}
```

If you're familiar with [Peano arithmetic][peano] it should be pretty clear how this works --- we have two base cases:
`_0` is less than or equal to `_0`, and `_0` is less than or equal to the successor of any number; and we have one
induction case: if `A <= B` then `A+1 <= B+1`. With these definitions in place, the magic of Scala's implicit
resolution allows us to ask the compiler about relationships between different `Nat` types,

```scala
scala> import shapeless._ ; import Nat._ ; import LTEq._
import shapeless._
import Nat._
import LTEq._

scala> implicitly[_2 <= _5] // OK
res0: shapeless.LTEq.<=[shapeless.Nat._2,shapeless.Nat._5] =
  shapeless.LTEq$$anon$5@4fc8927c

scala> implicitly[_4 <= _2] // Does not compile
<console>:17: error: could not find implicit value for parameter
  e: shapeless.LTEq.<=[shapeless.Nat._4,shapeless.Nat._2]
    implicitly[_4 <= _2]
              ^
```

Before we go any further, let's define an operation which witnesses whether or not an `HList` of `Nat` is in sorted
order --- we'll want this to verify that our type-level sort is correct,

```scala
trait NonDecreasing[L <: HList]

implicit def hnilNonDecreasing =
  new NonDecreasing[HNil] {}

implicit def hlistNonDecreasing1[H] =
  new NonDecreasing[H :: HNil] {}

implicit def hlistNonDecreasing2[H1 <: Nat, H2 <: Nat, T <: HList]
  (implicit ltEq: H1 <= H2, ndt: NonDecreasing[H2 :: T]) =
    new NonDecreasing[H1 :: H2 :: T] {}

def acceptNonDecreasing[L <: HList](l: L)
  (implicit ni: NonDecreasing[L]) = l

// Verify type-level relations
implicitly[NonDecreasing[_1 :: _2 :: _3 :: HNil]] // OK
implicitly[NonDecreasing[_1 :: _3 :: _2 :: HNil]] // Doesn't compile

// Apply at the value-level
acceptNonDecreasing(_1 :: _2 :: _3 :: HNil)       // OK
acceptNonDecreasing(_1 :: _3 :: _2 :: HNil)       // Doesn't compile
```

This is a fairly straighforward induction --- we have two base cases: an empty list is in sorted order, as is a list
of exactly one element; and we have one induction case: a list is in sorted order if its tail is, and if its first
element is less than or equal to its second element.

Now we can define an operation to select the least element from an `HList` of `Nat`, returning both it and the
remainder of the list,

```scala
trait SelectLeast[L <: HList, M <: Nat, Rem <: HList] {
  def apply(l: L): (M, Rem)
}

trait LowPrioritySelectLeast {
  implicit def hlistSelectLeast1[H <: Nat, T <: HList] =
    new SelectLeast[H :: T, H, T] {
      def apply(l: H :: T): (H, T) = (l.head, l.tail)
    }
}

object SelectLeast extends LowPrioritySelectLeast {
  implicit def hlistSelectLeast3
    [H <: Nat, T <: HList, TM <: Nat, TRem <: HList]
      (implicit tsl: SelectLeast[T, TM, TRem], ev: TM < H) =
        new SelectLeast[H :: T, TM, H :: TRem] {
          def apply(l: H :: T): (TM, H :: TRem) = {
            val (tm, rem) = tsl(l.tail)
            (tm, l.head :: rem)
          }
        }
}

val (l1, r1) = selectLeast(_1 :: _2 :: _3 :: HNil)
typed[_1](l1)
typed[_2 :: _3 :: HNil](r1)

val (l2, r2) = selectLeast(_3 :: _1 :: _4 :: _0 :: _2 :: HNil)
typed[_0](l2)
typed[_3 :: _1 :: _4 :: _2 :: HNil](r2)
```

Here we're working at both the type-level and at the value-level --- for each example `HList` we're selecting the
least value-level `Nat` and it is assigned the corresponding `Nat` type. Hopefully the recursive pattern is beginning
to look fairly familiar, even in this slightly more complicated case --- we have a base case: the least element of a
singleton list is its only element; and the least element of a non-singleton list is the least element of its tail
unless its head is already the least element of the entire list.

And now we can sort!

```scala
trait SelectionSort[L <: HList, S <: HList] {
  def apply(l: L): S
}

trait LowPrioritySelectionSort {
  implicit def hlistSelectionSort1[S <: HList] =
    new SelectionSort[S, S] {
      def apply(l: S): S = l
    }
}

object SelectionSort extends LowPrioritySelectionSort {
  implicit def hlistSelectionSort2
    [L <: HList, M <: Nat, Rem <: HList, ST <: HList]
      (implicit
        sl: SelectLeast[L, M, Rem],
        sr: SelectionSort[Rem, ST]
      ) =
        new SelectionSort[L, M :: ST] {
          def apply(l: L) = {
            val (m, rem) = sl(l)
            m :: sr(rem)
          }
        }
}

def selectionSort[L <: HList, S <: HList](l: L)
  (implicit sort: SelectionSort[L, S]) = sort(l)

val unsorted = _3 :: _1 :: _4 :: _0 :: _2 :: HNil
typed[_3 :: _1 :: _4 :: _0 :: _2 :: HNil](unsorted)
acceptNonDecreasing(unsorted)  // Does not compile!

val sorted = selectionSort(unsorted)
typed[_0 :: _1 :: _2 :: _3 :: _4 :: HNil](sorted)
acceptNonDecreasing(sorted)    // Compiles!
```

As you can see, the static type of the sorted value reflects the fact that it is in sorted order, and that
consequently, unlike the initial unsorted value, it has the correct type to be passed to the `acceptNonDecreasing`
function that we wrote earlier.

**Update --- Joni Freeman has done a nice job of porting the algorithm used to Prolog [here][prolog].**

If you've made it this far, and want to play around with it yourself, you can find shapeless on [github][shapeless]
along with the [example source][sorting] this article is based on. You'll also find a mailing list for discussion
around shapeless [here][typelevel]. Oh, and if you're going to be at Nescala then I'll see you there ...

[shapeless]: https://github.com/milessabin/shapeless
[nescala]: http://nescala.org/
[selsort]: http://en.wikipedia.org/wiki/Selection_sort
[hlist]: https://github.com/milessabin/shapeless/blob/master/core/src/main/scala/shapeless/hlists.scala
[nat]: https://github.com/milessabin/shapeless/blob/master/core/src/main/scala/shapeless/nat.scala
[peano]: http://en.wikipedia.org/wiki/Peano_axioms
[prolog]: https://gist.github.com/1703501
[sorting]: https://github.com/milessabin/shapeless/blob/master/examples/src/main/scala/shapeless/examples/sorting.scala
[typelevel]: https://groups.google.com/forum/#!forum/typelevel
