//
// Handles Meta AI app callbacks (same pattern as Meta’s CameraAccess sample).
//

import MWDATCore
import SwiftUI

struct RegistrationView: View {
    @ObservedObject var viewModel: WearablesViewModel

    var body: some View {
        EmptyView()
            .onOpenURL { url in
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
