import Foundation
import UserNotifications

final class NotificationService: UNNotificationServiceExtension {
  private enum DeliveryState {
    case idle
    case awaitingCancellationDecision
    case cancellationStarted
    case finished
  }

  private let completionLock = NSLock()
  private var contentHandler: ((UNNotificationContent) -> Void)?
  private var originalContent: UNNotificationContent?
  private var state = DeliveryState.idle

  override func didReceive(
    _ request: UNNotificationRequest,
    withContentHandler contentHandler: @escaping (UNNotificationContent) -> Void
  ) {
    completionLock.lock()
    self.contentHandler = contentHandler
    originalContent = request.content
    state = .awaitingCancellationDecision
    completionLock.unlock()

    guard let identifier = FeastReminderRemoteContract.localRequestIdentifier(
      from: request.content.userInfo,
      now: Date()
    ) else {
      completeWithoutCancellation(with: request.content)
      return
    }

    guard beginCancellation() else { return }
    // flutter_local_notifications uses the decimal String form of the integer
    // passed to zonedSchedule as the iOS UNNotificationRequest identifier.
    UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [identifier])
    completeAfterCancellation(with: request.content)
  }

  override func serviceExtensionTimeWillExpire() {
    completeWithoutCancellation()
  }

  private func beginCancellation() -> Bool {
    completionLock.lock()
    guard state == .awaitingCancellationDecision else {
      completionLock.unlock()
      return false
    }
    state = .cancellationStarted
    completionLock.unlock()
    return true
  }

  private func completeAfterCancellation(with content: UNNotificationContent) {
    finish(ifStateIs: .cancellationStarted, with: content)
  }

  private func completeWithoutCancellation(with content: UNNotificationContent? = nil) {
    finish(ifStateIs: .awaitingCancellationDecision, with: content)
  }

  private func finish(
    ifStateIs expectedState: DeliveryState,
    with candidateContent: UNNotificationContent?
  ) {
    completionLock.lock()
    guard
      state == expectedState,
      let handler = contentHandler,
      let content = candidateContent ?? originalContent
    else {
      completionLock.unlock()
      return
    }
    state = .finished
    contentHandler = nil
    originalContent = nil
    completionLock.unlock()
    handler(content)
  }
}

private enum FeastReminderRemoteContract {
  private static let occurrenceComponent = try! NSRegularExpression(
    pattern: "^[a-z0-9]+(?:-[a-z0-9]+)*$"
  )
  private static let celebrationDate = try! NSRegularExpression(
    pattern: "^[0-9]{4}-[0-9]{2}-[0-9]{2}$"
  )

  static func localRequestIdentifier(
    from userInfo: [AnyHashable: Any],
    now: Date
  ) -> String? {
    guard
      let aps = userInfo["aps"] as? [AnyHashable: Any],
      integer(aps["mutable-content"]) == 1,
      integer(userInfo["schema"]) == 3,
      userInfo["type"] as? String == "feast_reminder",
      let occurrenceKey = nonEmptyString(userInfo["occurrence_key"]),
      validIdentity(occurrenceKey, userInfo: userInfo),
      let localIdentifier = integer(userInfo["local_notification_id"]),
      localIdentifier > 0,
      localIdentifier == stableNotificationIdentifier(for: occurrenceKey),
      let scheduledFor = instant(userInfo["scheduled_for"]),
      let remoteExpiresAt = instant(userInfo["remote_expires_at"]),
      let localSafetyAt = instant(userInfo["local_safety_at"]),
      approximately(remoteExpiresAt.timeIntervalSince(scheduledFor), equals: 120),
      approximately(localSafetyAt.timeIntervalSince(scheduledFor), equals: 180),
      remoteExpiresAt > now
    else {
      return nil
    }

    return String(localIdentifier)
  }

  private static func validIdentity(
    _ occurrenceKey: String,
    userInfo: [AnyHashable: Any]
  ) -> Bool {
    let parts = occurrenceKey.split(separator: ":", omittingEmptySubsequences: false).map(String.init)
    guard
      parts.count == 5,
      parts[0] == "feast",
      matches(occurrenceComponent, value: parts[1]),
      isValidCelebrationDate(parts[2]),
      parts[3] == "eve" || parts[3] == "on_day",
      matches(occurrenceComponent, value: parts[4]),
      nonEmptyString(userInfo["celebration_date"]) == parts[2],
      nonEmptyString(userInfo["timing"]) == parts[3],
      let region = nonEmptyString(userInfo["liturgical_region"]),
      slug(region) == parts[1]
    else {
      return false
    }

    if let saintID = nonEmptyString(userInfo["saint_id"]), slug(saintID) != parts[4] {
      return false
    }
    return true
  }

  private static func stableNotificationIdentifier(for value: String) -> Int {
    var hash: UInt32 = 0x811c9dc5
    for byte in value.utf8 {
      hash ^= UInt32(byte)
      hash = hash &* 0x01000193
    }
    let positive = Int(hash & 0x7fffffff)
    return positive == 0 ? 1 : positive
  }

  private static func isValidCelebrationDate(_ value: String) -> Bool {
    guard matches(celebrationDate, value: value) else { return false }
    let formatter = DateFormatter()
    formatter.calendar = Calendar(identifier: .gregorian)
    formatter.locale = Locale(identifier: "en_US_POSIX")
    formatter.timeZone = TimeZone(secondsFromGMT: 0)
    formatter.dateFormat = "yyyy-MM-dd"
    formatter.isLenient = false
    guard let parsed = formatter.date(from: value) else { return false }
    return formatter.string(from: parsed) == value
  }

  private static func integer(_ value: Any?) -> Int? {
    if let number = value as? NSNumber {
      guard CFGetTypeID(number) != CFBooleanGetTypeID() else { return nil }
      let integer = number.intValue
      guard number.doubleValue == Double(integer) else { return nil }
      return integer
    }
    if let string = value as? String, string.range(of: "^[0-9]+$", options: .regularExpression) != nil {
      return Int(string)
    }
    return nil
  }

  private static func nonEmptyString(_ value: Any?) -> String? {
    guard let string = value as? String else { return nil }
    let trimmed = string.trimmingCharacters(in: .whitespacesAndNewlines)
    return trimmed.isEmpty ? nil : trimmed
  }

  private static func instant(_ value: Any?) -> Date? {
    guard let string = nonEmptyString(value) else { return nil }
    let standard = ISO8601DateFormatter()
    standard.formatOptions = [.withInternetDateTime]
    if let date = standard.date(from: string) {
      return date
    }
    let fractional = ISO8601DateFormatter()
    fractional.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
    return fractional.date(from: string)
  }

  private static func matches(_ expression: NSRegularExpression, value: String) -> Bool {
    let range = NSRange(value.startIndex..<value.endIndex, in: value)
    return expression.firstMatch(in: value, range: range)?.range == range
  }

  private static func slug(_ value: String) -> String {
    let normalized = value
      .trimmingCharacters(in: .whitespacesAndNewlines)
      .lowercased()
      .replacingOccurrences(of: "[^a-z0-9]+", with: "-", options: .regularExpression)
      .trimmingCharacters(in: CharacterSet(charactersIn: "-"))
    return normalized.isEmpty ? "celebration" : normalized
  }

  private static func approximately(_ value: TimeInterval, equals expected: TimeInterval) -> Bool {
    abs(value - expected) < 0.001
  }
}
