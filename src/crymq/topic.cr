
class TopicError < Exception
end

struct Topic
    @topic: String

    def self.is_valid(topic : String)
      if topic == ""
        false
      else
        true
      end
    end

    def self.validate(topic : String)
      if is_valid(topic) == false
        raise TopicError.new("Invalid topic")
      end
    end

    def initialize(@topic)
      if is_valid(@topic) == false
        raise TopicError.new("Invalid topic")
      end
    end

    def to_s
      @topic
    end
end