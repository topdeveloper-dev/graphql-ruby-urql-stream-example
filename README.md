This is a copy of `urql`'s stream example, with the server ported to Sinatra (`server/server.rb`) and Rails `stream_server/`

Install dependencies:

```
yarn install
```

To start the javascript server:

```
yarn run start
```

Or, to start the Sinatra server:

```
yarn run startruby
```

Or, to start the Rails server:

```
cd stream_server
rails server
# Run the JS client separately as described below
```

Alternatively, start the client with `yarn run vite`, then start the JS server with `node server/index.js` or the Ruby server with `ruby server/server.rb`.

### Caveats

There are some differences between the Ruby server's behavior and the JS server.

- Most notably, the JS server runs multiple "setTimeout" waits at the same time, so `secondVerse` arrives in the middle of the stream of letters. Ruby, on the other hand, runs one `sleep` at a time, so letters must pause while `secondVerse` is sleeping. This could probably be improved by `use GraphQL::Dataloader, nonblocking: true`, and re-working those fields to use Dataloader sources.
- _Where_ the `alphabet` field pauses is slightly different. The JS server uses an iterator-type pattern and pauses _while_ enumerating the alphabet. Ruby, on the other hand, pauses before the `char` field.

  In my opinion, this is the right approach to `@stream` in a Ruby/Rails context. Consider a list of items fetched from ActiveRecord: the whole list is returned at once, after a pause (waiting for the SQL query to return). At that point, you'd want to return the results for _each item_ separately. That is, if each item has many selections on it, you'd want to run those "sub-queries" independently.

  (You _could_ get a different behavior by using `@defer` on the list. This _exclude_ the list from the initial response, sending the whole selection in one patch later.)

  Maybe I'm wrong -- is there an advantage in a Ruby/Rails context to supporting pauses _between_ list items? If so, I bet the use of `.each` in `lib/graphql/execution/interpreter/runtime.rb` could be expanded to properly support Ruby enumerators.
- Weirdly, Sinatra doesn't work right with this example when you set `Transfer-Encoding: chunked` in Ruby -- can't figure out why.
