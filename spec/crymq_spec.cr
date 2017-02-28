require "./spec_helper"

describe Crymq do
  it "connect packet write works" do
    socket = IO::Memory.new
    connect = Connect.new("hello", 10_u16)
    socket.write_bytes(connect, IO::ByteFormat::NetworkEndian)
    socket.to_slice.hexstring.should eq("101100044d5154540402000a000568656c6c6f")
  end
  it "connack packet write works" do
    socket = IO::Memory.new
    connack = Connack.new(true, 0_u8)
    socket.write_bytes(connack, IO::ByteFormat::NetworkEndian)
    socket.to_slice.hexstring.should eq("20020100")
  end
  it "publish packet write works" do
    socket = IO::Memory.new
    publish = Publish.new("hello/world", QoS::AtleastOnce, "hello world".to_slice, Pkid.new(100_u16))
    socket.write_bytes(publish, IO::ByteFormat::NetworkEndian)
    socket.to_slice.hexstring.should eq("321a000b68656c6c6f2f776f726c64006468656c6c6f20776f726c64")
  end
  it "puback packet write works" do
    socket = IO::Memory.new
    puback = Puback.new(Pkid.new(1000_u16))
    socket.write_bytes(puback, IO::ByteFormat::NetworkEndian)
    socket.to_slice.hexstring.should eq("400203e8")
  end
  it "subscribe packet write works" do
    socket = IO::Memory.new
    subscribe = Subscribe.new([{"hello/world", QoS::AtleastOnce}, {"hello/crystal", QoS::ExactlyOnce}], Pkid.new(100_u16))
    socket.write_bytes(subscribe, IO::ByteFormat::NetworkEndian)
    socket.to_slice.hexstring.should eq("82200064000b68656c6c6f2f776f726c6401000d68656c6c6f2f6372797374616c02")
  end
  it "suback packet write works" do
    socket = IO::Memory.new
    suback = Suback.new(Pkid.new(100_u16), [1_u8, 2_u8, 3_u8, 128_u8])
    socket.write_bytes(suback, IO::ByteFormat::NetworkEndian)
    socket.to_slice.hexstring.should eq("9006006401020380")
  end
end
