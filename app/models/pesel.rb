# Numer PESEL: suma kontrolna i zakodowana data urodzenia (miesiąc +80/+0/+20/+40/+60 dla lat 1800–2299).
class Pesel
  WEIGHTS = [ 1, 3, 7, 9, 1, 3, 7, 9, 1, 3 ].freeze
  CENTURIES = { 80 => 1800, 0 => 1900, 20 => 2000, 40 => 2100, 60 => 2200 }.freeze

  def initialize(number)
    @number = number.to_s.strip
  end

  def valid?
    @number.match?(/\A\d{11}\z/) && checksum_valid? && birth_date.present?
  end

  def birth_date
    return unless @number.match?(/\A\d{11}\z/)

    year, month, day = @number[0, 2].to_i, @number[2, 2].to_i, @number[4, 2].to_i
    offset = CENTURIES.keys.find { month.between?(it + 1, it + 12) }
    return unless offset

    Date.new(CENTURIES[offset] + year, month - offset, day)
  rescue Date::Error
    nil
  end

  private
    def checksum_valid?
      digits = @number.chars.map(&:to_i)
      (10 - digits.first(10).zip(WEIGHTS).sum { |d, w| d * w } % 10) % 10 == digits.last
    end
end
