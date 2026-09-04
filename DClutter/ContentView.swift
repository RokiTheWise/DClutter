//
//  ContentView.swift
//  DClutter
//

import SwiftUI
import DClutterUI

struct ContentView: View {
    var body: some View {
        TriageView(folder: TriageView.defaultDownloadsFolder)
    }
}

#Preview {
    ContentView()
}
