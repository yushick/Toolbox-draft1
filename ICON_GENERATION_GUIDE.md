# OneBox Custom Icon Generation Guide

Use this specification whenever adding a new category or tool icon so all assets match the existing 3D frosted-glass icon family in `ToolBox/Assets.xcassets`.

---

## 1. Image Generation Prompt Template

Invoke `image-generator` with this exact prompt structure, replacing `<SUBJECT>` and `<TOOL_OR_CATEGORY_NAME>`:

```text
Generate a single minimalist sleek 3D frosted-glass and brushed-silver icon of <SUBJECT> representing "<TOOL_OR_CATEGORY_NAME>", centered with generous margin on a pure solid #000000 black background. Subtle cyan-teal (#00A19B) and electric blue (#2E6BFF) edge glow, soft studio rim light, no text, no watermark, crisp Apple dark-mode aesthetic. Save as PNG and reply with the file path.
```

### Existing Asset Prompts Used
- `CategoryImages`: two overlapping glossy photo frames
- `CategoryPDF`: layered crisp document pages
- `CategoryScanOCR`: glowing scanner reticle over a sleek document
- `CategoryFavorites`: sculpted rounded 5-point star
- `ToolScanDocument`: document inside a camera viewfinder frame
- `ToolCompressPDF`: document page with sleek inward compression arrows
- `ToolCompressImage`: photo frame with sleek inward compression arrows
- `ToolResizeImage`: photo frame with diagonal expand/resize arrows
- `ToolOCR`: glowing text lines inside a scanner bracket
- `ToolQR`: stylized geometric QR matrix inside a sleek viewfinder

---

## 2. Converting & Installing into `Assets.xcassets`

`generate_image` outputs `.jpg` files. Convert each generated image into a `256×256` PNG `.imageset` so bundle size stays small and Xcode generates `ImageResource` symbols automatically:

```bash
NAME="ToolNewFeature"
SRC="/path/to/generated.jpg"
DEST="ToolBox/Assets.xcassets/${NAME}.imageset"

mkdir -p "$DEST"
sips -s format png -z 256 256 "$SRC" --out "${DEST}/${NAME}.png"
cat > "${DEST}/Contents.json" <<EOF
{
  "images": [
    { "filename": "${NAME}.png", "idiom": "universal", "scale": "1x" },
    { "idiom": "universal", "scale": "2x" },
    { "idiom": "universal", "scale": "3x" }
  ],
  "info": { "author": "xcode", "version": 1 }
}
EOF
```

> **Note on Xcode Symbol Naming:** `actool` strips a trailing `Image` suffix when generating `ImageResource` extensions (for example, `ToolCompressImage` becomes `.toolCompress`). Prefer names without a trailing `Image` (e.g., `ToolMergePDF`, `ToolSplitPDF`).

---

## 3. Rendering in SwiftUI

Render every icon with `.blendMode(.screen)` so the pure `#000000` background melts seamlessly into dark translucent glass cards:

```swift
Image(tool.assetImage)
    .resizable()
    .aspectRatio(contentMode: .fit)
    .frame(width: 56, height: 56)
    .blendMode(.screen)
```
