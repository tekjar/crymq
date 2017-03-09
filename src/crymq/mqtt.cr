require "./topic"

PROTO_NAME  = {0x00_u8, 0x04_u8, 0x4D_u8, 0x51_u8, 0x54_u8, 0x54_u8} #04MQTT
PROTO_LEVEL = 4_u8
MAX_PAYLOAD_SIZE = 268435455

class MqttError < Exception
end

enum QoS: UInt8
    AtmostOnce = 0
    AtleastOnce
    ExactlyOnce

    def self.from_num(num : UInt8)
      begin
        self.from_value(num)
      rescue
        raise MqttError.new("Invalid QoS. QoS can only be 0, 1 or 2")
      end
    end
end

struct Pkid
    @pkid : UInt16

    def initialize(@pkid)
    end

    def value
      @pkid
    end

    def reset
        @pkid = 0_u16
    end

    def next
        @pkid += 1_u16
    end
end

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

abstract struct Control
    def initialize
    end

    def write_remaining_length(io : IO, remaining_len)
      if remaining_len > MAX_PAYLOAD_SIZE
        raise MqttError.new("Payload too big")
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


## Fixed header for CONNACK PACKET
##
## 7                          3                          0
## +--------------------------+--------------------------+
## |     CONNACK (2) NIBBLE   |     RESERVED             |   0
## +--------------------------+--------------------------+
## |    Remaining Len = Len of Varable header(2)         |   1
## +-----------------------------------------------------+
## 
##
## Variable header ( LENGTH = 2 Bytes)
##
## +--------------------------+--------------------------+
## |   Reserved bits 1-7 must be set to 0 (0b0000 0000x) |   2
## |   Bit 0 is 'session present' flag                   |
## +-----------------------------------------------------+
## +--------------------------+--------------------------+
## |                  Connect Return Code                |   3
## +-----------------------------------------------------
struct Connack < Control
    @session_present : Bool
    @return_code : UInt8

    def initialize(@session_present, @return_code)
    end

    def to_io(io : IO, format : IO::ByteFormat = IO::ByteFormat::SystemEndian)
      frame = UInt8.slice(0x20, 0x02, @session_present ? 1_u8:0_u8, @return_code.to_u8)
      io.write(frame)
    end
end

## Fixed header for PUBLISH PACKET
##
## 7                          3                          0
## +--------------------------+--------------------------+
## |     PUBLISH (3) NIBBLE   | DUP(1), QoS(2), Retain(1)|   0
## +--------------------------+--------------------------+
## |    Remaining Len = Len of Variable header + Payload |   1
## +-----------------------------------------------------+
## 
##
## Variable header ( LENGTH = 2 Bytes)
##
## +--------------------------+--------------------------+
## |            TOPIC Name Length MSB (VALUE = 0)        |   2
## +-----------------------------------------------------+
## +--------------------------+--------------------------+
## |            TOPIC Name Length LSB (VALUE = 4)        |   3
## +-----------------------------------------------------+
##
##                          TOPIC
##
## Payload: Set these optionals
## +--------------------------+--------------------------+
## |                 Packet Identifier MSB               |   n
## +-----------------------------------------------------+
## +--------------------------+--------------------------+
## |                 Packet Identifier LSB               |   n + 1
## +-----------------------------------------------------+
##
## Application payload
#
struct Publish < Control
    @qos: QoS
    @dup: Bool
    @retain: Bool
    @topic: String
    @pkid: Pkid
    @payload: Bytes

    def initialize(@topic, @qos, @payload, @pkid, @retain = false, @dup = false)
      Topic.validate(@topic)
    end

    def to_io(io : IO, format : IO::ByteFormat = IO::ByteFormat::SystemEndian)
      remaining_len = 2 + @topic.bytesize + @payload.bytesize

      if @qos != QoS::AtmostOnce
        remaining_len += 2
      end

      io.write_byte(0x30_u8 | (@retain? 1_u8:0_u8) | @qos.value << 1 | (@dup? 1_u8:0_u8) << 3)
      write_remaining_length(io, remaining_len)
      write_mqtt_string(io, @topic)

      if @qos != QoS::AtmostOnce
        io.write_byte((@pkid.value >> 8).to_u8)
        io.write_byte(@pkid.value.to_u8)
      end

      io.write(@payload)
    end
end


