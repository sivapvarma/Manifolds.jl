@doc doc"""
    GeneralizedStiefel{n,k,T} <: Manifold

The Generalized Stiefel manifold consists of all $n\times k$, $n\geq k$ orthonormal matrices w.r.t. an arbitrary scalar product `B`, i.e.

````math
\operatorname{St(n,k,B)} = \{ x \in \mathbb F^{n\times k} : x^{\mathrm{H}} B x = I_k \},
````

where $\mathbb F \in \{\mathbb R, \mathbb C\}$,
$\cdot^{\mathrm{H}}$ denotes the complex conjugate transpose or Hermitian, and
$I_n \in \mathbb R^{n\times n}$ denotes the $k \times k$ identity matrix.


In the case $B=I_k$ one gets the usual [`Stiefel`](@ref) manifold.

The tangent space at a point $x\in\mathcal M=\operatorname{St(n,k,B)}$ is given by

````math
T_x\mathcal M = \{ v \in \mathbb{F}^{n\times k} : x^{\mathrm{H}}Bv + v^{\mathrm{H}}Bx=0_n\},
````

# Constructor
    Stiefel(n,k,F=ℝ,B=I_k)

Generate the (real-valued) Generalized Stiefel manifold of $n\times k$ dimensional orthonormal matrices with scalar product `B`.
"""
struct GeneralizedStiefel{n,k,F,TB<:AbstractMatrix} <: Manifold 
    B::TB
end

GeneralizedStiefel(n::Int, k::Int, F::AbstractNumbers = ℝ, B::AbstractMatrix = Matrix{Float64}(I,k,k)) = GeneralizedStiefel{n,k,F,typeof(B)}(B)

@doc doc"""
    representation_size(M::GeneralizedStiefel)

Returns the representation size of the [`Stiefel`](@ref) `M`=$\operatorname{St}(n,k,B)$,
i.e. `(n,k)`, which is the matrix dimensions.
"""
@generated representation_size(::GeneralizedStiefel{n,k}) where {n,k} = (n, k)


@doc doc"""
    check_manifold_point(M::GeneralizedStiefel, x; kwargs...)

Check whether `x` is a valid point on the [`GeneralizedStiefel`](@ref) `M`=$\operatorname{St}(n,k,B)$,
i.e. that it has the right [`AbstractNumbers`](@ref) type and $x^{\mathrm{H}}Bx$
is (approximately) the identity, where $\cdot^{\mathrm{H}}$ is the complex conjugate
transpose. The settings for approximately can be set with `kwargs...`.
"""
function check_manifold_point(M::GeneralizedStiefel{n,k,T}, x; kwargs...) where {n,k,T}
    if (T === ℝ) && !(eltype(x) <: Real)
        return DomainError(
            eltype(x),
            "The matrix $(x) is not a real-valued matrix, so it does not lie on the Generalized Stiefel manifold of dimension ($(n),$(k)).",
        )
    end
    if (T === ℂ) && !(eltype(x) <: Real) && !(eltype(x) <: Complex)
        return DomainError(
            eltype(x),
            "The matrix $(x) is neiter real- nor complex-valued matrix, so it does not lie on the complex Generalized Stiefel manifold of dimension ($(n),$(k)).",
        )
    end
    if any(size(x) != representation_size(M))
        return DomainError(
            size(x),
            "The matrix $(x) is does not lie on the Generalized Stiefel manifold of dimension ($(n),$(k)), since its dimensions are wrong.",
        )
    end
    c = x' * M.B * x
    if !isapprox(c, one(c); kwargs...)
        return DomainError(
            norm(c - one(c)),
            "The point $(x) does not lie on the Generalized Stiefel manifold of dimension ($(n),$(k)), because x'Bx is not the unit matrix.",
        )
    end
end


@doc doc"""
    check_tangent_vector(M::GeneralizedStiefel, x, v; kwargs...)

Check whether `v` is a valid tangent vector at `x` on the [`GeneralizedStiefel`](@ref)
`M`=$\operatorname{St}(n,k,B)$, i.e. the [`AbstractNumbers`](@ref) fits,
`x` is a valid point on `M` and
it (approximately) holds that $x^{\mathrm{H}}Bv + v^{\mathrm{H}}Bx = 0$, where
`kwargs...` is passed to the `isapprox`.
"""
function check_tangent_vector(M::GeneralizedStiefel{n,k,T}, x, v; kwargs...) where {n,k,T}
    mpe = check_manifold_point(M, x, kwargs)
    mpe === nothing || return mpe
    if (T === ℝ) && !(eltype(v) <: Real)
        return DomainError(
            eltype(v),
            "The matrix $(v) is not a real-valued matrix, so it can not be a tangent vector to the Generalized Stiefel manifold of dimension ($(n),$(k)).",
        )
    end
    if (T === ℂ) && !(eltype(v) <: Real) && !(eltype(v) <: Complex)
        return DomainError(
            eltype(v),
            "The matrix $(v) is a neither real- nor complex-valued matrix, so it can not be a tangent vector to the complex Generalized Stiefel manifold of dimension ($(n),$(k)).",
        )
    end
    if any(size(v) != representation_size(M))
        return DomainError(
            size(v),
            "The matrix $(v) does not lie in the tangent space of $(x) on the Generalized Stiefel manifold of dimension ($(n),$(k)), since its dimensions are wrong.",
        )
    end
    if !isapprox(x' * M.B * v + v' * M.B * x, zeros(k, k); kwargs...)
        return DomainError(
            norm(x' * v + v' * x),
            "The matrix $(v) does not lie in the tangent space of $(x) on the Generalized Stiefel manifold of dimension ($(n),$(k)), since x'Bv + v'Bx is not the zero matrix.",
        )
    end
