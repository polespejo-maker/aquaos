#!/usr/bin/env python3
"""
Genera los fondos de pantalla de AquaOS.

Diseño propio (sin material con copyright de Apple): mallas de gradientes
suaves + manchas de luz difuminadas, al estilo macOS Sonoma/Ventura.

Uso:
    python scripts/make-wallpapers.py [destino]

Por defecto escribe en:
    profile/airootfs/usr/share/wallpapers/AquaOS/

Requiere Pillow y numpy:  pip install pillow numpy
"""
from __future__ import annotations

import sys
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw, ImageFilter

W, H = 2560, 1440
SS = 4  # factor de supersampling para los bordes suaves


def _lerp(a: float, b: float, t: np.ndarray) -> np.ndarray:
    return a + (b - a) * t


def mesh_gradient(size: tuple[int, int], stops: list[tuple[tuple[float, float], tuple[int, int, int]]],
                  angle: float = 35.0) -> np.ndarray:
    """Gradiente lineal de varios puntos (en espacio normalizado 0..1)."""
    w, h = size
    xs = np.linspace(0.0, 1.0, w, dtype=np.float32)[None, :]
    ys = np.linspace(0.0, 1.0, h, dtype=np.float32)[:, None]
    a = np.deg2rad(angle)
    t = np.clip(xs * np.cos(a) + ys * np.sin(a), 0.0, 1.0)
    t = (t - t.min()) / max(float(t.max() - t.min()), 1e-6)

    out = np.zeros((h, w, 3), dtype=np.float32)
    for i in range(len(stops) - 1):
        (p0, c0), (p1, c1) = stops[i], stops[i + 1]
        seg = (t >= p0) & (t <= p1)
        local = np.clip((t - p0) / max(p1 - p0, 1e-6), 0.0, 1.0)
        for ch in range(3):
            v = _lerp(float(c0[ch]), float(c1[ch]), local)
            out[..., ch] = np.where(seg, v, out[..., ch])
    return out


def add_blob(img: np.ndarray, cx: float, cy: float, radius: float,
             color: tuple[int, int, int], strength: float = 1.0) -> np.ndarray:
    """Añade una luz radial suave (en coordenadas normalizadas)."""
    h, w = img.shape[:2]
    yy, xx = np.mgrid[0:h, 0:w].astype(np.float32)
    x = xx / w
    y = yy / h
    d = np.sqrt((x - cx) ** 2 + (y - cy) ** 2 * (w / h) ** 2)
    falloff = np.clip(1.0 - d / radius, 0.0, 1.0) ** 2.2
    falloff *= strength
    for ch in range(3):
        img[..., ch] = img[..., ch] * (1.0 - falloff) + float(color[ch]) * falloff
    return img


def vignette(img: np.ndarray, amount: float = 0.16) -> np.ndarray:
    h, w = img.shape[:2]
    yy, xx = np.mgrid[0:h, 0:w].astype(np.float32)
    x = xx / w - 0.5
    y = yy / h - 0.5
    r = np.sqrt(x * x + y * y) / 0.7071
    mask = np.clip(1.0 - amount * r ** 2.4, 0.0, 1.0)[..., None]
    return img * mask


def grain(img: np.ndarray, amount: float = 1.6) -> np.ndarray:
    rng = np.random.default_rng(7)
    noise = rng.normal(0.0, amount, size=img.shape[:2])[..., None]
    return np.clip(img + noise, 0, 255)


def render(name: str, angle: float, base: list, blobs: list, out_dir: Path,
           dark: bool = False) -> Path:
    img = mesh_gradient((W, H), base, angle=angle)
    for (cx, cy, r, col, s) in blobs:
        img = add_blob(img, cx, cy, r, col, s)
    img = vignette(img, 0.20 if dark else 0.12)
    img = grain(img, 1.8 if dark else 1.2)
    im = Image.fromarray(np.clip(img, 0, 255).astype(np.uint8), "RGB")
    im = im.filter(ImageFilter.GaussianBlur(0.6))
    out = out_dir / f"{name}.png"
    im.save(out, optimize=True)
    return out


# --- Definición de los fondos -------------------------------------------------

