include(joinpath(@__DIR__, "..", "lib", "bench.jl"))

# square every element, keep the even squares, sum them.
const MAPFILTER_DATA = collect(0:9999)

mapfilter_work() = sum(filter(iseven, map(x -> x * x, MAPFILTER_DATA)))

bench("mapfilter", mapfilter_work)