end

@doc doc"""
    project_point(M::GeneralizedStiefel,x)

Projects `x` from the embedding onto the [`SymmetricMatrices`](@ref) `M`, i.e.

````math
\operatorname{proj}_{\operatorname{Sym}(n)}(x) = \frac{1}{2} \bigl( x + x^{\mathrm{H}} \bigr),
````

where $\cdot^{\mathrm{H}}$ denotes the hermitian, i.e. complex conjugate transposed.
"""
project_point(::GeneralizedStiefel, ::Any...)

function project_point!(M::GeneralizedStiefel, x)
    s = svd(x)
    e=eigen(s.U' * M.B * s.U)
    qsinv = e.vectors * Diagonal(1 ./ sqrt.(e.values))
    x = s.U * qsinv * e.vectors' * s.V'
    return x
end

@doc doc"""
    project_tangent(M, x, v)

Project `v` onto the tangent space of `x` to the [`GeneralizedStiefel`](@ref) manifold `M`.
The formula reads

````math
\operatorname{proj}_{\mathcal M}(x,v) = v - x \operatorname{Sym}(x^{\mathrm{H}}Bv),
````

where $\operatorname{Sym}(y)$ is the symmetrization of $y$, e.g. by
$\operatorname{Sym}(y) = \frac{y^{\mathrm{H}}+y}{2}$.
"""
project_tangent(::GeneralizedStiefel, ::Any...)

project_tangent!(::GeneralizedStiefel, w, x, v) = copyto!(w, v - x * Symmetric(x' * v))


@doc doc"""
    manifold_dimension(M::GeneralizedStiefel)

Return the dimension of the [`GeneralizedStiefel`](@ref) manifold `M`=$\operatorname{St}(n,k,B,𝔽)$.
The dimension is given by

````math
\begin{aligned}
\dim \mathrm{Stiefel}(n, k, ℝ) &= nk - \frac{1}{2}k(k+1) \\
\dim \mathrm{Stiefel}(n, k, ℂ) &= 2nk - k^2\\
\dim \mathrm{Stiefel}(n, k, ℍ) &= 4nk - k(2k-1)
\end{aligned}
````
"""
manifold_dimension(::GeneralizedStiefel{n,k,ℝ}) where {n,k} = n * k - div(k * (k + 1), 2)
manifold_dimension(::GeneralizedStiefel{n,k,ℂ}) where {n,k} = 2 * n * k - k * k
manifold_dimension(::GeneralizedStiefel{n,k,ℍ}) where {n,k} = 4 * n * k - k * (2k - 1)


@doc doc"""
    inner(M::GeneralizedStiefel, x, v, w)

Compute the inner product for two tangent vectors `v`, `w` from the
tangent space of `x` on the [`GeneralizedStiefel`](@ref) manifold `M`. The formula reads

````math
(v,w)_x = \operatorname{trace}(v^{\mathrm{H}}Bw),
````
i.e. the metric induced by the scalar product `B` from the embedding, restricted to the tangent
space.
"""
inner(M::GeneralizedStiefel, x, v, w) = dot(v, M.B * w)


@doc doc"""
    retract(M, x, v, ::PolarRetraction)

Compute the SVD-based retraction [`PolarRetraction`](@ref) on the
[`GeneralizedStiefel`](@ref) manifold `M`. With $USV = x + v$ the retraction reads
````math
\operatorname{retr}_x(v) = U\bar{V}^\mathrm{H}.
````

    retract(M, x, v, ::QRRetraction )

Compute the QR-based retraction [`QRRetraction`](@ref) on the
[`Stiefel`](@ref) manifold `M`. With $QR = x + v$ the retraction reads
````math
\operatorname{retr}_x(v) = QD,
````
where D is a $n\times k$ matrix with
````math
D = \operatorname{diag}\bigl(\operatorname{sgn}(R_{ii}+0,5)_{i=1}^k \bigr),
````
where $\operatorname{sgn}(x) = \begin{cases}
1 & \text{ for } x > 0,\\
0 & \text{ for } x = 0,\\
-1& \text{ for } x < 0.
\end{cases}$
"""
retract(::GeneralizedStiefel, ::Any...)

function retract!(M::GeneralizedStiefel, y, x, v, ::PolarRetraction)
    project_point!(M,y,x+v)
    return y
end