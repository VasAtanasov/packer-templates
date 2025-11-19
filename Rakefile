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

# Minimum versions (overridable via env)
PACKER_MIN_VER = ENV['PACKER_MIN_VER'] || '1.7.0'
VBOX_MIN_VER = ENV['VBOX_MIN_VER'] || '7.1.6'

# Dynamic accessors for environment-driven values
def provider
  ENV['PROVIDER'] || 'virtualbox'
end

def target_os
  ENV['TARGET_OS'] || 'debian'
end

def k8s_version
  ENV['K8S_VERSION'] || '1.33'
end

# Find all .pkrvars.hcl files for current target_os
def pkrvars_files
  Dir.glob("#{PKRVARS_DIR}/#{target_os}/**/*.pkrvars.hcl").sort
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

desc 'Validate all Packer templates for current TARGET_OS'
task :validate do
  puts "#{GREEN}Validating #{target_os} templates...#{RESET}\n\n"

  template_dir = TEMPLATE_DIR_BASE
  failed = []

  pkrvars_files.each do |var_file|
    puts "\n#{GREEN}Validating with #{var_file}#{RESET}\n\n"

    success = system("packer validate -syntax-only -var-file=#{var_file} #{template_dir}")

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

desc 'Validate templates for all OSes under os_pkrvars'
task :validate_all do
  os_dirs = Dir.glob(File.join(PKRVARS_DIR, '*')).select { |d| File.directory?(d) }
  os_list = os_dirs.map { |d| File.basename(d) }.sort

  failed = []

  os_list.each do |os|
    puts "\n#{GREEN}=== Validating #{os} ===#{RESET}\n\n"
    success = system({ 'TARGET_OS' => os }, 'rake validate')
    failed << os unless success
  end

  if failed.empty?
    puts "\n#{GREEN}All OS templates validated successfully!#{RESET}"
  else
    puts "\n#{RED}Validation failed for OS:#{RESET}"
    failed.each { |os| puts "  - #{os}" }
    exit 1
  end
end

desc 'Validate a single template (usage: rake validate_one TEMPLATE=debian/12-x86_64.pkrvars.hcl)'
task :validate_one do
  template = ENV['TEMPLATE']

  unless template
    puts "#{RED}Error: TEMPLATE variable not set#{RESET}"
    puts "Usage: rake validate_one TEMPLATE=debian/12-x86_64.pkrvars.hcl"
    exit 1
  end

  template_dir = TEMPLATE_DIR_BASE
  var_file = File.join(PKRVARS_DIR, template)

  puts "#{GREEN}Validating with #{var_file}#{RESET}\n\n"

  success = system("packer validate -syntax-only -var-file=#{var_file} #{template_dir}")

  exit 1 unless success
end

##@ Building

desc 'Initialize Packer plugins'
task :init do
  puts "#{GREEN}Initializing Packer plugins...#{RESET}"
  template_dir = TEMPLATE_DIR_BASE
  Dir.chdir(template_dir) do
    system('packer init .')
  end
end

desc 'Build a specific box (usage: rake build TEMPLATE=debian/12-x86_64.pkrvars.hcl [VARIANT=k8s-node])'
task build: :init do
  template = ENV['TEMPLATE']
  variant = ENV['VARIANT']
  primary_source = ENV['PRIMARY_SOURCE']
  ovf_source_path = ENV['OVF_SOURCE_PATH']
  ovf_checksum = ENV['OVF_CHECKSUM']

  unless template
    puts "#{RED}Error: TEMPLATE variable not set#{RESET}"
    puts "Usage: rake build TEMPLATE=debian/12-x86_64.pkrvars.hcl [VARIANT=k8s-node]"
    exit 1
  end

  template_dir = TEMPLATE_DIR_BASE
  var_file = File.join(PKRVARS_DIR, template)

  extra_vars = ""
  if variant && !variant.empty?
    extra_vars = "-var=variant=#{variant}"
    if variant == "k8s-node"
      extra_vars += " -var=kubernetes_version=#{k8s_version} -var=cpus=2 -var=memory=4096 -var=disk_size=61440"
    end
  end
  if primary_source && !primary_source.empty?
    extra_vars += " -var=primary_source=#{primary_source}"
  end
  if ovf_source_path && !ovf_source_path.empty?
    extra_vars += " -var=ovf_source_path=#{ovf_source_path}"
  end
  if ovf_checksum && !ovf_checksum.empty?
    extra_vars += " -var=ovf_checksum=#{ovf_checksum}"
  end

  puts "#{GREEN}Building from #{var_file}#{RESET}"
  puts "#{YELLOW}Variant: #{variant}#{RESET}" if variant && !variant.empty?

  success = system("packer build -var-file=#{var_file} #{extra_vars} #{template_dir}")

  exit 1 unless success
