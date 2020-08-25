require "topological_inventory/migration_toolkit_virtualization/operations/core/migration_toolkit_virtualization_client"

RSpec.describe TopologicalInventory::MigrationToolkitVirtualization::Operations::Core::MigrationToolkitVirtualizationClient do
  let(:order_params) do
    {
      'service_plan_id'             => 1,
      'service_parameters'          => {:name   => "Job 1",
                                        :param1 => "Test Topology",
                                        :param2 => 50},
      'provider_control_parameters' => {}
    }
  end

  let(:source_id) { 1 }
  let(:identity) { {'x-rh-identity' => '1234567890'} }
  let(:task_id) { 10 }
  let(:migration_toolkit_virtualization_client) { described_class.new(source_id, task_id, identity) }

  before do
    migration_toolkit_virtualization, @api = double, double
    allow(migration_toolkit_virtualization_client).to receive(:migration_toolkit_virtualization).and_return(migration_toolkit_virtualization)
    allow(migration_toolkit_virtualization).to receive(:api).and_return(@api)

    allow(migration_toolkit_virtualization_client).to receive(:logger).and_return(double('null_object').as_null_object)
  end

  describe "#order_service_plan" do
    let(:job_templates) { double }
    let(:job_template) { double }
    let(:job) { double }

    before do
      allow(job_templates).to receive(:find).and_return(job_template)
      allow(job_template).to receive(:launch).and_return(job)
      expect(job_template).to receive(:launch).with(:extra_vars => order_params['service_parameters'])
    end

    it "launches job_template and returns job" do
      allow(@api).to receive(:job_templates).and_return(job_templates)

      expect(@api).to receive(:job_templates).once

      svc_instance = migration_toolkit_virtualization_client.order_service("job_template", 1, order_params)
      expect(svc_instance).to eq(job)
    end

    it "launches workflow and returns workflow job" do
      allow(@api).to receive(:workflow_job_templates).and_return(job_templates)

      expect(@api).to receive(:workflow_job_templates).once

      svc_instance = migration_toolkit_virtualization_client.order_service("workflow_job_template", 1, order_params)
      expect(svc_instance).to eq(job)
    end
  end
end
