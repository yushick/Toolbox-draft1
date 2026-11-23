import SwiftUI

// MARK: - Color Palette
private extension Color {
    init(hex: String) {
        let clean = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: clean).scanHexInt64(&int)
        let r, g, b, a: UInt64
        switch clean.count {
        case 6:
            (r, g, b, a) = (int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF, 255)
        case 8:
            (r, g, b, a) = (int >> 24 & 0xFF, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (r, g, b, a) = (0, 0, 0, 255)
        }
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }

    static let oledBlack = Color.black
    static let darkRow = Color(hex: "141416")
    static let electricBlue = Color(hex: "1E22FF")
    static let vividRed = Color(hex: "E5252A")
    static let vibrantOrange = Color(hex: "FF3B00")
    static let voltYellow = Color(hex: "E8FF00")
    static let tealGlow = Color(hex: "00D2C6")
    static let petronasTeal = Color(hex: "00A19B")
    static let telemetryGold = Color(hex: "C89D3C")
    static let deepCrimson = Color(hex: "7A1228")
    static let deepIndigo = Color(hex: "1B1E66")
}

// MARK: - Liquid Glass Modifier
private struct LiquidGlassModifier<S: InsettableShape>: ViewModifier {
    let shape: S
    var interactive: Bool = true

    func body(content: Content) -> some View {
        if #available(iOS 26.0, *) {
            content
                .glassEffect(interactive ? .regular.interactive() : .regular, in: shape)
        } else {
            content
                .background(
                    shape.fill(.ultraThinMaterial)
                        .overlay(shape.strokeBorder(Color.white.opacity(0.14), lineWidth: 0.5))
                )
        }
    }
}

private extension View {
    func liquidGlass<S: InsettableShape>(in shape: S, interactive: Bool = true) -> some View {
        modifier(LiquidGlassModifier(shape: shape, interactive: interactive))
    }
}

// MARK: - Shared Bottom Bar
private struct OneBoxFloatingBottomBar: View {
    @State private var selectedTab: Int = 0

    var body: some View {
        HStack(spacing: 12) {
            // Main Glass Capsule
            HStack(spacing: 0) {
                tabButton(icon: "house.fill", index: 0)
                Spacer()
                tabButton(icon: "square.grid.2x2.fill", index: 1)
                Spacer()
                tabButton(icon: "folder.fill", index: 2)
                Spacer()
                tabButton(icon: "gearshape.fill", index: 3)
            }
            .padding(.horizontal, 22)
            .frame(height: 58)
            .liquidGlass(in: Capsule())

            // Standalone Circular + Button
            Button {
            } label: {
                Image(systemName: "plus")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(width: 58, height: 58)
            }
            .liquidGlass(in: Circle())
        }
        .padding(.horizontal, 16)
        .padding(.bottom, 6)
    }

