# ElmFire

Use the Firebase API in Elm.

This is work in progress. We aim to expose the complete [Firebase API](https://www.firebase.com/docs/web/). Currently only basic value setting and removing are supported as well as querying without filtering and sorting.

## Constructing Firebase References

To refer to a Firebase location you need a `Location`, which can be built by the following functions:

`fromUrl: String -> Location` Construct a new reference from a full Firebase URL.

`sub: String -> Location -> Location` Go down a path from a given location to a descendant location.

`parent: Location -> Location` Go up to the parent location.

Example:

    location : Location
    location = fromUrl "https://elmfire.firebaseio-demo.com/test"
                 |> parent
                 |> sub "anotherTest"`

These three function are pure. They don't touch a real Firebase until they are used in one of the tasks outlined below.

## Writing a Value

`set : Value -> Location -> Task Error ()` Write a Json value to the referenced Firebase location.

The task completes with `()` when synchronization to the Firebase servers has completed. The task may result in an error if the location is invalid or you have no permission to write the data.

Example:

    port write : Task Error ()
    port write = set (Json.Encode.string "foo") location
    
`remove : Location -> Task Error ()` Remove the data at the referenced Firebase location.

## Querying a Location

`subscribe : Address Response -> Query -> Location -> Task Error QueryId` Start a query for the value of the location. On success the task returns a QueryId, which can be used to match the corresponding responses.

The first parameter is the address of a mailbox that receives the responses.

The second parameter specifies the event to listen to: `valueChanged`, `child added`, `child changed`, `child removed` or `child moved`.

The third parameter references the queried location.

`type Response = NoResponse | Data DataMsg | QueryCanceled QueryId String`

`type alias DataMsg = { queryId: QueryId, key: String, value: Maybe Value }`

A response is either a `DataMsg` or a `QueryCanceled`.

A `DataMsg` carries the corresponding `QueryId` and `Just Value` for the Json value or `Nothing` if the location doesn't exist. The `key` corresponds to the last part of the path. It is the empty string for the root.

Example:

    responses : Signal.Mailbox Response
    responses = Signal.mailbox NoResponse
    
    port query : Task Error QueryId
    port query = subscribe responses.address valueChanged location
    
    ... = Signal.map
            (\response -> case response of
                Data dataMsg -> ...
                otherwise -> ...
            )
            responses.signal
    
See `Example.elm` for working code that handles `responses`.

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

* Writing to Firebase: `push`, `update`
* Querying: `once`, filtering and sorting
* Authentication
* Better test app
* A nice example app

Also please take notice that the API is not stabilized yet. The exact interface may change a bit here and there.