PALETTES = {
    # Amanecer cálido, tipo "Sonoma"
    "sonoma": dict(
        angle=38,
        dark=False,
        base=[((0.00, (255, 214, 170))), (0.35, (255, 168, 146)),
              (0.66, (198, 128, 190)), (1.00, (86, 82, 158))],
        blobs=[
            (0.18, 0.16, 0.55, (255, 236, 196), 0.85),
            (0.78, 0.22, 0.58, (255, 158, 178), 0.55),
            (0.55, 0.82, 0.62, (116, 96, 178), 0.75),
            (0.92, 0.75, 0.40, (255, 196, 170), 0.40),
        ],
    ),
    # Azul profundo, tipo "Ventura"
    "ventura": dict(
        angle=28,
        dark=True,
        base=[(0.00, (12, 22, 48)), (0.30, (22, 58, 116)),
              (0.62, (40, 116, 168)), (1.00, (18, 40, 78))],
        blobs=[
            (0.22, 0.22, 0.60, (56, 148, 214), 0.70),
            (0.72, 0.30, 0.52, (120, 210, 226), 0.45),
            (0.42, 0.86, 0.55, (16, 34, 72), 0.70),
            (0.88, 0.78, 0.44, (72, 92, 178), 0.50),
        ],
    ),
    # Verde azulado, tipo "Sequoia"
    "sequoia": dict(
        angle=52,
        dark=True,
        base=[(0.00, (8, 26, 30)), (0.36, (14, 62, 62)),
              (0.70, (30, 118, 104)), (1.00, (10, 34, 40))],
        blobs=[
            (0.16, 0.74, 0.58, (44, 160, 138), 0.55),
            (0.60, 0.18, 0.52, (96, 206, 176), 0.38),
            (0.86, 0.62, 0.50, (12, 48, 56), 0.65),
            (0.36, 0.38, 0.34, (140, 226, 200), 0.22),
        ],
    ),
    # Gris grafito, tipo "espacio gris"
    "graphite": dict(
        angle=64,
        dark=True,
        base=[(0.00, (18, 18, 22)), (0.40, (38, 40, 48)),
              (0.74, (62, 66, 78)), (1.00, (20, 21, 26))],
        blobs=[
            (0.24, 0.28, 0.58, (78, 82, 96), 0.50),
            (0.76, 0.22, 0.46, (150, 156, 172), 0.23),
            (0.58, 0.84, 0.52, (14, 14, 18), 0.70),
            (0.10, 0.86, 0.40, (96, 100, 116), 0.30),
        ],
    ),
}


def make_menu_icon(path: Path, size: int = 128) -> None:
    """Marca de AquaOS: una gota/ola minimalista (sin parecidos registrados)."""
    S = size * SS
    im = Image.new("RGBA", (S, S), (0, 0, 0, 0))
    d = ImageDraw.Draw(im)
    # gota
    d.ellipse((S * 0.16, S * 0.42, S * 0.84, S * 1.02), fill=(10, 132, 255, 255))
    d.polygon([(S * 0.5, S * 0.06), (S * 0.84, S * 0.72), (S * 0.16, S * 0.72)],
              fill=(10, 132, 255, 255))
    # brillo
    d.ellipse((S * 0.30, S * 0.52, S * 0.50, S * 0.78), fill=(255, 255, 255, 70))
    im = im.resize((size, size), Image.LANCZOS)
    im.save(path)


def main() -> int:
    root = Path(__file__).resolve().parents[1]
    out_dir = Path(sys.argv[1]) if len(sys.argv) > 1 else root / "profile/airootfs/usr/share/wallpapers/AquaOS"
    out_dir.mkdir(parents=True, exist_ok=True)

    for name, pal in PALETTES.items():
        p = render(name, out_dir=out_dir, **pal)
        print(f"  wallpaper  {p.relative_to(root)}  ({p.stat().st_size // 1024} KiB)")

    branding = root / "profile/airootfs/usr/share/aquaos/branding"
    branding.mkdir(parents=True, exist_ok=True)
    make_menu_icon(branding / "menu-icon.png")
    print(f"  marca      {(branding / 'menu-icon.png').relative_to(root)}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
