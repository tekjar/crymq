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

class FixedHeader
    @packet_type : UInt8
    @flags : UInt8
    @remaining_len: UInt8

    def initialize(@packet_type)
    end

    def encode : UInt8
      fh = @packet_type << 4
      fh = fh | (@quality_of_service << 1)
      if @duplicate
        fh = fh | (1 << 3)
      end
      if @retained
        fh = fh | 1
      end
      fh
    end

end