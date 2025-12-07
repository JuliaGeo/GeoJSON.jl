# JSON3.jl to JSON.jl Migration Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Migrate GeoJSON.jl from JSON3.jl + StructTypes.jl to JSON.jl 1.0 + StructUtils.jl

**Architecture:** Replace all JSON3 API calls with JSON.jl equivalents. StructTypes.jl declarations must be converted to StructUtils.jl patterns. The key changes are: `JSON3.read` → `JSON.parse`, `JSON3.write` → `JSON.json`, and StructTypes trait declarations → StructUtils macros/patterns.

**Tech Stack:** Julia, JSON.jl 1.0, StructUtils.jl, GeoInterface.jl, Tables.jl

---

## Summary of Changes Required

### Files to Modify:
1. `Project.toml` - Update dependencies
2. `src/GeoJSON.jl` - Update imports
3. `src/geojson_types.jl` - Convert StructTypes to StructUtils
4. `src/io.jl` - Convert JSON3.read/write to JSON.parse/json
5. `src/precompile.jl` - Update precompile statements
6. `test/runtests.jl` - Update test imports
7. `README.md` - Update documentation references

### Key API Mapping:
| JSON3.jl | JSON.jl 1.0 |
|----------|-------------|
| `JSON3.read(io, Type)` | `JSON.parse(io, Type)` |
| `JSON3.write(obj)` | `JSON.json(obj)` |
| `JSON3.write(io, obj)` | `JSON.json(io, obj)` |
| `JSON3.RawValue` | Need custom handling |
| `JSON3.rawbytes` | Need custom handling |
| `StructTypes.StructType` | StructUtils auto-detection or `@struct` macro |
| `StructTypes.AbstractType()` | `JSON.@choosetype` macro |
| `StructTypes.subtypes` | `JSON.@choosetype` with selector function |
| `StructTypes.omitempties` | `JSON.json(x; omit_null=true, omit_empty=true)` |

---

## Task 1: Update Project.toml Dependencies

**Files:**
- Modify: `Project.toml` (via Pkg.jl only)

**Step 1: Remove old dependencies**

Run:
```julia
using Pkg
Pkg.rm("JSON3")
Pkg.rm("StructTypes")
```

**Step 2: Add new dependencies**

Run:
```julia
Pkg.add("JSON")
Pkg.add("StructUtils")
```

**Step 3: Set compat bounds**

Run:
```julia
Pkg.compat("JSON", "1")
Pkg.compat("StructUtils", "1")
```

**Step 4: Verify the changes**

Run: `cat Project.toml | grep -E "(JSON|StructTypes|StructUtils)"`
Expected: Only `JSON` and `StructUtils` appear, no `JSON3` or `StructTypes`

**Step 5: Commit**

```bash
git add Project.toml
git commit -m "deps: replace JSON3/StructTypes with JSON/StructUtils"
```

---

## Task 2: Update Main Module Imports

**Files:**
- Modify: `src/GeoJSON.jl:9`

**Step 1: Edit the import line**

```julia
# Old (line 9):
import Extents, GeoFormatTypes, JSON3, Tables, StructTypes

# New:
import Extents, GeoFormatTypes, JSON, Tables
import StructUtils
```

**Step 2: Verify the edit**

Run: `grep -n "import" src/GeoJSON.jl`

**Step 3: Commit**

```bash
git add src/GeoJSON.jl
git commit -m "refactor: update imports from JSON3/StructTypes to JSON/StructUtils"
```

---

## Task 3: Convert io.jl - Reading Functions

**Files:**
- Modify: `src/io.jl:1-36`

**Step 1: Update the read function to use JSON.parse**

