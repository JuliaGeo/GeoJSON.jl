using Random
Random.seed!(1)
dir = joinpath(ENV["TMPDIR"], "benchdata"); mkpath(dir)
r() = round(rand()*360-180, digits=6)
function points(n)
    io = IOBuffer(); print(io, """{"type":"FeatureCollection","features":[""")
    for i in 1:n
        i > 1 && print(io, ",")
        print(io, """{"type":"Feature","id":$i,"geometry":{"type":"Point","coordinates":[$(r()),$(r())]},"properties":{"name":"f$i","pop":$(rand(1:10^6)),"area":$(rand()),"ok":$(rand(Bool))}}""")
    end
    print(io, "]}"); String(take!(io))
end
function polys(n, k)
    io = IOBuffer(); print(io, """{"type":"FeatureCollection","features":[""")
    for i in 1:n
        i > 1 && print(io, ",")
        ring = join(["[$(r()),$(r())]" for _ in 1:k], ",")
        g = isodd(i) ? """{"type":"Polygon","coordinates":[[$ring]]}""" : """{"type":"MultiPolygon","coordinates":[[[$ring]],[[$ring]]]}"""
        print(io, """{"type":"Feature","geometry":$g,"properties":{"name":"f$i","nested":{"a":[1,2,{"b":"c"}],"d":null},"v":$(rand())}}""")
    end
    print(io, "]}"); String(take!(io))
end
function wideprops(n, m)
    io = IOBuffer(); print(io, """{"type":"FeatureCollection","features":[""")
    for i in 1:n
        i > 1 && print(io, ",")
        props = join(["\"p$j\":" * (j % 3 == 0 ? "\"s$(rand(1:100))\"" : j % 3 == 1 ? string(rand(1:1000)) : string(rand())) for j in 1:m], ",")
        print(io, """{"type":"Feature","geometry":{"type":"Point","coordinates":[$(r()),$(r())]},"properties":{$props}}""")
    end
    print(io, "]}"); String(take!(io))
end
write(joinpath(dir, "points10k.json"), points(10_000))
write(joinpath(dir, "polys2k_50.json"), polys(2_000, 50))
write(joinpath(dir, "bigpoly.json"), polys(2, 200_000))
write(joinpath(dir, "wide2k_100.json"), wideprops(2_000, 100))
foreach(f -> println(f, " ", filesize(joinpath(dir,f)) ÷ 1000, " kB"), readdir(dir))
