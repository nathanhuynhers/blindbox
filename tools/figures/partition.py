"""Deterministic lossless triangle partitioning; no Blender dependency."""
from collections import defaultdict


def partition(faces, positions, limit):
    """Keep connected islands together when they fit, then bisect large islands.

    Returns source triangle indices. No cuts, caps, welding or dropped triangles.
    Spatial cuts can leave open parts; the assembled surface is unchanged.
    """
    owners = defaultdict(list)
    for index, face in enumerate(faces):
        for vertex in face:
            owners[vertex].append(index)
    remaining = set(range(len(faces)))
    islands = []
    while remaining:
        seed = min(remaining)
        remaining.remove(seed)
        stack, island = [seed], []
        while stack:
            current = stack.pop()
            island.append(current)
            for vertex in faces[current]:
                for other in owners[vertex]:
                    if other in remaining:
                        remaining.remove(other)
                        stack.append(other)
        islands.append(sorted(island))
    centroids = [tuple(sum(positions[v][axis] for v in face) / 3 for axis in range(3)) for face in faces]

    def split(indices):
        if len(indices) <= limit:
            return [indices]
        spread = [max(centroids[i][a] for i in indices) - min(centroids[i][a] for i in indices) for a in range(3)]
        axis = max(range(3), key=lambda a: (spread[a], -a))
        ordered = sorted(indices, key=lambda i: (centroids[i][axis], i))
        middle = len(ordered) // 2
        return split(ordered[:middle]) + split(ordered[middle:])

    result, packed = [], []
    for island in islands:
        if len(island) > limit:
            if packed:
                result.append(packed)
                packed = []
            result.extend(split(island))
        elif len(packed) + len(island) > limit:
            result.append(packed)
            packed = island
        else:
            packed += island
    if packed:
        result.append(packed)
    return result
