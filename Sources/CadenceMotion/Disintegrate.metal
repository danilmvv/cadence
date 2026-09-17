#include <metal_stdlib>
#include <SwiftUI/SwiftUI_Metal.h>

using namespace metal;

// MARK: - Hashes

// Cheap hash without transcendentals. This shader evaluates it a few hundred
// times per pixel (nine sites per lookup, five lookups per pixel), so the
// usual `fract(sin(dot(...)) * 43758.5453)` would put a sine in the inner
// loop for no reason. Deterministic: the same cell always gets the same
// numbers, which is what keeps a shard's trajectory stable across frames.
inline float hash11(float2 p) {
    float3 p3 = fract(float3(p.x, p.y, p.x) * 0.1031);
    p3 += dot(p3, float3(p3.y, p3.z, p3.x) + 33.33);
    return fract((p3.x + p3.y) * p3.z);
}

inline float2 hash21(float2 p) {
    float3 p3 = fract(float3(p.x, p.y, p.x) * float3(0.1031, 0.1030, 0.0973));
    p3 += dot(p3, float3(p3.y, p3.z, p3.x) + 33.33);
    return fract((float2(p3.x, p3.x) + float2(p3.y, p3.z)) * float2(p3.z, p3.y));
}

// MARK: - Partition

// Nominal shard size in points. The actual pieces are larger and smaller than
// this because of the per-site weight below.
constant float kCellSize = 22.0;

// How far a site may push its own boundary outwards, as a fraction of the
// cell. This is the whole reason the pieces come out in different sizes: a
// plain Voronoi over a jittered grid gives cells that are irregular in shape
// but all roughly one size, and uniform pieces read as procedural.
constant float kWeightRange = 0.45;

struct Shard {
    float2 id;      // grid cell of the winning site — the shard's identity
    float2 center;  // the site itself, in points; also the axis it spins about
    float dist;
};

/// Additively weighted Voronoi over a jittered grid.
///
/// A plain grid would read as tiles; jittering the site inside its cell makes
/// the boundaries irregular polygons, and the weight makes the polygons
/// different sizes. Three-by-three is enough because a weight can never move
/// a boundary by more than half a cell.
inline Shard nearestShard(float2 p) {
    float2 g = floor(p / kCellSize);

    Shard best;
    best.dist = 1e9;
    best.id = g;
    best.center = p;

    for (int dy = -1; dy <= 1; ++dy) {
        for (int dx = -1; dx <= 1; ++dx) {
            float2 n = g + float2(dx, dy);
            float2 site = (n + hash21(n)) * kCellSize;
            float weight = hash11(n + float2(41.7, 17.3)) * kWeightRange * kCellSize;
            float d = distance(p, site) - weight;
            if (d < best.dist) {
                best.dist = d;
                best.id = n;
                best.center = site;
            }
        }
    }
    return best;
}

// MARK: - Per-shard motion

struct Motion {
    float2 displacement;
    float angle;
    float alpha;
};

/// Everything about how one shard leaves, derived from a hash of its cell id
/// so that every pixel of the shard computes the identical answer. That is
/// what makes the piece move as a rigid body instead of as noise.
inline Motion shardMotion(float2 id, float2 center, float2 size, float progress, float maxOffset) {
    float2 ra = hash21(id + float2(1.7, 9.2));   // start jitter, span
    float2 rb = hash21(id + float2(4.3, 2.8));   // scatter angle, speed
    float spin = hash11(id + float2(7.1, 5.9));

    // The breakup sweeps diagonally from the bottom-left corner instead of
    // every piece leaving at once: mostly horizontal, with a quarter of the
    // weight on height so the sweep line is tilted rather than a vertical
    // curtain. The random quarter keeps the line from being a straight edge.
    float2 uv = center / max(size, float2(1.0));
    float sweep = 0.75 * uv.x + 0.25 * (1.0 - uv.y);
    float start = (0.6 * sweep + 0.4 * ra.x) * 0.55;
    float span = 0.42 + 0.26 * ra.y;

    float life = clamp((progress - start) / span, 0.0, 1.0);

    Motion m;
    m.displacement = float2(0.0);
    m.angle = 0.0;
    m.alpha = 1.0;
    if (life <= 0.0) {
        return m;
    }

    // Ease-out on the displacement: the piece detaches quickly and then
    // coasts. Linear motion here looks mechanical, ease-in looks like the
    // piece is being sucked away rather than breaking off.
    float move = 1.0 - pow(1.0 - life, 3.0);

    // Outward from the middle of the view, plus a per-shard scatter, plus a
    // constant upward bias (negative y is up in this space).
    float2 outward = center - size * 0.5;
    outward = outward / max(length(outward), 1.0);
    float scatterAngle = rb.x * 6.28318530718;
    float2 dir = outward * 0.7 + float2(cos(scatterAngle), sin(scatterAngle)) * 0.45 + float2(0.0, -0.9);
    dir = dir / max(length(dir), 1e-4);

    float speed = 0.4 + 0.85 * rb.y;
    m.displacement = dir * move * maxOffset * speed;

    // Rotation about the shard's own site, both directions.
    m.angle = (spin - 0.5) * 2.4 * move;

    // Alpha lags the movement: nothing starts fading until the piece is 40%
    // through its own life, so it is still visible while it travels. Fading
    // from the instant of detachment would hide the very thing the rigid
    // motion was built to show.
    m.alpha = 1.0 - smoothstep(0.4, 1.0, life);

    return m;
}

/// Where a destination pixel's colour comes from, if it belongs to `shard`.
/// The inverse of "rotate about the site, then translate".
inline float2 inverseTransform(float2 position, Shard shard, Motion motion) {
    float ca = cos(-motion.angle);
    float sa = sin(-motion.angle);
    float2 local = position - shard.center - motion.displacement;
    return shard.center + float2(local.x * ca - local.y * sa,
                                 local.x * sa + local.y * ca);
}

// MARK: - Entry point

[[ stitchable ]]
half4 disintegrate(
    float2 position,
    SwiftUI::Layer layer,
    float2 size,
    float progress,
    float maxOffset
) {
    if (progress <= 0.0) {
        return layer.sample(position);
    }

    // A shard covers this pixel exactly when its own inverse transform maps
    // the pixel back inside its own cell. Testing every candidate in the
    // radius the displacement allows would be a hundred-odd lookups per
    // pixel, so instead this walks to a fixed point: take the shard under the
    // pixel, undo its motion, see which shard is there now, repeat. Neighbours
    // move similarly, so it lands in three or four steps.
    Shard shard = nearestShard(position);
    Motion motion = shardMotion(shard.id, shard.center, size, progress, maxOffset);
    float2 source = inverseTransform(position, shard, motion);

    for (int i = 0; i < 4; ++i) {
        Shard next = nearestShard(source);
        if (all(next.id == shard.id)) {
            break;
        }
        shard = next;
        motion = shardMotion(shard.id, shard.center, size, progress, maxOffset);
        source = inverseTransform(position, shard, motion);
    }

    // Still not a fixed point: no shard covers this pixel. This is the gap
    // between flying pieces, and it has to be genuinely empty — returning the
    // layer here instead would smear the intact card into the holes.
    Shard settled = nearestShard(source);
    if (!all(settled.id == shard.id)) {
        return half4(0.0);
    }

    // `layer.sample` is premultiplied, so the whole half4 is scaled. Touching
    // only `.a` would leave rgb too bright and the pieces would glow as they
    // fade.
    return layer.sample(source) * half(motion.alpha);
}
