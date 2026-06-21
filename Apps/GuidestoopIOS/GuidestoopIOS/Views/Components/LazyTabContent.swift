import SwiftUI

/// Only builds tab content when selected, so @Query views are not all created at launch.
struct LazyTabContent<Tab: Hashable, Content: View>: View {
    let tab: Tab
    let selectedTab: Tab
    @ViewBuilder let content: () -> Content

    var body: some View {
        if tab == selectedTab {
            content()
        } else {
            Color.clear
        }
    }
}
