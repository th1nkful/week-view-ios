# Week View iOS Icon Assets

This directory contains SVG icon assets for use with Apple's Icon Composer application, following the iOS icon design guidelines.

## Overview

These assets were created following Apple's Icon Composer workflow, which uses a layered approach to create depth and 3D effects through the Liquid Glass system.

## Files

### Layer-based Assets (for Icon Composer)

- **`layer-1-squares.svg`** - Top layer: Three rounded squares with holographic gradient
- **`layer-2-lines.svg`** - Bottom layer: Two horizontal lines with holographic gradient

### Combined Asset

- **`icon-foreground.svg`** - Complete foreground with all icon elements combined

## Design Specifications

### Visual Elements

The icon design represents a weekly calendar view with:
- **Top layer**: Three rounded squares (132px from top, 150px from left edge)
  - Spacing: 272px centers (150px + 180px + 92px = 422px for second square)
  - Dimensions: 180×180px each
  - Corner radius: 36px
- **Bottom layer**: Two horizontal lines (384px and 636px from top)
  - Dimensions: 724×180px each
  - Corner radius: 36px

### Holographic Gradient

All elements use the same holographic gradient (`holo3`):
- Start: `#7B61FF` (Purple)
- Mid: `#00FF88` (Cyan-Green)
- End: `#00D9FF` (Cyan-Blue)

### Canvas & Padding

- Canvas size: 1024×1024px
- Edge padding: 150px on left/right, 132px on top, ~208px on bottom
- This ensures elements won't be clipped by the squircle mask that Icon Composer applies

## Usage with Icon Composer

### Step 1: Import Layers

1. Open Icon Composer
2. Import the layer files:
   - `layer-1-squares.svg` as the top/foreground layer (Group 1)
   - `layer-2-lines.svg` as the middle/background layer (Group 2)

### Step 2: Apply Effects

- **Layer 1 (Squares)**: Apply specular highlights, subtle shadows
- **Layer 2 (Lines)**: Apply blur effects, increased translucency for depth

### Step 3: Customize Appearances

Use the Appearance inspector to ensure the icon looks good across:
- Default mode
- Dark mode
- Clear/tinted modes

### Step 4: Preview & Export

1. Preview across iOS, iPadOS, watchOS, and macOS
2. Test with different backgrounds and lighting conditions
3. Export as a single `.icon` file
4. Drag the `.icon` file into `WeekView/Assets.xcassets/AppIcon.appiconset` in Xcode

## Design Notes

### Background Removed

The original concept included a dark background (`#0A0A0A`), but it has been removed from these assets. Icon Composer automatically applies the iOS squircle shape, so only foreground elements should be provided.

### Transparent Background

All SVG files use `fill="none"` on the root SVG element to ensure a transparent background, as required by Icon Composer.

### Alternative Gradients

While the current design uses `holo3` for all elements, the original concept included additional gradient options:

```xml
<!-- Alternative gradient 1: Cyan to Purple to Pink -->
<linearGradient id="holo1" x1="0%" y1="0%" x2="100%" y2="100%">
  <stop offset="0%" style="stop-color:#00D9FF;stop-opacity:1" />
  <stop offset="50%" style="stop-color:#7B61FF;stop-opacity:1" />
  <stop offset="100%" style="stop-color:#FF3D71;stop-opacity:1" />
</linearGradient>

<!-- Alternative gradient 2: Pink to Yellow to Green -->
<linearGradient id="holo2" x1="0%" y1="0%" x2="100%" y2="100%">
  <stop offset="0%" style="stop-color:#FF3D71;stop-opacity:1" />
  <stop offset="50%" style="stop-color:#FFB800;stop-opacity:1" />
  <stop offset="100%" style="stop-color:#00FF88;stop-opacity:1" />
</linearGradient>
```

These can be added back to create visual variation between layers if desired.

## Future Iterations

Consider these enhancements for future versions:
- Experiment with different gradients for each layer to create more depth
- Adjust element positioning for better visual balance
- Add subtle variations in corner radius for organic feel
- Test with additional layer separation in Icon Composer

## References

- [Apple Icon Design Guidelines](https://developer.apple.com/design/human-interface-guidelines/app-icons)
- [Apple Developer Documentation](https://developer.apple.com/documentation/)
