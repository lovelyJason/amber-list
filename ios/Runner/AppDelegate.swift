import Flutter
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate {

  /// App Group ID
  private let appGroupID = "group.com.amberlist.amberList"

  /// Database file name
  private let dbFileName = "amber_list.db"

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    GeneratedPluginRegistrant.register(with: self)

    // Migrate database to App Group (for Widget access)
    migrateDatabaseToAppGroup()

    // Register MethodChannel for database path
    setupDatabaseChannel()

    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  /// Migrate database from Documents to App Group shared directory
  /// This allows Widget Extension to access the same database
  private func migrateDatabaseToAppGroup() {
    guard let appGroupURL = FileManager.default.containerURL(
      forSecurityApplicationGroupIdentifier: appGroupID
    ) else {
      print("[AppDelegate] App Group container not found")
      return
    }

    let newDbPath = appGroupURL.appendingPathComponent(dbFileName)

    // Skip if already migrated
    if FileManager.default.fileExists(atPath: newDbPath.path) {
      print("[AppDelegate] Database already in App Group")
      return
    }

    // Find old database in Documents directory
    guard let documentsURL = FileManager.default.urls(
      for: .documentDirectory,
      in: .userDomainMask
    ).first else {
      print("[AppDelegate] Documents directory not found")
      return
    }

    let oldDbPath = documentsURL.appendingPathComponent(dbFileName)

    // Check if old database exists
    guard FileManager.default.fileExists(atPath: oldDbPath.path) else {
      print("[AppDelegate] No old database to migrate")
      return
    }

    do {
      // Copy database file
      try FileManager.default.copyItem(at: oldDbPath, to: newDbPath)

      // Copy WAL and SHM files if they exist
      let walPath = oldDbPath.appendingPathExtension("wal")
      let shmPath = oldDbPath.appendingPathExtension("shm")
      let newWalPath = newDbPath.appendingPathExtension("wal")
      let newShmPath = newDbPath.appendingPathExtension("shm")

      if FileManager.default.fileExists(atPath: walPath.path) {
        try? FileManager.default.copyItem(at: walPath, to: newWalPath)
      }
      if FileManager.default.fileExists(atPath: shmPath.path) {
        try? FileManager.default.copyItem(at: shmPath, to: newShmPath)
      }

      print("[AppDelegate] Database migrated to App Group successfully")
    } catch {
      print("[AppDelegate] Database migration failed: \(error)")
    }
  }

  /// 设置数据库相关的 MethodChannel
  /// 提供 App Group 路径给 Flutter 端，实现数据库共享
  private func setupDatabaseChannel() {
    guard let controller = window?.rootViewController as? FlutterViewController else {
      return
    }

    let channel = FlutterMethodChannel(
      name: "com.amberlist.database",
      binaryMessenger: controller.binaryMessenger
    )

    channel.setMethodCallHandler { [weak self] (call, result) in
      switch call.method {
      case "getAppGroupPath":
        self?.handleGetAppGroupPath(call: call, result: result)
      default:
        result(FlutterMethodNotImplemented)
      }
    }
  }

  /// 处理获取 App Group 路径的请求
  private func handleGetAppGroupPath(call: FlutterMethodCall, result: @escaping FlutterResult) {
    guard let args = call.arguments as? [String: Any],
          let groupId = args["groupId"] as? String else {
      result(FlutterError(code: "INVALID_ARGS", message: "Missing groupId", details: nil))
      return
    }

    // 获取 App Group 共享目录
    if let containerURL = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: groupId) {
      result(containerURL.path)
    } else {
      result(FlutterError(code: "NOT_FOUND", message: "App Group container not found", details: nil))
    }
  }
}
