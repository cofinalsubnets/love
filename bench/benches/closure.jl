include(joinpath(@__DIR__, "..", "lib", "bench.jl"))

# closure / higher-order stress (see bench/benches/closure.l). checksum = sum 3i.
# We iterate a prebuilt vector rather than a literal `0:N-1` range: its element
# values are opaque to LLVM, which stops scalar-evolution from recognising the
# loop as a closed-form arithmetic series and folding the WHOLE benchmark to a
# compile-time literal (an O(1) "answer" that measures nothing). Julia still
# inlines the monomorphic closures and vectorises the sum -- an honest "these
# closures are ~free here" result, just an actual O(n) loop.
twice(f) = x -> f(f(x))
adder(i) = x -> x + i
const CLOSURE_IDX = collect(0:99999)

function closure_work()
    s = 0
    for i in CLOSURE_IDX
        s += twice(adder(i))(i)
    end
    return s
end

bench("closure", closure_work)
