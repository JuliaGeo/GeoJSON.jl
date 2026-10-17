precompile(read, (String,))
precompile(read, (Vector{UInt8},))
for D in (2, 3), T in (Float32, Float64)
    precompile(write, (Point{D,T},))
    precompile(write, (Feature{D,T},))
    precompile(write, (FeatureCollection{D,T},))
end