    private func tabButton(icon: String, index: Int) -> some View {
        Button {
            selectedTab = index
        } label: {
            Image(systemName: icon)
                .font(.system(size: 19, weight: selectedTab == index ? .semibold : .regular))
                .foregroundStyle(selectedTab == index ? .white : Color.white.opacity(0.42))
                .frame(width: 44, height: 44)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Variant 1: Bento Grid
struct OneBoxVariant1BentoView: View {
    var body: some View {
        ZStack(alignment: .bottom) {
            Color.oledBlack.ignoresSafeArea()

            // Subtle Top-Edge Teal Glow
            VStack {
                RadialGradient(
                    colors: [
                        Color.tealGlow.opacity(0.38),
                        Color.tealGlow.opacity(0.12),
                        Color.oledBlack.opacity(0)
                    ],
                    center: .top,
                    startRadius: 0,
                    endRadius: 280
                )
                .frame(height: 320)
                .ignoresSafeArea(edges: .top)
                Spacer()
            }

            // Scrollable Bento Content
            ScrollView(showsIndicators: false) {
                VStack(spacing: 16) {
                    // Header Bar
                    HStack {
                        // Top-left Electric Blue Pill
                        HStack(spacing: 6) {
                            Circle()
                                .fill(Color.white)
                                .frame(width: 6, height: 6)
                            Text("OneBox")
                                .font(.system(size: 13, weight: .bold, design: .rounded))
                                .foregroundStyle(.white)
                                .tracking(0.5)
                        }
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .background(Color.electricBlue, in: Capsule())

                        Spacer()

                        // Top-right Circular Glass Settings Button
                        Button { } label: {
                            Image(systemName: "gearshape.fill")
                                .font(.system(size: 15, weight: .medium))
                                .foregroundStyle(.white)
                                .frame(width: 38, height: 38)
                        }
                        .liquidGlass(in: Circle())
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 12)

                    // Hero Import Card (Vivid Red #E5252A)
                    VStack(alignment: .leading, spacing: 20) {
                        HStack(alignment: .top) {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("DROP OR SELECT")
                                    .font(.system(size: 11, weight: .bold, design: .monospaced))
                                    .foregroundStyle(Color.white.opacity(0.85))
                                    .tracking(1.2)
                                Text("Import a File")
                                    .font(.system(size: 28, weight: .black, design: .rounded))
                                    .foregroundStyle(.white)
                            }
                            Spacer()
                            Image(systemName: "arrow.down.doc.fill")
                                .font(.system(size: 32, weight: .bold))
                                .foregroundStyle(Color.white.opacity(0.92))
                        }

                        // Format Pills
                        HStack(spacing: 8) {
                            ForEach(["PDF", "IMG", "QR"], id: \.self) { format in
                                Text(format)
                                    .font(.system(size: 12, weight: .bold, design: .monospaced))
                                    .foregroundStyle(.white)
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 6)
                                    .background(Color.white.opacity(0.22), in: Capsule())
                            }
                            Spacer()
                            HStack(spacing: 4) {
                                Text("BROWSE")
                                    .font(.system(size: 12, weight: .bold, design: .rounded))
                                Image(systemName: "chevron.right")
                                    .font(.system(size: 11, weight: .bold))
                            }
                            .foregroundStyle(.white)
                        }
                    }
                    .padding(20)
                    .frame(maxWidth: .infinity)
                    .background(Color.vividRed, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
                    .padding(.horizontal, 16)

                    // 2-Column Split (12pt Gap)
                    HStack(spacing: 12) {
                        // Electric Blue Card: Compress PDF
                        VStack(alignment: .leading, spacing: 14) {
                            HStack {
                                Image(systemName: "doc.badge.arrow.up.fill")
                                    .font(.system(size: 22, weight: .semibold))
                                    .foregroundStyle(.white)
                                Spacer()
                                Text("PDF")
                                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                                    .foregroundStyle(Color.white.opacity(0.75))
                            }
                            Spacer()
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Compress")
                                    .font(.system(size: 18, weight: .heavy, design: .rounded))
                                    .foregroundStyle(.white)
                                Text("PDF Files")
                                    .font(.system(size: 13, weight: .medium))
                                    .foregroundStyle(Color.white.opacity(0.85))
                            }
                        }
                        .padding(18)
                        .frame(height: 140)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color.electricBlue, in: RoundedRectangle(cornerRadius: 24, style: .continuous))

                        // Vibrant Orange Card: Compress Image
                        VStack(alignment: .leading, spacing: 14) {
                            HStack {
                                Image(systemName: "photo.badge.arrow.down.fill")
                                    .font(.system(size: 22, weight: .semibold))
                                    .foregroundStyle(.white)
                                Spacer()
                                Text("IMG")
                                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                                    .foregroundStyle(Color.white.opacity(0.75))
                            }
                            Spacer()
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Compress")
                                    .font(.system(size: 18, weight: .heavy, design: .rounded))
                                    .foregroundStyle(.white)
                                Text("Photos & Assets")
                                    .font(.system(size: 13, weight: .medium))
                                    .foregroundStyle(Color.white.opacity(0.85))
                            }
                        }
                        .padding(18)
                        .frame(height: 140)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color.vibrantOrange, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
                    }
                    .padding(.horizontal, 16)

                    // Two #141416 Dark Utility Rows (56pt height)
                    VStack(spacing: 8) {
                        utilityRow(icon: "arrow.up.left.and.arrow.down.right", title: "Resize Image", subtitle: "Pixels & scale")
                        utilityRow(icon: "text.viewfinder", title: "Extract Text (OCR)", subtitle: "On-device Vision")
                    }
                    .padding(.horizontal, 16)

                    // Full-Width Neon Volt Yellow Banner (#E8FF00)
                    HStack(spacing: 16) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("CAMERA CAPTURE")
                                .font(.system(size: 10, weight: .bold, design: .monospaced))
                                .foregroundStyle(Color.black.opacity(0.65))
                                .tracking(1)
                            Text("Scan Document")
                                .font(.system(size: 22, weight: .heavy, design: .rounded))
                                .foregroundStyle(Color.black)
                            Text("Instant edge detection & PDF export")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundStyle(Color.black.opacity(0.75))
                        }
                        Spacer()
                        // Circular black ↗ badge
                        ZStack {
                            Circle()
                                .fill(Color.black)
                                .frame(width: 44, height: 44)
                            Image(systemName: "arrow.up.right")
                                .font(.system(size: 17, weight: .bold))
                                .foregroundStyle(Color.voltYellow)
                        }
                    }
                    .padding(20)
                    .frame(maxWidth: .infinity)
                    .background(Color.voltYellow, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
                    .padding(.horizontal, 16)
                    .padding(.bottom, 100)
                }
            }

