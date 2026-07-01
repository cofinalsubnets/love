include(joinpath(@__DIR__, "..", "lib", "bench.jl"))
twice(f) = x -> f(f(x))
adder(i) = x -> x + i
function closure_work()
    fns = Function[twice(adder(i)) for i in 0:99999]
    s = 0
    for i in 0:99999
        s += fns[i+1](i)::Int
    end
    return s
end
bench("closure", closure_work)
