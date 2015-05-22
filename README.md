# ElmFire

Use the Firebase API in Elm.

This is work in progress.
We aim to expose the complete [Firebase API](https://www.firebase.com/docs/web/).

## Constructing Firebase Locations

To refer to a Firebase location you need a `Location`.
Locations can be built with the following functions:

    -- Location is an opaque type.
    fromUrl  : String -> Location
    sub      : String -> Location -> Location
    parent   : Location -> Location
    root     : Location -> Location
    push     : Location -> Location
    location : Reference -> Location
            
These are all pure functions.
They don't touch a real Firebase until the resulting location is used in one of the tasks outlined below.

Example:

    location : Location
    location = fromUrl "https://elmfire.firebaseio-demo.com/test"
                 |> parent
                 |> sub "anotherTest"`
                 |> push

## References to Locations

Many actions on a Firebase location return a reference to that location in their results.
Likewise, query results contains a reference to the location of the reported value.

References can inform about the key or the complete URL of the referred location.
And a reference may be converted back to a location, which can be used for a new task.

Additionally, a location can be opened (without modifying or querying),
which results in a reference if the location is valid.
It's generally not necessary to explicitly open a constructed location,
but it may be used to check the location or to cache Firebase references.

    -- Reference is an opaque type
    key      : Reference -> String
    toUrl    : Reference -> String
    location : Reference -> Location
    open     : Location -> Task Error Reference

## Modifying Values

    set             : Value -> Location -> Task Error Reference
    setWithPriority : Value -> Priority -> Location -> Task Error Reference
    setPriority     : Priority -> Location -> Task Error Reference
    update          : Value -> Location -> Task Error Reference
    remove          : Location -> Task Error Reference

These tasks complete when synchronization to the Firebase servers has completed.
They result in a Reference to the modified location.
A task may result in an error if the location is invalid or you have no permission to modify the data.

Values are given as Json values, i.e. `Json.Encode.Value`.

Example:

    port write : Task Error ()
    port write = set (Json.Encode.string "foo") location
    
## Querying

Only basic querying is supported in this early version of ElmFire, so no filtering, no sorting, no `once`.

    subscribe : (Response -> Task x a) -> Query -> Location -> Task Error QueryId
    unsubscribe : QueryId -> Task Error ()
    
Use `subscribe` to start a querying the value(s) at a location. Query results are reported via running a supplied task.
 
The first parameter is a function used to construct that task from a response.
The second parameter specifies the event to listen to: `valueChanged`, `child added`, `child changed`, `child removed` or `child moved`.
The third parameter references the queried location.
On success the task returns a QueryId, which can be used to match the corresponding responses and to cancel the query.

    type Response = NoResponse | Data DataMsg | QueryCanceled QueryId String
    type alias DataMsg =
      { queryId: QueryId
      , key: String
      , reference: Reference
      , value: Maybe Value
      }

A response is either a `DataMsg` or a `QueryCanceled`.
A `DataMsg` carries the corresponding `QueryId` and `Just Value` for the Json value or `Nothing` if the location doesn't exist.
The `key` corresponds to the last part of the path. It is the empty string for the root.

Example:

    responses : Signal.Mailbox Response
    responses = Signal.mailbox NoResponse
    
    port query : Task Error QueryId
    port query = subscribe
                   (Signal.send responses.address)
                   valueChanged
                   (fromUrl "https:...firebaseio.com/...")
    
    ... = Signal.map
            (\response -> case response of
                Data dataMsg -> ...
                otherwise -> ...
            )
            responses.signal
    
Notes on a possible change of the API: The `key` field of `DataMsg` is redundant and may be dropped, as `reference` also contains the key.

## Example.elm

There is a very basic example app in `example/src/Example.elm`. To build it:

    cd example
    make all open
    
Alternatively without using `make`:

    cd example
    elm make --output Example.html src/Example.elm

Prior to building you may want to put your own Firebase URL in it.

## Test.elm

I started a testing app, living in `test/src`. It runs a given sequence of tasks on the Firebase API and logs these steps along with the query results.

There is a Makefile to build the app. On most Unix-like systems a `cd test; make all open` should do the trick.

## Future work

There are a lot of features I plan to add in the near future:

* Querying: `once`, filtering and sorting
* Transactions
* Authentication
* Better test app
* A nice example app

Also please take notice that the API is not stabilized yet. The exact interface may change a bit here and there.
