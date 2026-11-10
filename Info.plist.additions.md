# Target Info keys

Add these in Xcode: select the **Toolbox target → Info tab → Custom iOS
Target Properties → +**. Keep "Generate Info.plist File" = Yes and leave
"Info.plist File" empty — do not use a physical Info.plist.

| Key (as shown in Xcode) | Raw key | Value | Needed for |
|---|---|---|---|
| Privacy - Camera Usage Description | `NSCameraUsageDescription` | Toolbox uses your camera to scan documents. | Stage 2 scanner |
| Privacy - Photo Library Additions Usage Description | `NSPhotoLibraryAddUsageDescription` | Toolbox saves your compressed images to Photos when you ask it to. | Stage 4 "Save Images" |
| Application supports iTunes file sharing | `UIFileSharingEnabled` | YES | Files visible under On My iPhone → Toolbox |
| Supports opening documents in place | `LSSupportsOpeningDocumentsInPlace` | YES | Same as above |

Choosing photos with the picker needs no Photos permission. The
"Photo Library Additions" key is only used when the user taps
"Save Images". Without it, that button crashes the app.

## Stage 6 (QR & Barcode) — optional capability for Wi-Fi

The live scanner uses the camera key you already added in Stage 2
(`NSCameraUsageDescription`), so no new Info key is needed.

The **Connect** button on Wi-Fi codes needs the *Hotspot Configuration*
capability: Target → **Signing & Capabilities → + Capability → Hotspot
Configuration**. Without it, everything else works, and Connect just
tells the user to copy the password and join from Settings › Wi-Fi.
Note: joining a network only works on a real iPhone, not the simulator.
