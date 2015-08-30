#
# Cookbook Name:: drush
# Recipe:: github
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#

include_recipe "php"
require_recipe 'composer'

vers = node['drush']['version']
indir = node['drush']['install_dir']

## We can dinamically discover the Drush version and the appropriate archive

release_list = 'https://api.github.com/repos/drush-ops/drush/releases'

require 'open-uri'

releases = JSON.parse(open(release_list).read)

if %w[prerelease stable].include?(vers)

  if vers == 'stable'
    vers = releases.find_all { |e| !e['prerelease'] }.collect { |e| 
           e['tag_name'] }.find_all { |t| t.match(/\A\d+\.\d+(\.\d+)?\Z/) }.first
  elsif vers == 'prerelease'
    vers = releases.find_all { |e| e['prerelease'] }.collect { |e| e['tag_name'] }.first
  end
end

drush_url = releases.find { |r| r['tag_name'] == vers }['tarball_url']
drush_pkg = "drush-#{vers}.tar.gz"

remote_file "drush-#{vers}" do
  path "#{Chef::Config[:file_cache_path]}/#{drush_pkg}"
  source drush_url
  mode 0644
end

directory "#{indir}" do
  owner 'root'
  group 'root'
  mode  '0755'
  action :create
end

execute "extract drush-#{vers}" do
  command <<-EOS
tar -zxf #{Chef::Config[:file_cache_path]}/#{drush_pkg} -C #{indir}
EOS
  creates "#{indir}/drush.php"
  notifies :run, 'execute[install-drush-deps]', :immediately
end

execute 'install-drush-deps' do
  command "#{node['composer']['bin']} install --no-interaction --no-ansi --quiet --no-dev"
  cwd "#{indir}"
  user 'root'
  group 'root'
  only_if { File.exists?(node['composer']['bin']) && File.exists?(node['drush']['install_dir'] + '/composer.json') }
  action :nothing
end

link "#{indir}/bin/drush" do
  to '/usr/local/bin/drush'
  only_if "test -f #{indir}/bin/drush"
end

