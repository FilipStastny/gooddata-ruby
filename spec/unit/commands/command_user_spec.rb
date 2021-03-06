require 'gooddata/commands/user'

describe GoodData::Command::User do
  before(:each) do
    ConnectionHelper.create_default_connection
  end

  after(:each) do
    GoodData.disconnect
  end

  it "Is Possible to create GoodData::Command::User instance" do
    cmd = GoodData::Command::User.new()
    cmd.should be_a(GoodData::Command::User)
  end

  describe "#show" do
    it "Shows profile" do
      GoodData::Command::User.show
    end
  end
end