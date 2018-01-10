require 'spec_helper'

describe 'vra_puppet_plugin_prep' do
  on_supported_os.each do |os, os_facts|
    context "on #{os}" do
      let(:facts) { os_facts }
      let(:pre_condition) { 'service { "pe-puppetserver": }' }

      it { is_expected.to compile }
    end
  end
end
