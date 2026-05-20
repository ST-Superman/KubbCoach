//
//  ShareCardData.swift
//  Kubb Coach
//
//  Value type that describes a shareable session card. Every session type
//  (training phases, game tracker, pressure cooker) produces one of these
//  via its own mapper; `ShareCardView` renders it.
//

import SwiftUI

struct ShareCardData {
    let mainStat: String
    let mainStatTint: MainStatTint
    let subtitle: String
    let subtitleCaption: String?
    let statRows: [ShareCardStatRow]
    let personalBests: [PersonalBest]
    let date: Date

    enum MainStatTint {
        case gold
        case dim
    }
}

struct ShareCardLabel {
    let icon: String
    let text: String
    let tint: Color?

    init(icon: String, text: String, tint: Color? = nil) {
        self.icon = icon
        self.text = text
        self.tint = tint
    }
}

enum ShareCardStatRow {
    case single(ShareCardLabel)
    case pair(ShareCardLabel, ShareCardLabel)
}
