require "./mqtt"

enum PacketType : UInt8
    Connect     = 1
    Connack
    Publish
    Puback
    Pubrec
    Pubrel
    Pubcomp
    Subscribe
    Suback
    Unsubscribe
    Unsuback
    Pingreq
    Pingresp
    Disconnect
  end

  PROTO_NAME  = {0x00_u8, 0x04_u8, 0x4D_u8, 0x51_u8, 0x54_u8, 0x54_u8} #04MQTT
  PROTO_LEVEL = 4_u8

  alias Packet = Connect | Connack | Publish | Puback | Pubrec | Pubrel | Pubcomp | Suback | Suback | Unsubscribe | Unsuback

enum QoS: UInt8
    AtmostOnce = 0
    AtleastOnce
    ExactlyOnce
end

struct Pkid
    @pkid : UInt16

    def initialize(@pkid)
    end

    def reset
        @pkid = 0
    end

    def next
        @pkid += 1
    end
end

## Fixed header for CONNECT PACKET
##
## 7                          3                          0
## +--------------------------+--------------------------+
## |     CONNECT (1) NIBBLE   |     RESERVED             |   0
## +--------------------------+--------------------------+
## | Remaining Len = Len of Varable header(10) + Payload |   1
## +-----------------------------------------------------+
## 
##
## Variable header ( LENGTH = 10 Bytes)
##
## +--------------------------+--------------------------+
## |            PROTOCOL Name Length MSB (VALUE = 0)     |   2
## +-----------------------------------------------------+
## +--------------------------+--------------------------+
## |            PROTOCOL Name Length LSB (VALUE = 4)     |   3
## +-----------------------------------------------------+
## +--------------------------+--------------------------+
## |                          M                          |   4
## +-----------------------------------------------------+
## +--------------------------+--------------------------+
## |                          Q                          |   5
## +-----------------------------------------------------+
## +--------------------------+--------------------------+
## |                          T                          |   6
## +-----------------------------------------------------+
## +--------------------------+--------------------------+
## |                          T                          |   7
## +-----------------------------------------------------+
## +--------------------------+--------------------------+
## |         PROTOCOL LEVEL (VALUE = 4 for MQTT 3.1.1)   |   8
## +-----------------------------------------------------+
## +--------------------------+--------------------------+
## |  CONNECT FLAGS                                      |
## |  UN(1 bit), PW(1), WR(1), WQ(2), W(1), CS(1), R(1)  |   9
## +-----------------------------------------------------+
## +--------------------------+--------------------------+
## |                  KEEP ALIVE MSB                     |   10
## +-----------------------------------------------------+
## +--------------------------+--------------------------+
## |                  KEEP ALIVE LSB                     |   11
## +-----------------------------------------------------+
##
##
## Payload: Set these optionals depending on CONNECT flags in variable header
##
##     2 bytes client id length + client id
##     +
##     2 bytes len of will topic +  will topic
##     +
##     2 bytes len of will payload +  will payload
##     +
##     2 bytes len of username +  username
##     +
##     2 bytes len of password +  password
##
struct Connect < Control
    #TODO: Implement last will
    @keep_alive : UInt16
    @client_id : String
    @username : String
    @password : String
    @clean_session: Bool

    #TODO: Generate random client id
    def initialize(@client_id = "", @keep_alive = 30_u16, @clean_session = true, @username = "", @password = "")
    end

    def to_io(io : IO, format : IO::ByteFormat = IO::ByteFormat::SystemEndian)
      remaining_len = 10

      if !@client_id.empty?
        remaining_len += 2 + @client_id.bytesize
      end

      if !@username.empty?
        remaining_len += 2 + @username.bytesize
      end

      if !@password.empty?
        remaining_len += 2 + @password.bytesize
      end

      flags = 0_u8
      if @clean_session
        flags |= 0x02
      end
      if !@username.empty?
        flags |= 0x80
      end
      if !@password.empty?
        flags |= 0x40
      end

      io.write_byte(0x10_u8)
      write_remaining_length(io, remaining_len)
      PROTO_NAME.each { |x| io.write_byte(x) }
      io.write_byte(PROTO_LEVEL)
      io.write_byte(flags)
      io.write_byte((@keep_alive >> 8).to_u8)
      io.write_byte(@keep_alive.to_u8)

      if !@client_id.empty?
        write_mqtt_string(io, @client_id)
      end

      if !@username.empty?
        write_mqtt_string(io, @username)
      end

      if !@password.empty?
        write_mqtt_string(io, @password)
      end
    end
end

struct Connack
    @session_present : Bool
    @return_code : UInt8

    def initialize
        @session_present = false
        @return_code = 0_u8
    end
end

struct Publish
    @qos: QoS
    @dup: Bool
    @retain: Bool
    @topic: String
    @pkid: Pkid
    @payload: Bytes

    def initialize(@topic, @qos, @payload)
        @dup = false
        @retain = false
        @pkid = Pkid.new(0_u16)
    end
end

struct Puback
    @pkid: Pkid

    def initialize(@pkid)
    end
end

struct Pubrec
    @pkid: Pkid

    def initialize(@pkid)
    end
end

struct Pubrel
    @pkid: Pkid

    def initialize(@pkid)
    end
end

struct Pubcomp
    @pkid: Pkid

    def initialize(@pkid)
    end
end

struct Subscribe
    @topic: String
    @qos: QoS
    @pkid: Pkid

    def initialize(@topic, @qos)
        @pkid = Pkid.new(0_u16)
    end
end

struct Suback
    @pkid : Pkid
    @return_code : UInt8

    def initialize
        @pkid = 0_u8
        @return_code = 0_u8
    end
end

struct Unsubscribe
    @topic: String
    @pkid: Pkid

    def initialize(@topic)
        @pkid = Pkid.new(0_u16)
    end
end

struct Unsuback
    @pkid: Pkid

    def initialize(@pkid)
    end
end

require "socket"
socket = TCPSocket.new("localhost", 1883)
#socket = IO::Memory.new
connect = Connect.new("hello", 10_u16)
puts connect
socket.write_bytes(connect, IO::ByteFormat::NetworkEndian)
sleep 5
# puts connect

# connack = Connack.new
# puts connack

# publish = Publish.new("a/b/c", QoS::AtleastOnce, "hello world".to_slice)
# puts publish