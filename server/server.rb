require "bundler/inline"

gemfile do
  gem "graphql", "1.13.6", path: "~/code/graphql-ruby"
  gem "graphql-pro", "1.21.1", path: "~/code/graphql-pro"
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
      sleep 0.5
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
      sleep 5
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
        # It seems like urql expects the first flush of data to include only this boundary marker:
        out << "---"

        deferred.deferrals.each_with_index do |deferral, idx|
          # This is a lot of fussing to try to replicate urql's format _exactly_ --
          # I think it's all unnecessary though, the extra `---` above was what made it start working.
          payload = {}
          payload["data"] = deferral.data
          if idx > 0
            payload["path"] = deferral.path
          end
          payload["hasNext"] = deferral.has_next?
          text = [
              "",
              "Content-Type: application/json; charset=utf-8",
              "",
              JSON.dump(payload),
              deferral.has_next? ? "---" : ""
          ].join("\r\n")
          puts Time.now.to_i
          puts text.inspect
          out << text
        end
      end
    else
      content_type :json
      result.to_json
    end
  end
end

App.run!
