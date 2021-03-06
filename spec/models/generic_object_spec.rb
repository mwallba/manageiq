describe GenericObject do
  let(:go_object_name) { "load_balancer_1" }
  let(:max_number)     { 100 }
  let(:server_name)    { "test_server" }
  let(:data_read)      { 345.67 }
  let(:s_time)         { Time.now.utc }

  let(:definition) do
    FactoryGirl.create(
      :generic_object_definition,
      :name       => "test_definition",
      :properties => {
        :attributes => {
          :flag       => "boolean",
          :data_read  => "float",
          :max_number => "integer",
          :server     => "string",
          :s_time     => "datetime"
        }
      }
    )
  end

  let(:go) do
    FactoryGirl.create(
      :generic_object,
      :generic_object_definition => definition,
      :name                      => go_object_name,
      :flag                      => true,
      :data_read                 => data_read,
      :max_number                => max_number,
      :server                    => server_name,
      :s_time                    => s_time
    )
  end

  it "should ensure presence of name" do
    o = GenericObject.new(:generic_object_definition => definition, :name => nil)
    expect(o).not_to be_valid
  end

  describe "#create" do
    it "creates a generic object without definition and properties" do
      expect(GenericObject.create).to be_a_kind_of(GenericObject)
    end

    it "creates a generic object with both definition and properties" do
      expect(GenericObject.create(:max_number => max_number, :generic_object_definition => definition)).to be_a_kind_of(GenericObject)
    end

    it "raises an error when create a generic object with properties but no definition" do
      expect { GenericObject.create(:max_number => max_number) }.to raise_error(ActiveModel::UnknownAttributeError)
    end
  end

  context "property attributes" do
    context "with generic_object_definition" do
      it "can be accessed as an attribute" do
        expect(go.generic_object_definition).to eq(definition)
        expect(go.name).to                      eq(go_object_name)
        expect(go.flag).to                      eq(true)
        expect(go.data_read).to                 eq(data_read)
        expect(go.max_number).to                eq(max_number)
        expect(go.server).to                    eq(server_name)
        expect(go.s_time).to                    be_same_time_as(s_time).with_precision(2)
      end

      it "can be set as an attribute" do
        go.max_number = max_number + 100
        go.save!
        expect(go.reload.max_number).to eq(max_number + 100)
      end

      it "can't set undefined property attribute" do
        expect { go.some_thing = 'not_defined' }.to raise_error(NoMethodError)
      end

      it "sets defined property attribute" do
        go.properties = {
          :data_read  => data_read + 100.50,
          :flag       => false,
          :max_number => max_number + 100,
          :server     => "#{server_name}_2",
          :s_time     => s_time - 2.days
        }
        go.save!

        expect(go.properties['s_time']).to be_same_time_as(s_time - 2.days).with_precision(2)
        expect(go.properties).to include(
          "flag"       => false,
          "data_read"  => data_read + 100.50,
          "max_number" => max_number + 100,
          "server"     => "#{server_name}_2",
        )
      end

      it "raises an error if any property attribute is not defined" do
        expect { go.properties = {:max_number => max_number + 100, :bad => ''} }.to raise_error(ActiveModel::UnknownAttributeError)
        go.save!
        expect(go.properties).to have_attributes('max_number' => max_number)
      end
    end

    context "without generic_object_definition" do
      let(:empty_go) { FactoryGirl.build(:generic_object) }

      it "raises an error when set a property attribute" do
        expect { empty_go.max_number = max_number }.to raise_error(NoMethodError)
      end

      it "raises an error when set property attributes" do
        expect { empty_go.properties = {:max_number => max_number} }.to raise_error(RuntimeError)
      end
    end
  end
end
