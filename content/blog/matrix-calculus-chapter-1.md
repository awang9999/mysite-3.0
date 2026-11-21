---
title: Matrix Calculus — Preliminaries
date: 2023-03-21
slug: matrix-calculus-chapter-1
series: Matrix Calculus
part: 1
readingTime: 10
summary: "The derivative, re-expressed as the best linear approximation — the foundation the rest of the series builds on."
---

## The Derivative

We can begin the discussion of matrix calculus by revisiting the definition of a derivative. For many students, the difference quotient definition will be familiar. We will show that it is equivalent to defining the derivative as the best linear approximator of the function — a setup that lays the foundations for discussing derivatives of matrix-like objects.

Recall the difference quotient definition of the derivative. Let $U \subseteq \mathbb{R}$ be an open subset (for simplicity) and $f : U \to \mathbb{R}$ a sufficiently smooth, single variable, scalar-valued function. Let $a \in U$. Then we can define the derivative of $f$ at $a$ to be

$$
\frac{d}{dx} f(a) = \lim_{h \to 0} \frac{f(a+h) - f(a)}{h}
$$

If $f$ has a derivative at every point in its domain, then we say $f$ is a differentiable function, and its derivative $\frac{df}{dx} : U \to \mathbb{R}$ is the function defined by the difference quotient:

$$
\frac{df}{dx} (x) = \lim_{h \to 0} \frac{f(x+h) - f(x)}{h}
$$

This function is unique to $f$, although that property will not be proven here. Refer to Strichartz, Chapter 5, for more details.

If you are unfamiliar with the rigorous definitions of "open subset" or "sufficiently smooth," that is fine. The idea behind them in the definition is to rule out the case where we try to define the derivative of a non-differentiable function. A more rigorous discussion of differentiability and subset topology belongs to an analysis course and is unfortunately out of scope for this guide.

Now observe how we can convert the difference quotient expression into a linear approximation. If we remove the limit, then there must exist a function $\epsilon(h)$ representing the error between the difference quotient and the derivative at a point. We know that $\epsilon(h)$ must satisfy $\lim_{h \to 0} \epsilon(h) = 0$. <!-- NOTE: 2.0 original wrote lim_{x→0} ε(h) — limit variable mismatched the function's argument; corrected to h --> So we can write

$$
\frac{df}{dx}(x) + \epsilon(h) = \frac{f(x+h) - f(x)}{h}
$$

and consequently

$$
f(x+h) = f(x) + \frac{df}{dx}(x)\, h + \epsilon(h)h
$$

As $h \to 0$, the term $\epsilon(h) h \approx h^2 = o(h)$, using little-O notation.

Here is a quick recap of little-O notation and the main property we will use: if $f(x) = o(g(x))$, then

$$
\lim_{x \to 0} \frac{f(x)}{g(x)} = 0
$$

We can rearrange the expression above to show how the derivative is a linear approximation:

$$
f(x+h) = f(x) + \frac{df}{dx}(x)\, h + o(h)
$$

For small values of $h$, the error term can be disregarded. Observe how $f(x+h)$ can be approximated by an affine function (of the type $ax + b$) where the derivative $\frac{df}{dx}(x)$ acts as the slope. We can define the derivative to be the unique scalar value for which the error is minimal (uniqueness not proven here). By rearranging the terms and dividing both sides by $h$, we get

$$
\frac{f(x+h) - f(x) - \frac{df}{dx}(x)\, h}{h} = \frac{o(h)}{h}
$$

If we take the limit of both sides as $h \to 0$ (equivalently, the limit of the absolute value of the quotient), we arrive at an alternate definition of the derivative.

Let $U \subseteq \mathbb{R}$ be an open subset and $f : U \to \mathbb{R}$ a sufficiently smooth, single variable, scalar-valued function. Let $a \in U$. If there exists a scalar value $A$ such that

$$
\lim_{h \to 0} \frac{f(a+h) - f(a) - Ah}{h} = \lim_{h \to 0} \frac{o(h)}{h} = 0
$$

