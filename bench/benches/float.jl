include(joinpath(@__DIR__, "..", "lib", "bench.jl"))

# mandelbrot escape counts over a 64x64 grid (see bench/benches/float.l).
function mand(cx, cy)
    zx = 0.0
    zy = 0.0
    it = 0
    while it < 100 && zx * zx + zy * zy <= 4.0
        nzx = zx * zx - zy * zy + cx
        nzy = 2.0 * zx * zy + cy
        zx = nzx
        zy = nzy
        it += 1
    end
    return it
end

function float_work()
    s = 0
    for px in 0:63, py in 0:63
        s += mand(-2.0 + px * 0.046875, -1.5 + py * 0.046875)
    end
    return s
end

bench("float", float_work)