## Fixed header for PUBACK/PUBREC/PUBCOMP/PUBREL PACKET
##
## 7                          3                          0
## +--------------------------+--------------------------+
## |         ACK (1) NIBBLE   |     RESERVED             |   0
## +--------------------------+--------------------------+
## |    Remaining Len = Len of Varable header(2)         |   1
## +-----------------------------------------------------+
## 
## Variable header ( LENGTH = 2 Bytes)
##
## +--------------------------+--------------------------+
## |                 Packet Identifier MSB               |   2
## +-----------------------------------------------------+
## +--------------------------+--------------------------+
## |                 Packet Identifier LSB               |   3
## +-----------------------------------------------------+
#
struct Puback
    @pkid: Pkid

    def initialize(@pkid)
    end

    def to_io(io : IO, format : IO::ByteFormat = IO::ByteFormat::SystemEndian)
      frame = UInt8.slice(0x40, 0x02)
      io.write(frame)
      io.write_byte((@pkid.value >> 8).to_u8)
      io.write_byte(@pkid.value.to_u8)
    end
end

struct Pubrec
    @pkid: Pkid

    def initialize(@pkid)
    end

    def to_io(io : IO, format : IO::ByteFormat = IO::ByteFormat::SystemEndian)
      frame = UInt8.slice(0x50, 0x02)
      io.write(frame)
      io.write_byte((@pkid.value >> 8).to_u8)
      io.write_byte(@pkid.value.to_u8)
    end
end

struct Pubrel
    @pkid: Pkid

    def initialize(@pkid)
    end

    def to_io(io : IO, format : IO::ByteFormat = IO::ByteFormat::SystemEndian)
      frame = UInt8.slice(0x62, 0x02)
      io.write(frame)
      io.write_byte((@pkid.value >> 8).to_u8)
      io.write_byte(@pkid.value.to_u8)
    end
end

struct Pubcomp
    @pkid: Pkid

    def initialize(@pkid)
    end

    def to_io(io : IO, format : IO::ByteFormat = IO::ByteFormat::SystemEndian)
      frame = UInt8.slice(0x70, 0x02)
      io.write(frame)
      io.write_byte((@pkid.value >> 8).to_u8)
      io.write_byte(@pkid.value.to_u8)
    end
end

## Fixed header for SUBSCRIBE PACKET
##
## 7                          3                          0
## +--------------------------+--------------------------+
## |   SUBSCRIBE (8) NIBBLE   |     RESERVED             |   0
## +--------------------------+--------------------------+
## | Remaining Len = Len of Variable header(2) + Payload |   1
## +-----------------------------------------------------+
## 
##
## Variable header ( LENGTH = 2 Bytes)
##
## +--------------------------+--------------------------+
## |                 Packet Identifier MSB               |   2
## +-----------------------------------------------------+
## +--------------------------+--------------------------+
## |                 Packet Identifier LSB               |   3
## +-----------------------------------------------------+
##
## Payload: Set these optionals
##
##     2 bytes subscribe topic length + subscribe topic + 1 byte qos
##
##     ... for all the topics
##
struct Subscribe < Control
    @topics: Array({String, QoS})
    @pkid: Pkid

    def initialize(@topics, @pkid)
      @topics.each do |topic, qos|
        Topic.validate(topic)
      end
    end

    def to_io(io : IO, format : IO::ByteFormat = IO::ByteFormat::SystemEndian)
      remaining_len = 2 + @topics.map { |s| s[0].size + 3 }.sum
      io.write_byte(0x82_u8)
      io.write_byte(remaining_len.to_u8)
      io.write_byte((@pkid.value >> 8).to_u8)
      io.write_byte(@pkid.value.to_u8)

      @topics.each do |s|
        write_mqtt_string(io, s[0])
        io.write_byte(s[1].to_u8)
      end
    end
end


## Fixed header for SUBACK PACKET
##
## 7                          3                          0
## +--------------------------+--------------------------+
## |     PUBLISH (9) NIBBLE   | DUP(1), QoS(2), Retain(1)|   0
## +--------------------------+--------------------------+
## | Remaining Len = Len of Variable header(10) + Payload|   1
## +-----------------------------------------------------+
## 
##
## Variable header ( LENGTH = 2 Bytes)
##
## +--------------------------+--------------------------+
## |                  Packet Identifier MSB              |   2
## +-----------------------------------------------------+
## +--------------------------+--------------------------+
## |                  Packet Identifier LSB              |   3
## +-----------------------------------------------------+
##
##
## PAYLOAD (RETURN CODES)
## +--------------------------+--------------------------+
## |                 PAYLOAD BYTE 0 FOR SUB 0            |   n
## +-----------------------------------------------------+
## +--------------------------+--------------------------+
## |                 PAYLOAD BYTE 1 FOR SUB 1            |   n + 1
## +-----------------------------------------------------+
##                          ....
##                          ....
## +--------------------------+--------------------------+
## |                 PAYLOAD BYTE N FOR SUB N            |   n + N
## +-----------------------------------------------------+

