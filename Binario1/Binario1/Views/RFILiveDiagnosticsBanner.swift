//
//  RFILiveDiagnosticsBanner.swift
//  Binario1
//
//  DEBUG-ONLY compact diagnostics line for the RFI live spike, shown under the
//  Home header when `.rfiLivePadova` is active. Secondary by design; never in
//  RELEASE. Console logs carry the fuller detail (URL, content type, captured
//  HTML path, error).
//

#if DEBUG
import SwiftUI

struct RFILiveDiagnosticsBanner: View {
    var body: some View {
        let store = RFILiveDiagnosticsStore.shared
        if let d = store.latest {
            Text(verbatim: "DEBUG RFI: \(d.compactSummary)")
                .font(.system(size: 10, weight: .medium, design: .monospaced))
                .foregroundStyle(d.usedFallback ? BoardColors.delay : BoardColors.amberDim)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 18)
                .accessibilityHidden(true)
        }
    }
}
#endif
