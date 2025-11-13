require 'fileutils'
require 'open3'
require 'rubygems'

# Colors for output
GREEN = "\e[32m"
YELLOW = "\e[33m"
RED = "\e[31m"
RESET = "\e[0m"

# Directories
TEMPLATE_DIR_BASE = 'packer_templates'
PKRVARS_DIR = 'os_pkrvars'
BUILDS_DIR = 'builds'

# Default provider and OS
PROVIDER = ENV['PROVIDER'] || 'virtualbox'
OS = ENV['OS'] || 'debian'

# Default Kubernetes version for k8s-node variant
K8S_VERSION = ENV['K8S_VERSION'] || '1.33'

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

  # Get task list from rake -T and colorize it
  require 'open3'
  stdout, stderr, status = Open3.capture3('rake -T')

  if status.success?
    stdout.each_line do |line|
      if line =~ /^rake\s+(\S+)\s+#\s+(.+)/
        task_name = $1
        description = $2
        puts "  #{GREEN}%-20s#{RESET} %s" % [task_name, description]
      end
    end
  else
    # Fallback to simple list
    puts "Available tasks:"
    puts "  Run 'rake -T' to see all available tasks"
  end

  puts
end

task default: :help

##@ Validation

desc 'Validate all Packer templates for current provider/OS'
task :validate do
  puts "#{GREEN}Validating #{PROVIDER}/#{OS} templates...#{RESET}\n\n"

  template_dir = "#{TEMPLATE_DIR_BASE}/#{PROVIDER}/#{OS}"
  failed = []

  pkrvars_files.each do |var_file|
    puts "\n#{GREEN}Validating with #{var_file}#{RESET}\n\n"

    success = system("packer validate -var-file=#{var_file} #{template_dir}")

    failed << var_file unless success
  end

  if failed.empty?
    puts "\n#{GREEN}All templates validated successfully!#{RESET}"
  else
    puts "\n#{RED}Validation failed for:#{RESET}"
    failed.each { |f| puts "  - #{f}" }
    exit 1
  end
end

desc 'Validate a single template (usage: rake validate_one TEMPLATE=debian/12-x86_64.pkrvars.hcl)'
task :validate_one do
  template = ENV['TEMPLATE']

  unless template
    puts "#{RED}Error: TEMPLATE variable not set#{RESET}"
    puts "Usage: rake validate_one TEMPLATE=debian/12-x86_64.pkrvars.hcl [PROVIDER=virtualbox] [OS=debian]"
    exit 1
  end

  template_dir = "#{TEMPLATE_DIR_BASE}/#{PROVIDER}/#{OS}"
  var_file = File.join(PKRVARS_DIR, template)

  puts "#{GREEN}Validating #{PROVIDER}/#{OS} with #{var_file}#{RESET}\n\n"

  success = system("packer validate -var-file=#{var_file} #{template_dir}")

  exit 1 unless success
end

##@ Building

desc 'Initialize Packer plugins for default provider/OS'
task :init do
  puts "#{GREEN}Initializing Packer plugins for #{PROVIDER}/#{OS}...#{RESET}"
  template_dir = "#{TEMPLATE_DIR_BASE}/#{PROVIDER}/#{OS}"
  Dir.chdir(template_dir) do
    system('packer init .')
  end
end

desc 'Build a specific box (usage: rake build TEMPLATE=debian/12-x86_64.pkrvars.hcl [VARIANT=k8s-node])'
task build: :init do
  template = ENV['TEMPLATE']
  variant = ENV['VARIANT']

  unless template
    puts "#{RED}Error: TEMPLATE variable not set#{RESET}"
    puts "Usage: rake build TEMPLATE=debian/12-x86_64.pkrvars.hcl [PROVIDER=virtualbox] [OS=debian] [VARIANT=k8s-node]"
    exit 1
  end

  template_dir = "#{TEMPLATE_DIR_BASE}/#{PROVIDER}/#{OS}"
  var_file = File.join(PKRVARS_DIR, template)

  extra_vars = ""
  if variant && !variant.empty?
    extra_vars = "-var='variant=#{variant}'"
    if variant == "k8s-node"
      extra_vars += " -var='kubernetes_version=#{K8S_VERSION}' -var='cpus=2' -var='memory=4096' -var='disk_size=61440'"
    end
  end

  puts "#{GREEN}Building #{PROVIDER}/#{OS} from #{var_file}#{RESET}"
  puts "#{YELLOW}Variant: #{variant}#{RESET}" if variant && !variant.empty?

  success = system("packer build -var-file=#{var_file} #{extra_vars} #{template_dir}")

  exit 1 unless success
