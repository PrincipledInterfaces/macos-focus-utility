# TOME - Marketing Assets Export System

Professional-grade assets for creating video ads with smooth zoom-ins and transparent animations.

## 🎯 Quick Start

### 1. Export Assets from TOME App

Temporarily add this to your TOME app (in a debug button or menu):

```swift
// Import the exporter
// (Add Scripts/MarketingExporter.swift to your Xcode project first)

// Export static screenshots (ultra high-res)
MarketingExporter.exportAllEnvironments(state: yourTOMEState)

// Export animated shockwaves (PNG sequences)
MarketingExporter.exportAnimations()
```

### 2. Convert Animations to Transparent MOV

```bash
cd MarketingExport/Scripts
./convert-to-mov.sh
```

**Requirements:** `ffmpeg` (install with: `brew install ffmpeg`)

### 3. Import into Video Editor

- **After Effects:** File → Import → Select MOV files
- **Apple Motion:** File → Import
- **Final Cut Pro:** Drag MOV files to timeline
- **DaVinci Resolve:** Media Pool → Import

---

## 📁 What Gets Exported

```
MarketingExport/
├── Environments/          # Ultra high-res screenshots (9600×6400px)
│   ├── Home/
│   ├── Garden/
│   ├── Workshop/
│   ├── Coffeeshop/
│   ├── WriterDesk/
│   └── Planning/
├── Components/
│   └── Shockwaves/        # Static shockwave frames
├── Animations/
│   ├── PNGSequences/      # 120 frames per animation @ 60fps
│   └── *.mov              # Transparent ProRes 4444 files
└── Scripts/
    ├── MarketingExporter.swift
    └── convert-to-mov.sh
```

---

## 🎬 Why This Works for Video Ads

### Ultra High Resolution
- **8x Retina scale** for static images (9600×6400px)
- Zoom in 8x at Full HD without quality loss
- Zoom in 4x at 4K without quality loss

### Transparent Animations
- Shockwaves exported as ProRes 4444 with alpha channel
- Perfect for compositing over backgrounds
- Professional broadcast quality

### Apple-Style Production
- Static high-res UI elements for smooth camera moves
- Animated effects as separate transparent layers
- Composite in After Effects/Motion for maximum control

---

## 💡 Video Production Tips

### For Apple-Style Zoom-Ins
1. Import high-res environment screenshots into After Effects/Motion
2. Create a 3D camera
3. Animate camera position to zoom into specific UI elements
4. No quality loss thanks to 8x resolution headroom

### For Shockwave Effects
1. Import transparent MOV files
2. Place over environment screenshots
3. They'll composite perfectly with full transparency
4. Adjust timing/speed as needed

### Recommended Workflow
1. Use static high-res exports for UI close-ups
2. Use transparent MOV files for animated elements
3. Screen record (OBS @ 4K) for interactive sequences
4. Composite all layers in your video editor

---

## 🎨 Technical Specs

**Static Images:**
- Resolution: 9600 × 6400 pixels
- Scale: 8x Retina
- Format: PNG with transparency
- Color: sRGB

**Animations:**
- Resolution: 3200 × 3200 pixels
- Frame Rate: 60fps
- Duration: 2 seconds (120 frames)
- Format: ProRes 4444 (MOV with alpha)
- Scale: 4x Retina

---

## 🗑️ Cleanup

To remove all generated assets:

```bash
rm -rf MarketingExport/
```

This folder is self-contained and safe to delete.

---

## 📚 More Info

See `ASSET_INFO.txt` for:
- Fonts used in TOME
- Detailed folder structure
- Software recommendations
- Video production tips
- ffmpeg conversion commands

---

**Last Updated:** 2025-10-15
