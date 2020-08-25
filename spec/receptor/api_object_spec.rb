RSpec.describe TopologicalInventory::MigrationToolkitVirtualization::Receptor::ApiObject do
  let(:receptor_client) { double("Receptor Client", :identity_header= => nil) }
  let(:receptor_node_id) { 'receptor-node' }
  let(:account_number) { '1' }
  let(:connection) { TopologicalInventory::MigrationToolkitVirtualization::Receptor::Connection.new(receptor_client, receptor_node_id, account_number) }
  let(:api) { connection.api }
  let(:type) { 'job_templates' }

  subject { described_class.new(api, connection, type) }

  before do
    allow(connection).to receive(:api).and_return(subject)
  end

  describe "#send_request" do
    let(:msg_id) { '123' }
    let(:receiver) { double("Receiver", :on_success => nil, :on_error => nil, :on_timeout => nil, :on_eof => nil) }
    let(:directive) { double(:call => nil) }
    let(:payload) { {'href_slug' => '/api/v2/job_templates'} }

    before do
      allow(subject).to receive(:build_payload).and_return(payload)
    end

    it "calls blocking directive if receiver not present" do
      expect(receptor_client).to(receive(:directive)
                                   .with(account_number,
                                         receptor_node_id,
                                         :directive          => described_class::RECEPTOR_DIRECTIVE,
                                         :log_message_common => payload['href_slug'],
                                         :payload            => payload.to_json,
                                         :type               => :blocking)
                                   .and_return(directive))

      subject.send(:send_request, :get, '/')
    end

    it "calls non-blocking directive if receiver present" do
      subject.send(:receiver=, receiver)

      %i[on_success on_error on_timeout on_eof].each do |callback|
        allow(directive).to receive(callback).and_return(directive)
      end

      expect(receptor_client).to(receive(:directive)
                                   .with(account_number,
                                         receptor_node_id,
                                         :directive          => described_class::RECEPTOR_DIRECTIVE,
                                         :log_message_common => payload['href_slug'],
                                         :payload            => payload.to_json,
                                         :type               => :non_blocking)
                                   .and_return(directive))

      subject.send(:send_request, :get, '/')
    end
  end

  describe "#get" do
    context "sync" do
      it "sends request to the default path and type" do
        allow(subject).to receive(:raw_kafka_response)
        expect(subject).to(receive(:send_request)
                             .with(:get, '/api/v2/job_templates'))

        subject.get
      end

      it "sends request to the type if it already contains default path" do
        subject.send(:type=, '/api/v2/something/1/something')

        allow(subject).to receive(:raw_kafka_response)
        expect(subject).to(receive(:send_request)
                             .with(:get, '/api/v2/something/1/something'))

        subject.get
      end

      it "sends request and wraps response to Response object" do
        body = {:key => :value}
        allow(subject).to receive(:send_request).and_return('status' => 200, 'body' => body)

        response = subject.get

        expect(response).to be_kind_of(TopologicalInventory::MigrationToolkitVirtualization::Receptor::Response)
        expect(response.body).to eq(body)
      end
    end
  end

  describe "#find" do
    context "sync" do
      it "sends request to endpoint with ID" do
        allow(subject).to receive_messages(:parse_kafka_response => nil, :build_object => nil)
        expect(subject).to(receive(:send_request)
                             .with(:get, '/api/v2/job_templates/42/'))

        subject.find(42)
      end

      it "parses response and wraps to MigrationToolkitVirtualizationClient object" do
        body = {:id => 1, :type => type}
        response = {'status' => '200', 'body' => body.to_json}

        allow(subject).to receive(:send_request).and_return(response)

        obj = subject.find(42)

        expect(obj).to be_kind_of(MigrationToolkitVirtualizationClient::JobTemplate)
      end

      it "raises ReceptorNodeError exception when String response returned" do
        response = "Error occurred"
        allow(subject).to receive(:send_request).and_return(response)

        expect { subject.find(42) }.to raise_exception(TopologicalInventory::MigrationToolkitVirtualization::Receptor::ReceptorNodeError)
      end

      it "raises ReceptorUnknownResponseError exception when response is non-hash and non-string" do
        allow(subject).to receive(:send_request).and_return(nil)

        expect { subject.find(42) }.to raise_exception(TopologicalInventory::MigrationToolkitVirtualization::Receptor::ReceptorUnknownResponseError)
      end

      it "raises ReceptorKafkaResponseError if receptor node returned HTTP status non 2xx" do
        body = {:id => 1, :type => type}
        response = {'status' => '400', 'body' => body.to_json}

        allow(subject).to receive(:send_request).and_return(response)
        expect { subject.find(42) }.to raise_exception(TopologicalInventory::MigrationToolkitVirtualization::Receptor::ReceptorKafkaResponseError)
      end

      it "raises ReceptorKafkaResponseError if response is hash without status or body" do
        body = {:id => 1, :type => type}
        response = {'s' => '400', 'b' => body.to_json}

        allow(subject).to receive(:send_request).and_return(response)
        expect { subject.find(42) }.to raise_exception(TopologicalInventory::MigrationToolkitVirtualization::Receptor::ReceptorKafkaResponseError)
      end
    end
  end

  describe "#all" do
    context "async" do
      let(:msg_id) { '123' }
      let(:receiver) { double("Receiver", :on_success => nil, :on_error => nil, :on_timeout => nil, :on_eof => nil) }
      let(:directive) { double(:call => nil) }

      before do
        subject.send(:receiver=, receiver)

        %i[on_success on_error on_timeout on_eof].each do |callback|
          allow(directive).to receive(callback).and_return(directive)
        end
      end

      it "sends directive request" do
        query_params = {:id__in => '42,1'}
        receptor_opts = {:accept_encoding => 'gzip', :fetch_all_pages => true}

        payload = {
          'method'          => 'GET',
          'href_slug'       => '/api/v2/job_templates?id__in=42%2C1',
          'params'          => query_params,
          'fetch_all_pages' => true,
          'accept_encoding' => 'gzip'
        }

        expect(receptor_client).to(receive(:directive)
                                     .with(account_number,
                                           receptor_node_id,
                                           :directive          => described_class::RECEPTOR_DIRECTIVE,
                                           :log_message_common => '/api/v2/job_templates?id__in=42%2C1',
                                           :payload            => payload.to_json,
                                           :type               => :non_blocking)
                                     .and_return(directive))

        subject.all(query_params, receptor_opts)
      end
    end
  end

  context "async callbacks" do
    it "raises NotImplementedError if receiver not provided" do
      expect { subject.send(:on_success, '1', {}) }.to raise_exception(NotImplementedError)
      expect { subject.send(:on_error, '1', '1', '') }.to raise_exception(NotImplementedError)
      expect { subject.send(:on_timeout, '1') }.to raise_exception(NotImplementedError)
      expect { subject.send(:on_eof, '1') }.to raise_exception(NotImplementedError)
    end

    it "raises NotImplementedError if receiver doesn't implement methods" do
      subject.send(:receiver=, double)

      expect { subject.send(:on_success, '1', {}) }.to raise_exception(NotImplementedError)
      expect { subject.send(:on_error, '1', '1', '') }.to raise_exception(NotImplementedError)
      expect { subject.send(:on_timeout, '1') }.to raise_exception(NotImplementedError)
      expect { subject.send(:on_eof, '1') }.to raise_exception(NotImplementedError)
    end

    context "successful" do
      let(:receiver) { double('Receiver') }
      let(:msg_id) { '123' }
      let(:code) { '100' }
      let(:response) { {'status' => '200', 'body' => [{'id' => 42}].to_json} }

      it "calls receiver callbacks" do
        subject.send(:receiver=, receiver)

        expect(receiver).to(receive(:on_success).with(msg_id, 'id' => 42))
        subject.send(:on_success, msg_id, response)

        expect(receiver).to receive(:on_error).with(msg_id, code, response)
        subject.send(:on_error, msg_id, code, response)

        expect(receiver).to receive(:on_timeout).with(msg_id)
        subject.send(:on_timeout, msg_id)

        expect(receiver).to receive(:on_eof).with(msg_id)
        subject.send(:on_eof, msg_id)
      end
    end
  end
end