```julia
# Old (lines 13-28):
function read(io; lazyfc=false, ndim=2, numbertype=Float32)
    if lazyfc
        obj = JSON3.read(io, LazyFeatureCollection{ndim,numbertype})
    else
        try
            obj = JSON3.read(io, GeoJSONWrapper{ndim,numbertype}).obj
        catch e
            if e isa ArgumentError
                @warn "Failed to parse GeoJSON as 2D, trying 3D. Set `ndim` to 3 to avoid this warning."
                obj = JSON3.read(io, GeoJSONWrapper{ndim + 1,numbertype}).obj
            else
                rethrow(e)
            end
        end
    end
end

# New:
function read(io; lazyfc=false, ndim=2, numbertype=Float32)
    if lazyfc
        obj = JSON.parse(io, LazyFeatureCollection{ndim,numbertype})
    else
        try
            obj = JSON.parse(io, GeoJSONWrapper{ndim,numbertype}).obj
        catch e
            if e isa ArgumentError
                @warn "Failed to parse GeoJSON as 2D, trying 3D. Set `ndim` to 3 to avoid this warning."
                obj = JSON.parse(io, GeoJSONWrapper{ndim + 1,numbertype}).obj
            else
                rethrow(e)
            end
        end
    end
end
```

**Step 2: Update the Dict-to-string conversion**

```julia
# Old (lines 32-36):
function read(source::GeoFormatTypes.GeoJSON{<:AbstractDict})
    dict = GeoFormatTypes.val(source)
    str = JSON3.write(dict)
    return read(str)
end

# New:
function read(source::GeoFormatTypes.GeoJSON{<:AbstractDict})
    dict = GeoFormatTypes.val(source)
    str = JSON.json(dict)
    return read(str)
end
```

**Step 3: Run tests to verify read works**

Run: `julia --project -e 'using GeoJSON; println(GeoJSON.read("{\"type\":\"Point\",\"coordinates\":[1,2]}"))'`
Expected: Should print a Point object (will fail until all changes complete)

**Step 4: Commit**

```bash
git add src/io.jl
git commit -m "refactor: convert read functions from JSON3.read to JSON.parse"
```

---

## Task 4: Convert io.jl - Writing Functions

**Files:**
- Modify: `src/io.jl:50-56`

**Step 1: Update write functions to use JSON.json**

```julia
# Old (lines 50-55):
write(io, obj::GeoJSONT) = JSON3.write(io, obj)
write(obj::GeoJSONT) = JSON3.write(obj)

# GeoInterface supported objects
write(io, obj; geometrycolumn = first(GI.geometrycolumns(obj))) = JSON3.write(io, _lower(obj; geometrycolumn))
write(obj; geometrycolumn = first(GI.geometrycolumns(obj))) = JSON3.write(_lower(obj; geometrycolumn))

# New:
write(io, obj::GeoJSONT) = JSON.json(io, obj)
write(obj::GeoJSONT) = JSON.json(obj)

# GeoInterface supported objects
write(io, obj; geometrycolumn = first(GI.geometrycolumns(obj))) = JSON.json(io, _lower(obj; geometrycolumn))
write(obj; geometrycolumn = first(GI.geometrycolumns(obj))) = JSON.json(_lower(obj; geometrycolumn))
```

**Step 2: Run basic write test**

Run: `julia --project -e 'using GeoJSON; p = GeoJSON.Point(coordinates=(1.0f0, 2.0f0)); println(GeoJSON.write(p))'`
Expected: Should print JSON string (will fail until all changes complete)

**Step 3: Commit**

```bash
git add src/io.jl
git commit -m "refactor: convert write functions from JSON3.write to JSON.json"
```

---

## Task 5: Convert geojson_types.jl - LazyFeature JSON3 References

**Files:**
- Modify: `src/geojson_types.jl:210-220`

**Step 1: Analyze LazyFeature and its JSON3 dependencies**

The LazyFeature uses:
- `JSON3.RawValue` for lazy parsing
- `JSON3.rawbytes` for byte access

This is a JSON3-specific feature. JSON.jl 1.0 uses `JSON.lazy()` differently. We need to refactor this.