then we say that $f$ is differentiable at $a$, and we can usually denote the quantity $A$ as

$$
\frac{df}{dx}(a) = A
$$

If $f$ is differentiable at every point $x \in U$, then we say $f$ is differentiable on $U$, and its derivative is the function $\frac{df}{dx} : U \to \mathbb{R}$ that maps points in the domain to the scalar value satisfying the pointwise condition above. Now that we have established this alternate definition of the derivative, we are in good shape to continue deciphering matrix calculus.

## Partial Derivatives

The partial derivative is closely related to the ordinary derivative. However, partial derivatives pertain to functions with several variables in the domain. The partial derivative of a function of several variables is its derivative with respect to one of the variables, with the others held constant. We can formalize this the following way.

Let $U \subseteq \mathbb{R}^n$ be an open subset and $f : U \to \mathbb{R}$ a function. The partial derivative of $f$ at the point $\mathbf{a} = (a_1, \dots, a_n) \in U$ with respect to the $i$'th variable is the scalar value $A$ that satisfies

$$
\lim_{h \to 0} \frac{f(\mathbf{a} + h\mathbf{e}_i) - f(\mathbf{a}) - Ah}{h} = 0
$$

<!-- NOTE: 2.0 original had "− Ah·eᵢ" in the numerator (and in the equivalent form below); f is scalar-valued, so that term is type-incorrect. Corrected to "− Ah". -->

This is equivalent to

$$
f(\mathbf{a} + h\mathbf{e}_i) = f(\mathbf{a}) + Ah + o(h)
$$

Here, $\mathbf{e}_i$ is the unit vector in $\mathbb{R}^n$ with zeros in all elements except for a $1$ in the $i$'th element. The value $A$ is often denoted

$$
A = \frac{\partial f}{\partial x_i}(\mathbf{a})
$$

and read as the partial derivative of $f$ with respect to $x_i$ at the point $\mathbf{a}$. The partial derivative will be important for deciphering what elements make up the total derivative discussed in the next chapter.

## Linear Maps

Soon we will learn that the total derivative is defined to be a linear map. But before we get into that topic, we must first recall some properties of linear maps. Here is a hopefully familiar definition from linear algebra.

Let $V$ and $W$ be vector spaces over the same field $K$. A mapping $T : V \to W$ from the vector space $V$ to the vector space $W$ is said to be a linear map if it satisfies the following two conditions for any $\mathbf{u}, \mathbf{v} \in V$ and any scalar $k \in K$:

<!-- NOTE: 2.0 original read "Let T: U → V be a mapping from the V vector space to the W vector space" (U undefined); corrected to T: V → W. -->

1. Additivity: $T(\mathbf{u} + \mathbf{v}) = T(\mathbf{u}) + T(\mathbf{v})$
2. Degree 1 Homogeneity: $T(k \mathbf{v}) = kT(\mathbf{v})$

Another useful property of linear maps is that they can be entirely determined by their action on a set of basis vectors for the domain. This allows us to create a matrix that represents the linear mapping, so that applying the linear mapping to a vector becomes equivalent to multiplying the matrix by the vector. This is vastly useful because it allows for concrete computations. Secondly, most applications of matrix calculus deal with linear mappings in $\mathbb{R}^n$, and thus the values of the linear transformation matrix and the vectors in the domain correspond to real quantities.

Suppose $V$ and $W$ are finite-dimensional vector spaces, and let $\{\mathbf{v}_1, \dots, \mathbf{v}_n\}$ and $\{\mathbf{w}_1, \dots, \mathbf{w}_m\}$ be bases for $V$ and $W$ respectively. Every vector $\mathbf{v} \in V$ can be uniquely determined by the coefficients $c_1, \dots, c_n$:

$$
\mathbf{v} = \sum_{j=1}^n c_j \mathbf{v}_j
$$

Note that, conventionally, the entries $c_j$ make up the elements of the vector when it is written out in the $\{\mathbf{v}_j\}$ coordinate system. That is,

