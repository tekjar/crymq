require "./spec_helper"

describe Crymq do
  it "checks connect packet encoding and decoding" do
    socket = IO::Memory.new
    connect = Connect.new("hello", 10_u16)
    socket.write_bytes(connect, IO::ByteFormat::NetworkEndian)
    socket.to_slice.hexstring.should eq("101100044d5154540402000a000568656c6c6f")

    # The cursor is still after the written data. There are no two cursors for
    # reading and writing, there's only one for both. Use #rewind before reading it back
    socket.rewind
    c = socket.read_bytes(Mqtt, IO::ByteFormat::NetworkEndian)
    c.class.should eq(Connect)
    c.should eq(connect)
  end
  it "checks connack packet encoding and decoding" do
    socket = IO::Memory.new
    connack = Connack.new(true, 0_u8)
    socket.write_bytes(connack, IO::ByteFormat::NetworkEndian)
    socket.to_slice.hexstring.should eq("20020100")

    # The cursor is still after the written data. There are no two cursors for
    # reading and writing, there's only one for both. Use #rewind before reading it back
    socket.rewind
    ca = socket.read_bytes(Mqtt, IO::ByteFormat::NetworkEndian)
    ca.class.should eq(Connack)
    puts ca, connack
    #TODO: Fix this
    ca.should eq(connack)
  end
  it "checks publish packet encoding and decodings" do
    socket = IO::Memory.new
    publish = Publish.new("hello/world", QoS::AtleastOnce, "hello world".to_slice, Pkid.new(100_u16))
    socket.write_bytes(publish, IO::ByteFormat::NetworkEndian)
    socket.to_slice.hexstring.should eq("321a000b68656c6c6f2f776f726c64006468656c6c6f20776f726c64")

    socket.rewind
    pub = socket.read_bytes(Mqtt, IO::ByteFormat::NetworkEndian)
    pub.class.should eq(Publish)
    pub.should eq(publish)
  end
  it "checks puback packet encoding and decoding" do
    socket = IO::Memory.new
    puback = Puback.new(Pkid.new(1000_u16))
    socket.write_bytes(puback, IO::ByteFormat::NetworkEndian)
    socket.to_slice.hexstring.should eq("400203e8")

    socket.rewind
    puba = socket.read_bytes(Mqtt, IO::ByteFormat::NetworkEndian)
    puba.class.should eq(Puback)
    puba.should eq(puback)
  end
  it "checks subscribe packet encoding and decoding" do
    socket = IO::Memory.new
    subscribe = Subscribe.new([{"hello/world", QoS::AtleastOnce}, {"hello/crystal", QoS::ExactlyOnce}], Pkid.new(100_u16))
    socket.write_bytes(subscribe, IO::ByteFormat::NetworkEndian)
    socket.to_slice.hexstring.should eq("82200064000b68656c6c6f2f776f726c6401000d68656c6c6f2f6372797374616c02")

    socket.rewind
    sub = socket.read_bytes(Mqtt, IO::ByteFormat::NetworkEndian)
    sub.class.should eq(Subscribe)
    sub.should eq(subscribe)
  end
  it "checks suback packet encoding and decoding" do
    socket = IO::Memory.new
    suback = Suback.new(Pkid.new(100_u16), [1_u8, 2_u8, 3_u8, 128_u8])
    socket.write_bytes(suback, IO::ByteFormat::NetworkEndian)
    socket.to_slice.hexstring.should eq("9006006401020380")

    socket.rewind
    suba = socket.read_bytes(Mqtt, IO::ByteFormat::NetworkEndian)
    suba.class.should eq(Suback)
    suba.should eq(suback)
  end
  it "checks pingreq packet encoding and decoding" do
    socket = IO::Memory.new
    pingreq = Pingreq.new
    socket.write_bytes(pingreq, IO::ByteFormat::NetworkEndian)
    socket.to_slice.hexstring.should eq("c000")

    socket.rewind
    pingr = socket.read_bytes(Mqtt, IO::ByteFormat::NetworkEndian)
    pingr.class.should eq(Pingreq)
    pingr.should eq(pingreq)
  end
  it "checks pingreq packet encoding and decoding" do
    socket = IO::Memory.new
    pingresp = Pingresp.new
    socket.write_bytes(pingresp, IO::ByteFormat::NetworkEndian)
    socket.to_slice.hexstring.should eq("d000")

    socket.rewind
    pingr = socket.read_bytes(Mqtt, IO::ByteFormat::NetworkEndian)
    pingr.class.should eq(Pingresp)
    pingr.should eq(pingresp)
  end
  it "checks disconnect packet encoding and decoding" do
    socket = IO::Memory.new
    disconnect = Disconnect.new
    socket.write_bytes(disconnect, IO::ByteFormat::NetworkEndian)
    socket.to_slice.hexstring.should eq("e000")

    socket.rewind
    disc = socket.read_bytes(Mqtt, IO::ByteFormat::NetworkEndian)
    disc.class.should eq(Disconnect)
    disc.should eq(disconnect)
  end
  it "check invalid qos" do
    expect_raises(CryMqError, "Invalid QoS. QoS can only be 0, 1 or 2") do
      QoS.from_num(10_u8)
    end
  end
  it "check publish packet contains payload" do
    socket = IO::Memory.new
    socket.write_bytes(0x32000000, IO::ByteFormat::BigEndian)
    socket.rewind
    
    expect_raises(CryMqError, "Invalid packet received") do
      socket.read_bytes(Mqtt, IO::ByteFormat::NetworkEndian)
    end
  end
  it "recognize unsupported packets" do
    socket = IO::Memory.new
    socket.write_bytes(0xF2000000, IO::ByteFormat::BigEndian)
    socket.rewind
    
    expect_raises(CryMqError, "Unsupported packet received") do
      socket.read_bytes(Mqtt, IO::ByteFormat::NetworkEndian)
    end
  end
  it "check invalid payload size in puback packet" do
    socket = IO::Memory.new
    socket.write_bytes(0x43111111, IO::ByteFormat::BigEndian)
    socket.rewind
    
    expect_raises(CryMqError, "Incorrect payload size") do
      socket.read_bytes(Mqtt, IO::ByteFormat::NetworkEndian)
    end
  end
  it "check for invalis publish and subscribe topic" do
    expect_raises(TopicError, "Invalid topic") do
      Publish.new("", QoS::AtleastOnce, "hello world".to_slice, Pkid.new(100_u16))
    end

    expect_raises(TopicError, "Invalid topic") do
      Subscribe.new([{"", QoS::AtleastOnce}, {"hello/crystal", QoS::ExactlyOnce}], Pkid.new(100_u16))
    end
  end
end
