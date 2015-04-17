# ElmFire

Use the Firebase API in Elm.

This is work in progress. We aim to offer the complete functionality of the [Firebase API](https://www.firebase.com/docs/web/). Currently only basic value setting and querying are implemented.

## Constructing Firebase References

To refer to a Firebase location you need a `Ref`, which can be built by the following functions:

`location: String -> Ref` Construct a new reference from a full Firebase URL.

`child: String -> Ref -> Ref` Go down a path from a given location to a descendant location.

`parent: Ref -> Ref` Go up to the parent location.

Example:

    ref : Ref
    ref = location "https://elmfire.firebaseio-demo.com/test"
            |> parent
            |> child "anotherTest"`

These three function are pure. They don't touch a real Firebase until they are used in one of the tasks outlined below.

## Writing a Value

`set : Value -> Ref -> Task Error ()` Write a Json value to the referenced Firebase location.

The task completes with `()` when synchronization to the Firebase servers has completed. The task may result in an error if the ref is invalid or you have no permission to write the data.

Example:

    port write : Task Error ()
    port write = set (Json.Encode.string "foo") ref
    
## Querying a Location

`subscribe : Query -> Ref -> Task Error QueryId` Start a query for the value of the location. On success the task returns a QueryId, which can be used to match the corresponding responses.

The first parameter supports currently only the constant `valueChanged`. In later version there will be more query types like `child added` and so on.

All query responses a reported through the signal `responses`:

`responses : Signal Response`

`type Response = NoResponse | Data DataMsg | QueryCanceled QueryId String`

`type alias DataMsg = { queryId: QueryId, value: Maybe Value }`

A response is either a `DataMsg` or a `QueryCanceled`.
A `DataMsg` carries the corresponding `QueryId` and `Just Value` for the Json value or `Nothing` if the location doesn't exist.

Example:

    port query : Task Error QueryId
    port query = subscribe valueChanged ref
    
    ... = Signal.map
            (\response -> case response of
                Data dataMsg -> ...
                otherwise -> ...
            )
            responses
    
See `Example.elm` for working code that handles `responses`.

## Example.elm

There is a very basic example app. To build it:

    elm-package install evancz/elm-html 3.0.0
    elm-make --output Example.html Example.elm

Prior to building you may want to put your own Firebase URL in it.