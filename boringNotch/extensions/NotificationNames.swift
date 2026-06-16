import Foundation

extension Notification.Name {
    static let mediaControllerChanged = Notification.Name("mediaControllerChanged")
    static let selectedScreenChanged = Notification.Name("SelectedScreenChanged")
    static let notchHeightChanged = Notification.Name("NotchHeightChanged")
    static let showOnAllDisplaysChanged = Notification.Name("showOnAllDisplaysChanged")
    static let automaticallySwitchDisplayChanged = Notification.Name("automaticallySwitchDisplayChanged")
    static let expandedDragDetectionChanged = Notification.Name("expandedDragDetectionChanged")
    static let pomodoroTimerDidFinish = Notification.Name("PomodoroTimerDidFinish")
    static let drinkingReminderDidFire = Notification.Name("DrinkingReminderDidFire")
    static let sharingDidFinish = Notification.Name("com.boringNotch.sharingDidFinish")
    static let accessibilityAuthorizationChanged = Notification.Name("accessibilityAuthorizationChanged")
}
