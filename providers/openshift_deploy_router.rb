#
# Cookbook Name:: cookbook-openshift3
# Resources:: openshift_deploy_router
#
# Copyright (c) 2015 The Authors, All Rights Reserved.

use_inline_resources
provides :openshift_deploy_router if defined? provides

def whyrun_supported?
  true
end

action :create do
  remote_file "#{Chef::Config[:file_cache_path]}/admin.kubeconfig" do
    source 'file:///etc/origin/master/admin.kubeconfig'
    mode '0644'
  end

  execute 'Deploy Hosted Router' do
    command "#{node['cookbook-openshift3']['openshift_common_client_binary']} adm router --selector=${selector_router} -n ${namespace_router} --config=admin.kubeconfig || true"
    environment(
      'selector_router' => node['cookbook-openshift3']['openshift_hosted_router_selector'],
      'namespace_router' => node['cookbook-openshift3']['openshift_hosted_router_namespace']
    )
    cwd Chef::Config[:file_cache_path]
    only_if '[[ `oc get pod --selector=router=router --config=admin.kubeconfig | wc -l` -eq 0 ]]'
  end

  execute 'Auto Scale Router based on label' do
    command "#{node['cookbook-openshift3']['openshift_common_client_binary']} scale dc/router --replicas=${replica_number} -n ${namespace_router} --config=admin.kubeconfig"
    environment(
      'replica_number' => Mixlib::ShellOut.new("oc get node --no-headers --selector=#{node['cookbook-openshift3']['openshift_hosted_router_selector']} --config=#{Chef::Config[:file_cache_path]}/admin.kubeconfig | wc -l").run_command.stdout.strip,
      'namespace_router' => node['cookbook-openshift3']['openshift_hosted_router_namespace']
    )
    cwd Chef::Config[:file_cache_path]
    not_if '[[ `oc get pod --selector=router=router --config=admin.kubeconfig --no-headers | wc -l` -eq ${replica_number} ]]'
  end

  new_resource.updated_by_last_action(true)
end
