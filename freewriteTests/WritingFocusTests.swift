import Foundation
import Testing

@testable import freewrite

struct IdleFadeTests {
    @Test func showsChromeWhenDisabled() {
        #expect(IdleFade.chromeVisible(
            idleFadeEnabled: false,
            idleFor: 60,
            timerRunning: false,
            hovering: false,
            forceVisible: false
        ))
    }

    @Test func timerHidesChromeImmediatelyUnlessHovering() {
        #expect(!IdleFade.chromeVisible(
            idleFadeEnabled: false,
            idleFor: 0,
            timerRunning: true,
            hovering: false,
            forceVisible: false
        ))
        #expect(IdleFade.chromeVisible(
            idleFadeEnabled: false,
            idleFor: 60,
            timerRunning: true,
            hovering: true,
            forceVisible: false
        ))
    }

    @Test func idleFadeHidesOnlyAfterThreshold() {
        #expect(IdleFade.chromeVisible(
            idleFadeEnabled: true,
            idleFor: 3,
            timerRunning: false,
            hovering: false,
            forceVisible: false
        ))
        #expect(!IdleFade.chromeVisible(
            idleFadeEnabled: true,
            idleFor: 8,
            timerRunning: false,
            hovering: false,
            forceVisible: false
        ))
        #expect(IdleFade.chromeVisible(
            idleFadeEnabled: true,
            idleFor: 30,
            timerRunning: false,
            hovering: true,
            forceVisible: false
        ))
        #expect(IdleFade.chromeVisible(
            idleFadeEnabled: true,
            idleFor: 30,
            timerRunning: false,
            hovering: false,
            forceVisible: true
        ))
    }
}

struct FavoriteFontsTests {
    @Test func parseAndSerializeRoundTrip() {
        #expect(FavoriteFonts.parse("Lato-Regular, Arial,") == ["Lato-Regular", "Arial"])
        #expect(FavoriteFonts.serialize(["Lato-Regular", "Arial", "Lato-Regular"]) == "Lato-Regular,Arial")
        #expect(FavoriteFonts.parse("") == [])
    }

    @Test func togglingAddsAndRemoves() {
        #expect(FavoriteFonts.toggling("Arial", in: []) == ["Arial"])
        #expect(FavoriteFonts.toggling("Arial", in: ["Arial", "Lato-Regular"]) == ["Lato-Regular"])
    }

    @Test func displayNameUsesBuiltinTitles() {
        #expect(FavoriteFonts.displayName(for: "Lato-Regular") == "Lato")
        #expect(FavoriteFonts.displayName(for: "Times New Roman") == "Serif")
        #expect(FavoriteFonts.displayName(for: "Futura") == "Futura")
    }
}

struct CompositionGuardTests {
    @Test func blocksDeleteOnlyWhenLockIsOnAndNotComposing() {
        #expect(!CompositionGuard.shouldBlockBackspace(lockEnabled: false, keyCode: 51, hasMarkedText: false))
        #expect(CompositionGuard.shouldBlockBackspace(lockEnabled: true, keyCode: 51, hasMarkedText: false))
        #expect(CompositionGuard.shouldBlockBackspace(lockEnabled: true, keyCode: 117, hasMarkedText: false))
        #expect(!CompositionGuard.shouldBlockBackspace(lockEnabled: true, keyCode: 51, hasMarkedText: true))
        #expect(!CompositionGuard.shouldBlockBackspace(lockEnabled: true, keyCode: 0, hasMarkedText: false))
    }
}
