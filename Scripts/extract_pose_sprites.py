#!/usr/bin/env python3
from __future__ import annotations

import argparse
from collections import deque
from pathlib import Path

from PIL import Image


POSE_NAMES = [
    "idle",
    "walk-1",
    "walk-2",
    "jump",
    "fall",
    "sit",
    "sleep",
    "wave",
    "happy",
    "alert",
    "play",
    "peek",
]


def is_subject(pixel: tuple[int, int, int, int], key: tuple[int, int, int], tolerance: int) -> bool:
    r, g, b, _ = pixel
    distance = abs(r - key[0]) + abs(g - key[1]) + abs(b - key[2])
    return distance > tolerance


def estimate_key(image: Image.Image) -> tuple[int, int, int]:
    corners = [
        image.getpixel((0, 0)),
        image.getpixel((image.width - 1, 0)),
        image.getpixel((0, image.height - 1)),
        image.getpixel((image.width - 1, image.height - 1)),
    ]
    return tuple(sum(pixel[index] for pixel in corners) // len(corners) for index in range(3))


def largest_component(mask: list[list[bool]]) -> tuple[int, int, int, int] | None:
    height = len(mask)
    width = len(mask[0])
    visited = [[False for _ in range(width)] for _ in range(height)]
    best: tuple[int, int, int, int, int] | None = None

    for y in range(height):
        for x in range(width):
            if visited[y][x] or not mask[y][x]:
                continue

            queue: deque[tuple[int, int]] = deque([(x, y)])
            visited[y][x] = True
            count = 0
            min_x = max_x = x
            min_y = max_y = y

            while queue:
                cx, cy = queue.popleft()
                count += 1
                min_x = min(min_x, cx)
                max_x = max(max_x, cx)
                min_y = min(min_y, cy)
                max_y = max(max_y, cy)

                for nx, ny in ((cx + 1, cy), (cx - 1, cy), (cx, cy + 1), (cx, cy - 1)):
                    if 0 <= nx < width and 0 <= ny < height and not visited[ny][nx] and mask[ny][nx]:
                        visited[ny][nx] = True
                        queue.append((nx, ny))

            if best is None or count > best[0]:
                best = (count, min_x, min_y, max_x, max_y)

    if best is None:
        return None
    _, min_x, min_y, max_x, max_y = best
    return min_x, min_y, max_x + 1, max_y + 1


def extract_pose(cell: Image.Image, key: tuple[int, int, int], tolerance: int, output_size: int, padding: int) -> Image.Image:
    rgba = cell.convert("RGBA")
    pixels = rgba.load()
    mask: list[list[bool]] = []

    for y in range(rgba.height):
        row = []
        for x in range(rgba.width):
            row.append(is_subject(pixels[x, y], key, tolerance))
        mask.append(row)

    bbox = largest_component(mask)
    if bbox is None:
        return Image.new("RGBA", (output_size, output_size), (0, 0, 0, 0))

    min_x, min_y, max_x, max_y = bbox
    min_x = max(0, min_x - padding)
    min_y = max(0, min_y - padding)
    max_x = min(rgba.width, max_x + padding)
    max_y = min(rgba.height, max_y + padding)

    cropped = rgba.crop((min_x, min_y, max_x, max_y))
    cropped_pixels = cropped.load()
    for y in range(cropped.height):
        for x in range(cropped.width):
            r, g, b, a = cropped_pixels[x, y]
            distance = abs(r - key[0]) + abs(g - key[1]) + abs(b - key[2])
            green_spill_edge = g > 145 and g > r + 24 and g > b + 24
            if distance <= tolerance or green_spill_edge:
                cropped_pixels[x, y] = (0, 0, 0, 0)
            elif distance < tolerance * 4:
                alpha = min(255, max(0, int((distance - tolerance) / (tolerance * 3) * 255)))
                cropped_pixels[x, y] = (*despill(r, g, b, key), min(a, alpha))
            else:
                cropped_pixels[x, y] = (*despill(r, g, b, key), a)

    alpha = cropped.getchannel("A")
    alpha_pixels = alpha.load()
    contracted = alpha.copy()
    contracted_pixels = contracted.load()
    for y in range(1, cropped.height - 1):
        for x in range(1, cropped.width - 1):
            if alpha_pixels[x, y] == 0:
                continue
            if min(
                alpha_pixels[x - 1, y],
                alpha_pixels[x + 1, y],
                alpha_pixels[x, y - 1],
                alpha_pixels[x, y + 1],
            ) == 0:
                contracted_pixels[x, y] = 0
    cropped.putalpha(contracted)

    canvas = Image.new("RGBA", (output_size, output_size), (0, 0, 0, 0))
    scale = min((output_size - 24) / cropped.width, (output_size - 24) / cropped.height)
    resized = cropped.resize((max(1, int(cropped.width * scale)), max(1, int(cropped.height * scale))), Image.Resampling.LANCZOS)
    x = (output_size - resized.width) // 2
    y = output_size - resized.height - 10
    canvas.alpha_composite(resized, (x, y))
    return canvas


def despill(r: int, g: int, b: int, key: tuple[int, int, int]) -> tuple[int, int, int]:
    if key[1] <= key[0] or key[1] <= key[2]:
        return r, g, b
    spill = max(0, g - max(r, b) - 8)
    if spill == 0:
        return r, g, b
    return r, max(0, g - int(spill * 0.82)), b


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--input", required=True, type=Path)
    parser.add_argument("--out-dir", required=True, type=Path)
    parser.add_argument("--columns", type=int, default=4)
    parser.add_argument("--rows", type=int, default=3)
    parser.add_argument("--output-size", type=int, default=512)
    parser.add_argument("--tolerance", type=int, default=52)
    parser.add_argument("--padding", type=int, default=10)
    args = parser.parse_args()

    args.out_dir.mkdir(parents=True, exist_ok=True)
    image = Image.open(args.input).convert("RGBA")
    key = estimate_key(image)
    cell_width = image.width // args.columns
    cell_height = image.height // args.rows

    for index, pose_name in enumerate(POSE_NAMES[: args.columns * args.rows]):
        column = index % args.columns
        row = index // args.columns
        cell = image.crop((column * cell_width, row * cell_height, (column + 1) * cell_width, (row + 1) * cell_height))
        pose = extract_pose(cell, key, args.tolerance, args.output_size, args.padding)
        pose.save(args.out_dir / f"{index:02d}-{pose_name}.png")

    print(f"Wrote {min(len(POSE_NAMES), args.columns * args.rows)} poses to {args.out_dir}")
    print(f"Key color: #{key[0]:02x}{key[1]:02x}{key[2]:02x}")


if __name__ == "__main__":
    main()
