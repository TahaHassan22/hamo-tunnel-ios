#!/bin/bash
# setup_extension_target_ci.sh
# Automated CI version - runs in GitHub Actions macOS runner
# Adds Network Extension target and configures it for unsigned TrollStore build
# Links libxray-apple-cgo.xcframework and HevSocks5Tunnel.xcframework

set -e

PROJECT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_FILE="$PROJECT_DIR/Runner.xcodeproj"

echo "=== Setting up HamoTunnelExtension target in CI (no DEVELOPMENT_TEAM) ==="

# Check if xcodeproj gem is available
if ! gem list xcodeproj -i > /dev/null 2>&1; then
    echo "Installing xcodeproj gem..."
    gem install xcodeproj --no-document
fi

ruby << 'RUBY_SCRIPT'
require 'xcodeproj'
require 'fileutils'

project_path = ARGV[0]
ext_path = ARGV[1]

project = Xcodeproj::Project.open(project_path)

# Check if target already exists
if project.targets.find { |t| t.name == 'HamoTunnelExtension' }
  puts "HamoTunnelExtension target already exists"
  exit 0
end

puts "Creating HamoTunnelExtension target..."

# Create the extension target
ext_target = project.new_target(:app_extension, 'HamoTunnelExtension', :ios, '15.0')
ext_target.product_bundle_identifier = 'com.hamo.hamo_tunnel.HamoTunnelExtension'

# Set build settings - NO CODE SIGNING
ext_target.build_configurations.each do |config|
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
  config.build_settings['FRAMEWORK_SEARCH_PATHS'] ||= ['$(inherited)']
  config.build_settings['FRAMEWORK_SEARCH_PATHS'] << '$(PROJECT_DIR)/../Frameworks'
  config.build_settings['LIBRARY_SEARCH_PATHS'] ||= ['$(inherited)']
  config.build_settings['LIBRARY_SEARCH_PATHS'] << '$(PROJECT_DIR)/../Frameworks'
  config.build_settings['HEADER_SEARCH_PATHS'] ||= ['$(inherited)']
  config.build_settings['HEADER_SEARCH_PATHS'] << '$(PROJECT_DIR)/../Frameworks'
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
  framework_ref = project.frameworks_group.new_file("System/Library/Frameworks/#{fw}.framework")
  ext_target.frameworks_build_phase.add_file_reference(framework_ref)
end

# Add libxray-apple-cgo.xcframework
xcframework_path = File.join(ext_path, '..', 'Frameworks', 'libxray-apple-cgo.xcframework')
if File.exist?(xcframework_path)
  xcframework_ref = project.frameworks_group.new_file(xcframework_path)
  ext_target.frameworks_build_phase.add_file_reference(xcframework_ref)
  puts "Linked libxray-apple-cgo.xcframework"
else
  puts "WARNING: libxray-apple-cgo.xcframework not found"
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

# Set the extension's principal class
ext_target.build_configurations.each do |config|
  config.build_settings['PRODUCT_MODULE_NAME'] = 'HamoTunnelExtension'
end

# Save project
project.save
puts "=== HamoTunnelExtension target created successfully (no code signing) ==="
RUBY_SCRIPT

ruby -e "$(cat << 'EOF'
require 'xcodeproj'
require 'fileutils'

project_path = ARGV[0]
ext_path = ARGV[1]

project = Xcodeproj::Project.open(project_path)

# Check if target already exists
if project.targets.find { |t| t.name == 'HamoTunnelExtension' }
  puts "HamoTunnelExtension target already exists"
  exit 0
end

puts "Creating HamoTunnelExtension target..."

# Create the extension target
ext_target = project.new_target(:app_extension, 'HamoTunnelExtension', :ios, '15.0')
ext_target.product_bundle_identifier = 'com.hamo.hamo_tunnel.HamoTunnelExtension'

# Set build settings - NO CODE SIGNING
ext_target.build_configurations.each do |config|
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
  config.build_settings['FRAMEWORK_SEARCH_PATHS'] ||= ['$(inherited)']
  config.build_settings['FRAMEWORK_SEARCH_PATHS'] << '$(PROJECT_DIR)/../Frameworks'
  config.build_settings['LIBRARY_SEARCH_PATHS'] ||= ['$(inherited)']
  config.build_settings['LIBRARY_SEARCH_PATHS'] << '$(PROJECT_DIR)/../Frameworks'
  config.build_settings['HEADER_SEARCH_PATHS'] ||= ['$(inherited)']
  config.build_settings['HEADER_SEARCH_PATHS'] << '$(PROJECT_DIR)/../Frameworks'
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
  framework_ref = project.frameworks_group.new_file("System/Library/Frameworks/#{fw}.framework")
  ext_target.frameworks_build_phase.add_file_reference(framework_ref)
end

# Add libxray-apple-cgo.xcframework
xcframework_path = File.join(ext_path, '..', 'Frameworks', 'libxray-apple-cgo.xcframework')
if File.exist?(xcframework_path)
  xcframework_ref = project.frameworks_group.new_file(xcframework_path)
  ext_target.frameworks_build_phase.add_file_reference(xcframework_ref)
  puts "Linked libxray-apple-cgo.xcframework"
else
  puts "WARNING: libxray-apple-cgo.xcframework not found"
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

# Set the extension's principal class
ext_target.build_configurations.each do |config|
  config.build_settings['PRODUCT_MODULE_NAME'] = 'HamoTunnelExtension'
end

# Save project
project.save
puts "=== HamoTunnelExtension target created successfully (no code signing) ==="
EOF
) "$PROJECT_FILE" "$PROJECT_DIR/HamoTunnelExtension"

echo "=== Extension target setup complete (no code signing) ==="