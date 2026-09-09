import Testing

@testable import freewrite

struct WritingPreferencesTests {

    @Test func unknownFontFallsBackToLato() {
        #expect(WritingPreferences.resolvedFont("") == "Lato-Regular")
        #expect(WritingPreferences.resolvedFont("   ") == "Lato-Regular")
        #expect(WritingPreferences.resolvedFont("Times New Roman") == "Times New Roman")
    }

    @Test func fontSizeSnapsToAllowedList() {
        #expect(WritingPreferences.resolvedFontSize(18) == 18)
        #expect(WritingPreferences.resolvedFontSize(19) == 18)
        #expect(WritingPreferences.resolvedFontSize(25) == 24)
        #expect(WritingPreferences.resolvedFontSize(0) == 18)
        #expect(WritingPreferences.resolvedFontSize(99) == 26)
    }

    @Test func timerSecondsClampAndSanitize() {
        #expect(WritingPreferences.resolvedTimerSeconds(900) == 900)
        #expect(WritingPreferences.resolvedTimerSeconds(-30) == 0)
        #expect(WritingPreferences.resolvedTimerSeconds(4000) == 2700)
        #expect(WritingPreferences.resolvedTimerSeconds(61) == 60)
    }

    @Test func timerScrollStepsByFiveMinutes() {
        #expect(WritingPreferences.steppedTimerSeconds(current: 900, directionMinutes: 5) == 1200)
        #expect(WritingPreferences.steppedTimerSeconds(current: 900, directionMinutes: -5) == 600)
        #expect(WritingPreferences.steppedTimerSeconds(current: 0, directionMinutes: -5) == 0)
        #expect(WritingPreferences.steppedTimerSeconds(current: 2700, directionMinutes: 5) == 2700)
    }
}
