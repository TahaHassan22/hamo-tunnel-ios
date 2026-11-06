#!/bin/bash
# setup_extension_target_ci.sh
# Automated CI version - runs in GitHub Actions macOS runner
# Adds Network Extension target and configures it for unsigned TrollStore build
# Links LibXray.xcframework and HevSocks5Tunnel.xcframework

set -e

# Resolve project path explicitly
REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
PROJECT_FILE="${REPO_ROOT}/ios/Runner.xcodeproj"
EXT_PATH="${REPO_ROOT}/ios/HamoTunnelExtension"

echo "=== Setting up HamoTunnelExtension target in CI (no DEVELOPMENT_TEAM) ==="
echo "Project file: ${PROJECT_FILE}"
echo "Extension path: ${EXT_PATH}"

# Validate paths exist
if [[ ! -d "${PROJECT_FILE}" ]]; then
    echo "ERROR: Xcode project not found at ${PROJECT_FILE}"
    echo "Contents of ios/:"
    ls -la ios/ || true
    exit 1
fi

if [[ ! -d "${EXT_PATH}" ]]; then
    echo "ERROR: Extension directory not found at ${EXT_PATH}"
    exit 1
fi

echo "Project file found: ${PROJECT_FILE}"
echo "Extension path found: ${EXT_PATH}"

# Check if xcodeproj gem is available
if ! gem list xcodeproj -i > /dev/null 2>&1; then
    echo "Installing xcodeproj gem..."
    gem install xcodeproj --no-document
fi

# Export for Ruby to use via ENV
export PROJECT_FILE
export EXT_PATH

ruby << 'RUBY_SCRIPT'
require 'xcodeproj'
require 'fileutils'

project_path = ENV.fetch('PROJECT_FILE') { raise "PROJECT_FILE env var not set" }
ext_path = ENV.fetch('EXT_PATH') { raise "EXT_PATH env var not set" }

puts "Opening project: #{project_path}"
project = Xcodeproj::Project.open(project_path)

# Check if target already exists
if project.targets.find { |t| t.name == 'HamoTunnelExtension' }
  puts "HamoTunnelExtension target already exists"
  exit 0
end

puts "Creating HamoTunnelExtension target..."

# Create the extension target
ext_target = project.new_target(:app_extension, 'HamoTunnelExtension', :ios, '15.0')

# Set build settings - NO CODE SIGNING
ext_target.build_configurations.each do |config|
  config.build_settings['PRODUCT_BUNDLE_IDENTIFIER'] = 'com.hamo.hamo_tunnel.HamoTunnelExtension'
  # xcodeproj 1.28.1 does not set PRODUCT_NAME for :app_extension targets
  # (Constants::COMMON_BUILD_SETTINGS defines it only for :framework) and the
  # Flutter project does not define it at project level either, so without
  # this PRODUCT_NAME resolves to "" and Xcode emits an empty ".appex".
  config.build_settings['PRODUCT_NAME'] = '$(TARGET_NAME)'
  config.build_settings['SKIP_INSTALL'] = 'YES'
  config.build_settings['INFOPLIST_FILE'] ||= 'HamoTunnelExtension/Info.plist'
  config.build_settings['SWIFT_VERSION'] = '5.0'
  config.build_settings['IPHONEOS_DEPLOYMENT_TARGET'] = '15.0'
  config.build_settings['CODE_SIGN_STYLE'] = 'Manual'
  config.build_settings['CODE_SIGNING_ALLOWED'] = 'NO'
  config.build_settings['CODE_SIGNING_REQUIRED'] = 'NO'
  config.build_settings['CODE_SIGN_IDENTITY'] = ''
  config.build_settings['DEVELOPMENT_TEAM'] = ''
  config.build_settings['PROVISIONING_PROFILE_SPECIFIER'] = ''
  config.build_settings['SDKROOT'] = 'iphoneos'
  config.build_settings['ENABLE_BITCODE'] = 'NO'
  config.build_settings['SWIFT_OBJC_BRIDGING_HEADER'] = 'HamoTunnelExtension/Tun2SocksBridge.h'
  config.build_settings['GCC_PREPROCESSOR_DEFINITIONS'] ||= ['$(inherited)']
  config.build_settings['GCC_PREPROCESSOR_DEFINITIONS'] << 'XRAY_STATIC_LIB'
  config.build_settings['OTHER_LDFLAGS'] ||= ['$(inherited)']
  config.build_settings['OTHER_LDFLAGS'] << '-framework NetworkExtension'
  # PROJECT_DIR is the directory containing Runner.xcodeproj, i.e. ios/
  config.build_settings['FRAMEWORK_SEARCH_PATHS'] ||= ['$(inherited)']
  config.build_settings['FRAMEWORK_SEARCH_PATHS'] << '$(PROJECT_DIR)/Frameworks'
  config.build_settings['LIBRARY_SEARCH_PATHS'] ||= ['$(inherited)']
  config.build_settings['LIBRARY_SEARCH_PATHS'] << '$(PROJECT_DIR)/Frameworks'
  config.build_settings['HEADER_SEARCH_PATHS'] ||= ['$(inherited)']
  config.build_settings['HEADER_SEARCH_PATHS'] << '$(PROJECT_DIR)/Frameworks'
end

# Create or get the extension group
ext_group = project.main_group.find_subpath('HamoTunnelExtension', true)
ext_group.set_source_tree('SOURCE_ROOT')

