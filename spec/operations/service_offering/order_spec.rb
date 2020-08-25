require "topological_inventory-api-client"
require "topological_inventory/migration_toolkit_virtualization/operations/service_offering"

RSpec.describe TopologicalInventory::MigrationToolkitVirtualization::Operations::ServiceOffering do
  context "#order" do
    let(:subject)  { described_class.new(params, identity) }
    let(:identity) { {"account_number" => "12345" } }
    let(:service_offering) do
      TopologicalInventoryApiClient::ServiceOffering.new(
        :id => "1", :source_id => "1", :source_ref => "2", :name => "My Job Template", :extra => {:type => "job_template"}
      )
    end
    let(:params) do
      {
        "order_params"        => {
          "service_offering_id"         => 1,
          "service_parameters"          => {
            :name   => "Job 1",
            :param1 => "Test Topology",
            :param2 => 50
          },
          "provider_control_parameters" => {}
        },
        "service_offering_id" => 1,
        "task_id"             => 1 # in tp-inv api (Task)
      }
    end

    let(:migration_toolkit_virtualization_client) { TopologicalInventory::MigrationToolkitVirtualization::Operations::Core::MigrationToolkitVirtualizationClient.new('1', params['task_id']) }

    it "orders the service offering" do
      expect(subject).to receive(:update_task).with(1, :state => "running", :status => "ok")

      topology_api_client = double
      expect(subject).to receive(:topology_api_client).and_return(topology_api_client)
      expect(topology_api_client).to receive(:show_service_offering).with("1")
        .and_return(service_offering)

      expect(subject).to receive(:migration_toolkit_virtualization_client)
        .with(service_offering.source_id, params["task_id"], identity)
        .and_return(migration_toolkit_virtualization_client)

      job = double
      allow(job).to receive(:id).and_return(42)
      allow(job).to receive(:status).and_return('successful')

      allow(migration_toolkit_virtualization_client).to receive(:job_external_url).and_return('https://tower.example.com/job/1')
      expect(migration_toolkit_virtualization_client).to receive(:order_service)
        .with(service_offering.extra.dig(:type), service_offering.source_ref, params["order_params"])
        .and_return(job)

      expect(subject).to receive(:update_task)
                           .with(1,
                                 :context => {
                                   :service_instance => {
                                     :job_status => 'successful',
                                     :url        => 'https://tower.example.com/job/1'
                                   }
                                 },
                                 :state             => "running",
                                 :status            => migration_toolkit_virtualization_client.job_status_to_task_status(job.status),
                                 :source_id         => '1',
                                 :target_source_ref => job.id.to_s,
                                 :target_type       => 'ServiceInstance'
                           )
      subject.order
    end
  end
end
