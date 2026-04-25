require 'xcodeproj'

project_path = 'boringNotch.xcodeproj'
project = Xcodeproj::Project.open(project_path)
target = project.targets.find { |t| t.name == 'boringNotch' } || project.targets.first

files = [
  'boringNotch/components/Productivity/ProductivityRootView.swift',
  'boringNotch/components/Productivity/PomodoroTimerView.swift',
  'boringNotch/components/Productivity/WaterTrackerView.swift',
  'boringNotch/components/Settings/ProductivitySettingsView.swift'
]

files.each do |fpath|
  name = File.basename(fpath)
  project.files.select { |r| r.path == name || r.name == name }.each { |r| target.source_build_phase.remove_file_reference(r); r.remove_from_project }
end

project.save

project = Xcodeproj::Project.open(project_path)
target = project.targets.find { |t| t.name == 'boringNotch' }

files.each do |fpath|
  ref = project.main_group.new_reference(fpath)
  target.source_build_phase.add_file_reference(ref)
end

project.save
puts "Added Productivity views to PBXPROJ using real_path"
