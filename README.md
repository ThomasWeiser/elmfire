# ElmFire

Use the Firebase API in Elm.

This is work in progress.
We aim to expose the complete [Firebase API](https://www.firebase.com/docs/web/).

## Constructing Firebase Locations

To refer to a Firebase path you need a `Location`.
Locations can be built with the following functions:

```elm
-- Location is an opaque type.
fromUrl  : String -> Location
sub      : String -> Location -> Location
parent   : Location -> Location
root     : Location -> Location
push     : Location -> Location
location : Reference -> Location
```
            
These are all pure functions.
They don't touch a real Firebase until the resulting location is used in one of the tasks outlined below.

Example:

```elm
location : Location
location = 
  fromUrl "https://elmfire.firebaseio-demo.com/test"
    |> parent
    |> sub "anotherTest"`
    |> push
```

## References to Locations

Most actions on a Firebase location return a reference to that location.
Likewise, query results contain a reference to the location of the reported value.

References can inform about the key or the complete URL of the referred location.
And a reference may be converted back to a location, which can be used in a new task.

There is a special task to open a location without modifying or querying it,
which results in a reference if the location is valid.
It's generally not necessary to explicitly open a constructed location,
but it may be used to check the location or to cache Firebase references.

```elm
-- Reference is an opaque type
key      : Reference -> String
toUrl    : Reference -> String
location : Reference -> Location
open     : Location -> Task Error Reference
```

## Modifying Values

```elm
set             : Value -> Location -> Task Error Reference
setWithPriority : Value -> Priority -> Location -> Task Error Reference
setPriority     : Priority -> Location -> Task Error Reference
update          : Value -> Location -> Task Error Reference
remove          : Location -> Task Error Reference
```

These tasks complete when synchronization to the Firebase servers has completed.
On success they result in a Reference to the modified location.
They result in an error if the location is invalid or you have no permission to modify the data.

Values are given as Json values, i.e. `Json.Encode.Value`.

Example:

```elm
port write : Task Error ()
port write =
  set (Json.Encode.string "new branch") (push location)
  `andThen`
  (\ref -> ... ref.key ... )
```
    
## Transactions

Atomic modifications of the data at a location can be done by transactions.

A transaction takes an update function (or alternatively an update task)
that maps the previous value to a new value.
In case of a conflict with concurrent updates by other clients
the update function is called repeatedly until no more conflict is encountered.

```elm
transaction : (Maybe Value -> Action) ->
              Location ->
              Bool ->
              Task Error (Bool, Snapshot)
transactionByTask :
              (Maybe Value -> Task x Action) ->
              Location ->
              Bool ->
              Task Error (Bool, Snapshot)
type Action = Abort | Remove | Set Value
```
              
Example:

```elm
port trans : Task Error -> Task Error () 
port trans =
  transaction
    ( \maybeVal -> case maybeVal of
        Just value ->
          case Json.Decode.decodeValue Json.Decode.int value of
            Ok counter -> Set (Json.Encode.int (counter + 1)
            _          -> Abort
        Nothing ->
          Set (Json.Encode.int (1)
    ) location False
  `andThen`
  (\(committed, snapshot) -> ... )
```

## Querying

```elm
once        : Query -> Location -> Task Error Snapshot       
subscribe   : (Snapshot -> Task x a) ->
              (Cancellation -> Task y b) ->
              Query ->
              Location ->
              Task Error QueryId
unsubscribe : QueryId -> Task Error ()
```
    
Use `once` to listen to exactly one event of the given type.
The first parameter specifies the event to listen to: `valueChanged`, `childAdded`, `childChanged`, `childRemoved` or `childMoved`.
Additionally, this parameter can also specify ordering, filtering and limiting of the query (see below).

The second parameter references the queried location.

Use `subscribe` to start querying the specified events.
Subscription queries return a arbitrary number of data messages,
which are reported via running a supplied task.

The first parameter of `subscribe` is a function used to construct that task from a data message.
The second parameter is a function used to construct a task that is run when the query gets canceled.

The third and fourth parameter of `subscribe` are the same as the first two of `once`.

On success the `subscribe` task returns a QueryId, which can be used to match the corresponding responses and to cancel the query.

```elm
type alias Snapshot =
  { queryId: QueryId
  , key: String
  , reference: Reference
  , value: Maybe Value
  , prevKey: Maybe String
  , priority: Priority
  }
type Cancellation
  = Unsubscribed QueryId
  | QueryError QueryId Error
```

A `Snapshot` carries the corresponding `QueryId` and `Just Value` for the Json value or `Nothing` if the location doesn't exist.

`key` corresponds to the last part of the path.
It is the empty string for the root.
Keys are relevant notably for child queries.

Example:

```elm
responses : Signal.Mailbox (Maybe Snapshot)
responses = Signal.mailbox Nothing

port query : Task Error QueryId
port query =
  subscribe
    (Signal.send responses.address << Just)
    (always (Task.succeed ()))
    (child added)
    (fromUrl "https:...firebaseio.com/...")

... = Signal.map
        (\response -> case response of
            Nothing -> ...
            Just snapshot -> ...
        )
        responses.signal
```
            
## Ordering, Filtering and Limiting Queries

Query results can be ordered (by value, by a child's value, by key or by priority),
filtered by giving a start and/or end value,
and limited to the first or last certain number of children.
            
Example queries to be used in once and subscribe:
            
```elm
childAdded |> limitToFirst 2
childAdded |> orderByValue
childAdded |> orderByChild "size"
childAdded |> orderByKey
childAdded |> orderByPriority
childAdded |> orderByValue |> startAtValue "foo"
childAdded |> orderByValue |> startAtValue "foo" | limitToLast 10
childAdded |> orderByChild "size" |> startAtValue 42 |> endAtValue 42
childAdded |> orderByKey |> endAtKey "d"
childAdded |> orderByPriority |> startAtPriority (NumberPriority 17) (Just "d")
```
    
## Authentication

The sub-module ElmFire.Auth provides all authentication and user management functions
that are offered by Firebase.

Some example tasks:

```elm
import ElmFire.Auth exposing (..)

-- create a new user-account with email and password
userOperation (createUser "me@some.where" "myPassword")

-- login with with email and password
authenticate loc [rememberSessionOnly] (withPassword "me@some.where" "myPassword")

-- login with with github account
authenticate loc [] (withOAuthPopup "github")

-- watch for logins and logouts
subscribeAuth
  (\maybeAuth -> case maybeAuth of
    Just auth -> ... auth.uid ...
    Nothing   -> ... -- not authenticated
  )
  loc
```

## Example.elm

There is a very basic example app in `example/src/Example.elm`. To build it:

```sh
cd example
make all open
```
    
Alternatively without using `make`:

```sh
cd example
elm make --output Example.html src/Example.elm
```

Prior to building you may want to put your own Firebase URL in it.

## Testing

I started a testing app, living in the directory `test`.
It runs a given sequence of tasks on the Firebase API and logs these steps along with the query results.

This app uses a small ad-hoc testing framework for task-based code. 

There is a Makefile to build the app. On most Unix-like systems a `cd test; make all open` should do the trick.

An older, still functional testing app lives in the directory `demo`.

## Future work

There are a lot of features I plan to add in the near future:

* Complete the API, some special features are still missing
* Synchronization of Dicts, Lists, Arrays. Maybe more convenience functions.
* Better test app
* A nice example app

Please take notice that the API is not finalized yet.
The exact interface may change a bit here and there.
