//
//  ContentView.swift
//  Binario1
//
//  Created by Romesh Singhabahu on 13/06/26.
//

import SwiftUI

/// Thin wrapper around the main board screen (kept for previews / hosting).
struct ContentView: View {
    var body: some View {
        StationBoardView(
            viewModel: StationBoardViewModel(service: MockTrainBoardService())
        )
    }
}

#Preview {
    ContentView()
}
