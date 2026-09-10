//
//  WritingGoal.swift
//  freewrite
//
//  Optional daily word goal. Zero means the meter stays hidden.
//

import Foundation

enum WritingGoal {
    static func progress(current: Int, goal: Int) -> Double {
        guard goal > 0 else { return 0 }
        return min(Double(max(current, 0)) / Double(goal), 1)
    }

    static func label(current: Int, goal: Int) -> String {
        guard goal > 0 else { return "" }
        return "\(max(current, 0)) / \(goal)"
    }
}
