import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest_all.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

/// One rotating line for the daily reminder, so it does not read identically
/// every single day without needing any state to track what was shown last.
class _ReminderCopy {
  const _ReminderCopy(this.title, this.body);

  final String title;
  final String body;

  static const List<_ReminderCopy> _rotation = [
    _ReminderCopy(
      'Quick shelf check',
      'A minute to see if anything has drifted since you last looked.',
    ),
    _ReminderCopy(
      'Cluckfall Heights',
      'Your shelves have had a full day. Worth a glance?',
    ),
    _ReminderCopy(
      'Steady as it goes',
      'Nothing urgent — just a nudge to check on your plans.',
    ),
    _ReminderCopy(
      'Top-heavy check-in',
      'A daily look catches a wobble before it becomes a tumble.',
    ),
    _ReminderCopy(
      'Shelf life',
      'See what changed today across your stored plans.',
    ),
    _ReminderCopy(
      'A moment for your shelves',
      'Stability rarely breaks all at once. Little daily checks catch it early.',
    ),
    _ReminderCopy(
      'Cluckfall Heights',
      'One tap to see today\u2019s stability at a glance.',
    ),
  ];

  /// Deterministic on any given calendar day, so this reads the same if the
  /// OS calls in twice, but rotates day to day through the month.
  static _ReminderCopy forDay(int dayOfMonth) => _rotation[dayOfMonth % _rotation.length];
}

/// Schedules the single optional daily reminder the user can turn on in
/// Settings.
///
/// This is a purely local, on-device alarm — nothing is sent to or received
/// from a server. It is deliberately kept in its own namespace (Android
/// channel id, iOS category id, and a fixed notification id) so that if a
/// push-notification provider such as Firebase Cloud Messaging is ever added
/// to this app, the two cannot collide: enabling, disabling, or receiving a
/// push message can never cancel, duplicate, or be mistaken for this
/// reminder, and vice versa.
class NotificationService {
  NotificationService() : _plugin = FlutterLocalNotificationsPlugin();

  final FlutterLocalNotificationsPlugin _plugin;
  bool _initialized = false;

  static const String _channelId = 'local.dailyReminder';
  static const String _channelName = 'Daily reminder';
  static const String _channelDescription =
      'The single optional daily nudge you can turn on in Settings.';
  static const String _iosCategoryId = 'local.dailyReminder';

  /// Deliberately not a low, easily-guessed number: keeps this reminder's id
  /// well clear of whatever range a future push integration might pick.
  static const int _notificationId = 480001;

  Future<void> _ensureInitialized() async {
    if (_initialized) return;

    tz_data.initializeTimeZones();
    try {
      final String name = (await FlutterTimezone.getLocalTimezone()).identifier;
      tz.setLocalLocation(tz.getLocation(name));
    } on Object {
      // Left on the package's default location. Worst case the reminder
      // fires at the chosen wall-clock time in the wrong zone, which is far
      // better than the feature failing outright.
    }

    await _plugin.initialize(
      settings: const InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
        iOS: DarwinInitializationSettings(
          // Requested explicitly via [requestPermission] once the user turns
          // the toggle on, rather than the moment the app first starts.
          requestAlertPermission: false,
          requestBadgePermission: false,
          requestSoundPermission: false,
          notificationCategories: [DarwinNotificationCategory(_iosCategoryId)],
        ),
      ),
    );
    _initialized = true;
  }

  /// Asks the OS for permission to show notifications.
  ///
  /// Safe to call more than once: past the first ask, the system silently
  /// returns the answer the user already gave instead of prompting again.
  Future<bool> requestPermission() async {
    await _ensureInitialized();

    final bool? androidGranted = await _plugin
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.requestNotificationsPermission();
    final bool? iosGranted = await _plugin
        .resolvePlatformSpecificImplementation<IOSFlutterLocalNotificationsPlugin>()
        ?.requestPermissions(alert: true, badge: true, sound: true);

    // Platforms that answer neither (older Android, desktop) are treated as
    // granted: there was nothing to ask permission for in the first place.
    return (androidGranted ?? true) && (iosGranted ?? true);
  }

  /// Schedules the daily reminder for [hour]:[minute] in the device's local
  /// time, replacing any previously scheduled one.
  Future<void> scheduleDaily({required int hour, required int minute}) async {
    await _ensureInitialized();

    final tz.TZDateTime next = _nextInstanceOf(hour, minute);
    final _ReminderCopy copy = _ReminderCopy.forDay(next.day);

    await _plugin.zonedSchedule(
      id: _notificationId,
      title: copy.title,
      body: copy.body,
      scheduledDate: next,
      notificationDetails: const NotificationDetails(
        android: AndroidNotificationDetails(
          _channelId,
          _channelName,
          channelDescription: _channelDescription,
          importance: Importance.defaultImportance,
          priority: Priority.defaultPriority,
          category: AndroidNotificationCategory.reminder,
        ),
        iOS: DarwinNotificationDetails(categoryIdentifier: _iosCategoryId),
      ),
      // Roughly the chosen minute rather than to-the-second: avoids needing
      // the exact-alarm permission Android 12+ gates behind an extra prompt,
      // which is not worth it for a reminder that isn't time-critical.
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      matchDateTimeComponents: DateTimeComponents.time,
    );
  }

  /// Cancels the daily reminder. Safe to call even if none is scheduled.
  Future<void> cancel() async {
    await _ensureInitialized();
    await _plugin.cancel(id: _notificationId);
  }

  tz.TZDateTime _nextInstanceOf(int hour, int minute) {
    final tz.TZDateTime now = tz.TZDateTime.now(tz.local);
    tz.TZDateTime scheduled = tz.TZDateTime(
      tz.local,
      now.year,
      now.month,
      now.day,
      hour,
      minute,
    );
    if (scheduled.isBefore(now)) {
      scheduled = scheduled.add(const Duration(days: 1));
    }
    return scheduled;
  }
}

final Provider<NotificationService> notificationServiceProvider = Provider<NotificationService>(
  (ref) => NotificationService(),
);