```julia
# Old (lines 210-220):
# This is a non-public type used to lazily construct a Feature from a JSON3.RawValue
# It can be written again as String, which can also be used to parse to a Feature
struct LazyFeature{D,T} <: GeoJSONT{D,T}
    bytes::Any
    pos::Int
    len::Int
end
@inline StructTypes.construct(::Type{LazyFeature{D,T}}, x::JSON3.RawValue) where {D,T} = LazyFeature{D,T}(x.bytes, x.pos, x.len)
@inline Base.codeunits(x::LazyFeature) = unsafe_string(pointer(x.bytes, x.pos), x.len)
@inline JSON3.rawbytes(x::LazyFeature) = codeunits(x)

# New - Using JSON.jl's lazy parsing approach:
# This is a non-public type used to lazily construct a Feature from JSON bytes
# It can be written again as String, which can also be used to parse to a Feature
struct LazyFeature{D,T} <: GeoJSONT{D,T}
    bytes::Any
    pos::Int
    len::Int
end

# StructUtils construction from raw JSON data
@inline function StructUtils.construct(::Type{LazyFeature{D,T}}, data) where {D,T}
    bytes = codeunits(String(data))
    LazyFeature{D,T}(bytes, 1, length(bytes))
end

@inline Base.codeunits(x::LazyFeature) = unsafe_string(pointer(x.bytes, x.pos), x.len)
```

**Note:** The LazyFeature pattern may need significant rework since JSON.jl handles lazy parsing differently. For now, we'll adapt the interface to work with StructUtils.

**Step 2: Commit**

```bash
git add src/geojson_types.jl
git commit -m "refactor: adapt LazyFeature for StructUtils"
```

---

## Task 6: Convert geojson_types.jl - StructTypes Declarations to StructUtils

**Files:**
- Modify: `src/geojson_types.jl:316-354`

**Step 1: Understand the current StructTypes pattern**

Current code uses:
- `StructTypes.StructType(::Type{T}) = StructTypes.Struct()` for concrete types
- `StructTypes.StructType(::Type{T}) = StructTypes.AbstractType()` for abstract types
- `StructTypes.subtypekey` and `StructTypes.subtypes` for polymorphic parsing

**Step 2: Convert to StructUtils/JSON.jl patterns**

The JSON.jl 1.0 approach uses `@choosetype` macro for abstract types:

