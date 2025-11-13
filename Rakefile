require 'fileutils'
require 'open3'
require 'rubygems'

# Colors for output
GREEN = "\e[32m"
YELLOW = "\e[33m"
RED = "\e[31m"
RESET = "\e[0m"

# Directories
TEMPLATE_DIR = 'packer_templates'
PKRVARS_DIR = 'os_pkrvars'
BUILDS_DIR = 'builds'

# Build configuration
PROVIDERS = ENV['PROVIDERS'] || 'virtualbox-iso.vm'

# Minimum versions (overridable via env)
PACKER_MIN_VER = ENV['PACKER_MIN_VER'] || '1.7.0'
VBOX_MIN_VER = ENV['VBOX_MIN_VER'] || '7.1.6'

# Find all .pkrvars.hcl files
def pkrvars_files
  Dir.glob("#{PKRVARS_DIR}/**/*.pkrvars.hcl").sort
end

##@ General

desc 'Display help message'
task :help do
  puts "\nUsage:"
  puts "  rake #{GREEN}<task>#{RESET}\n\n"

  # Extract task descriptions
  Rake.application.tasks.each do |task|
    puts "  #{GREEN}%-15s#{RESET} %s" % [task.name, task.comment] if task.comment
  end
  puts
end

task default: :help

##@ Validation

desc 'Validate all Packer templates'
task :validate do
  puts "#{GREEN}Validating all Packer templates...#{RESET}\n\n"

  failed = []
  pkrvars_files.each do |template_path|
    template_dir = File.dirname(template_path)
    filename = File.basename(template_path)

    puts "\n#{GREEN}Validating #{template_path}#{RESET}\n\n"

    success = Dir.chdir(template_dir) do
      system("packer validate -var-file=#{filename} ../../#{TEMPLATE_DIR}")
    end

    failed << template_path unless success
  end

  if failed.empty?
    puts "\n#{GREEN}All templates validated successfully!#{RESET}"
  else
    puts "\n#{RED}Validation failed for:#{RESET}"
    failed.each { |f| puts "  - #{f}" }
    exit 1
  end
end

desc 'Validate a single template (usage: rake validate_one TEMPLATE=debian/debian-12-x86_64.pkrvars.hcl)'
task :validate_one do
  template = ENV['TEMPLATE']

  unless template
    puts "#{RED}Error: TEMPLATE variable not set#{RESET}"
    puts "Usage: rake validate_one TEMPLATE=debian/debian-12-x86_64.pkrvars.hcl"
    exit 1
  end

  template_path = File.join(PKRVARS_DIR, template)
  template_dir = File.dirname(template_path)
  filename = File.basename(template_path)

  puts "#{GREEN}Validating #{template_path}#{RESET}\n\n"

  success = Dir.chdir(template_dir) do
    system("packer validate -var-file=#{filename} ../../#{TEMPLATE_DIR}")
  end

  exit 1 unless success
end

##@ Building

desc 'Initialize Packer plugins'
task :init do
  puts "#{GREEN}Initializing Packer plugins...#{RESET}"
  Dir.chdir(TEMPLATE_DIR) do
    system('packer init .')
  end
end

desc 'Build a specific box (usage: rake build TEMPLATE=debian/debian-12-x86_64.pkrvars.hcl)'
task build: :init do
  template = ENV['TEMPLATE']

  unless template
    puts "#{RED}Error: TEMPLATE variable not set#{RESET}"
    puts "Usage: rake build TEMPLATE=debian/debian-12-x86_64.pkrvars.hcl"
    exit 1
  end

  template_path = File.join(PKRVARS_DIR, template)
  template_dir = File.dirname(template_path)
  filename = File.basename(template_path)

  puts "#{GREEN}Building box from #{template_path}#{RESET}\n\n"

  success = Dir.chdir(template_dir) do
    system("packer build -var-file=#{filename} -only=#{PROVIDERS} ../../#{TEMPLATE_DIR}")
  end

  exit 1 unless success
end

desc 'Build all boxes'
task build_all: :init do
  puts "#{GREEN}Building all boxes...#{RESET}\n\n"

  failed = []
  pkrvars_files.each do |template_path|
    template_dir = File.dirname(template_path)
    filename = File.basename(template_path)

    puts "\n#{GREEN}Building #{template_path}#{RESET}\n\n"

    success = Dir.chdir(template_dir) do
      system("packer build -var-file=#{filename} -only=#{PROVIDERS} ../../#{TEMPLATE_DIR}")
    end

    failed << template_path unless success
  end

  if failed.empty?
    puts "\n#{GREEN}All boxes built successfully!#{RESET}"
  else
    puts "\n#{RED}Build failed for:#{RESET}"
    failed.each { |f| puts "  - #{f}" }
    exit 1
  end
end

desc 'Clean and rebuild'
task force_build: [:clean, :build]

##@ Cleaning

desc 'Remove build artifacts'
task :clean do
  puts "#{YELLOW}Cleaning build artifacts...#{RESET}"
  if Dir.exist?(BUILDS_DIR)
    puts "Removing #{BUILDS_DIR}/*"
    FileUtils.rm_rf(Dir.glob("#{BUILDS_DIR}/*"))
  end
  puts "#{GREEN}Clean complete#{RESET}"
end

desc 'Remove Packer cache'
task :clean_cache do
  puts "#{YELLOW}Removing Packer cache...#{RESET}"
  FileUtils.rm_rf('packer_cache')
  puts "#{GREEN}Cache cleaned#{RESET}"
end

desc 'Remove all build artifacts and cache'
task clean_all: [:clean, :clean_cache]

