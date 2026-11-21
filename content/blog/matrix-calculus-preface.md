---
title: Matrix Calculus — Preface
date: 2023-03-21
slug: matrix-calculus-preface
series: Matrix Calculus
part: 0
readingTime: 3
summary: "Matrix calculus has no home in the standard curriculum — this series builds it from multivariable calculus, aimed at machine learning."
---

Matrix calculus is an elusive topic: too complicated for multivariable calculus, too simple for analysis, too off-topic for linear algebra, and a prerequisite for several machine learning courses. As a teaching assistant for a machine learning course over several semesters, I had the unusual opportunity to coach hundreds of students through their first pass at the subject. One struggle common to nearly all of them was their first encounter with matrix calculus. Even students familiar with multivariable calculus initially struggled to make sense of the notation — and more importantly, of what any of it meant.

Who could blame them? After all, mathematicians, statisticians, and physicists disagree among themselves about which notation to use. In writing this series, I hope to bridge the gap between multivariable calculus and matrix calculus; the latter is, in many ways, just a notational difference from the former.

This series develops the meaning of the derivative of matrix-like structures. We will derive the derivatives of common matrix expressions and build a framework for understanding — and computing — the derivatives of more complex ones. <!-- The promise of a "second part" (ML applications, backprop) was cut at the owner's direction 2026-11-21: it was never published in 2.0. -->

Matrix calculus is inherently an advanced topic, requiring both linear algebra and multivariable calculus, so treat those two as prerequisites. I will try to provide context wherever possible to keep the guide accessible to readers from all backgrounds.

## A note on notation

The most familiar symbols for the derivative, and likely the ones taught in elementary courses, are $f'(x)$ (Lagrange's notation) and $\frac{df}{dx}$ (Leibniz's notation). Both are valid and have their own advantages, but this guide uses Euler's notation, $D_x f$, to denote the derivative of matrix-like objects, or of elements within a matrix-like object. When the derivative is a scalar-like object, we use Leibniz's notation. An example:

Suppose $f : \mathbb{R} \to \mathbb{R}$ is given by $f(x) = x^2$. The derivative of this function, following the well-known power rule, is $\frac{df}{dx} = 2x$. Notice that we used Leibniz's notation because the derivative is a scalar value.

Now suppose $f : \mathbb{R}^2 \to \mathbb{R}$ is given by $f(x,y) = x^2 + y^2$. The total derivative of this function is

$$
Df =
\begin{bmatrix}
    D_x f & D_y f
\end{bmatrix}
=
\begin{bmatrix}
    2x & 2y
\end{bmatrix}
$$

(Don't worry if you're not yet sure what a total derivative is — it's a concept we'll build up throughout this guide!)

Notice how we use Euler's notation here to denote the matrix-like object that is the total derivative of $f$. To refer to either of the objects inside the total derivative, we can write $D_y f = \frac{\partial f}{\partial y} = 2y$, where the subscript $y$ means the derivative with respect to the $y$ variable.

When we use differentiation as an operator, we may write $D$ or $\frac{d}{dx}$ interchangeably depending on the context. If we are propagating the differentiation operator into a matrix-like object, we continue to use Euler's $D$ notation.

Finally, this guide is a living document. Typos may arise, or worse, I might have made a genuine mistake! Please email me at alexander.wang2001@gmail.com to point out any errors or mistakes in the articles, and I'll try to correct them as soon as I can. Thank you!

## In this series

- [Matrix Calculus — Preface](/blog/matrix-calculus-preface)
- [Matrix Calculus — Preliminaries](/blog/matrix-calculus-chapter-1)
- [Matrix Calculus — The Total Derivative](/blog/matrix-calculus-chapter-2)