struct Suback
    @pkid : Pkid
    @return_codes : Array(UInt8)

    def initialize(@pkid, @return_codes)
    end

    def to_io(io : IO, format : IO::ByteFormat = IO::ByteFormat::SystemEndian)
      remaining_len = 2 + @return_codes.size
      io.write_byte(0x90_u8)
      io.write_byte(remaining_len.to_u8)

      io.write_byte((@pkid.value >> 8).to_u8)
      io.write_byte(@pkid.value.to_u8)
      
      @return_codes.each do |r|
        io.write_byte(r)
      end
    end
end

struct Unsubscribe
    @topics: Array(String)
    @pkid: Pkid

    def initialize(@topics, @pkid)
    end

    def to_io(io : IO, format : IO::ByteFormat = IO::ByteFormat::SystemEndian)
      remaining_len = 2 + @topics.map { |s| s[0].size + 2 }.sum
      io.write_byte(0xA2_u8)
      io.write_byte(remaining_len.to_u8)
      io.write_byte((@pkid.value >> 8).to_u8)
      io.write_byte(@pkid.value.to_u8)

      @topics.each do |s|
        write_mqtt_string(io, s)
      end
    end
end

struct Unsuback
    @pkid: Pkid

    def initialize(@pkid)
    end

    def to_io(io : IO, format : IO::ByteFormat = IO::ByteFormat::SystemEndian)
      frame = UInt8.slice(0xB0, 0x02)
      io.write(frame)
      io.write_byte((@pkid.value >> 8).to_u8)
      io.write_byte(@pkid.value.to_u8)
    end
end

struct Pingreq
    def initialize
    end

    def to_io(io : IO, format : IO::ByteFormat = IO::ByteFormat::SystemEndian)
      frame = UInt8.slice(0xC0, 0x00)
      io.write(frame)
    end
end

struct Pingresp
    def initialize
    end

    def to_io(io : IO, format : IO::ByteFormat = IO::ByteFormat::SystemEndian)
      frame = UInt8.slice(0xD0, 0x00)
      io.write(frame)
    end
end

struct Disconnect
    def initialize
    end

    def to_io(io : IO, format : IO::ByteFormat = IO::ByteFormat::SystemEndian)
      frame = UInt8.slice(0xE0, 0x00)
      io.write(frame)
    end
end



enum Packet : UInt8
  Connect = 1
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

  def self.from_num(num : UInt8)
    begin
      self.from_value(num)
    rescue
      raise MqttError.new("Unsupported packet received")
    end
  end
end

