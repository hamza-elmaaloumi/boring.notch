require 'xcodeproj'
require 'pathname'

project_path = 'boringNotch.xcodeproj'
project = Xcodeproj::Project.open(project_path)
target = project.targets.find { |t| t.name == 'boringNotch' } || project.targets.first

# The exact absolute or relative paths:
files = [
  'boringNotch/models/ClipboardModels.swift',
  'boringNotch/managers/ClipboardManager.swift',
  'boringNotch/components/Settings/SnippetsSettingsView.swift',
  'boringNotch/components/Clipboard/ClipboardRootView.swift',
  'boringNotch/components/Clipboard/ClipboardHistoryView.swift',
  'boringNotch/components/Clipboard/SnippetCollectionView.swift'
]

# Clean up old poorly linked file references
files.each do |f|
  name = File.basename(f)
  refs = project.files.select { |r| r.path == name || r.name == name }
  refs.each do |r|
     puts "Removing old ref: #{r.path || r.name}"
     target.source_build_phase.remove_file_reference(r)
     r.remove_from_project
  end
end

project.save

# Group creation logic that properly links the filesystem folder
def get_or_create_group(project, path_str)
  group = project.main_group
  components = path_str.split('/')
  components.each do |folder|
    child = group.children.find { |c| c.display_name == folder || c.path == folder }
    if child.nil?
      child = group.new_group(folder, folder) # Ensure path is set!
      puts "Created new group: #{folder}"
    end
    group = child
  end
  group
end

files.each do |file_path|
  dir = File.dirname(file_path)
  filename = File.basename(file_path)
  
  group = get_or_create_group(project, dir)
  
  existing = group.children.find { |c| c.display_name == filename || c.path == filename }
  if existing
    file_ref = existing
  else
    file_ref = group.new_file(filename)
    puts "Created perfect ref: #{file_path}"
  end
  
  unless target.source_build_phase.files_references.include?(file_ref)
    target.source_build_phase.add_file_reference(file_ref)
    puts "Added to Target Build Phase: #{file_path}"
  end
end

project.save
puts "Project Map Fixed."
