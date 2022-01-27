require "bundler/inline"

gemfile do
  gem "graphql", "1.13.6"
  gem "graphql-pro", "1.21.1"
  gem "sinatra"
  gem "sinatra-contrib"
  gem "sinatra-cross_origin"
  gem "thin"
end

require "sinatra/streaming"

class Schema < GraphQL::Schema
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
  use GraphQL::Pro::Defer
  use GraphQL::Pro::Stream
  # use GraphQL::Dataloader, nonblocking: true
end

require "logger"

class App < Sinatra::Base
  set :port, 3004
  register Sinatra::CrossOrigin
  helpers Sinatra::Streaming

  configure do
    use Rack::CommonLogger, ::Logger.new(STDOUT)
  end

  before do
    response.headers['Access-Control-Allow-Origin'] = '*'
  end

  options "*" do
    response.headers["Allow"] = "GET, PUT, POST, DELETE, OPTIONS"
    response.headers["Access-Control-Allow-Headers"] = "Authorization, Content-Type, Accept, Transfer-Encoding"
    response.headers["Access-Control-Allow-Origin"] = "*"
    200
  end

  post "/graphql" do
    cross_origin
    params = JSON.parse(request.body.read)
    query_str = params["query"]
    query_str.gsub!("initial_count", "initialCount")

    variables = params["variables"]
    operation_name = params["operationName"]
    result = Schema.execute(
      query_str,
      variables: variables,
      operation_name: operation_name,
    )
    if (deferred = result.context[:defer])
      response.headers["Connection"] = "keep-alive"
      response.headers["Content-Type"] = "multipart/mixed; boundary=\"-\""
      # response.headers["Transfer-Encoding"] = "chunked"
      stream do |out|
        deferred.deferrals.each do |deferral|
          out << deferral.to_http_multipart
          sleep 0.1
        end
      end
    else
      content_type :json
      result.to_json
    end
  end
end

App.run!
