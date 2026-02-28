//
//  AppSettings.swift
//  Kubb Coach
//
//  Created by Claude Code on 2/27/26.
//

import SwiftData
import Foundation

@Model
class AppSettings {
    var hapticsEnabled: Bool = true
    var lastModified: Date = Date()

    init() {}
}
