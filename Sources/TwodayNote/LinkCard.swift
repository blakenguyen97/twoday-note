import SwiftUI
import TwodayNoteKit

/// A video's thumbnail across the top of its block. Click it to watch.
struct VideoThumbnail: View {
    let link: LinkPreview
    let open: () -> Void

    var body: some View {
        Button(action: open) {
            Color.clear
                .aspectRatio(16 / 9, contentMode: .fit)
                .overlay {
                    if let name = link.thumbnail, let image = ImageStore.preview(name) {
                        // hqdefault is 4:3 with bars; filling 16:9 crops them off.
                        Image(nsImage: image)
                            .resizable()
                            .scaledToFill()
                    } else {
                        Image(systemName: "play.rectangle")
                            .font(.title)
                            .foregroundStyle(.tertiary)
                    }
                }
                .overlay {
                    Image(systemName: "play.fill")
                        .font(.body)
                        .foregroundStyle(.primary)
                        .frame(width: Space.section, height: Space.section)
                        .background(.regularMaterial, in: .circle)
                }
                .background(.fill.tertiary)
                .clipShape(.rect(cornerRadius: Space.xs))
                .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .help("Mở video trên YouTube")
        .accessibilityLabel("Ảnh video, bấm để mở trên YouTube")
    }
}

/// What a link block shows about its link: a repo's name, owner, stars,
/// description, and topics, or a video's title and channel.
struct LinkInfo: View {
    let link: LinkPreview
    let isDone: Bool
    let open: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: Space.xs) {
            HStack(alignment: .firstTextBaseline, spacing: Space.sm) {
                Button(action: open) {
                    Text(title)
                        .font(link.key == nil ? .body : .headline)
                        .lineLimit(link.site == .youtube ? 2 : 1)
                        .truncationMode(.middle)
                        .multilineTextAlignment(.leading)
                        .strikethrough(isDone)
                        .foregroundStyle(isDone ? .secondary : .primary)
                        .contentShape(.rect)
                }
                .buttonStyle(.plain)
                .help("Mở \(link.shortURL)")
                if link.repoPath != nil {
                    Text("Repo")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, Space.sm)
                        .padding(.vertical, 2) // grid: ok badge inside a text line
                        .overlay { Capsule().strokeBorder(.separator, lineWidth: 1) }
                        .fixedSize()
                }
            }
            if let line = detailLine {
                line
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            if let summary = link.summary {
                Text(summary)
                    .font(.callout)
                    .lineLimit(3)
                    .foregroundStyle(isDone ? .secondary : .primary)
            }
            if let topics = link.topics, !topics.isEmpty {
                FlowLayout(spacing: Space.xs) {
                    ForEach(topics.prefix(8), id: \.self) { topic in
                        Text(topic)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .padding(.horizontal, Space.sm)
                            .padding(.vertical, 2) // grid: ok chip inside a text line
                            .background(.fill.tertiary, in: .capsule)
                    }
                }
                .padding(.top, Space.xs)
            }
        }
    }

    private var title: String {
        if link.key == nil { return link.shortURL }
        if let title = link.title { return title }
        return link.checked ? link.shortURL : "Đang tải…"
    }

    /// "github/spec-kit  ★ 147k  Python" or the video's channel.
    private var detailLine: Text? {
        switch link.site {
        case .github:
            guard let path = link.repoPath else { return nil }
            var line = Text(path).monospaced()
            if let stars = link.stars {
                line = Text("\(line)   \(Image(systemName: "star")) \(LinkPreview.compact(stars))")
            }
            if let language = link.language {
                line = Text("\(line)   \(language)")
            }
            return line
        case .youtube:
            guard link.key != nil else { return nil }
            return Text(link.author ?? "YouTube")
        }
    }
}

extension LinkSite {
    /// The block's symbol when it is a note: code for GitHub, a video for YouTube.
    var symbol: String {
        switch self {
        case .github: "chevron.left.forwardslash.chevron.right"
        case .youtube: "play.rectangle"
        }
    }
}

/// Lays its views out in rows, wrapping to the next row when one is full.
struct FlowLayout: Layout {
    var spacing: CGFloat

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let rows = arrange(width: proposal.width ?? .infinity, subviews: subviews)
        let width = rows.map { $0.width }.max() ?? 0
        let height = rows.map(\.height).reduce(0, +) + spacing * CGFloat(max(rows.count - 1, 0))
        return CGSize(width: width, height: height)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var y = bounds.minY
        for row in arrange(width: bounds.width, subviews: subviews) {
            var x = bounds.minX
            for index in row.indices {
                let size = subviews[index].sizeThatFits(.unspecified)
                subviews[index].place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(size))
                x += size.width + spacing
            }
            y += row.height + spacing
        }
    }

    private struct Row {
        var indices: [Int] = []
        var width: CGFloat = 0
        var height: CGFloat = 0
    }

    private func arrange(width: CGFloat, subviews: Subviews) -> [Row] {
        var rows: [Row] = []
        var row = Row()
        for index in subviews.indices {
            let size = subviews[index].sizeThatFits(.unspecified)
            let needed = row.indices.isEmpty ? size.width : row.width + spacing + size.width
            if needed > width, !row.indices.isEmpty {
                rows.append(row)
                row = Row()
            }
            row.width = row.indices.isEmpty ? size.width : row.width + spacing + size.width
            row.height = max(row.height, size.height)
            row.indices.append(index)
        }
        if !row.indices.isEmpty { rows.append(row) }
        return rows
    }
}