struct Mqtt
  def initialize
  end

  # TODO: Raise exeception for malformed remaining length
  def self.read_remaining_length(io : IO)
      remaining_length = 0_u32
      multiplier = 0_u32
      loop do
        if digit = io.read_byte
          remaining_length |= (digit & 127) << multiplier
          if (digit & 128) == 0
            return remaining_length.to_i
          end
          multiplier += 7
        end
      end
  end

  def self.read_mqtt_string(io : IO)
    len = io.read_bytes(UInt16, IO::ByteFormat::BigEndian)
    data = Bytes.new(len)
    io.read_fully(data)
    String.new(data)
  end

  def self.from_io(io : IO, format : IO::ByteFormat = IO::ByteFormat::SystemEndian)
      header = io.read_byte.not_nil!
      remaining_len = read_remaining_length(io)
      pkt_type = Packet.from_num(header >> 4)
      hflags = header & 0x0F
      
      if remaining_len == 0
        case pkt_type
        when Packet::Pingreq
          return Pingreq.new
        when Packet::Pingresp
          return Pingresp.new
        when Packet::Disconnect
          return Disconnect.new
        else
          raise MqttError.new("Invalid packet received")
        end
      end

      #TODO: Replace `not_nil` with custom exception
      #TODO: Split to smaller methods
      case pkt_type   
      when Packet::Connect
        protocol = read_mqtt_string(io)    
        level = io.read_byte.not_nil!      
        connect_flags = io.read_byte.not_nil!
        keep_alive = io.read_bytes(UInt16, IO::ByteFormat::BigEndian)   
        client_id = read_mqtt_string(io)
        clean_session = (connect_flags & 0b10 != 0)? true : false
        username = (connect_flags & 0b10000000 == 0)? "" : read_mqtt_string(io)
        password = (connect_flags & 0b01000000 == 0)? "" : read_mqtt_string(io)

        Connect.new(client_id, keep_alive, clean_session, username, password)
      
      when Packet::Connack
        if remaining_len != 2
          raise MqttError.new("Incorrect payload size")
        end
        flags = io.read_byte.not_nil!
        return_code = io.read_byte.not_nil!

        Connack.new((flags & 0x01) == 1, return_code)
     
      when Packet::Publish
        topic = read_mqtt_string(io)
        retain = (hflags & 0x01) == 1
        qos = (hflags & 0x06) >> 1
        dup = (hflags & 0x08) == 8
        pkid = (qos == 0)? 0_u16 : io.read_bytes(UInt16, IO::ByteFormat::BigEndian)

        payload_size = (qos == 0)? remaining_len - 2 - topic.bytesize : remaining_len - 2 - topic.bytesize - 2
        payload = Bytes.new(payload_size)
        io.read_fully(payload)
        
        qos = QoS.from_num(qos)

        Publish.new(topic, qos, payload, Pkid.new(pkid))
      
      when Packet::Puback
        if remaining_len != 2
          raise MqttError.new("Incorrect payload size")
        end
        pkid = io.read_bytes(UInt16, IO::ByteFormat::BigEndian)
        
        Puback.new(Pkid.new(pkid))
      
      when Packet::Pubrec
        if remaining_len != 2
          raise MqttError.new("Incorrect payload size")
        end
        pkid = io.read_bytes(UInt16, IO::ByteFormat::BigEndian)
        
        Pubrec.new(Pkid.new(pkid))
      
      when Packet::Pubrel
        if remaining_len != 2
          raise MqttError.new("Incorrect payload size")
        end
        pkid = io.read_bytes(UInt16, IO::ByteFormat::BigEndian)
        
        Pubrel.new(Pkid.new(pkid))
      
      when Packet::Pubcomp
        if remaining_len != 2
          raise MqttError.new("Incorrect payload size")
        end
        pkid = io.read_bytes(UInt16, IO::ByteFormat::BigEndian)
        
        Pubcomp.new(Pkid.new(pkid))
      
      when Packet::Subscribe
        pkid = io.read_bytes(UInt16, IO::ByteFormat::BigEndian)
        topics = [] of {String, QoS}

        remaining_bytes = remaining_len - 2
        while remaining_bytes > 0
          topic = read_mqtt_string(io)
          qos = io.read_byte.not_nil!
          remaining_bytes -= topic.bytesize  + 3
          topics.push({topic, QoS.from_value(qos)})
        end

        Subscribe.new(topics, Pkid.new(pkid))
      
      when Packet::Suback
        pkid = io.read_bytes(UInt16, IO::ByteFormat::BigEndian)
        return_codes = [] of UInt8

        remaining_bytes = remaining_len - 2
        while remaining_bytes > 0
          return_code = io.read_byte.not_nil!
          remaining_bytes -= 1
          return_codes.push(return_code)
        end
        Suback.new(Pkid.new(pkid), return_codes)
      
      when Packet::Unsubscribe
        pkid = io.read_bytes(UInt16, IO::ByteFormat::BigEndian)
        topics = [] of String

        remaining_bytes = remaining_len - 2
        while remaining_bytes > 0
          topic = read_mqtt_string(io)
          remaining_bytes -= topic.bytesize  + 2
          topics.push(topic)
        end

        Unsubscribe.new(topics, Pkid.new(pkid))
      
      when Packet::Unsuback
        if remaining_len != 2
          raise MqttError.new("Incorrect payload size")
        end
        pkid = io.read_bytes(UInt16, IO::ByteFormat::BigEndian)
        
        Unsuback.new(Pkid.new(pkid))
      
      when Packet::Pingreq, Packet::Pingresp, Packet::Disconnect
        raise MqttError.new("Incorrect packet format")
      else
          raise MqttError.new("Invalid packet received")
      end
    end
end