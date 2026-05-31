import SwiftUI

enum KinesisDesign {
    static let panelRadius: CGFloat = 8
    static let controlRadius: CGFloat = 8
    static let spacing: CGFloat = 16
}

enum GlassProminence {
    case standard
    case primary
    case warning
}

struct GlassPanel<Content: View>: View {
    var title: String?
    var systemImage: String?
    var prominence: GlassProminence
    @ViewBuilder var content: Content

    init(
        _ title: String? = nil,
        systemImage: String? = nil,
        prominence: GlassProminence = .standard,
        @ViewBuilder content: () -> Content
    ) {
        self.title = title
        self.systemImage = systemImage
        self.prominence = prominence
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            if title != nil || systemImage != nil {
                HStack(spacing: 8) {
                    if let systemImage {
                        Image(systemName: systemImage)
                            .foregroundStyle(accentStyle)
                    }
                    if let title {
                        Text(title)
                            .font(.headline)
                    }
                    Spacer()
                }
            }
            content
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassPanel(prominence: prominence)
    }

    private var accentStyle: AnyShapeStyle {
        switch prominence {
        case .standard:
            AnyShapeStyle(.secondary)
        case .primary:
            AnyShapeStyle(.blue)
        case .warning:
            AnyShapeStyle(.orange)
        }
    }
}

extension View {
    func glassPanel(prominence: GlassProminence = .standard) -> some View {
        modifier(GlassPanelModifier(prominence: prominence))
    }
}

private struct GlassPanelModifier: ViewModifier {
    var prominence: GlassProminence

    func body(content: Content) -> some View {
        content
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: KinesisDesign.panelRadius, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: KinesisDesign.panelRadius, style: .continuous)
                    .strokeBorder(borderStyle, lineWidth: 1)
            }
            .shadow(color: shadowColor, radius: 22, x: 0, y: 12)
    }

    private var borderStyle: AnyShapeStyle {
        switch prominence {
        case .standard:
            AnyShapeStyle(.white.opacity(0.20))
        case .primary:
            AnyShapeStyle(.blue.opacity(0.28))
        case .warning:
            AnyShapeStyle(.orange.opacity(0.34))
        }
    }

    private var shadowColor: Color {
        switch prominence {
        case .standard:
            .black.opacity(0.08)
        case .primary:
            .blue.opacity(0.12)
        case .warning:
            .orange.opacity(0.12)
        }
    }
}

struct KinesisStatusBadge: View {
    var text: String
    var systemImage: String
    var state: State

    enum State {
        case ready
        case active
        case paused
        case warning
    }

    var body: some View {
        Label(text, systemImage: systemImage)
            .font(.caption.weight(.medium))
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(tint.opacity(0.14), in: Capsule())
            .foregroundStyle(tint)
    }

    private var tint: Color {
        switch state {
        case .ready:
            .green
        case .active:
            .blue
        case .paused:
            .secondary
        case .warning:
            .orange
        }
    }
}
