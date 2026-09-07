include(joinpath(@__DIR__, "..", "lib", "bench.jl"))
# sortby: N (key, idx) records ordered by a user comparator on a derived key (key%4096, then key);
# checksum = rolling hash of the idx sequence.
const SORTBY_N = 5000
function sortby_work()
    x = 1
    data = Vector{Tuple{Int,Int}}(undef, SORTBY_N)
    for i in 1:SORTBY_N
        x = (16807 * x) % 2147483647
        data[i] = (x, i - 1)
    end
    sort!(data, lt = (a, b) -> begin
        ma = a[1] % 4096; mb = b[1] % 4096
        ma < mb || (ma == mb && a[1] < b[1])
    end)
    h = 0
    for (_, i) in data
        h = (h * 31 + i) % 1000000007
    end
    return h
end

bench("sortby", sortby_work)