            // Floating Bottom Liquid Glass
            OneBoxFloatingBottomBar()
        }
    }

    private func utilityRow(icon: String, title: String, subtitle: String) -> some View {
        HStack(spacing: 14) {
            Image(systemName: icon)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: 34, height: 34)
                .background(Color.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 10, style: .continuous))

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(.white)
                Text(subtitle)
                    .font(.system(size: 12, weight: .regular))
                    .foregroundStyle(Color.white.opacity(0.5))
            }
            Spacer()
            Image(systemName: "chevron.right")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(Color.white.opacity(0.3))
        }
        .padding(.horizontal, 16)
        .frame(height: 56)
        .background(Color.darkRow, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}

// MARK: - Variant 2: Telemetry Hero
struct OneBoxVariant2TelemetryView: View {
    var body: some View {
        ZStack(alignment: .bottom) {
            Color.oledBlack.ignoresSafeArea()

            // Edge-to-Edge Petronas Teal-to-Gold Radial Wash (Top 42%)
            VStack {
                RadialGradient(
                    colors: [
                        Color.petronasTeal.opacity(0.50),
                        Color.telemetryGold.opacity(0.28),
                        Color.oledBlack
                    ],
                    center: .top,
                    startRadius: 10,
                    endRadius: 360
                )
                .frame(height: 380)
                .ignoresSafeArea(edges: .top)
                Spacer()
            }

            ScrollView(showsIndicators: false) {
                VStack(spacing: 20) {
                    // Hero Telemetry Container with Watermark Typography
                    ZStack(alignment: .topLeading) {
                        // Giant faint "BOX" watermark
                        Text("BOX")
                            .font(.system(size: 140, weight: .black, design: .rounded))
                            .foregroundStyle(Color.white.opacity(0.08))
                            .tracking(-6)
                            .offset(x: 10, y: -20)
                            .allowsHitTesting(false)

                        VStack(alignment: .leading, spacing: 18) {
                            HStack {
                                Text("SYSTEM TELEMETRY")
                                    .font(.system(size: 11, weight: .bold, design: .monospaced))
                                    .foregroundStyle(Color.white.opacity(0.8))
                                    .tracking(1.5)
                                Spacer()
                                HStack(spacing: 5) {
                                    Circle().fill(Color.tealGlow).frame(width: 6, height: 6)
                                    Text("ONLINE")
                                        .font(.system(size: 10, weight: .bold, design: .monospaced))
                                        .foregroundStyle(Color.tealGlow)
                                }
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(Color.white.opacity(0.1), in: Capsule())
                            }

                            // Tabular Stats with Equalizer Meters
                            HStack(alignment: .bottom, spacing: 28) {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("14")
                                        .font(.system(size: 38, weight: .bold, design: .monospaced))
                                        .foregroundStyle(.white)
                                    Text("FILES PROCESSED")
                                        .font(.system(size: 10, weight: .bold, design: .monospaced))
                                        .foregroundStyle(Color.white.opacity(0.6))
                                }

                                VStack(alignment: .leading, spacing: 2) {
                                    HStack(alignment: .firstTextBaseline, spacing: 4) {
                                        Text("128")
                                            .font(.system(size: 38, weight: .bold, design: .monospaced))
                                            .foregroundStyle(.white)
                                        Text("MB")
                                            .font(.system(size: 18, weight: .bold, design: .monospaced))
                                            .foregroundStyle(Color.tealGlow)
                                    }
                                    Text("STORAGE SAVED")
                                        .font(.system(size: 10, weight: .bold, design: .monospaced))
                                        .foregroundStyle(Color.white.opacity(0.6))
                                }

                                Spacer()

                                // Vertical Teal Equalizer Bars
                                HStack(alignment: .bottom, spacing: 4) {
                                    ForEach([16, 28, 22, 36, 18], id: \.self) { h in
                                        RoundedRectangle(cornerRadius: 2)
                                            .fill(Color.tealGlow)
                                            .frame(width: 4, height: CGFloat(h))
                                    }
                                }
                                .padding(.bottom, 6)
                            }
                        }
                        .padding(.horizontal, 20)
                        .padding(.top, 24)
                    }
                    .frame(height: 180)

                    // Centered 4-Icon Liquid Glass Quick-Action Dock
                    HStack(spacing: 0) {
                        dockItem(icon: "arrow.down.circle.fill", label: "Import")
                        dockDivider
                        dockItem(icon: "doc.fill", label: "PDF")
                        dockDivider
                        dockItem(icon: "photo.fill", label: "Image")
                        dockDivider
                        dockItem(icon: "text.viewfinder", label: "OCR")
                    }
                    .padding(.vertical, 10)
                    .frame(maxWidth: .infinity)
                    .liquidGlass(in: Capsule())
                    .padding(.horizontal, 16)

                    // Lower Section: Two Vibrant Bento Cards
                    HStack(spacing: 12) {
                        // Electric Blue: Compress PDF
                        VStack(alignment: .leading, spacing: 10) {
                            Image(systemName: "doc.badge.arrow.up.fill")
                                .font(.system(size: 20, weight: .bold))
                                .foregroundStyle(.white)
                            Spacer()
                            Text("Compress PDF")
                                .font(.system(size: 16, weight: .heavy, design: .rounded))
                                .foregroundStyle(.white)
                            Text("Ultra-lean output")
                                .font(.system(size: 11, weight: .medium))
                                .foregroundStyle(Color.white.opacity(0.8))
                        }
                        .padding(16)
                        .frame(height: 120)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color.electricBlue, in: RoundedRectangle(cornerRadius: 24, style: .continuous))

                        // Vivid Red: Compress Image
                        VStack(alignment: .leading, spacing: 10) {
                            Image(systemName: "photo.badge.arrow.down.fill")
                                .font(.system(size: 20, weight: .bold))
                                .foregroundStyle(.white)
                            Spacer()
                            Text("Compress Image")
                                .font(.system(size: 16, weight: .heavy, design: .rounded))
                                .foregroundStyle(.white)
                            Text("HEIC / JPEG / WebP")
                                .font(.system(size: 11, weight: .medium))
                                .foregroundStyle(Color.white.opacity(0.8))
                        }
                        .padding(16)
                        .frame(height: 120)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color.vividRed, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
                    }
                    .padding(.horizontal, 16)

                    // Numbered Recents Rows (01, 02, 03)
                    VStack(alignment: .leading, spacing: 10) {
                        Text("RECENTS")
                            .font(.system(size: 11, weight: .bold, design: .monospaced))
                            .foregroundStyle(Color.white.opacity(0.5))
                            .tracking(1.5)
                            .padding(.horizontal, 16)

                        VStack(spacing: 8) {
                            telemetryRecentRow(num: "01", name: "Contract_Signed.pdf", detail: "2 min ago · 1.4 MB", tag: "PDF")
                            telemetryRecentRow(num: "02", name: "Keynote_SlideDeck.pdf", detail: "1 hr ago · 18.2 MB", tag: "PDF")
                            telemetryRecentRow(num: "03", name: "Photo_DSC8921.jpg", detail: "Yesterday · 4.1 MB", tag: "IMG")
                        }
                        .padding(.horizontal, 16)
                    }
                    .padding(.bottom, 100)
                }
            }

