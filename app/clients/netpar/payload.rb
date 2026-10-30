module Netpar
  # Dane zgłoszenia przysyłane przez NETPAR (EgzaminyProposal#request_update): parametr "proposal" to Hash#to_s
  # z Ruby (np. {"proposal_status_id"=>2, "exam_fullname"=>"…"}) – albo JSON, gdy NETPAR przejdzie na JSON.
  # Zamieniamy składnię Ruby na JSON tylko poza tekstami (poprzednia wersja psuła komentarze zawierające „=>”).
  module Payload
    module_function

    def parse(raw)
      raw = raw.to_s
      data = JSON.parse(raw)
    rescue JSON::ParserError
      data = JSON.parse(ruby_hash_to_json(raw))
    ensure
      raise ArgumentError, "dane zgłoszenia nie są obiektem" unless data.nil? || data.is_a?(Hash)
    end

    def ruby_hash_to_json(text)
      out = +""
      in_string = false
      i = 0
      while i < text.length
        char = text[i]
        if in_string
          if char == "\\"
            following = text[i + 1].to_s
            out << ({ "#" => "#", "e" => "\\u001b" }[following] || "\\#{following}")
            i += 2
            next
          end
          in_string = false if char == '"'
          out << char
        elsif char == '"'
          in_string = true
          out << char
        elsif text[i, 2] == "=>"
          out << ":"
          i += 2
          next
        elsif text[i, 3] == "nil" && text[i - 1].to_s !~ /\w/ && text[i + 3].to_s !~ /\w/
          out << "null"
          i += 3
          next
        else
          out << char
        end
        i += 1
      end
      out
    end
  end
end