end

desc 'Build all boxes for current provider/OS'
task build_all: :init do
  puts "#{GREEN}Building all boxes for #{PROVIDER}/#{OS}...#{RESET}\n\n"

  template_dir = "#{TEMPLATE_DIR_BASE}/#{PROVIDER}/#{OS}"
  failed = []

  pkrvars_files.each do |var_file|
    puts "\n#{GREEN}Building #{var_file}#{RESET}\n\n"

    success = system("packer build -var-file=#{var_file} #{template_dir}")

    failed << var_file unless success
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

desc 'Inspect a template (usage: rake inspect TEMPLATE=debian/12-x86_64.pkrvars.hcl)'
task :inspect do
  template = ENV['TEMPLATE']

  unless template
    puts "#{RED}Error: TEMPLATE variable not set#{RESET}"
    puts "Usage: rake inspect TEMPLATE=debian/12-x86_64.pkrvars.hcl [PROVIDER=virtualbox] [OS=debian]"
    exit 1
  end

  template_dir = "#{TEMPLATE_DIR_BASE}/#{PROVIDER}/#{OS}"
  var_file = File.join(PKRVARS_DIR, template)

  puts "#{GREEN}Inspecting #{PROVIDER}/#{OS} with #{var_file}#{RESET}\n\n"

  system("packer inspect -var-file=#{var_file} #{template_dir}")
end

##@ Quick Builds (Debian)

desc 'Build Debian 12 x86_64 base box'
task :debian_12 do
  ENV['TEMPLATE'] = 'debian/12-x86_64.pkrvars.hcl'
  Rake::Task[:build].invoke
end

desc 'Build Debian 12 aarch64 base box'
task :debian_12_arm do
  ENV['TEMPLATE'] = 'debian/12-aarch64.pkrvars.hcl'
  Rake::Task[:build].invoke
end

desc 'Build Debian 12 x86_64 Kubernetes node box'
task :debian_12_k8s do
  ENV['TEMPLATE'] = 'debian/12-x86_64.pkrvars.hcl'
  ENV['VARIANT'] = 'k8s-node'
  Rake::Task[:build].invoke
end

desc 'Build Debian 12 aarch64 Kubernetes node box'
task :debian_12_arm_k8s do
  ENV['TEMPLATE'] = 'debian/12-aarch64.pkrvars.hcl'
  ENV['VARIANT'] = 'k8s-node'
  Rake::Task[:build].invoke
end

desc 'Build Debian 12 x86_64 Docker host box'
task :debian_12_docker do
  ENV['TEMPLATE'] = 'debian/12-x86_64.pkrvars.hcl'
  ENV['VARIANT'] = 'docker-host'
  Rake::Task[:build].invoke
end

desc 'Build Debian 12 aarch64 Docker host box'
task :debian_12_arm_docker do
  ENV['TEMPLATE'] = 'debian/12-aarch64.pkrvars.hcl'
  ENV['VARIANT'] = 'docker-host'
  Rake::Task[:build].invoke
end

desc 'Build Debian 13 x86_64 base box'
task :debian_13 do
  ENV['TEMPLATE'] = 'debian/13-x86_64.pkrvars.hcl'
  Rake::Task[:build].invoke
end

desc 'Build Debian 13 aarch64 base box'
task :debian_13_arm do
  ENV['TEMPLATE'] = 'debian/13-aarch64.pkrvars.hcl'
  Rake::Task[:build].invoke
end

##@ Development

desc 'Show debug information'
task :debug do
  puts "#{GREEN}Packer Configuration Debug Info#{RESET}"
  puts "TEMPLATE_DIR_BASE: #{TEMPLATE_DIR_BASE}"
  puts "PROVIDER:          #{PROVIDER}"
  puts "OS:                #{OS}"
  puts "Template Dir:      #{TEMPLATE_DIR_BASE}/#{PROVIDER}/#{OS}"
  puts "PKRVARS_DIR:       #{PKRVARS_DIR}"
  puts "BUILDS_DIR:        #{BUILDS_DIR}"
  puts "K8S_VERSION:       #{K8S_VERSION}"
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
  unless Dir.exist?(TEMPLATE_DIR_BASE)
    errors << "#{TEMPLATE_DIR_BASE} directory not found"
  end

  unless Dir.exist?(PKRVARS_DIR)
    errors << "#{PKRVARS_DIR} directory not found"
  end

  template_dir = "#{TEMPLATE_DIR_BASE}/#{PROVIDER}/#{OS}"
  unless Dir.exist?(template_dir)
    errors << "#{template_dir} directory not found"
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
