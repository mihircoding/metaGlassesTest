//
// The app's one URL handler: Meta AI app callbacks (same pattern as Meta’s CameraAccess sample)
// and Supabase password-reset links. One handler, so each URL is routed exactly once.
//

import MWDATCore
import SwiftUI

struct RegistrationView: View {
    let viewModel: WearablesViewModel
    /// Passed in: this view sits in an overlay, outside the `.environment(app)` it is attached next to.
    let app: AppModel

    var body: some View {
        EmptyView()
            .onOpenURL { url in
                if Backend.isPasswordResetLink(url) {
                    Task { await app.openPasswordResetLink(url) }
                    return
                }
                guard
                    let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
                    components.queryItems?.contains(where: { $0.name == "metaWearablesAction" }) == true
                else { return }
                Task {
                    do {
                        _ = try await Wearables.shared.handleUrl(url)
                    } catch let error as RegistrationError {
                        viewModel.presentError(error.description)
                    } catch {
                        viewModel.presentError(error.localizedDescription)
                    }
                }
            }
    }
}
