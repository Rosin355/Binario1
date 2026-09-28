//
//  Binario1LiveActivityBundle.swift
//  Binario1LiveActivity
//
//  Created by Romesh Singhabahu on 28/09/26.
//
//  The extension ships ONE thing: the followed-train Live Activity. No home screen
//  widget (out of scope for LA1).
//

import WidgetKit
import SwiftUI

@main
struct Binario1LiveActivityBundle: WidgetBundle {
    var body: some Widget {
        FollowedTrainLiveActivity()
    }
}