```julia
# Old (lines 316-354):
@inline StructTypes.StructType(::Type{<:GeoJSONWrapper}) = StructTypes.CustomStruct()
@inline StructTypes.lower(x::GeoJSONWrapper) = x.obj
@inline StructTypes.lowertype(::Type{<:GeoJSONWrapper{D,T}}) where {D,T} = GeoJSONT{D,T}

# ... type string functions ...

@inline StructTypes.StructType(::Type{<:GeoJSONT}) = StructTypes.AbstractType()
@inline StructTypes.StructType(::Type{<:AbstractGeometry}) = StructTypes.AbstractType()
@inline StructTypes.StructType(::Type{<:Point}) = StructTypes.Struct()
# ... more Struct declarations ...
@inline StructTypes.subtypekey(::Type{<:AbstractGeometry}) = :type
@inline StructTypes.subtypes(::Type{<:AbstractGeometry{D,T}}) where {D,T} = geom_mapping(D, T)
@inline StructTypes.subtypekey(::Type{<:GeoJSONT}) = :type
@inline StructTypes.subtypes(::Type{<:GeoJSONT{D,T}}) where {D,T} = merge(geom_mapping(D, T), obj_mapping(D, T))

@inline StructTypes.StructType(::Type{<:Feature}) = StructTypes.Struct()
@inline StructTypes.StructType(::Type{<:LazyFeature}) = JSON3.RawType()
@inline StructTypes.StructType(::Type{<:FeatureCollection}) = StructTypes.Struct()
@inline StructTypes.excludes(::Type{<:FeatureCollection}) = (:names, :types,)
@inline StructTypes.StructType(::Type{<:LazyFeatureCollection}) = StructTypes.Struct()
@inline StructTypes.StructType(::Type{CRS}) = StructTypes.Struct()

@inline StructTypes.omitempties(::Type{<:GeoJSONT}) = (:id, :crs, :bbox,)

# New - Using JSON.jl 1.0 / StructUtils patterns:

# GeoJSONWrapper lowering for serialization
@inline StructUtils.lower(x::GeoJSONWrapper) = x.obj

# Type choosers for polymorphic parsing
# For AbstractGeometry - select based on "type" field
function _choose_geometry_type(::Type{AbstractGeometry{D,T}}, json) where {D,T}
    type_str = json.type[]
    mapping = geom_mapping(D, T)
    return get(mapping, Symbol(type_str), nothing)
end

JSON.@choosetype AbstractGeometry{D,T} where {D,T} _choose_geometry_type

# For GeoJSONT - select based on "type" field (includes geometries + Feature/FeatureCollection)
function _choose_geojson_type(::Type{GeoJSONT{D,T}}, json) where {D,T}
    type_str = json.type[]
    mapping = merge(geom_mapping(D, T), obj_mapping(D, T))
    return get(mapping, Symbol(type_str), nothing)
end

JSON.@choosetype GeoJSONT{D,T} where {D,T} _choose_geojson_type

# Exclude computed fields from FeatureCollection serialization
StructUtils.@exclude FeatureCollection :names :types

# Handle omit empty for optional fields - use keyword args when writing instead
```

**Important Notes:**
1. JSON.jl 1.0 handles struct serialization automatically via StructUtils
2. The `@choosetype` macro replaces `AbstractType()` + `subtypes()`
3. `omitempties` is handled via `JSON.json(x; omit_null=true, omit_empty=true)` at call site

**Step 3: Commit**

```bash
git add src/geojson_types.jl
git commit -m "refactor: convert StructTypes to StructUtils/JSON.jl patterns"
```

---

## Task 7: Update LazyFeatureCollection Indexing

**Files:**
- Modify: `src/geojson_types.jl:291`

**Step 1: Update the JSON3.read call in getindex**

```julia
# Old (line 291):
Base.getindex(x::LazyFeatureCollection{D,T}, i::Int) where {D,T} = JSON3.read(codeunits(x.features[i]), Feature{D,T})::Feature{D,T}

# New:
Base.getindex(x::LazyFeatureCollection{D,T}, i::Int) where {D,T} = JSON.parse(codeunits(x.features[i]), Feature{D,T})::Feature{D,T}
```

**Step 2: Commit**

```bash
git add src/geojson_types.jl
git commit -m "refactor: update LazyFeatureCollection indexing to use JSON.parse"
```

---

## Task 8: Update precompile.jl

**Files:**
- Modify: `src/precompile.jl`

**Step 1: Update all JSON3 references to JSON**

The precompile file contains many precompile statements with `JSON3`. These need bulk replacement:

```bash
# Replace all JSON3 with JSON in precompile.jl
sed -i '' 's/JSON3/JSON/g' src/precompile.jl
```

Also replace StructTypes references:
```bash
sed -i '' 's/StructTypes/StructUtils/g' src/precompile.jl
```

**Step 2: Verify replacements**

Run: `grep -c "JSON3\|StructTypes" src/precompile.jl`
Expected: 0

**Step 3: Commit**

```bash
git add src/precompile.jl
git commit -m "refactor: update precompile statements for JSON/StructUtils"
```

---

## Task 9: Update Test File

**Files:**
- Modify: `test/runtests.jl:6`

**Step 1: Update the JSON3 import**

```julia
# Old (line 6):
using JSON3

# New:
using JSON
```

**Step 2: Commit**

```bash
git add test/runtests.jl
git commit -m "test: update imports from JSON3 to JSON"
```

