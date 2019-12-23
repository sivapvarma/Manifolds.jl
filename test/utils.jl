using Manifolds
using ManifoldsBase

using LinearAlgebra
using Distributions
using DoubleFloats
using ForwardDiff
using Random
using ReverseDiff
using StaticArrays
using Test

"""
    test_manifold(m::Manifold, pts::AbstractVector;
    args
    )

Tests general properties of manifold `m`, given at least three different points
that lie on it (contained in `pts`).

# Arguments
- `default_inverse_retraction_method = ManifoldsBase.LogarithmicInverseRetraction()` - default method for inverse retractions ([`log`](@ref))
- `default_retraction_method = ManifoldsBase.ExponentialRetraction()` - default method for retractions ([`exp`](@ref))
- `exp_log_atol_multiplier = 0`, change absolute tolerance of exp/log tests (0 use default, i.e. deactivate atol and use rtol)
- `exp_log_rtol_multiplier = 1`, change the relative tolerance of exp/log tests (1 use default). This is deactivated if the `exp_log_atol_multiplier` is nonzero.
- `retraction_atol_multiplier = 0`, change absolute tolerance of (inverse) retraction tests (0 use default, i.e. deactivate atol and use rtol)
- `retraction_rtol_multiplier = 1`, change the relative tolerance of (inverse) retraction tests (1 use default). This is deactivated if the `exp_log_atol_multiplier` is nonzero.
- `inverse_retraction_methods = []`: inverse retraction methods that will be tested.
- `point_distributions = []` : point distributions to test
- `projection_tvector_atol_multiplier = 0` : chage absolute tolerance in testing projections (0 use default, i.e. deactivate atol and use rtol)
-  tvector_distributions = []` : tangent vector distributions to test
- `rand_tvector_atol_multiplier = 0` : chage absolute tolerance in testing random vectors (0 use default, i.e. deactivate atol and use rtol)
  random tangent vectors are tangent vectors
- `retraction_methods = []`: retraction methods that will be tested.
- `test_forward_diff = true`: if true, automatic differentiation using
  ForwardDiff is tested.
- `test_forward_diff = true`: if true, automatic differentiation using
  ReverseDiff is tested.
- `test_musical_isomorphisms = false` : test musical isomorphisms
- `test_mutating_rand = false` : test the mutating random function for points on manifolds
- `test_project_tangent = false` : test projections on tangent spaces
- `test_representation_size = true` : test repersentation size of points/tvectprs
- `test_tangent_vector_broadcasting = true` : test boradcasting operators on TangentSpace
- `test_vector_transport = false` : test vector transport
- `test_vector_spaces = true` : test Vector bundle of this manifold
"""
function test_manifold(M::Manifold, pts::AbstractVector;
    test_exp_log = true,
    test_is_tangent = true,
    test_injectivity_radius=true,
    test_forward_diff = true,
    test_reverse_diff = true,
    test_tangent_vector_broadcasting = true,
    test_project_tangent = false,
    test_representation_size = true,
    test_musical_isomorphisms = false,
    test_vector_transport = false,
    test_mutating_rand = false,
    test_vector_spaces = true, 
    default_inverse_retraction_method = ManifoldsBase.LogarithmicInverseRetraction(),
    default_retraction_method = ManifoldsBase.ExponentialRetraction(),
    retraction_methods = [],
    inverse_retraction_methods = [],
    point_distributions = [],
    tvector_distributions = [],
    exp_log_atol_multiplier = 0,
    exp_log_rtol_multiplier = 1,
    retraction_atol_multiplier = 0,
    retraction_rtol_multiplier = 1,
    projection_atol_multiplier = 0,
    rand_tvector_atol_multiplier = 0,
    is_tangent_atol_multiplier=1,
)

    length(pts) ≥ 3 || error("Not enough points (at least three expected)")
    isapprox(M, pts[1], pts[2]) && error("Points 1 and 2 are equal")
    isapprox(M, pts[1], pts[3]) && error("Points 1 and 3 are equal")

    # get a default tangent vector for every of the three tangent spaces
    n = length(pts)
    if default_inverse_retraction_method === nothing
        tv = [ zero_tangent_vector(M,pts[i]) for i=1:n ] # no other available
    else
        tv = [ inverse_retract(M,pts[i],pts[((i+1)%n)+1],default_inverse_retraction_method) for i=1:n]
    end
    @testset "dimension" begin
        @test isa(manifold_dimension(M), Integer)
        @test manifold_dimension(M) ≥ 0
        @test manifold_dimension(M) == vector_space_dimension(Manifolds.VectorBundleFibers(Manifolds.TangentSpace, M))
        @test manifold_dimension(M) == vector_space_dimension(Manifolds.VectorBundleFibers(Manifolds.CotangentSpace, M))
    end

    test_representation_size && @testset "representation" begin
        function test_repr(repr)
            @test isa(repr, Tuple)
            for rs ∈ repr
                @test rs > 0
            end
        end

        test_repr(Manifolds.representation_size(M))
        for VS ∈ (Manifolds.TangentSpace, Manifolds.CotangentSpace)
            test_repr(Manifolds.representation_size(Manifolds.VectorBundleFibers(VS, M)))
        end
    end

    test_injectivity_radius && @testset "injectivity radius" begin
        @test injectivity_radius(M, pts[1]) > 0
        @test injectivity_radius(M, pts[1]) ≥ injectivity_radius(M)
        for rm ∈ retraction_methods
            @test injectivity_radius(M, pts[1], rm) > 0
            @test injectivity_radius(M, pts[1], rm) ≤ injectivity_radius(M, pts[1])
        end
    end

    @testset "is_manifold_point" begin
        for pt ∈ pts
            @test is_manifold_point(M, pt)
            @test check_manifold_point(M, pt) === nothing
            @test check_manifold_point(M, pt) === nothing
        end
    end

    test_is_tangent && @testset "is_tangent_vector" begin
        for (x,v) in zip(pts,tv)
            if !( check_tangent_vector(M, x,v; atol = is_tangent_atol_multiplier*eps(eltype(x)))  === nothing )
                print( check_tangent_vector(M, x,v; atol = is_tangent_atol_multiplier*eps(eltype(x))) )
            end
            @test is_tangent_vector(M, x, v; atol = is_tangent_atol_multiplier*eps(eltype(x)))
            @test check_tangent_vector(M, x,v; atol = is_tangent_atol_multiplier*eps(eltype(x))) === nothing
        end
    end

    test_exp_log && @testset "log/exp tests" begin
        v1 = log(M, pts[1], pts[2])
        v2 = log(M, pts[2], pts[1])
        @test isapprox(M, pts[2], exp(M, pts[1], v1))
        @test isapprox(M, pts[1], exp(M, pts[1], v1, 0))
        @test isapprox(M, pts[2], exp(M, pts[1], v1, 1))
        @test isapprox(M, pts[1], exp(M, pts[2], v2))
        @test is_manifold_point(M, exp(M, pts[1], v1))
        @test isapprox(M, pts[1], exp(M, pts[1], v1, 0))
        for x ∈ pts
            @test isapprox(M, x, zero_tangent_vector(M, x), log(M, x, x);
                atol = eps(eltype(x)) * exp_log_atol_multiplier,
                rtol = exp_log_atol_multiplier == 0. ? sqrt(eps(eltype(x)))*exp_log_rtol_multiplier : 0
            )
            @test isapprox(M, x, zero_tangent_vector(M, x), inverse_retract(M, x, x);
                atol = eps(eltype(x)) * exp_log_atol_multiplier,
                rtol = exp_log_atol_multiplier == 0. ? sqrt(eps(eltype(x)))*exp_log_rtol_multiplier : 0.
            )
        end
        zero_tangent_vector!(M, v1, pts[1])
        @test isapprox(M, pts[1], v1, zero_tangent_vector(M, pts[1]); atol = eps(eltype(pts[1])) * exp_log_atol_multiplier)
        log!(M, v1, pts[1], pts[2])
        @test norm(M, pts[1], v1) ≈ sqrt(inner(M, pts[1], v1, v1))

        @test isapprox(M, exp(M, pts[1], v1, 1), pts[2]; atol = eps(eltype(pts[1])) * exp_log_atol_multiplier)
        @test isapprox(M, exp(M, pts[1], v1, 0), pts[1]; atol = eps(eltype(pts[1])) * exp_log_atol_multiplier)

        @test distance(M, pts[1], pts[2]) ≈ norm(M, pts[1], v1)
    end
    
    @testset "(inverse &) retraction tests" begin
        for (x,v) in zip(pts,tv)
            for retr_method ∈ retraction_methods
                @test is_manifold_point(M, retract(M, x, v, retr_method))
                @test isapprox(M, x, retract(M, x, v, 0, retr_method);
                    atol = eps(eltype(x)) * retraction_atol_multiplier,
                    rtol = retraction_atol_multiplier == 0 ? sqrt(eps(eltype(x)))*retraction_rtol_multiplier : 0
                )
                new_pt = similar(x)
                retract!(M, new_pt, x, v, retr_method)
                @test is_manifold_point(M, new_pt)
            end
        end
        for x ∈ pts
            for inv_retr_method ∈ inverse_retraction_methods
                @test isapprox(M, x, zero_tangent_vector(M, x), inverse_retract(M, x, x, inv_retr_method);
                    atol = eps(eltype(x)) * retraction_atol_multiplier,
                    rtol = retraction_atol_multiplier == 0 ? sqrt(eps(eltype(x)))*retraction_rtol_multiplier : 0
                )
            end
        end
    end

    test_vector_spaces && @testset "vector spaces tests" begin
        for x ∈ pts
            v = zero_tangent_vector(M, x)
            mts = Manifolds.VectorBundleFibers(Manifolds.TangentSpace, M)
            @test isapprox(M, x, v, zero_vector(mts, x))
            zero_vector!(mts, v, x)
            @test isapprox(M, x, v, zero_tangent_vector(M,x))
        end
    end

    @testset "basic linear algebra in tangent space" begin
        for (x,v) in zip(pts,tv)
            @test isapprox(M, x, 0*v, zero_tangent_vector(M, x); atol = eps(eltype(pts[1])))
            @test isapprox(M, x, 2*v, v+v)
            @test isapprox(M, x, 0*v, v-v)
            @test isapprox(M, x, (-1)*v, -v)
        end
    end

    test_tangent_vector_broadcasting && @testset "broadcasted linear algebra in tangent space" begin
        for (x,v) in zip(pts,tv)
            @test isapprox(M, x, 3*v, 2 .* v .+ v)
            @test isapprox(M, x, -v, v .- 2 .* v)
            @test isapprox(M, x, -v, .-v)
            w = similar(v)
            w .= 2 .* v .+ v
            @test w ≈ 3*v
        end
    end

    test_project_tangent && @testset "project_tangent test" begin
        for (x,v) in zip(pts,tv)
            @test isapprox(M, x, v, project_tangent(M, x, v); atol = eps(eltype(x)) * projection_atol_multiplier)
            v2 = similar(v)
            project_tangent!(M, v2, x, v)
            @test isapprox(M, x, v2, v; atol = eps(eltype(x)) * projection_atol_multiplier)
        end
    end

    test_vector_transport && !( default_inverse_retraction_method === nothing) && @testset "vector transport" begin
        v1 = inverse_retract(M, pts[1], pts[2], default_inverse_retraction_method)
        v2 = inverse_retract(M, pts[1], pts[3], default_inverse_retraction_method)
        v1t1 = vector_transport_to(M, pts[1], v1, pts[3])
        v1t2 = vector_transport_direction(M, pts[1], v1, v2)
        @test is_tangent_vector(M, pts[3], v1t1)
        @test is_tangent_vector(M, pts[3], v1t2)
        @test isapprox(M, pts[3], v1t1, v1t2)
        @test isapprox(M, pts[1], vector_transport_to(M, pts[1], v1, pts[1]), v1)
    end

    test_forward_diff && @testset "ForwardDiff support" begin
        for (x,v) in zip(pts,tv)
            exp_f(t) = distance(M, x, exp(M, x, t[1]*v))
            d12 = norm(M,x,v)
            for t ∈ 0.1:0.1:0.9
                @test d12 ≈ ForwardDiff.derivative(exp_f, t)
            end

            retract_f(t) = distance(M, x, retract(M, x, t[1]*v))
            for t ∈ 0.1:0.1:0.9
                @test ForwardDiff.derivative(retract_f, t) ≥ 0
            end
        end
    end

    test_reverse_diff && @testset "ReverseDiff support" begin
        for (x,v) in zip(pts,tv)
            exp_f(t) = distance(M, x, exp(M, x, t[1]*v))
            d12 = norm(M,x,v)
            for t ∈ 0.1:0.1:0.9
                @test d12 ≈ ReverseDiff.gradient(exp_f, [t])[1]
            end

            retract_f(t) = distance(M, x, retract(M, x, t[1]*v))
            for t ∈ 0.1:0.1:0.9
                @test ReverseDiff.gradient(retract_f, [t])[1] ≥ 0
            end
        end
    end

    test_musical_isomorphisms && @testset "Musical isomorphisms" begin
        if default_inverse_retraction_method !== nothing
            tv_m = inverse_retract(M, pts[1], pts[2],default_inverse_retraction_method)
        else
            tv_m = zero_tangent_vector(M,pts[1])
        end
        ctv_m = flat(M, pts[1], FVector(TangentSpace, tv_m))
        @test ctv_m.type == CotangentSpace
        tv_m_back = sharp(M, pts[1], ctv_m)
        @test tv_m_back.type == TangentSpace
    end

    @testset "eltype" begin
        for (x,v) in zip(pts,tv)
            @test eltype(v) == eltype(x)
            p = retract(M, x, v, default_retraction_method)
            @test eltype(p) == eltype(x)
        end
    end

    @testset "copyto!" begin
        for (x,v) in zip(pts,tv)
            x2 = similar(x)
            copyto!(x2, x)
            @test isapprox(M, x2, x)

            v2 = similar(v)
            if default_inverse_retraction_method === nothing
                v3 = zero_tangent_vector(M,x)
                copyto!(v2, v3)
                @test isapprox(M, x, v2, zero_tangent_vector(M,x))
            else
                y = retract(M,x,v, default_retraction_method)
                v3 = inverse_retract(M, x, y, default_inverse_retraction_method)
                copyto!(v2, v3)
                @test isapprox(M, x, v2, inverse_retract(M, x, y, default_inverse_retraction_method))
            end
        end
    end

    @testset "point distributions" begin
        for x in pts
            prand = similar(x)
            for pd ∈ point_distributions
                for _ in 1:10
                    @test is_manifold_point(M, rand(pd))
                    if test_mutating_rand
                        rand!(pd, prand)
                        @test is_manifold_point(M, prand)
                    end
                end
            end
        end
    end

    @testset "tangent vector distributions" begin
        for tvd ∈ tvector_distributions
            supp = Manifolds.support(tvd)
            for _ in 1:10
                randtv = rand(tvd)
                @test is_tangent_vector(M, supp.x, randtv; atol = rand_tvector_atol_multiplier * eps(eltype(randtv)))
            end
        end
    end
end
