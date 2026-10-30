require "test_helper"

class NetparPayloadTest < ActiveSupport::TestCase
  test "Hash#to_s z Ruby (format NETPAR) – także z „=>”, cudzysłowem i nową linią w tekście" do
    raw = { "proposal_status_id" => 3, "not_approved_comment" => "Brak => \"opłaty\"\nlinia 2 \#{x}", "test_unlocked" => false, "note" => nil }.to_s
    assert_equal({ "proposal_status_id" => 3, "not_approved_comment" => "Brak => \"opłaty\"\nlinia 2 \#{x}", "test_unlocked" => false, "note" => nil },
                 Netpar::Payload.parse(raw))
  end

  test "format Ruby 2.2 (bez spacji wokół =>) i JSON" do
    assert_equal({ "a" => 1, "b" => "x" }, Netpar::Payload.parse('{"a"=>1, "b"=>"x"}'))
    assert_equal({ "a" => 1 }, Netpar::Payload.parse('{"a":1}'))
  end

  test "dane, które nie są obiektem" do
    assert_raises(ArgumentError) { Netpar::Payload.parse("[1, 2]") }
    assert_raises(JSON::ParserError) { Netpar::Payload.parse("nie json") }
  end
end
