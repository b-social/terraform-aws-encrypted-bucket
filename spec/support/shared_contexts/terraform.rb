# frozen_string_literal: true

require 'awspec'
require 'ostruct'

require_relative '../terraform_module'

shared_context :terraform do
  include Awspec::Helper::Finder

  def vars
    @vars ||= OpenStruct.new(
      TerraformModule.configuration
                     .for(:harness)
                     .vars
    )
  end

  def configuration
    TerraformModule.configuration
  end

  def output_for(role, name)
    TerraformModule.output_for(role, name)
  end

  def plan(overrides = nil)
    TerraformModule.plan_for(
      :harness,
      TerraformModule.configuration.for(:harness, overrides).vars)
  end

  def provision(overrides = nil)
    TerraformModule.provision_for(
      :harness,
      TerraformModule.configuration.for(:harness, overrides).vars
    )
  end

  def destroy(overrides = nil)
    TerraformModule.destroy_for(
      :harness,
      TerraformModule.configuration.for(:harness, overrides).vars,
      force: true)
  end

  def reprovision(overrides = nil)
    destroy(overrides)
    provision(overrides)
  end
end
