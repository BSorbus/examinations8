require "test_helper"

class TerytClientTest < ActiveSupport::TestCase
  test "lista adresów i adres" do
    stub_request(:get, "#{TERYT_URL}/Address").with(query: hash_including("Query" => "gdynia morska", "Order" => "name"))
                                              .to_return(json({ total: 1, items: [ teryt_address ] }))
    stub_request(:get, "#{TERYT_URL}/Address/#{teryt_address['combineId']}").to_return(json(teryt_address))
    stub_request(:get, "#{TERYT_URL}/Address/brak").to_return(status: 404)

    client = Teryt::Client.new
    assert_equal [ teryt_address ], client.addresses("gdynia morska")["items"]
    assert_equal "Gdynia", client.address(teryt_address["combineId"])["cityName"]
    assert_nil client.address("brak")
  end

  test "niedostępność usługi" do
    stub_request(:get, %r{#{TERYT_URL}/Address}).to_return(status: 502)
    assert_raises(Teryt::Unavailable) { Teryt::Client.new.addresses("abc") }
  end
end
