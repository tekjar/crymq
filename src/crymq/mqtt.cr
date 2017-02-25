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


struct Connect
    @protocol : UInt8
    @keep_alive : UInt16
    @client_id : String
    @last_will : UInt8
    @username : String
    @password : String

    def initialize(@client_id, @keep_alive)
        @protocol = 4_u8
        @last_will = 0_u8
        @username = ""
        @password = ""
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

connect = Connect.new("hello", 10_u16)
puts connect

connack = Connack.new
puts connack

publish = Publish.new("a/b/c", QoS::AtleastOnce, "hello world".to_slice)
puts publish