##@ Inspection

desc 'List all available templates'
task :list_templates do
  puts "#{GREEN}Available templates:#{RESET}"
  pkrvars_files.each do |template|
    puts "  - #{template.sub("#{PKRVARS_DIR}/", '')}"
  end
end

desc 'List all built boxes'
task :list_builds do
  build_complete_dir = File.join(BUILDS_DIR, 'build_complete')

  if Dir.exist?(build_complete_dir)
    puts "#{GREEN}Built boxes:#{RESET}"
    boxes = Dir.glob("#{build_complete_dir}/**/*.box").map { |f| File.basename(f) }.sort
    if boxes.empty?
      puts "No boxes found"
    else
      boxes.each { |box| puts "  - #{box}" }
    end
  else
    puts "#{YELLOW}No builds found#{RESET}"
  end
end

desc 'Inspect a template (usage: rake inspect TEMPLATE=debian/debian-12-x86_64.pkrvars.hcl)'
task :inspect do
  template = ENV['TEMPLATE']

  unless template
    puts "#{RED}Error: TEMPLATE variable not set#{RESET}"
    puts "Usage: rake inspect TEMPLATE=debian/debian-12-x86_64.pkrvars.hcl"
    exit 1
  end

  template_path = File.join(PKRVARS_DIR, template)
  template_dir = File.dirname(template_path)
  filename = File.basename(template_path)

  puts "#{GREEN}Inspecting #{template_path}#{RESET}\n\n"

  Dir.chdir(template_dir) do
    system("packer inspect -var-file=#{filename} ../../#{TEMPLATE_DIR}")
  end
end

##@ Quick Builds (Debian)

desc 'Build Debian 12 x86_64 box'
task :debian_12 do
  ENV['TEMPLATE'] = 'debian/debian-12-x86_64.pkrvars.hcl'
  Rake::Task[:build].invoke
end

desc 'Build Debian 12 aarch64 box'
task :debian_12_arm do
  ENV['TEMPLATE'] = 'debian/debian-12-aarch64.pkrvars.hcl'
  Rake::Task[:build].invoke
end

desc 'Build Debian 13 x86_64 box'
task :debian_13 do
  ENV['TEMPLATE'] = 'debian/debian-13-x86_64.pkrvars.hcl'
  Rake::Task[:build].invoke
end

desc 'Build Debian 13 aarch64 box'
task :debian_13_arm do
  ENV['TEMPLATE'] = 'debian/debian-13-aarch64.pkrvars.hcl'
  Rake::Task[:build].invoke
end

##@ Development

desc 'Show debug information'
task :debug do
  puts "#{GREEN}Packer Configuration Debug Info#{RESET}"
  puts "TEMPLATE_DIR: #{TEMPLATE_DIR}"
  puts "PKRVARS_DIR:  #{PKRVARS_DIR}"
  puts "BUILDS_DIR:   #{BUILDS_DIR}"
  puts "PROVIDERS:    #{PROVIDERS}"
  puts ""

  puts "#{GREEN}Packer version:#{RESET}"
  stdout, stderr, status = Open3.capture3('packer version')
  if status.success?
    puts stdout
  else
    puts "Packer not found in PATH"
  end
  puts ""

  puts "#{GREEN}VBoxManage version:#{RESET}"
  stdout, stderr, status = Open3.capture3('VBoxManage --version')
  if status.success?
    puts stdout
  else
    puts "VBoxManage not found in PATH"
  end
end

desc 'Check environment and dependencies'
task :check_env do
  puts "#{GREEN}Checking environment...#{RESET}"

  errors = []
  warnings = []

  # Check for packer
  unless system('which packer > /dev/null 2>&1')
    errors << "packer not found"
  end

  # Check for VBoxManage
  unless system('which VBoxManage > /dev/null 2>&1')
    errors << "VBoxManage not found (required for VirtualBox builds)"
  end

  # Check for directories
  unless Dir.exist?(TEMPLATE_DIR)
    errors << "#{TEMPLATE_DIR} directory not found"
  end

  unless Dir.exist?(PKRVARS_DIR)
    errors << "#{PKRVARS_DIR} directory not found"
  end

  # Version checks (only if binaries are present)
  if errors.none? { |e| e.include?('packer not found') }
    pv_out, = Open3.capture2('packer version')
    pv = pv_out[/v?(\d+\.\d+\.\d+)/, 1]
    if pv.nil?
      errors << 'unable to parse Packer version'
    elsif Gem::Version.new(pv) < Gem::Version.new(PACKER_MIN_VER)
      errors << "Packer #{pv} < required #{PACKER_MIN_VER}"
    end
  end

  if errors.none? { |e| e.include?('VBoxManage not found') }
    vv_out, = Open3.capture2('VBoxManage --version')
    vv = vv_out[/^(\d+\.\d+\.\d+)/, 1]
    if vv.nil?
      errors << 'unable to parse VirtualBox version'
    elsif Gem::Version.new(vv) < Gem::Version.new(VBOX_MIN_VER)
      errors << "VirtualBox #{vv} < required #{VBOX_MIN_VER}"
    end
  end

  if errors.empty? && warnings.empty?
    puts "#{GREEN}Environment check passed!#{RESET}"
  else
    unless errors.empty?
      puts "#{RED}Errors:#{RESET}"
      errors.each { |e| puts "  - #{e}" }
    end

    unless warnings.empty?
      puts "#{YELLOW}Warnings:#{RESET}"
      warnings.each { |w| puts "  - #{w}" }
    end

    exit 1 unless errors.empty?
  end
end
