import WidgetKit
import SwiftUI

struct ClaudeMeterWidget: Widget {
    let kind: String = "ClaudeMeterWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: ClaudeMeterTimelineProvider()) { entry in
            ClaudeMeterWidgetEntryView(entry: entry)
        }
        .configurationDisplayName("Claude Usage")
        .description("Monitor your Claude AI usage at a glance.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

struct ClaudeMeterWidgetEntryView: View {
    @Environment(\.widgetFamily) var family
    let entry: ClaudeMeterEntry

    var body: some View {
        switch family {
        case .systemSmall:
            SmallWidgetView(entry: entry)
        case .systemMedium:
            MediumWidgetView(entry: entry)
        default:
            SmallWidgetView(entry: entry)
        }
    }
}

@main
struct ClaudeMeterWidgetBundle: WidgetBundle {
    var body: some Widget {
        ClaudeMeterWidget()
    }
}

#if DEBUG
struct ClaudeMeterWidget_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            ClaudeMeterWidgetEntryView(entry: .placeholder)
                .previewContext(WidgetPreviewContext(family: .systemSmall))
                .previewDisplayName("Small")

            ClaudeMeterWidgetEntryView(entry: .placeholder)
                .previewContext(WidgetPreviewContext(family: .systemMedium))
                .previewDisplayName("Medium")

            ClaudeMeterWidgetEntryView(entry: .unconfigured)
                .previewContext(WidgetPreviewContext(family: .systemSmall))
                .previewDisplayName("Unconfigured")
        }
    }
}
#endif
