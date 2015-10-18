# ElmFire: Use the Firebase API in Elm

Virtually all features of the [Firebase Web API](https://www.firebase.com/docs/web/) are exposed as a [library](http://package.elm-lang.org/packages/ThomasWeiser/ElmFire/latest) for [Elm](http://elm-lang.org/):

- Setting, removing and modifying values
- Transactions
- Querying data, both one-time and per subscription
- Complex queries with sorting, filtering and limiting
- Authentication
- User management
- Offline capabilities

## API Usage

The API design corresponds closely to the targeted Firebase JavaScript API.
Please refer to the [original documentation](https://www.firebase.com/docs/web/) for further discussions of the concepts.

In the following we give a short overview of the API.
Detailed documentation is embedded in the source code.

### Constructing Firebase Locations

To refer to a Firebase path use a `Location`.
It can be built with the following functions:

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

### References to Locations

Most actions on a Firebase location return a reference to that location.
Likewise, query results contain a reference to the location of the reported value.

References can inform about the key or the complete URL of the referred location.
And a reference may be converted back to a location, which can be used in a new task.

There is a special task to open a location without modifying or querying it,
which results in a reference if the location is valid.
It's generally not necessary to explicitly open a constructed location,
but it may be used to check the validity of a location or to cache Firebase references.

```elm
-- Reference is an opaque type
key      : Reference -> String
toUrl    : Reference -> String
location : Reference -> Location
open     : Location -> Task Error Reference
```

### Modifying Values

```elm
set             : Value -> Location -> Task Error Reference
setWithPriority : Value -> Priority -> Location -> Task Error Reference
setPriority     : Priority -> Location -> Task Error Reference
update          : Value -> Location -> Task Error Reference
remove          : Location -> Task Error Reference
```

These tasks complete when synchronization to the Firebase servers has completed.
On success they result in a Reference to the modified location.
They result in an error if the location is invalid or if you have no permission to modify the data.

Values are given as Json values, i.e. `Json.Encode.Value`.

Example:

```elm
port write : Task Error ()
port write =
  set (Json.Encode.string "new branch") (push location)
  `andThen`
  (\ref -> ... ref.key ... )
```

### Transactions

Atomic modifications of the data at a location can be achieved by transactions.

A transaction takes an update function that maps the previous value to a new value.
In case of a conflict with concurrent updates by other clients
the update function is called repeatedly until no more conflict is encountered.

```elm
transaction : (Maybe Value -> Action) ->
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
            Ok counter -> Set (Json.Encode.int (counter + 1))
            _          -> Abort
        Nothing ->
          Set (Json.Encode.int 1)
    ) location False
  `andThen`
  (\(committed, snapshot) -> ... )
```

### Querying

```elm
once        : Query -> Location -> Task Error Snapshot
subscribe   : (Snapshot -> Task x a) ->
              (Cancellation -> Task y b) ->
              Query ->
              Location ->
              Task Error Subscription
unsubscribe : Subscription -> Task Error ()
```

Use `once` to listen to exactly one event of the given type.

The first parameter specifies the event to listen to: `valueChanged`, `childAdded`, `childChanged`, `childRemoved` or `childMoved`.
Additionally, this parameter may also specify ordering, filtering and limiting of the query (see below).
If you don't need these options a simple query specification is `valueChanged noOrder`.

The second parameter references the queried location.

Use `subscribe` to start a continuing query of the specified events.
Subscription queries return a arbitrary number of data messages,
which are reported via running a supplied task.

The first parameter of `subscribe` is a function used to construct that task from a data message.

The second parameter is a function used to construct a task that is run when the query gets canceled.

The third and fourth parameter of `subscribe` are the same as the first two of `once`.

On success the `subscribe` task returns a Subscription, an identifier that can be used to match the corresponding responses and to cancel the query.

```elm
type alias Snapshot =
  { subscription: Subscription
  , key: String
  , reference: Reference
  , existing: Bool
  , value: Value
  , prevKey: Maybe String
  , priority: Priority
  }
type Cancellation
  = Unsubscribed Subscription
  | QueryError Subscription Error
```

A `Snapshot` carries the resulting `Value` (as Json) among other information,
e.g. the corresponding `Subscription` identifier.

In queries of type `valueChanged` the result may be that there is no value at the queried location.
In this case `existing` will be `False` and value will be the Json value of `null`.

`key` corresponds to the last part of the path.
It is the empty string for the root.
Keys are relevant notably for child queries.

Example:

```elm
responses : Signal.Mailbox (Maybe Snapshot)
responses = Signal.mailbox Nothing

port query : Task Error Subscription
port query =
  subscribe
    (Signal.send responses.address << Just)
    (always (Task.succeed ()))
    (childAdded noOrder noLimit)
    (fromUrl "https:...firebaseio.com/...")

... = Signal.map
        (\response -> case response of
            Nothing -> ...
            Just snapshot -> ...
        )
        responses.signal
```

### Ordering, Filtering and Limiting Queries

Query results can be ordered (by value, by a child's value, by key or by priority),
and then filtered by giving a start and/or end value within that order,
and limited to the first or last certain number of children.

Example queries to be used in `once` and `subscribe`:

```elm
childAdded noOrder
childAdded (orderByValue noRange noLimit)
childAdded (orderByChild "size" noRange noLimit)
childAdded (orderByKey noRange noLimit)
childAdded (orderByPriority noRange (limitToFirst 2))
childAdded (orderByValue (startAt (Json.Encode.string "foo")) noLimit)
childAdded (orderByValue (startAt (Json.Encode.string "foo")) (limitToLast 10))
childAdded (orderByChild "size" (equalTo (Json.Encode.int 42)) noLimit)
childAdded (orderByKey (endAt "k") noLimit)
childAdded (orderByPriority (startAt (NumberPriority 17, Just "k")) noLimit)
```

When doing ordered `valuedChanged` queries it may be useful to map the result
to a list to conserve the ordering:

```elm
toSnapshotList : Snapshot -> List Snapshot
toValueList    : Snapshot -> List JE.Value
toKeyList      : Snapshot -> List String
toPairList     : Snapshot -> List (String, JE.Value)
```

### Authentication

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

### Offline Capabilities

- Detecting connection state changes: `subscribeConnected`
- Manually disconnect and reconnect:
  `goOffline`, `goOnline`
- Managing presence:
  `onDisconnectSet`, `onDisconnectSetWithPriority`, `onDisconnectUpdate`,
  `onDisconnectRemove`, `onDisconnectCancel`
- Handling latency:
  `subscribeServerTimeOffset`, `serverTimeStamp`

## Examples

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

### TodoMVC

A more complete example is
[this implementation of TodoMVC](https://github.com/ThomasWeiser/todomvc-elmfire)
as a collaborative real-time app.

## Testing

There is a testing app, living in the directory `test`, that covers most of the code.
It runs a given sequence of tasks on the Firebase API and logs these steps along with the several results.

This app uses a small ad-hoc testing framework for task-based code.

There is a Makefile to build the app. On most Unix-like systems a `cd test; make all open` should do the trick.

An older, still functional testing app lives in the directory `demo`.

## Future work

Plans for the near future:

* New [API functionality)[https://www.firebase.com/blog/2015-09-24-atomic-writes-and-more.html] from Firebase's JS library 2.3
    * Ordering queries by deep paths
* Synchronization of Dicts, Lists, Arrays. Maybe more convenience functions.
    * First draft for (Dict.elm)[https://github.com/ThomasWeiser/elmfire/blob/dict/src/ElmFire/Dict.elm]
* Better test app
* A nice example app
* Adapt this Readme to better serve as the [front doc](http://package.elm-lang.org/packages/ThomasWeiser/ElmFire/latest) at the package site.
