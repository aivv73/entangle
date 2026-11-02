# Coverage rounding bound

The rectangle oracle never reads a production matrix or a projected vertex.
Its ideal arithmetic uses q=(0,0,3/5,4/5), scales (2,3,4), and the rational
local XY corners (-103/200,-1/75), (7/200,-2/25),
(103/200,1/75), and (-7/200,2/25). It therefore places edges on integer pixel coordinates.
Every pixel center is at least 1/2 pixel from an outer edge. Triangle shared
edges have identical color and constant depth.

The camera maps world coordinates to clip coordinates as
x/64-31/32, y/16-x/8+1/4, z/256+1/2, with w=1.
The 1024 by 256 positive-height viewport gives ideal rectangle centers
cx=16+8*(i+k), cy=160-12*k. Rectangle half-extents are two and four pixels.
The executable uses integer bounds cx-2<=x<cx+2 and cy-4<=y<cy+4.
Width four and center spacing eight make all 100 rectangles disjoint.
Local Z is 1/32 for red near vertices and 3/32 for green far vertices.
The two index orders exercise depth rejection with the same geometry.

Binary32 unit roundoff is u=2^-24. Include the decimal quaternion and vertex
conversions, CPU matrix operations, and shader dot products in a conservative
64-rounding path. Their error factor is gamma64=64u/(1-64u). All operations
are normal or exact zero on this workload. No division by a computed value
occurs. Homogeneous w remains exactly one.

An absolute-term envelope of 4096 pixels bounds either screen coordinate,
including viewport mapping. Over i=0..99, k=1..8, |tx|<=107, |ty|<=202,
|tz|<=115, |u_vertex|<=103/200, |v_vertex|<=2/25. The ideal scaled/rotated
XY vertex displacements have absolute-term sums below 4 world units per
axis. For Y, the larger screen axis, the camera's absolute sum is bounded by
128*((202+4)/16+(107+4)/8+1/4+1) < 3600.
X is bounded by 512*((107+4)/64+31/32+1) < 1900.
4096 leaves room for initial coefficient rounding as part of gamma64.
The 64-path budget exceeds the operations along a matrix coefficient,
model-camera product, vertex dot product, and viewport transform, including
input conversions and q-products. It also permits separately rounded products
and sums rather than requiring fused multiply-add.

Vulkan's baseline subpixel precision is at least four fractional bits. Add
one full 1/16 pixel to cover snapping without assuming nearest rounding.
The resulting displacement bound is gamma64*4096+1/16 < 0.079 pixel,
which is below the executable acceptance bound of 1/4 pixel and the 1/2-pixel
edge clearance. The executable independently evaluates this conservative
bound before rendering. Exact equality is required for every coverage byte.

Depth has no XY-dependent term. Seed Z and scaled mesh Z are dyadic, and the
camera uses 1/256 and 1/2. The near depth is exactly
(1025-8*i-16*k)/2048. The executable constructs the expected IEEE word by
integer exponent/mantissa encoding and compares every D32 byte. Driver
interpolation remains a real-runtime gate, not a theorem about Vulkan.
