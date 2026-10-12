#!/usr/bin/env ruby
# frozen_string_literal: true

# 喺 Xcode project 加 iOS 桌面 widget extension（Phase 3）。
#
# 點解係腳本而唔係直接改咗 project.pbxproj：寫呢個腳本嗰部機冇完整 Xcode，改完冇辦法
# build 驗證。所以 repo 入面嘅 ios/Runner.xcodeproj 保持原狀，等你喺有 Xcode 嘅機行一次：
#
#   gem install xcodeproj --user-install     # 如果未有
#   ruby scripts/add_ios_widget_target.rb
#   open ios/Runner.xcworkspace              # 用 Xcode 開，揀 Signing Team，build
#
# 腳本做嘅嘢（可重複行，已經加過會直接停）：
#  1. 新增 target `XuanLiWidgetExtension`（WidgetKit app extension，iOS 14+）
#  2. 加入 ios/XuanLiWidget/ 入面嘅 Swift／Info.plist／entitlements
#  3. Runner 同 extension 都掛 App Group `group.com.xuanli.xuanli`（entitlements）
#  4. 將 extension 嵌入 Runner（Embed Foundation Extensions，擺喺 Flutter 嘅 script phase 之前，
#     避免 Xcode 嘅 "Cycle inside Runner" 錯誤）
#
# 想試行唔動真 project：XCODEPROJ_PATH=/tmp/copy/Runner.xcodeproj ruby scripts/add_ios_widget_target.rb

require 'xcodeproj'

EXTENSION_NAME = 'XuanLiWidgetExtension'
WIDGET_DIR = 'XuanLiWidget'
APP_GROUP = 'group.com.xuanli.xuanli' # 要同 Dart WidgetDataBridge.appGroupId 一致

project_path = ENV['XCODEPROJ_PATH'] || File.expand_path('../ios/Runner.xcodeproj', __dir__)
abort "搵唔到 #{project_path}" unless File.directory?(project_path)

project = Xcodeproj::Project.open(project_path)
runner = project.targets.find { |t| t.name == 'Runner' }
abort '搵唔到 Runner target' unless runner

if project.targets.any? { |t| t.name == EXTENSION_NAME }
  puts "#{EXTENSION_NAME} 已經存在，唔使再加。"
  exit 0
end

runner_bundle_id = runner.build_configurations.first.build_settings['PRODUCT_BUNDLE_IDENTIFIER']
abort '搵唔到 Runner 嘅 bundle id' if runner_bundle_id.nil? || runner_bundle_id.empty?
extension_bundle_id = "#{runner_bundle_id}.XuanLiWidget"

# --- 1. target ---
extension = project.new_target(:app_extension, EXTENSION_NAME, :ios, '14.0')

# --- 2. 檔案 ---
group = project.main_group.new_group(WIDGET_DIR, WIDGET_DIR)
swift_files = %w[XuanLiWidget.swift XuanLiWidgetLogic.swift].map { |f| group.new_file(f) }
extension.add_file_references(swift_files)
group.new_file('Info.plist')
group.new_file('XuanLiWidget.entitlements')

extension.add_system_framework('WidgetKit')
extension.add_system_framework('SwiftUI')

# --- 3. build settings ---
runner_settings = runner.build_configurations.to_h { |c| [c.name, c.build_settings] }
extension.build_configurations.each do |config|
  s = config.build_settings
  s['PRODUCT_BUNDLE_IDENTIFIER'] = extension_bundle_id
  s['PRODUCT_NAME'] = '$(TARGET_NAME)'
  s['INFOPLIST_FILE'] = "#{WIDGET_DIR}/Info.plist"
  s['GENERATE_INFOPLIST_FILE'] = 'NO'
  s['CODE_SIGN_ENTITLEMENTS'] = "#{WIDGET_DIR}/XuanLiWidget.entitlements"
  s['CODE_SIGN_STYLE'] = 'Automatic'
  s['SWIFT_VERSION'] = '5.0'
  s['TARGETED_DEVICE_FAMILY'] = '1,2'
  s['IPHONEOS_DEPLOYMENT_TARGET'] = '14.0'
  s['SKIP_INSTALL'] = 'YES'
  s['MARKETING_VERSION'] = '1.0.0'
  s['CURRENT_PROJECT_VERSION'] = '1'
  s['LD_RUNPATH_SEARCH_PATHS'] = ['$(inherited)', '@executable_path/Frameworks', '@executable_path/../../Frameworks']
  team = runner_settings[config.name]&.fetch('DEVELOPMENT_TEAM', nil)
  s['DEVELOPMENT_TEAM'] = team if team && !team.empty?
end

# Runner 都要掛 App Group。
runner_group = project.main_group.find_subpath('Runner', false)
runner_group&.new_file('Runner.entitlements')
runner.build_configurations.each do |config|
  config.build_settings['CODE_SIGN_ENTITLEMENTS'] = 'Runner/Runner.entitlements'
end

# --- 4. 嵌入 extension ---
embed = runner.new_copy_files_build_phase('Embed Foundation Extensions')
embed.symbol_dst_subfolder_spec = :plug_ins
build_file = embed.add_file_reference(extension.product_reference, true)
build_file.settings = { 'ATTRIBUTES' => ['RemoveHeadersOnCopy'] }
runner.add_dependency(extension)

# 將 embed phase 擺喺 Flutter 嘅 "Thin Binary" script phase 之前（Flutter + widget 嘅慣常位置；
# 擺喺佢之後會令 Xcode 報 "Cycle inside Runner"）。搵唔到就退而求其次擺喺第一個 script 前。
script_phase = Xcodeproj::Project::Object::PBXShellScriptBuildPhase
runner.build_phases.delete(embed)
anchor = runner.build_phases.index { |ph| ph.is_a?(script_phase) && ph.name == 'Thin Binary' } ||
         runner.build_phases.index { |ph| ph.is_a?(script_phase) } ||
         runner.build_phases.length
runner.build_phases.insert(anchor, embed)

project.save
puts "已加入 #{EXTENSION_NAME}（bundle id #{extension_bundle_id}），App Group #{APP_GROUP}。"
puts '下一步：用 Xcode 開 ios/Runner.xcworkspace，喺兩個 target（Runner／XuanLiWidgetExtension）揀 Signing Team，再 build。'