# Add source files
source_files = [
  'PacketTunnelProvider.swift',
]

source_files.each do |file|
  file_path = File.join(ext_path, file)
  if File.exist?(file_path)
    file_ref = ext_group.new_file(file_path)
    ext_target.add_file_references([file_ref])
    puts "Added #{file}"
  else
    puts "WARNING: #{file} not found at #{file_path}"
  end
end

# Add C headers (bridging header)
bridging_header_path = File.join(ext_path, 'Tun2SocksBridge.h')
if File.exist?(bridging_header_path)
  bridging_header = ext_group.new_file(bridging_header_path)
  ext_target.add_file_references([bridging_header])
  puts "Added bridging header"
end

# Add Info.plist
info_plist_path = File.join(ext_path, 'Info.plist')
if File.exist?(info_plist_path)
  info_plist = ext_group.new_file(info_plist_path)
  ext_target.build_configurations.each do |config|
    config.build_settings['INFOPLIST_FILE'] = 'HamoTunnelExtension/Info.plist'
  end
  puts "Added Info.plist"
end

# Add entitlements
entitlements_path = File.join(ext_path, 'HamoTunnelExtension.entitlements')
if File.exist?(entitlements_path)
  entitlements = ext_group.new_file(entitlements_path)
  ext_target.build_configurations.each do |config|
    config.build_settings['CODE_SIGN_ENTITLEMENTS'] = 'HamoTunnelExtension/HamoTunnelExtension.entitlements'
  end
  puts "Added entitlements"
end

# Link required frameworks
frameworks = [
  'NetworkExtension',
  'SystemConfiguration',
  'Foundation'
]

frameworks.each do |fw|
  # System frameworks must be referenced with the SDKROOT source tree,
  # otherwise the path resolves relative to ios/ and the link fails.
  framework_ref = project.frameworks_group.new_file("System/Library/Frameworks/#{fw}.framework", :sdk_root)
  ext_target.frameworks_build_phase.add_file_reference(framework_ref)
end

# Add LibXray.xcframework (Xray core; release asset libxray-apple-cgo.zip
# extracts to libxray-apple-cgo/LibXray.xcframework)
libxray_xcframework_path = File.join(ext_path, '..', 'Frameworks', 'LibXray.xcframework')
if File.exist?(libxray_xcframework_path)
  libxray_xcframework_ref = project.frameworks_group.new_file(libxray_xcframework_path)
  ext_target.frameworks_build_phase.add_file_reference(libxray_xcframework_ref)
  puts "Linked LibXray.xcframework"
else
  puts "WARNING: LibXray.xcframework not found"
end

# Add HevSocks5Tunnel.xcframework
hev_xcframework_path = File.join(ext_path, '..', 'Frameworks', 'HevSocks5Tunnel.xcframework')
if File.exist?(hev_xcframework_path)
  hev_xcframework_ref = project.frameworks_group.new_file(hev_xcframework_path)
  ext_target.frameworks_build_phase.add_file_reference(hev_xcframework_ref)
  puts "Linked HevSocks5Tunnel.xcframework"
else
  puts "WARNING: HevSocks5Tunnel.xcframework not found"
end

# ---------------------------------------------------------------------------
# Wire the extension into the Runner app target so it is built and embedded
# ---------------------------------------------------------------------------
runner_target = project.targets.find { |t| t.name == 'Runner' }
unless runner_target
  raise "Runner target not found in #{project_path}. " \
        "Available targets: #{project.targets.map(&:name).join(', ')}"
end

# Build HamoTunnelExtension before Runner (once only)
unless runner_target.dependencies.any? { |dep| dep.target == ext_target }
  runner_target.add_dependency(ext_target)
end

# Copy HamoTunnelExtension.appex into Runner.app/PlugIns/ (dst_subfolder_spec 13).
# Reuse an existing phase so the product reference is never embedded twice.
embed_phase = runner_target.copy_files_build_phases.find { |phase| phase.name == 'Embed App Extensions' }
unless embed_phase
  embed_phase = project.new(Xcodeproj::Project::Object::PBXCopyFilesBuildPhase)
  embed_phase.name = 'Embed App Extensions'
  embed_phase.dst_path = ''
  embed_phase.symbol_dst_subfolder_spec = :plug_ins
  runner_target.build_phases << embed_phase
end

unless embed_phase.files.any? { |build_file| build_file.file_ref == ext_target.product_reference }
  embed_build_file = embed_phase.add_file_reference(ext_target.product_reference)
  embed_build_file.settings = { 'ATTRIBUTES' => %w(CodeSignOnCopy RemoveHeadersOnCopy) }
end
puts "Embedded HamoTunnelExtension.appex in Runner (target dependency + copy phase)"

# No other target may share the extension's product reference.
shared_product = project.targets.select do |target|
  target != ext_target && target.product_reference == ext_target.product_reference
end
unless shared_product.empty?
  raise "Product reference #{ext_target.product_reference.path} is shared with: " \
        "#{shared_product.map(&:name).join(', ')}"
end

# Set the extension's principal class
ext_target.build_configurations.each do |config|
  config.build_settings['PRODUCT_MODULE_NAME'] = 'HamoTunnelExtension'
end

# Save project
project.save
puts "=== HamoTunnelExtension target created successfully (no code signing) ==="
RUBY_SCRIPT

echo "=== Extension target setup complete (no code signing) ==="