$$
\mathbf{v} = \begin{bmatrix} c_1 \\ c_2 \\ \vdots \\ c_n \end{bmatrix}_{[\mathbf{v}_j]}
$$

If the basis for a certain coordinate system is already understood, then the subscript is often dropped from the explicit vector notation. If $f : V \to W$ is a linear map, then

$$
f(\mathbf{v}) = f\left(\sum_{j=1}^n c_j \mathbf{v}_j\right) = \sum_{j=1}^n c_j f(\mathbf{v}_j)
$$

This shows that the function $f$ can be entirely determined by the vectors $f(\mathbf{v}_j)$ for $j = 1, \dots, n$. Since each of these vectors is in $W$, we can represent each $f(\mathbf{v}_j)$ as

$$
f(\mathbf{v}_j) = \sum_{i=1}^m a_{ij} \mathbf{w}_i
$$

Putting this into the expression above, we get

$$
f(\mathbf{v}) = \sum_{j=1}^n c_j \sum_{i=1}^m a_{ij} \mathbf{w}_i
$$

Now watch what happens when we put the $a_{ij}$ entries into an $m \times n$ matrix. Consider the matrix

$$
M =
\begin{bmatrix}
    a_{11} & a_{12} & \cdots & a_{1n} \\
    a_{21} & a_{22} & \cdots & a_{2n} \\
    \vdots & \vdots & \ddots & \vdots \\
    a_{m1} & a_{m2} & \cdots & a_{mn}
\end{bmatrix}
$$

If we take an arbitrary $\mathbf{v} \in V$ and multiply it by $M$, we get

$$
M\mathbf{v} =
\begin{bmatrix}
    a_{11} & a_{12} & \cdots & a_{1n} \\
    a_{21} & a_{22} & \cdots & a_{2n} \\
    \vdots & \vdots & \ddots & \vdots \\
    a_{m1} & a_{m2} & \cdots & a_{mn}
\end{bmatrix}
\begin{bmatrix}
    c_1 \\ c_2 \\ \vdots \\ c_n
\end{bmatrix}
=
\begin{bmatrix}
    \sum_{j=1}^n c_j a_{1j} \\
    \sum_{j=1}^n c_j a_{2j} \\
    \vdots \\
    \sum_{j=1}^n c_j a_{mj}
\end{bmatrix}
=
\sum_{i=1}^m \sum_{j=1}^n c_j a_{ij} \mathbf{w}_i
$$

Rearranging the terms, we arrive at the exact same expression as $f(\mathbf{v})$:

$$
M\mathbf{v} = \sum_{j=1}^n c_j \sum_{i=1}^m a_{ij} \mathbf{w}_i = f(\mathbf{v})
$$

which shows that we can indeed represent any linear transformation with a matrix whose entries depend on the bases we choose for the domain and codomain vector spaces.

## Linearity of Differentiation

Consider two differentiable functions $f : \mathbb{R} \to \mathbb{R}$ and $g : \mathbb{R} \to \mathbb{R}$, and the scalar $a \in \mathbb{R}$. The sum and constant rules for derivatives are hopefully a familiar concept. For instance,

$$
\frac{d}{dx}(f(x) + g(x)) = \frac{df}{dx}(x) + \frac{dg}{dx}(x)
$$

and

$$
\frac{d}{dx}(a f(x)) = a \frac{df}{dx}(x)
$$

