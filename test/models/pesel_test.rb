require "test_helper"

class PeselTest < ActiveSupport::TestCase
  test "poprawny PESEL i data urodzenia (lata 1900 i 2000)" do
    assert Pesel.new("90010100009").valid?
    assert_equal Date.new(1990, 1, 1), Pesel.new("90010100009").birth_date
    assert_equal Date.new(2002, 7, 8), Pesel.new("02270803628").birth_date
  end

  test "błędna suma kontrolna, długość albo data" do
    assert_not Pesel.new("90010100005").valid?
    assert_not Pesel.new("9001010000").valid?
    assert_not Pesel.new("90023100009").valid? # 31 lutego
    assert_not Pesel.new("abc").valid?
  end
end
