#!/bin/bash
# setup_extension_target.sh
# Run this script in the ios/ directory to add the Network Extension target
# Requires: xcodeproj gem (sudo gem install xcodeproj)

set -e

PROJECT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_FILE="$PROJECT_DIR/Runner.xcodeproj"

echo "Setting up HamoTunnelExtension target in $PROJECT_FILE"

cat > /tmp/add_extension_target.rb << 'RUBY_SCRIPT'
require 'xcodeproj'

project_path = ARGV[0]
ext_path = ARGV[1]

project = Xcodeproj::Project.open(project_path)

# Create the extension target
ext_target = project.new_target(:app_extension, 'HamoTunnelExtension', :ios, '15.0')
ext_target.product_bundle_identifier = 'com.hamo.hamo_tunnel.HamoTunnelExtension'

# Set build settings
ext_target.build_configurations.each do |config|
  config.build_settings['SWIFT_VERSION'] = '5.0'
  config.build_settings['IPHONEOS_DEPLOYMENT_TARGET'] = '15.0'
  config.build_settings['CODE_SIGN_STYLE'] = 'Automatic'
  config.build_settings['DEVELOPMENT_TEAM'] = ''  # Set to your team ID
  config.build_settings['PROVISIONING_PROFILE_SPECIFIER'] = ''
  config.build_settings['CODE_SIGN_IDENTITY'] = 'Apple Development'
  config.build_settings['SDKROOT'] = 'iphoneos'
  config.build_settings['ENABLE_BITCODE'] = 'NO'
  config.build_settings['SWIFT_OBJC_BRIDGING_HEADER'] = 'HamoTunnelExtension/Tun2SocksBridge.h'
  config.build_settings['GCC_PREPROCESSOR_DEFINITIONS'] ||= ['$(inherited)']
  config.build_settings['GCC_PREPROCESSOR_DEFINITIONS'] << 'XRAY_STATIC_LIB'
end

# Add source files
ext_group = project.main_group.find_subpath('HamoTunnelExtension', true)
ext_group.set_source_tree('SOURCE_ROOT')

# Add Swift files
['PacketTunnelProvider.swift'].each do |file|
  file_ref = ext_group.new_file(File.join(ext_path, file))
  ext_target.add_file_references([file_ref])
end

# Add bridging header
bridging_header = ext_group.new_file(File.join(ext_path, 'Tun2SocksBridge.h'))
ext_target.add_file_references([bridging_header])

# Add Info.plist
info_plist = ext_group.new_file(File.join(ext_path, 'Info.plist'))
ext_target.build_configurations.each do |config|
  config.build_settings['INFOPLIST_FILE'] = 'HamoTunnelExtension/Info.plist'
end

# Add entitlements
entitlements = ext_group.new_file(File.join(ext_path, 'HamoTunnelExtension.entitlements'))
ext_target.build_configurations.each do |config|
  config.build_settings['CODE_SIGN_ENTITLEMENTS'] = 'HamoTunnelExtension/HamoTunnelExtension.entitlements'
end

# Link NetworkExtension framework
ext_target.frameworks_build_phase.add_file_reference(project.frameworks_group.new_file('System/Library/Frameworks/NetworkExtension.framework'))

# Add app group capability
ext_target.add_system_framework('NetworkExtension')

# Save
project.save
puts "Extension target created successfully!"
RUBY_SCRIPT

# Check if xcodeproj gem is available
if ! gem list xcodeproj -i > /dev/null 2>&1; then
    echo "Installing xcodeproj gem..."
    sudo gem install xcodeproj
fi

ruby /tmp/add_extension_target.rb "$PROJECT_FILE" "$PROJECT_DIR/HamoTunnelExtension"

echo "Done! Now open Runner.xcworkspace in Xcode and:"
echo "1. Select HamoTunnelExtension target"
echo "2. Set Signing & Capabilities: App Groups -> com.hamo.hamo_tunnel.shared"
echo "3. Set Network Extension capability"
echo "4. Add LibXray.xcframework to Frameworks"