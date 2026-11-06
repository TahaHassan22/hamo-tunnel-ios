import Flutter
import UIKit
import NetworkExtension

@main
@objc class AppDelegate: FlutterAppDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    // Register VPN Manager for MethodChannel. FlutterAppDelegate is a
    // FlutterPluginRegistry, not a FlutterPluginRegistrar, so ask it for one.
    if let registrar = registrar(forPlugin: "VpnManager") {
      VpnManager.shared.register(with: registrar)
    }
    
    GeneratedPluginRegistrant.register(with: self)
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
}