            // Floating Bottom Liquid Glass
            OneBoxFloatingBottomBar()
        }
    }

    private var dockDivider: some View {
        Rectangle()
            .fill(Color.white.opacity(0.12))
            .frame(width: 1, height: 26)
    }

    private func dockItem(icon: String, label: String) -> some View {
        Button { } label: {
            VStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(.white)
                Text(label)
                    .font(.system(size: 10, weight: .bold, design: .rounded))
                    .foregroundStyle(Color.white.opacity(0.75))
            }
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(.plain)
    }

    private func telemetryRecentRow(num: String, name: String, detail: String, tag: String) -> some View {
        HStack(spacing: 12) {
            Text(num)
                .font(.system(size: 14, weight: .bold, design: .monospaced))
                .foregroundStyle(Color.tealGlow)
                .frame(width: 26, alignment: .leading)

            VStack(alignment: .leading, spacing: 2) {
                Text(name)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                Text(detail)
                    .font(.system(size: 11, weight: .regular, design: .monospaced))
                    .foregroundStyle(Color.white.opacity(0.45))
            }

            Spacer()

            Text(tag)
                .font(.system(size: 10, weight: .bold, design: .monospaced))
                .foregroundStyle(.white)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color.white.opacity(0.1), in: RoundedRectangle(cornerRadius: 6, style: .continuous))
        }
        .padding(.horizontal, 14)
        .frame(height: 54)
        .background(Color.darkRow, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }
}

