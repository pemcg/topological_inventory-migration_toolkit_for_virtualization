require "topological_inventory/migration_toolkit_virtualization/operations/worker"

RSpec.describe TopologicalInventory::MigrationToolkitVirtualization::Operations::Worker do
  describe "#run" do
    let(:client) { double("ManageIQ::Messaging::Client") }
    let(:subject) { described_class.new }
    before do
      require "manageiq-messaging"
      allow(ManageIQ::Messaging::Client).to receive(:open).and_return(client)
      allow(client).to receive(:close)
      allow(subject).to receive(:logger).and_return(double('null_object').as_null_object)
    end

    it "calls subscribe_messages on the right queue" do
      operations_topic = "platform.topological-inventory.operations-ansible-tower"

      message = double("ManageIQ::Messaging::ReceivedMessage")
      allow(message).to receive(:message)
      allow(message).to receive(:payload)
      allow(message).to receive(:ack)

      expect(client).to receive(:subscribe_topic)
        .with(hash_including(:service => operations_topic)).and_yield(message)
      expect(TopologicalInventory::MigrationToolkitVirtualization::Operations::Processor)
        .to receive(:process!).with(message)
      subject.run
    end
  end
end
