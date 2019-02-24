
describe CompassJSON do
  let (:result) { CompassJSON.parse(input) }

  context "with a string" do
    let(:input) { "foo" }

    it "returns the input unchanged" do
      expect(result).to eql("foo")
    end
  end
  context "with an integer" do
    let(:input) { 1 }

    it "returns the input unchanged" do
      expect(result).to eql(1)
    end
  end
  context "with an array" do
    let(:input) { [1] }

    it "returns the input unchanged" do
      expect(result).to eql([1])
    end
  end
  context "with a hash containing just d" do
    let(:input) { { "d" => "foo"} }

    it "returns the value of d" do
      expect(result).to eql("foo")
    end
  end

  context "with a hash that doesn't contain d" do
    let(:input) { { "a" => "foo"} }

    it "returns the input unchanged" do
      expect(result).to eql("a" => "foo")
    end
  end

  context "with a serialised GenericMobileResponse" do
    let(:input) { { "__type" => "GenericMobileResponse", "data" => 1} }

    it "returns an instance of GenericMobileResponse" do
      expect(result).to eql(GenericMobileResponse.new(1))
    end
  end
end
