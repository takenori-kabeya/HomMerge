import SwiftUI

private struct AppViewModelKey: FocusedValueKey {
    typealias Value = AppViewModel
}

extension FocusedValues {
    var appViewModel: AppViewModel? {
        get { self[AppViewModelKey.self] }
        set { self[AppViewModelKey.self] = newValue }
    }
}
