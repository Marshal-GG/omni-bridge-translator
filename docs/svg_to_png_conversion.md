# SVG → PNG Conversion Guide

A quick reference for converting SVG assets to high-quality PNG using [`sharp-cli`](https://github.com/vseventer/sharp-cli) — a Node.js-powered CLI wrapper around the `sharp` image processing library.

---

## Prerequisites

You need **Node.js** installed. Then install `sharp-cli` globally (one-time setup):

```bash
npm install -g sharp-cli
```

Verify it works:

```bash
sharp --version
```

---

## Basic Conversion

```bash
sharp -i input.svg -o output.png
```

> ⚠️ The default density is ~72 DPI (screen resolution). This often produces a low-quality, small PNG — especially for SVGs with complex graphics or text.

---

## High-Quality Conversion (Recommended)

Use the `--density` flag to control the DPI (dots per inch) when rasterizing:

```bash
# 150 DPI — good for web / social media
sharp -i input.svg -o output.png --density 150

# 300 DPI — print-quality, recommended default
sharp -i input.svg -o output.png --density 300

# 600 DPI — ultra high-res, for large format printing
sharp -i input.svg -o output.png --density 600
```

### Rule of Thumb

| Use Case              | Density |
|-----------------------|---------|
| Web / screen display  | 72–96   |
| Social media banners  | 150–200 |
| Print / high-res      | 300     |
| Large format printing | 600+    |

---

## Resize Output Dimensions

You can explicitly set the output width (height scales proportionally):

```bash
sharp -i input.svg -o output.png --density 300 resize 1584
```

Or set both width and height:

```bash
sharp -i input.svg -o output.png --density 300 resize 1584 396
```

---

## Real-World Example

This is how `marshal_linkedin_banner.svg` was converted in this project:

```bash
# Step 1: Install (one-time)
npm install -g sharp-cli

# Step 2: Convert at 300 DPI for crisp quality
sharp -i assets/marshal_linkedin_banner.svg -o assets/marshal_linkedin_banner.png --density 300
```

**Result:** File went from **179 KB** (72 DPI) → **1.1 MB** (300 DPI), with a ~6× increase in pixel density and sharpness.

---

## Why Not Use Other Tools?

| Tool         | Notes                                                                 |
|--------------|-----------------------------------------------------------------------|
| `cairosvg`   | Python-based, requires `libcairo` system library (hard to set up on Windows) |
| `inkscape`   | Excellent quality, but requires a full Inkscape installation          |
| `ImageMagick`| Works well, but SVG support depends on the Ghostscript/librsvg build |
| `sharp-cli`  | ✅ Easy install via npm, cross-platform, fast, great quality          |

---

## Tips

- SVGs are **vector** (infinitely scalable), so always render at the **highest density you need** — you can't upscale a PNG later without quality loss.
- If your SVG uses custom fonts, make sure those fonts are installed on the system before converting.
- For animated SVGs, only the **first frame** is captured in the PNG output.
