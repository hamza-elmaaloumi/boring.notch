require 'xcodeproj'
require 'find'

project_path = 'boringNotch.xcodeproj'
project = Xcodeproj::Project.open(project_path)
target = project.targets.find { |t| t.name == 'boringNotch' } || project.targets.first

exclude_dirs = ['Preview Content', 'boringNotch.xcodeproj']
exclude_patterns = ['.DS_Store']

# --- Source files (.swift) ---
swift_files = []
Find.find('boringNotch') do |path|
  Find.prune if File.directory?(path) && exclude_dirs.include?(File.basename(path))
  next unless path.end_with?('.swift')
  next if exclude_patterns.any? { |p| path.include?(p) }
  swift_files << path
end

swift_files.each do |fpath|
  name = File.basename(fpath)

  existing_refs = project.files.select { |r| r.path == name || r.path == fpath }
  existing_refs.each do |ref|
    target.source_build_phase.remove_file_reference(ref)
    ref.remove_from_project
  end
end

project.save

project = Xcodeproj::Project.open(project_path)
target = project.targets.find { |t| t.name == 'boringNotch' }

swift_files.each do |fpath|
  ref = project.main_group.new_reference(fpath)
  target.source_build_phase.add_file_reference(ref)
end

project.save

puts "Linked #{swift_files.length} Swift files to target '#{target.name}'"

# --- Resource files (.caf, .xcstrings, etc.) ---
resource_extensions = ['.caf']
resource_files = []
Find.find('boringNotch') do |path|
  Find.prune if File.directory?(path) && exclude_dirs.include?(File.basename(path))
  next unless resource_extensions.any? { |ext| path.end_with?(ext) }
  next if exclude_patterns.any? { |p| path.include?(p) }
  resource_files << path
end

resource_files.each do |fpath|
  name = File.basename(fpath)

  existing_refs = project.files.select { |r| r.path == name || r.path == fpath }
  existing_refs.each do |ref|
    target.resources_build_phase.remove_file_reference(ref)
    ref.remove_from_project
  end
end

project.save

project = Xcodeproj::Project.open(project_path)
target = project.targets.find { |t| t.name == 'boringNotch' }

resource_files.each do |fpath|
  ref = project.main_group.new_reference(fpath)
  target.resources_build_phase.add_file_reference(ref)
end

project.save

puts "Linked #{resource_files.length} resource files to target '#{target.name}'"