// MARK: - Variant 3: Drop Cockpit
struct OneBoxVariant3CockpitView: View {
    var body: some View {
        ZStack(alignment: .bottom) {
            Color.oledBlack.ignoresSafeArea()

            // Deep Crimson-to-Indigo Radial Wash
            VStack {
                RadialGradient(
                    colors: [
                        Color.deepCrimson.opacity(0.65),
                        Color.deepIndigo.opacity(0.42),
                        Color.oledBlack
                    ],
                    center: .top,
                    startRadius: 20,
                    endRadius: 380
                )
                .frame(height: 400)
                .ignoresSafeArea(edges: .top)
                Spacer()
            }

            ScrollView(showsIndicators: false) {
                VStack(spacing: 18) {
                    // Borderless Hero with Giant Faint "ONE" Watermark
                    ZStack(alignment: .topLeading) {
                        Text("ONE")
                            .font(.system(size: 140, weight: .black, design: .rounded))
                            .foregroundStyle(Color.white.opacity(0.07))
                            .tracking(-6)
                            .offset(x: 12, y: -22)
                            .allowsHitTesting(false)

                        VStack(alignment: .leading, spacing: 14) {
                            Text("COCKPIT")
                                .font(.system(size: 11, weight: .bold, design: .monospaced))
                                .foregroundStyle(Color.white.opacity(0.6))
                                .tracking(2)

                            VStack(alignment: .leading, spacing: 4) {
                                Text("Drop a File")
                                    .font(.system(size: 34, weight: .black, design: .rounded))
                                    .foregroundStyle(.white)
                                Text("PDF • Photo • Document")
                                    .font(.system(size: 14, weight: .medium))
                                    .foregroundStyle(Color.white.opacity(0.7))
                            }

                            Button { } label: {
                                HStack(spacing: 8) {
                                    Image(systemName: "plus")
                                        .font(.system(size: 14, weight: .bold))
                                    Text("Browse Files")
                                        .font(.system(size: 14, weight: .bold, design: .rounded))
                                }
                                .foregroundStyle(.white)
                                .padding(.horizontal, 18)
                                .padding(.vertical, 10)
                                .background(Color.electricBlue, in: Capsule())
                            }
                            .buttonStyle(.plain)
                            .padding(.top, 4)
                        }
                        .padding(.horizontal, 20)
                        .padding(.top, 20)
                    }
                    .frame(height: 200)

                    // Segmented Liquid Glass 4-Slot Tool Strip
                    HStack(spacing: 0) {
                        cockpitToolSlot(icon: "doc.badge.arrow.up.fill", name: "Compress")
                        slotDivider
                        cockpitToolSlot(icon: "arrow.up.left.and.arrow.down.right", name: "Resize")
                        slotDivider
                        cockpitToolSlot(icon: "text.viewfinder", name: "OCR")
                        slotDivider
                        cockpitToolSlot(icon: "camera.viewfinder", name: "Scan")
                    }
                    .padding(.vertical, 12)
                    .frame(maxWidth: .infinity)
                    .liquidGlass(in: RoundedRectangle(cornerRadius: 20, style: .continuous))
                    .padding(.horizontal, 16)

                    // Featured Banner: Neon Volt Yellow (#E8FF00)
                    HStack(spacing: 16) {
                        VStack(alignment: .leading, spacing: 4) {
                            HStack(spacing: 6) {
                                Text("HOT TOOL")
                                    .font(.system(size: 9, weight: .black, design: .monospaced))
                                    .foregroundStyle(Color.black)
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(Color.black.opacity(0.12), in: Capsule())
                            }
                            Text("Batch Image Compressor")
                                .font(.system(size: 18, weight: .heavy, design: .rounded))
                                .foregroundStyle(Color.black)
                            Text("Process up to 50 photos simultaneously")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundStyle(Color.black.opacity(0.75))
                        }
                        Spacer()
                        Image(systemName: "bolt.fill")
                            .font(.system(size: 26, weight: .black))
                            .foregroundStyle(Color.black)
                    }
                    .padding(18)
                    .frame(maxWidth: .infinity)
                    .background(Color.voltYellow, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
                    .padding(.horizontal, 16)

                    // Clean Numbered Recents (01-04) with Color-Coded Tags
                    VStack(alignment: .leading, spacing: 10) {
                        Text("ACTIVE ASSETS")
                            .font(.system(size: 11, weight: .bold, design: .monospaced))
                            .foregroundStyle(Color.white.opacity(0.5))
                            .tracking(1.5)
                            .padding(.horizontal, 16)

                        VStack(spacing: 8) {
                            cockpitRecentRow(num: "01", name: "Tax_Return_2026.pdf", meta: "12 KB · 5m ago", tag: "PDF", tagColor: .electricBlue, tagTextColor: .white)
                            cockpitRecentRow(num: "02", name: "Studio_Portrait.heic", meta: "1.2 MB · 22m ago", tag: "IMG", tagColor: .vibrantOrange, tagTextColor: .white)
                            cockpitRecentRow(num: "03", name: "Receipt_Scan_Mar.txt", meta: "4 KB · 1h ago", tag: "OCR", tagColor: .voltYellow, tagTextColor: .black)
                            cockpitRecentRow(num: "04", name: "Passport_Copy.pdf", meta: "820 KB · Yesterday", tag: "PDF", tagColor: .electricBlue, tagTextColor: .white)
                        }
                        .padding(.horizontal, 16)
                    }
                    .padding(.bottom, 100)
                }
            }

            // Floating Bottom Liquid Glass
            OneBoxFloatingBottomBar()
        }
    }

    private var slotDivider: some View {
        Rectangle()
            .fill(Color.white.opacity(0.12))
            .frame(width: 1, height: 28)
    }

    private func cockpitToolSlot(icon: String, name: String) -> some View {
        Button { } label: {
            VStack(spacing: 5) {
                Image(systemName: icon)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(.white)
                Text(name)
                    .font(.system(size: 11, weight: .bold, design: .rounded))
                    .foregroundStyle(Color.white.opacity(0.85))
            }
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(.plain)
    }

    private func cockpitRecentRow(num: String, name: String, meta: String, tag: String, tagColor: Color, tagTextColor: Color) -> some View {
        HStack(spacing: 12) {
            Text(num)
                .font(.system(size: 13, weight: .bold, design: .monospaced))
                .foregroundStyle(Color.white.opacity(0.4))
                .frame(width: 24, alignment: .leading)

            VStack(alignment: .leading, spacing: 2) {
                Text(name)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                Text(meta)
                    .font(.system(size: 11, weight: .regular, design: .monospaced))
                    .foregroundStyle(Color.white.opacity(0.45))
            }

            Spacer()

            Text(tag)
                .font(.system(size: 10, weight: .black, design: .monospaced))
                .foregroundStyle(tagTextColor)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(tagColor, in: RoundedRectangle(cornerRadius: 6, style: .continuous))
        }
        .padding(.horizontal, 14)
        .frame(height: 52)
        .background(Color.darkRow, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }
}

// MARK: - Previews
#Preview("Variant 1: Bento Grid") {
    OneBoxVariant1BentoView()
}

#Preview("Variant 2: Telemetry Hero") {
    OneBoxVariant2TelemetryView()
}

#Preview("Variant 3: Drop Cockpit") {
    OneBoxVariant3CockpitView()
}
