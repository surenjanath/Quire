//
//  WritingSpark.swift
//  freewrite
//
//  One quiet prompt for the empty page. Stable for the whole day so
//  the same thought is waiting if you reopen the app later.
//

import Foundation

enum WritingSpark {
    static let prompts = [
        "What felt unfinished today?",
        "Who crossed your mind?",
        "What are you avoiding?",
        "What surprised you?",
        "What do you wish you had said?",
        "Where did the day leak?",
        "What are you grateful for, specifically?",
        "What would you tell yesterday-you?",
        "What is the thing under the thing?",
        "What felt like home?",
        "What felt like noise?",
        "What are you pretending not to know?",
        "What did your body want?",
        "What memory showed up uninvited?",
        "What would make tomorrow lighter?",
        "What are you holding too tightly?",
        "What did you notice and not say?",
        "What would kindness look like here?",
        "What is the smallest true sentence?",
        "What are you waiting for permission to write?",
        "What changed since last week?",
        "What still hurts a little?",
        "What made you laugh, even briefly?",
        "What do you keep circling?",
        "What would you keep if everything else went?",
        "What is the weather inside?",
        "What did you almost delete?",
        "What are you becoming?",
        "What did you learn the hard way?",
        "What do you want to remember in a year?",
        "Begin with the thing you almost skipped."
    ]

    static func prompt(for date: Date, calendar: Calendar = .current) -> String {
        let start = calendar.startOfDay(for: date)
        let day = calendar.ordinality(of: .day, in: .era, for: start) ?? 0
        return prompts[abs(day) % prompts.count]
    }
}
