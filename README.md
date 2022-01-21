This is a copy of `urql`'s stream example, with the server ported to ruby (`server/server.rb`)

Install dependencies:

```
yarn install
```

To start the javascript server:

```
yarn run start
```

Or, to start the Ruby server:

```
yarn run startruby
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
- This took me forever to figure out:

  Ruby sends a leading boundary (`---`) as part of the first patch. This is in the spec: there should be a boundary between the preamble part (with nothing in it, afaict) and the first patch.

  At first, running the demo with Ruby server always looked "one patch behind." That is, the server would send the first patch, but nothing would render. Then it would send the second patch, and the first patch would render, then send the third patch, and the second patch would render. Weird!

  I was fussing and fussing over trying to make the Ruby server _exactly_ like the Javascript one. Finally, I noticed that the JS server has a `res.write("---")` before any patches, so I added that to the Ruby server (and removed that boundary from the first patch) and now it seems to work right.

  So it seems like `urql` assumes that each flush of data from the server will contain exactly one patch.
