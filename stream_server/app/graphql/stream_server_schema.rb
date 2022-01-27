class StreamServerSchema < GraphQL::Schema
  class Alphabet < GraphQL::Schema::Object
    field :char, String

    def char
      # sleep 0.5
      object[:char]
    end
  end

  class Song < GraphQL::Schema::Object
    field :first_verse, String

    def first_verse
      "Now I know my ABC's."
    end

    field :second_verse, String

    def second_verse
      # sleep 5
      "Next time won't you sing with me"
    end
  end

  class Query < GraphQL::Schema::Object
    field :alphabet, [Alphabet]

    def alphabet
      ("A".."Z").map do |letter|
        { char: letter }
      end
    end

    field :song, Song

    def song
      "goodbye"
    end
  end

  query(Query)
  use GraphQL::Pro::Stream
  use GraphQL::Pro::Defer
end