end

desc 'Build all boxes for current TARGET_OS'
task build_all: :init do
  puts "#{GREEN}Building all boxes for #{target_os}...#{RESET}\n\n"

  template_dir = TEMPLATE_DIR_BASE
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
    puts "Usage: rake inspect TEMPLATE=debian/12-x86_64.pkrvars.hcl"
    exit 1
  end

  template_dir = TEMPLATE_DIR_BASE
  var_file = File.join(PKRVARS_DIR, template)

  puts "#{GREEN}Inspecting with #{var_file}#{RESET}\n\n"

  system("packer inspect -var-file=#{var_file} #{template_dir}")
end

##@ Quick Builds (Debian)

desc 'Build Debian 12 x86_64 base box'
task :debian_12 do
  ENV['TEMPLATE'] = 'debian/12-x86_64.pkrvars.hcl'
  ENV['PROVIDER'] = 'virtualbox'
  ENV['TARGET_OS'] = 'debian'
  Rake::Task[:build].invoke
end

desc 'Build Debian 12 aarch64 base box'
task :debian_12_arm do
  ENV['TEMPLATE'] = 'debian/12-aarch64.pkrvars.hcl'
  ENV['PROVIDER'] = 'virtualbox'
  ENV['TARGET_OS'] = 'debian'
  Rake::Task[:build].invoke
end

desc 'Build Debian 12 x86_64 Kubernetes node box'
task :debian_12_k8s do
  ENV['TEMPLATE'] = 'debian/12-x86_64.pkrvars.hcl'
  ENV['VARIANT'] = 'k8s-node'
  ENV['PROVIDER'] = 'virtualbox'
  ENV['TARGET_OS'] = 'debian'
  Rake::Task[:build].invoke
end