---

## Task 10: Update README.md

**Files:**
- Modify: `README.md:8`

**Step 1: Update the JSON3 reference**

```markdown
# Old (line 8):
Read [GeoJSON](https://geojson.org/) files using [JSON3.jl](https://github.com/quinnj/JSON3.jl), and provide the [Tables.jl](https://github.com/JuliaData/Tables.jl) interface.

# New:
Read [GeoJSON](https://geojson.org/) files using [JSON.jl](https://github.com/JuliaIO/JSON.jl), and provide the [Tables.jl](https://github.com/JuliaData/Tables.jl) interface.
```

**Step 2: Commit**

```bash
git add README.md
git commit -m "docs: update README to reference JSON.jl"
```

---

## Task 11: Handle omit_empty for Write Operations

**Files:**
- Modify: `src/io.jl:50-55`

**Step 1: Add omit_null and omit_empty to write calls**

Since JSON.jl 1.0 uses keyword arguments instead of StructTypes.omitempties:

```julia
# Update write functions to include omit options:
write(io, obj::GeoJSONT) = JSON.json(io, obj; omit_null=true)
write(obj::GeoJSONT) = JSON.json(obj; omit_null=true)

write(io, obj; geometrycolumn = first(GI.geometrycolumns(obj))) = JSON.json(io, _lower(obj; geometrycolumn); omit_null=true)
write(obj; geometrycolumn = first(GI.geometrycolumns(obj))) = JSON.json(_lower(obj; geometrycolumn); omit_null=true)
```

**Step 2: Commit**

```bash
git add src/io.jl
git commit -m "refactor: add omit_null to write functions for optional field handling"
```

---

## Task 12: Run Full Test Suite

**Files:**
- None (verification only)

**Step 1: Install new dependencies**

Run: `julia --project -e 'using Pkg; Pkg.update()'`

**Step 2: Run tests**

Run: `julia --project -e 'using Pkg; Pkg.test()'`

**Step 3: Fix any failing tests**

Review failures and iterate. Common issues:
- API differences between JSON3 and JSON
- StructUtils vs StructTypes behavior differences
- Lazy parsing behavior changes

**Step 4: Commit any fixes**

```bash
git add -A
git commit -m "fix: resolve test failures after JSON migration"
```

---

## Task 13: Final Verification and Cleanup

**Files:**
- All modified files

**Step 1: Verify no JSON3 or StructTypes references remain**

Run: `grep -r "JSON3\|StructTypes" src/ test/`
Expected: No matches

**Step 2: Run Aqua.jl quality checks**

Run: `julia --project -e 'using Pkg; Pkg.test()' | grep -A5 "Aqua"`
Expected: All Aqua tests pass

**Step 3: Create final commit**

```bash
git add -A
git commit -m "chore: complete JSON3 to JSON.jl migration"
```

---

## Known Challenges and Considerations

### 1. LazyFeature/LazyFeatureCollection
The lazy parsing mechanism in JSON3 uses `JSON3.RawValue` which stores byte positions. JSON.jl's `JSON.lazy()` returns a different structure. This may require more significant refactoring.

**Fallback approach:** If lazy parsing proves difficult to migrate, consider:
- Deprecating `lazyfc=true` option temporarily
- Or implementing custom lazy parsing using JSON.jl's lower-level APIs

### 2. Abstract Type Dispatch
JSON3's `StructTypes.AbstractType()` with `subtypes()` provides runtime type selection. JSON.jl's `@choosetype` is similar but uses a function-based approach. Ensure the type selection logic correctly handles all GeoJSON geometry types.

### 3. Type Inference
StructUtils may have different type inference behavior. Test with various GeoJSON files to ensure all geometry types parse correctly.

### 4. Performance
After migration, benchmark read/write performance to ensure no regressions. JSON.jl 1.0 is designed to be performant, but different code paths may have different characteristics.
