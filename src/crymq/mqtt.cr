require "./except"

## Fixed header for each MQTT control packet
##
## Format:
##
## ```plain
## 7                          3                          0
## +--------------------------+--------------------------+
## | MQTT Control Packet Type | Flags for each type      |
## +--------------------------+--------------------------+
## |                  Remaining Length                   |
## +-----------------------------------------------------+
## ```

MAX_PAYLOAD_SIZE = 268435455

abstract struct Control
    def initialize
    end

    def write_remaining_length(io : IO, remaining_len)
      
      if remaining_len > MAX_PAYLOAD_SIZE
        raise CryMqError.new("Payload too big")
      end

      loop do
        digit = (remaining_len % 128).to_u8
        remaining_len /= 128
        if remaining_len > 0
          digit |= 0x80_u8
        end
        io.write_byte(digit)
        if remaining_len == 0
          break
        end
      end
    end

    def write_mqtt_string(io : IO, s : String)
      io.write_bytes(s.bytesize.to_u16, IO::ByteFormat::NetworkEndian)
      s.each_byte { |x| io.write_byte(x) }
    end
end