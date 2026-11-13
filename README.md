
# Toolbox

**Useful tools. One place.**

A privacy-first iOS utility app: scan documents, compress and resize files, read QR codes and extract text, all on your device.

![Platform](https://img.shields.io/badge/platform-iOS%2018%2B-blue)
![Swift](https://img.shields.io/badge/Swift-SwiftUI-orange)
![Storage](https://img.shields.io/badge/storage-SwiftData-green)
![Network](https://img.shields.io/badge/network-none-lightgrey)

</div>

---

## Screenshots

<!-- Add screenshots to a /Screenshots folder and update the paths below. -->
| Home | Scanner | Files |
|:---:|:---:|:---:|:---:|
| <img width="240" height="500" alt="Homepage" src="https://github.com/user-attachments/assets/8b72b0dd-5a51-40e5-8052-082c1272debe" />
| <img width="240" height="500" alt="settings" src="https://github.com/user-attachments/assets/85dc014f-fe11-4f35-b779-9985b36f1677" />
 | <img width="240" height="500" alt="scanpage" src="https://github.com/user-attachments/assets/8de9d093-88ef-4b8e-b9ab-7ad8e62c12e5" />|</div>

## Why Toolbox?

Most "PDF / scanner / compressor" apps are slow, ad-filled, or upload your files to a server. Toolbox does everything **locally** using Apple's own frameworks. There is no backend, no account, no analytics and no third-party SDK. Your files never leave your phone.

## Features

### Six tools

| Tool | What it does |
|---|---|
| **Scan Document** | Camera scanner with automatic edge detection (VisionKit). Enhance pages (Color / Grayscale / B&W), reorder, retake, and export a multi-page PDF. |
| **Compress PDF** | Quality presets (Low / Medium / High) or a custom target size. Shows before and after size. |
| **Compress Image** | Batch compress up to 50 photos. Adjustable quality, JPEG or HEIC output, optional max dimension, and a live size estimate. |
| **Resize Image** | Social presets (Instagram, WhatsApp and more), custom dimensions with aspect-ratio lock, fit or fill modes, and a live preview. |
| **QR & Barcode** | Live scanning with flashlight, or scan a code from a photo. Recognises URLs, Wi-Fi, text and product barcodes, with one-tap actions. |
| **OCR** | Extract text from the camera, photos or PDFs. Edit the result, copy or share it, or export as TXT or PDF. |

### Import anything
Drop or pick a PDF or photo on the Home screen and Toolbox shows only the actions that work for it:

- **PDF** → Compress, Extract Text
- **Photo(s)** → Compress, Resize, Extract Text, Scan QR/Barcode

### Also included
- **Files**: everything you create, with search, sort, grouping by date, rename, delete, share and Quick Look preview.
- **Settings**: appearance (System / Light / Dark), default compression quality, privacy information and storage management.
- **Onboarding**: a short first-launch introduction.
- **Accessibility**: Dynamic Type, VoiceOver labels, 44pt tap targets, and Reduce Motion respected in animations.
- **Light and dark mode** with a custom design system and app icon (light and dark).

## Privacy

- 100% on-device processing
- No network requests, no backend, no analytics
- No account or sign-in
- Camera access is requested only when you open a camera feature
- Photos are chosen through the system picker, so no library-wide permission is needed
- SwiftData stores **metadata only** (names, sizes, dates). Files live in the app's own storage.

## Tech stack

| Area | Technology |
|---|---|
| UI | SwiftUI, `@Observable` view models |
| Persistence | SwiftData |
| Concurrency | async/await, `Task.detached` for heavy work, cancellation support |
| Scanning | VisionKit (`VNDocumentCameraViewController`, `DataScannerViewController`) |
| Recognition | Vision (`VNRecognizeTextRequest`, `VNDetectBarcodesRequest`) |
| PDF | PDFKit, Core Graphics, Core Text |
| Images | ImageIO, PhotosUI (`PhotosPicker`), Photos (add-only save) |
| Other | QuickLook, StoreKit (`requestReview`), NetworkExtension (Wi-Fi join) |

**Apple frameworks only. No third-party dependencies.**

## Requirements

- Xcode 16 or later
- iOS 18.0+ deployment target
- A physical device is recommended. Live QR scanning and the document camera aren't available in the Simulator.

## Getting started

1. Clone the repository:
   ```bash
   git clone https://github.com/<your-username>/Toolbox.git
   cd Toolbox
   ```
2. Open the project in Xcode and select your development team under **Signing & Capabilities**.
3. Make sure the following keys exist on the target's **Info** tab:

   | Key | Suggested value |
   |---|---|
   | `NSCameraUsageDescription` | Toolbox uses the camera to scan documents and codes. Nothing is uploaded. |
   | `NSPhotoLibraryAddUsageDescription` | Toolbox saves your processed images to Photos when you ask it to. |
   | `UIFileSharingEnabled` | YES |
   | `LSSupportsOpeningDocumentsInPlace` | YES |

4. *(Optional)* To enable "Connect to Wi-Fi" from scanned Wi-Fi QR codes, add the **Hotspot Configuration** capability. This requires a paid developer account.
5. Build and run (⌘R).

## Project structure

```
Toolbox/
├── App/                 App entry, ContentView (tabs), AppState
├── DesignSystem/        Colors, Typography, Spacing, reusable components
│   └── Components/      ToolCard, ProcessingView, SuccessView, ImportDropZone, ...
├── Models/              Tool, SwiftData models, per-feature models
├── Services/            Scanner, PDF, image, OCR, barcode, import, file services
├── Features/
│   ├── Home/            Home screen and search
│   ├── Import/          "What would you like to do?" sheet
│   ├── Scanner/         Document scanner flow
│   ├── PDFCompressor/
│   ├── ImageCompressor/
│   ├── ImageResizer/
│   ├── QRScanner/
│   ├── OCR/
│   ├── Files/
│   ├── Settings/
│   └── Onboarding/
└── Utilities/           Sharing, output files, preferences, feature access
```

The architecture follows one rule: **views display, view models coordinate, services do the work**. Services are plain, UI-free and testable.

## Tests

Unit tests cover tool search, resize math and real resizing, compression, file naming and renaming, PDF creation and compression, OCR on a rendered image, barcode / Wi-Fi / URL parsing, settings persistence, history clearing and the import logic. A small UI test suite covers launch, onboarding, tab navigation, search and opening the scanner screens.

Run with **⌘U** in Xcode. If your module isn't named `Toolbox`, update the `@testable import` line at the top of the unit test file.

## Known limitations

- Wi-Fi auto-connect needs the Hotspot Configuration capability.
- Hindi text recognition depends on the iOS version's Vision model.
- Dragging in files from other apps requires both apps on screen (Split View or Slide Over). Tapping works everywhere.
- The in-app privacy policy is a draft. Replace it, along with the placeholder support email and App Store ID in `AppLinks`, before releasing.
- UI strings are not localized yet.

## Roadmap

- [ ] Images → PDF
- [ ] Merge / split PDFs
- [ ] Localization
- [ ] iPad layout
- [ ] Pro tier (the `FeatureAccess` groundwork is already in place)

## Author

Built by **Ayush**. Feel free to open an issue or reach out.
