require "test_helper"

class NetparClientTest < ActiveSupport::TestCase
  setup do
    @client = Netpar::Client.new
    stub_netpar_token
  end

  test "rodzaje dla zapisów przez internet (enabled_in_examination) w treści JSON" do
    request = stub_request(:get, "#{NETPAR_URL}/divisions").with(body: { enabled_in_examination: true, category: "R" }.to_json)
                                                           .to_return(json({ divisions: [ division_a ] }))
    assert_equal [ division_a ], @client.divisions(category: "R")
    assert_requested request.with(headers: { "Authorization" => "Token token=tok-1" })
  end

  test "brak danych (404): nil albo pusta lista" do
    stub_request(:get, "#{NETPAR_URL}/divisions/9").to_return(json({ error: "brak" }, status: 404))
    stub_request(:get, "#{NETPAR_URL}/exam_fees/find").to_return(json({ error: "brak" }, status: 404))
    stub_request(:get, %r{/grades\z}).to_return(json({ error: "brak" }, status: 404))
    assert_nil @client.division(9)
    assert_nil @client.exam_fee(division_id: 9, esod_category: 41, for_date: Date.current)
    assert_equal [], @client.grades("abc")
  end

  test "zgłoszenie: POST z JSON w parametrze proposal; PATCH 404 → false; 422 → Rejected" do
    post = stub_request(:post, "#{NETPAR_URL}/proposals").to_return(json({ id: 1 }, status: 201))
    assert @client.create_proposal("multi_app_identifier" => "abc", "name" => "Kowalski")
    assert_requested post.with { URI.decode_www_form(it.body).to_h["proposal"] == { "multi_app_identifier" => "abc", "name" => "Kowalski" }.to_json }

    stub_request(:patch, "#{NETPAR_URL}/proposals/abc").to_return(json({ error: "brak" }, status: 404))
    assert_equal false, @client.update_proposal("abc", {})

    stub_request(:post, "#{NETPAR_URL}/proposals").to_return(json({ errors: { exam: [ "brak wolnych miejsc" ] } }, status: 422))
    error = assert_raises(Netpar::Rejected) { @client.create_proposal({}) }
    assert_equal [ "exam: brak wolnych miejsc" ], error.messages
  end

  test "wygasły token: nowy token i ponowienie" do
    stub_request(:get, "#{NETPAR_URL}/divisions").to_return(json({}, status: 401), json({ divisions: [] }))
    assert_equal [], @client.divisions(category: "M")
    assert_requested :get, "#{NETPAR_URL}/token", times: 2
  end

  test "błędy usługi jako Unavailable" do
    stub_request(:get, "#{NETPAR_URL}/divisions").to_return(status: 500, body: "x")
    assert_raises(Netpar::Unavailable) { @client.divisions(category: "M") }
    stub_request(:get, "#{NETPAR_URL}/divisions").to_timeout
    assert_raises(Netpar::Unavailable) { @client.divisions(category: "M") }
    stub_request(:get, "#{NETPAR_URL}/divisions").to_return(json({ inne: 1 }))
    assert_raises(Netpar::Unavailable) { @client.divisions(category: "M") }
  end
end