Proofs of the sum and constant rules can be found [here](https://en.wikipedia.org/wiki/Linearity_of_differentiation), and essentially require using the difference quotient definition of the derivative to derive these properties.

Notice that differentiation, if treated like an operator on the space of functions, satisfies the properties of a linear map. Hence, the linearity of the derivative is a property we hope to preserve for multivariable and vector-valued functions.

## Vector-Valued Functions

We now investigate the derivative of functions that map $\mathbb{R}$ to $\mathbb{R}^m$. This generalization is not significantly more complicated, and putting it here sets up the necessary pre-work for discussing the total derivative in the next chapter. Let $\mathbf{f} : \mathbb{R} \to \mathbb{R}^m$ be a single-variable, vector-valued function. If we expand $\mathbf{f}$ into its components,

$$
\mathbf{f}(x) = \begin{bmatrix} f_1(x) \\ f_2(x) \\ \vdots \\ f_m(x) \end{bmatrix}
$$

then $\mathbf{f}$ is differentiable at $a$ if and only if all of its components $f_j(x)$ are differentiable at $a$, and $D\mathbf{f}(a)$ is the $m \times 1$ matrix where the $j$'th entry is $\frac{df_j}{dx}(a)$. That is,

$$
D\mathbf{f}(a) =
\begin{bmatrix}
    D_x f_1(a) \\
    D_x f_2(a) \\
    \vdots \\
    D_x f_m(a)
\end{bmatrix}
$$

If $\mathbf{f}$ is differentiable everywhere in its domain, we can define its derivative to be the function $D\mathbf{f} : \mathbb{R} \to \mathbb{R}^m$

$$
D\mathbf{f}(x) =
\begin{bmatrix}
    D_x f_1(x) \\
    D_x f_2(x) \\
    \vdots \\
    D_x f_m(x)
\end{bmatrix}
=
\begin{bmatrix}
    D_x f_1 \\
    D_x f_2 \\
    \vdots \\
    D_x f_m
\end{bmatrix} (x)
$$

This characterization of the derivative of vector-valued functions does preserve the linearity of the differentiation operator. For instance, let $\mathbf{f}, \mathbf{g} : \mathbb{R} \to \mathbb{R}^m$ be two differentiable vector-valued functions and $a, b \in \mathbb{R}$ scalars. We will drop the subscript $x$ within the matrix, since it is understood that each $f_j$ and $g_j$ has only a single variable in the domain to differentiate with respect to. Then we can write

$$
D(a\mathbf{f} + b\mathbf{g})(x)
=
\begin{bmatrix}
    D(af_1 + bg_1)(x) \\
    D(af_2 + bg_2)(x) \\
    \vdots \\
    D(af_m + bg_m)(x)
\end{bmatrix}
=
\begin{bmatrix}
    aDf_1(x) + bDg_1(x) \\
    aDf_2(x) + bDg_2(x) \\
    \vdots \\
    aDf_m(x) + bDg_m(x)
\end{bmatrix}
$$

using the linearity property for scalar-valued functions discussed earlier. It follows, then, that

$$
D(a \mathbf{f} + b \mathbf{g})(x)
=
a
\begin{bmatrix}
    Df_1(x) \\ Df_2(x) \\ \vdots \\ Df_m(x)
\end{bmatrix}
+
b
\begin{bmatrix}
    Dg_1(x) \\ Dg_2(x) \\ \vdots \\ Dg_m(x)
\end{bmatrix}
=
a D\mathbf{f}(x) + b D\mathbf{g}(x)
$$

This shows that the linearity property holds for single-variable, vector-valued functions as well.

We now have the necessary tools to discuss the total derivative — what it means, what it is comprised of, and how to begin computing it — in the next chapter.

## Sources

- [Partial derivative — Wikipedia](https://en.wikipedia.org/wiki/Partial_derivative)
- [Derivative — Wikipedia](https://en.wikipedia.org/wiki/Derivative)
- [Directional derivative — Wikipedia](https://en.wikipedia.org/wiki/Directional_derivative)
- [Linear map — Wikipedia](https://en.wikipedia.org/wiki/Linear_map)
- Strichartz, Robert. *The Way of Analysis*.
- Rudin, Walter. *Principles of Mathematical Analysis*.

## In this series

- [Matrix Calculus — Preface](/blog/matrix-calculus-preface)
- [Matrix Calculus — Preliminaries](/blog/matrix-calculus-chapter-1)
- [Matrix Calculus — The Total Derivative](/blog/matrix-calculus-chapter-2)