desc 'Build Debian 12 x86_64 Kubernetes node box from existing OVF'
task :debian_12_k8s_ovf do
  var_file = File.join(PKRVARS_DIR, 'debian/12-x86_64.pkrvars.hcl')
  unless File.exist?(var_file)
    puts "#{RED}Var file not found: #{var_file}#{RESET}"
    exit 1
  end

  os_version_line = File.readlines(var_file).find { |l| l =~ /^\s*os_version\s*=\s*"/ }
  os_version = os_version_line && os_version_line[/^\s*os_version\s*=\s*"(.*?)"/, 1]
  os_version ||= '12'

  ovf_dir = "ovf/packer-debian-#{os_version}-x86_64-virtualbox"
  ovf_path = "#{ovf_dir}/debian-#{os_version}-x86_64.ovf"

  ENV['TEMPLATE'] = 'debian/12-x86_64.pkrvars.hcl'
  ENV['VARIANT'] = 'k8s-node'
  ENV['PRIMARY_SOURCE'] = 'virtualbox-ovf'
  ENV['PROVIDER'] = 'virtualbox'
  ENV['TARGET_OS'] = 'debian'
  ENV['OVF_SOURCE_PATH'] = ovf_path
  ENV['OVF_CHECKSUM'] = 'none'

  Rake::Task[:build].invoke
end

desc 'Build Debian 12 aarch64 Kubernetes node box'
task :debian_12_arm_k8s do
  ENV['TEMPLATE'] = 'debian/12-aarch64.pkrvars.hcl'
  ENV['VARIANT'] = 'k8s-node'
  ENV['PROVIDER'] = 'virtualbox'
  ENV['TARGET_OS'] = 'debian'
  Rake::Task[:build].invoke
end

desc 'Build Debian 12 x86_64 Docker host box'
task :debian_12_docker do
  ENV['TEMPLATE'] = 'debian/12-x86_64.pkrvars.hcl'
  ENV['VARIANT'] = 'docker-host'
  ENV['PROVIDER'] = 'virtualbox'
  ENV['TARGET_OS'] = 'debian'
  Rake::Task[:build].invoke
end

desc 'Build Debian 12 aarch64 Docker host box'
task :debian_12_arm_docker do
  ENV['TEMPLATE'] = 'debian/12-aarch64.pkrvars.hcl'
  ENV['VARIANT'] = 'docker-host'
  ENV['PROVIDER'] = 'virtualbox'
  ENV['TARGET_OS'] = 'debian'
  Rake::Task[:build].invoke
end

desc 'Build Debian 13 x86_64 base box'
task :debian_13 do
  ENV['TEMPLATE'] = 'debian/13-x86_64.pkrvars.hcl'
  ENV['PROVIDER'] = 'virtualbox'
  ENV['TARGET_OS'] = 'debian'
  Rake::Task[:build].invoke
end

desc 'Build Debian 13 aarch64 base box'
task :debian_13_arm do
  ENV['TEMPLATE'] = 'debian/13-aarch64.pkrvars.hcl'
  ENV['PROVIDER'] = 'virtualbox'
  ENV['TARGET_OS'] = 'debian'
  Rake::Task[:build].invoke
end

##@ Quick Builds (AlmaLinux)

desc 'Build AlmaLinux 8 x86_64 base box'
task :almalinux_8 do
  ENV['TEMPLATE'] = 'almalinux/8-x86_64.pkrvars.hcl'
  ENV['PROVIDER'] = 'virtualbox'
  ENV['TARGET_OS'] = 'almalinux'
  Rake::Task[:build].invoke
end

desc 'Build AlmaLinux 8 aarch64 base box'
task :almalinux_8_arm do
  ENV['TEMPLATE'] = 'almalinux/8-aarch64.pkrvars.hcl'
  ENV['PROVIDER'] = 'virtualbox'
  ENV['TARGET_OS'] = 'almalinux'
  Rake::Task[:build].invoke
end

desc 'Build AlmaLinux 9 x86_64 base box'
task :almalinux_9 do
  ENV['TEMPLATE'] = 'almalinux/9-x86_64.pkrvars.hcl'
  ENV['PROVIDER'] = 'virtualbox'
  ENV['TARGET_OS'] = 'almalinux'
  Rake::Task[:build].invoke
end

desc 'Build AlmaLinux 9 aarch64 base box'
task :almalinux_9_arm do
  ENV['TEMPLATE'] = 'almalinux/9-aarch64.pkrvars.hcl'
  ENV['PROVIDER'] = 'virtualbox'
  ENV['TARGET_OS'] = 'almalinux'
  Rake::Task[:build].invoke
end

desc 'Build AlmaLinux 9 x86_64 Kubernetes node box from existing OVF'
task :almalinux_9_k8s_ovf do
  var_file = File.join(PKRVARS_DIR, 'almalinux/9-x86_64.pkrvars.hcl')
  unless File.exist?(var_file)
    puts "#{RED}Var file not found: #{var_file}#{RESET}"
    exit 1
  end

  os_version_line = File.readlines(var_file).find { |l| l =~ /^\s*os_version\s*=\s*"/ }
  os_version = os_version_line && os_version_line[/^\s*os_version\s*=\s*"(.*?)"/, 1]
  os_version ||= '9'

  ovf_dir = "ovf/packer-almalinux-#{os_version}-x86_64-virtualbox"
  ovf_path = "#{ovf_dir}/almalinux-#{os_version}-x86_64.ovf"

  ENV['TEMPLATE'] = 'almalinux/9-x86_64.pkrvars.hcl'
  ENV['VARIANT'] = 'k8s-node'
  ENV['PRIMARY_SOURCE'] = 'virtualbox-ovf'
  ENV['PROVIDER'] = 'virtualbox'
  ENV['TARGET_OS'] = 'almalinux'
  ENV['OVF_SOURCE_PATH'] = ovf_path
  ENV['OVF_CHECKSUM'] = 'none'

  Rake::Task[:build].invoke
end

desc 'Build AlmaLinux 10 x86_64 base box'
task :almalinux_10 do
  ENV['TEMPLATE'] = 'almalinux/10-x86_64.pkrvars.hcl'
  ENV['PROVIDER'] = 'virtualbox'
  ENV['TARGET_OS'] = 'almalinux'
  Rake::Task[:build].invoke
end

desc 'Build AlmaLinux 10 aarch64 base box'
task :almalinux_10_arm do
  ENV['TEMPLATE'] = 'almalinux/10-aarch64.pkrvars.hcl'
  ENV['PROVIDER'] = 'virtualbox'
  ENV['TARGET_OS'] = 'almalinux'
  Rake::Task[:build].invoke
end

##@ Development

desc 'Show debug information'
task :debug do
  puts "#{GREEN}Packer Configuration Debug Info#{RESET}"
  puts "TEMPLATE_DIR_BASE: #{TEMPLATE_DIR_BASE}"
  puts "PROVIDER:          #{provider}"
  puts "TARGET_OS:         #{target_os}"
  puts "Template Dir:      #{TEMPLATE_DIR_BASE}"
  puts "PKRVARS_DIR:       #{PKRVARS_DIR}"
  puts "BUILDS_DIR:        #{BUILDS_DIR}"
  puts "K8S_VERSION:       #{k8s_version}"
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

##@ VirtualBox Utilities

desc 'Export a registered VirtualBox VM to OVA (usage: rake vbox_export TEMPLATE=debian/12-x86_64.pkrvars.hcl [VARIANT=k8s-node])'
task :vbox_export do
  template = ENV['TEMPLATE']
  variant_env = ENV['VARIANT']

  unless template
    puts "#{RED}Error: TEMPLATE variable not set#{RESET}"
    puts "Usage: rake vbox_export TEMPLATE=debian/12-x86_64.pkrvars.hcl [VARIANT=k8s-node]"
    exit 1
  end

  var_file = File.join(PKRVARS_DIR, template)
  unless File.exist?(var_file)
    puts "#{RED}Var file not found: #{var_file}#{RESET}"
    exit 1
  end

  read_val = ->(key) do
    line = File.readlines(var_file).find { |l| l =~ /^\s*#{key}\s*=\s*"/ }
    line && line[/^\s*#{key}\s*=\s*"(.*?)"/, 1]
  end

  os_name = read_val.call('os_name') || 'unknown'
  os_version = read_val.call('os_version') || 'unknown'
  os_arch = read_val.call('os_arch') || 'unknown'
  variant_file = read_val.call('variant') || 'base'
  variant = (variant_env && !variant_env.empty?) ? variant_env : variant_file
  k8s_ver = k8s_version
  base_box_name = "#{os_name}-#{os_version}-#{os_arch}"
  box_name =
    if variant == 'base' || variant.nil? || variant.empty?
      base_box_name
    elsif variant == 'k8s-node'
      "#{base_box_name}-#{variant}-#{k8s_ver}"
    else
      "#{base_box_name}-#{variant}"
    end

  out_dir = File.join(BUILDS_DIR, 'build_complete')
  FileUtils.mkdir_p(out_dir)
  ova_path = File.join(out_dir, "#{box_name}.ova")

  # Check VM registration
  show_cmd = [ 'VBoxManage', 'showvminfo', box_name ]
  ok = system(*show_cmd, out: File::NULL, err: File::NULL)
  unless ok
    puts "#{RED}VM '#{box_name}' not found or not registered.#{RESET}"
    puts "#{YELLOW}Build with -var=vbox_keep_registered=true, then run this task.#{RESET}"
    exit 1
  end

  puts "#{GREEN}Exporting #{box_name} to #{ova_path}#{RESET}"
  export_cmd = [ 'VBoxManage', 'export', box_name, '--output', ova_path ]
  success = system(*export_cmd)

  if success
    puts "#{GREEN}Export complete: #{ova_path}#{RESET}"
  else
    puts "#{RED}Export failed#{RESET}"
    exit 1
  end
end

desc 'Add a built box to local Vagrant (usage: rake vagrant_add TEMPLATE=debian/12-x86_64.pkrvars.hcl [VARIANT=k8s-node] [BOX_ALIAS=name])'
task :vagrant_add do
  template = ENV['TEMPLATE']
  variant_env = ENV['VARIANT']
  box_alias_env = ENV['BOX_ALIAS']

  unless template
    puts "#{RED}Error: TEMPLATE variable not set#{RESET}"
    puts "Usage: rake vagrant_add TEMPLATE=debian/12-x86_64.pkrvars.hcl [VARIANT=k8s-node] [BOX_ALIAS=name]"
    exit 1
  end

  var_file = File.join(PKRVARS_DIR, template)
  unless File.exist?(var_file)
    puts "#{RED}Var file not found: #{var_file}#{RESET}"
    exit 1
  end

  read_val = ->(key) do
    line = File.readlines(var_file).find { |l| l =~ /^\s*#{key}\s*=\s*"/ }
    line && line[/^\s*#{key}\s*=\s*"(.*?)"/, 1]
  end

  os_name = read_val.call('os_name') || 'unknown'
  os_version = read_val.call('os_version') || 'unknown'
  os_arch = read_val.call('os_arch') || 'unknown'
  variant_file = read_val.call('variant') || 'base'
  variant = (variant_env && !variant_env.empty?) ? variant_env : variant_file

  k8s_ver = k8s_version
  base_box_name = "#{os_name}-#{os_version}-#{os_arch}"
  box_name =
    if variant == 'base' || variant.nil? || variant.empty?
      base_box_name
    elsif variant == 'k8s-node'
      "#{base_box_name}-#{variant}-#{k8s_ver}"
    else
      "#{base_box_name}-#{variant}"
    end

  box_path = File.join(BUILDS_DIR, 'build_complete', "#{box_name}.virtualbox.box")
  unless File.exist?(box_path)
    puts "#{RED}Box file not found: #{box_path}#{RESET}"
    exit 1
  end

  box_alias = (box_alias_env && !box_alias_env.empty?) ? box_alias_env : box_name

  puts "#{GREEN}Adding box '#{box_alias}' from #{box_path}#{RESET}"
  success = system('vagrant', 'box', 'add', '--name', box_alias, box_path)
  exit 1 unless success
end

desc 'Generate Vagrant metadata JSON (usage: rake vagrant_metadata TEMPLATE=debian/12-x86_64.pkrvars.hcl [VARIANT=k8s-node] [BOX_NAME=name] [BOX_VERSION=version])'
task :vagrant_metadata do
  template = ENV['TEMPLATE']
  variant_env = ENV['VARIANT']
  box_name_override = ENV['BOX_NAME']
  box_version_override = ENV['BOX_VERSION']

  unless template
    puts "#{RED}Error: TEMPLATE variable not set#{RESET}"
    puts "Usage: rake vagrant_metadata TEMPLATE=debian/12-x86_64.pkrvars.hcl [VARIANT=k8s-node] [BOX_NAME=name] [BOX_VERSION=version]"
    exit 1
  end

  var_file = File.join(PKRVARS_DIR, template)
  unless File.exist?(var_file)
    puts "#{RED}Var file not found: #{var_file}#{RESET}"
    exit 1
  end

  read_val = lambda do |key|
    line = File.readlines(var_file).find { |l| l =~ /^\s*#{key}\s*=\s*"/ }
    line && line[/^\s*#{key}\s*=\s*"(.*?)"/, 1]
  end

  os_name = read_val.call('os_name') || 'unknown'
  os_version = read_val.call('os_version') || 'unknown'
  os_arch = read_val.call('os_arch') || 'unknown'
  variant_file = read_val.call('variant') || 'base'
  variant = (variant_env && !variant_env.empty?) ? variant_env : variant_file

  k8s_ver = k8s_version
  base_box_name = "#{os_name}-#{os_version}-#{os_arch}"

  box_name =
    if variant == 'base' || variant.nil? || variant.empty?
      base_box_name
    elsif variant == 'k8s-node'
      "#{base_box_name}-#{variant}-#{k8s_ver}"
    else
      "#{base_box_name}-#{variant}"
    end

  meta_name =
    if box_name_override && !box_name_override.empty?
      box_name_override
    elsif variant == 'k8s-node'
      "#{base_box_name}-#{variant}"
    else
      box_name
    end

  meta_version =
    if box_version_override && !box_version_override.empty?
      box_version_override
    elsif variant == 'k8s-node'
      k8s_ver
    else
      '0'
    end

  box_dir = File.join(BUILDS_DIR, 'build_complete')
  box_file = "#{box_name}.virtualbox.box"
  box_path = File.join(box_dir, box_file)

  unless File.exist?(box_path)
    puts "#{RED}Box file not found: #{box_path}#{RESET}"
    exit 1
  end

  metadata_path = File.join(box_dir, "#{meta_name}-#{meta_version}.json")

  metadata = <<~JSON
    {
      "name": "#{meta_name}",
      "versions": [
        {
          "version": "#{meta_version}",
          "providers": [
            {
              "name": "virtualbox",
              "url": "#{box_file}"
            }
          ]
        }
      ]
    }
  JSON

  File.write(metadata_path, metadata)
  puts "#{GREEN}Wrote Vagrant metadata: #{metadata_path}#{RESET}"
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
