module ElmFire.LowLevel
    exposing
        ( Location
        , fromUrl
        , child
        , parent
        , root
        , push
        , Reference
        , open
        , key
        , toUrl
        , location
        , Priority(..)
        , set
        , setWithPriority
        , setPriority
        , update
        , remove
        , Snapshot
        , Action(..)
        , transaction
        , Query
        , OrderOptions
        , RangeOptions
        , LimitOptions
        , Subscription
        , Cancellation(..)
        , subscribe
        , unsubscribe
        , once
        , valueChanged
        , childAdded
        , childChanged
        , childRemoved
        , childMoved
        , noOrder
        , orderByChild
        , orderByValue
        , orderByKey
        , orderByPriority
        , noRange
        , startAt
        , endAt
        , range
        , equalTo
        , noLimit
        , limitToFirst
        , limitToLast
        , toSnapshotList
        , toValueList
        , toKeyList
        , toPairList
        , exportValue
        , goOffline
        , goOnline
        , subscribeConnected
        , onDisconnectSet
        , onDisconnectSetWithPriority
        , onDisconnectUpdate
        , onDisconnectRemove
        , onDisconnectCancel
        , serverTimeStamp
        , subscribeServerTimeOffset
        , Error
        , ErrorType(..)
        , AuthErrorType(..)
        )

{-| Elm Bindings to Firebase.

ElmFire maps the Firebase JavaScript API to Elm functions and tasks.

# Firebase Locations
@docs Location, fromUrl, child, parent, root, push

# Firebase References
@docs Reference, open, key, toUrl, location

# Priorities
@docs Priority

# Writing
@docs set, setWithPriority, setPriority,  update, remove

# Snapshots
@docs Snapshot

# Transactions
@docs Action, transaction

# Querying
@docs Query, OrderOptions, RangeOptions, LimitOptions, Subscription, Cancellation,
  subscribe, unsubscribe, once,
  valueChanged, childAdded, childChanged, childRemoved, childMoved

# Ordering
@docs noOrder, orderByChild, orderByValue, orderByKey, orderByPriority

# Filtering
@docs noRange, startAt, endAt, range, equalTo

# Limiting
@docs noLimit, limitToFirst, limitToLast

# Snapshot Processing
@docs toSnapshotList, toValueList, toKeyList, toPairList, exportValue

# Connection State and Offline Capabilities
@docs goOffline, goOnline, subscribeConnected,
  onDisconnectSet, onDisconnectSetWithPriority,
  onDisconnectUpdate, onDisconnectRemove, onDisconnectCancel

# Server Time
@docs serverTimeStamp, subscribeServerTimeOffset

# Error Reporting
@docs Error, ErrorType, AuthErrorType
-}

import ElmFire.Types exposing (..)
import Native.Firebase
import Native.ElmFire
import Time exposing (Time)
import Json.Encode as JE
import Json.Decode as JD
import Task exposing (Task)


{-| Errors reported from Firebase or ElmFire
-}
type alias Error =
    { tag : ErrorType
    , description : String
    }


{-| Type of errors reported from Firebase or ElmFire
-}
type ErrorType
    = LocationError
    | PermissionError
    | UnavailableError
    | TooBigError
    | OtherFirebaseError
    | AuthError AuthErrorType
    | UnknownSubscription


{-| Errors reported from Authentication Module
-}
type AuthErrorType
    = AuthenticationDisabled
    | EmailTaken
    | InvalidArguments
    | InvalidConfiguration
    | InvalidCredentials
    | InvalidEmail
    | InvalidOrigin
    | InvalidPassword
    | InvalidProvider
    | InvalidToken
    | InvalidUser
    | NetworkError
    | ProviderError
    | TransportUnavailable
    | UnknownError
    | UserCancelled
    | UserDenied
    | OtherAuthenticationError


{-| A Firebase location, which is an opaque type
that represents a literal path into a firebase.

A location can be constructed or obtained from
- an absolute path by `fromUrl`
- relative to another location by `child`, `parent`, `root`, `push`
- a reference by `location`

Locations are generally unvalidated until their use in a task.
The constructor functions are pure.
-}
type Location
    = Location LocationSpec



{- Unfortunately we cannot use a union type for Location.

   The implementation of the effect manager demands Location to be a comparable type.
   Union types are not comparable (in Elm 0.17).
   Lists are the only aggregate type that transports comparability of its element type.
-}


{-| A Firebase reference, which is an opaque type that represents an opened path.

References are returned from many Firebase tasks as well as in query results.
-}
type Reference
    = Reference


{-| Each existing location in a Firebase may be attributed with a priority,
which can be a number or a string.

Priorities can be used for filtering and sorting entries in a query.
-}
type Priority
    = NoPriority
    | NumberPriority Float
    | StringPriority String


{-| Unique opaque identifier for running subscriptions
-}
type Subscription
    = Subscription


{-| Message about cancelled query
-}
type Cancellation
    = Unsubscribed Subscription
    | QueryError Subscription Error


{-| Message about a received value.

- `subscription` can be used to correlate the response to the corresponding query.
- `value` is a Json value (and `null` when the queried location doesn't exist).
- `existing` is `False` iff there is no value at the location, which can only occur in `valueChanged`-queries
- `reference` points to the queried location
- `key` is relevant particular for child queries and specifies the key of the data.
- `prevKey` specifies the key of previous child (or Nothing for the first child), revealing the ordering. It's always Nothing for valueChanged queries.
- `priority` returns the given priority of the data.
-}
type alias Snapshot =
    { subscription : Subscription
    , key : String
    , reference : Reference
    , existing : Bool
    , value : JE.Value
    , prevKey : Maybe String
    , priority : Priority
    , intern_ : SnapshotFB
    }



{- A Firebase snapshot as an internally used JS object -}


type SnapshotFB
    = SnapshotFB


{-| Return values for update functions of a transaction
-}
type Action
    = Abort
    | Remove
    | Set JE.Value


{-| Construct a new location from a full Firebase URL.

    loc = fromUrl "https://elmfire.firebaseio-demo.com/foo/bar"
-}
fromUrl : String -> Location
fromUrl url =
    Location [ ( "url", url ) ]


{-| Construct a location for the descendant at the specified relative path.

    locUsers = child "users" loc
-}
child : String -> Location -> Location
child name (Location list) =
    Location (( "child", name ) :: list)


{-| Construct the parent location from a child location.

    loc2 = parent loc1
-}
parent : Location -> Location
parent (Location list) =
    Location (( "parent", "" ) :: list)


{-| Construct the root location from descendant location

    loc2 = root loc1
-}
root : Location -> Location
root (Location list) =
    Location (( "root", "" ) :: list)


{-| Construct a new child location using a to-be-generated key.

A unique key is generated whenever the location is used in one of the tasks,
notably `open` or `set`.
Keys are prefixed with a client-generated timestamp so that a resulting list
will be chronologically-sorted.

You may `open` the location or use `set` to actually generate the key
and get its name.

    set val (push loc) `andThen` (\ref -> ... key ref ...)
-}
push : Location -> Location
push (Location list) =
    Location (( "push", "" ) :: list)


{-| Obtain a location from a reference.

    reference = location loc
-}
location : Reference -> Location
location ref =
    fromUrl <| Native.ElmFire.toUrl ref


{-| Get the url of a reference.
-}
toUrl : Reference -> String
toUrl =
    Native.ElmFire.toUrl


{-| Get the key of a reference.

The last token in a Firebase location is considered its key.
It's the empty string for the root.
-}
key : Reference -> String
key =
    Native.ElmFire.key


{-| Actually open a location, which results in a reference
(if the location is valid).

It's generally not necessary to explicitly open a constructed location.
It can be used to check the location and to cache Firebase references.

The task fails if the location construct is invalid.

    openTask =
      (open <| child user <| fromUrl "https://elmfire.firebaseio-demo.com/users")
      `andThen` (\ref -> Signal.send userRefCache.address (user, ref))
-}
open : Location -> Task Error Reference
open =
    Native.ElmFire.open


{-| Write a Json value to a Firebase location.

The task completes with a reference to the changed location when
synchronization to the Firebase servers has completed.
The task may result in an error if the location is invalid
or you have no permission to write this data.
-}
set : JE.Value -> Location -> Task Error Reference
set =
    Native.ElmFire.set False


{-| Write a Json value to a Firebase location and specify a priority for that data.
-}
setWithPriority : JE.Value -> Priority -> Location -> Task Error Reference
setWithPriority =
    Native.ElmFire.setWithPriority False


{-| Set a priority for the data at a Firebase location.
-}
setPriority : Priority -> Location -> Task Error Reference
setPriority =
    Native.ElmFire.setPriority


{-| Write the children in a Json value to a Firebase location.

This will overwrite only children present in the first parameter
and will leave others untouched.

It is also possible to do atomic multi-location updates as documented [here](https://www.firebase.com/blog/2015-09-24-atomic-writes-and-more.html).
-}
update : JE.Value -> Location -> Task Error Reference
update =
    Native.ElmFire.update False


{-| Delete a Firebase location.

The task completes with a reference to the deleted location when
synchronization to the Firebase servers has completed.
The task may result in an error if the location is invalid
or you have no permission to remove this data.
-}
remove : Location -> Task Error Reference
remove =
    Native.ElmFire.remove False


{-| Transaction: Atomically modify the data at a location

First parameter is a function which will be passed the current data stored at this location (or Nothing if the location contains no data).
The function returns an Action, which is either Set Value, or Abort, or Remove.
The second parameter specifies the location at which the transaction should be performed.
The third parameter denotes whether intermediate states are reported to local query subscriptions (True) or suppressed (False).

On success the task returns a tuple:
Its first element indicates whether the transaction was commited (True) or aborted (False).
Regardless, the second element is a Snapshot containing the resulting data at that location.
-}
transaction :
    (Maybe JE.Value -> Action)
    -> Location
    -> Bool
    -> Task Error ( Bool, Snapshot )
transaction =
    Native.ElmFire.transaction


{-| Queue a `set` operation on the server that get executed as soon as the client disconnects.
-}
onDisconnectSet : JE.Value -> Location -> Task Error ()
onDisconnectSet =
    Native.ElmFire.set True


{-| Queue a `setWithPriority` operation on the server that get executed as soon as the client disconnects.
-}
onDisconnectSetWithPriority : JE.Value -> Priority -> Location -> Task Error ()
onDisconnectSetWithPriority =
    Native.ElmFire.setWithPriority True


{-| Queue a `update` operation on the server that get executed as soon as the client disconnects.
-}
onDisconnectUpdate : JE.Value -> Location -> Task Error ()
onDisconnectUpdate =
    Native.ElmFire.update True


{-| Queue a `remove` operation on the server that get executed as soon as the client disconnects.
-}
onDisconnectRemove : Location -> Task Error ()
onDisconnectRemove =
    Native.ElmFire.remove True


{-| Cancels all previously queued operations for this location and all children.
-}
onDisconnectCancel : Location -> Task Error ()
onDisconnectCancel =
    Native.ElmFire.onDisconnectCancel


{-| Query a Firebase location by subscription

On success the task returns a Subscription,
which can be used to match the corresponding responses
and to unsubscribe the query.

The query results are reported via running a supplied task.

The first parameter is a function used to construct that task from a response.

The second parameter is a function used to construct a task that is run
when the query gets canceled.

The third parameter specifies the event to listen to:
`valueChanged`, `childAdded`, `childChanged`, `childRemoved` or `childMoved`.
Additionally, this parameter may also specify ordering, filtering and limiting of the query (see below).

The fourth parameter specifies the location to be queried.
-}
subscribe :
    (Snapshot -> Task x a)
    -> (Cancellation -> Task y b)
    -> Query
    -> Location
    -> Task Error Subscription
subscribe createResponseTask =
    subscribeConditional (Just << createResponseTask)



{- Query a Firebase location by subscription with optional reaction

   Similar to `subscribe` except that the function given as the first parameter
   can decide whether to run a task or not.
-}


subscribeConditional :
    (Snapshot -> Maybe (Task x a))
    -> (Cancellation -> Task y b)
    -> Query
    -> Location
    -> Task Error Subscription
subscribeConditional =
    Native.ElmFire.subscribeConditional


{-| Cancel a query subscription
-}
unsubscribe : Subscription -> Task Error ()
unsubscribe =
    Native.ElmFire.unsubscribe


{-| Query a Firebase location for exactly one event of the specified type

On success the tasks results in the desired Snapshot.
It results in an error if either the location is invalid
or you have no permission to read this data.

The third parameter specifies the event to listen to:
`valueChanged`, `childAdded`, `childChanged`, `childRemoved` or `childMoved`.
Additionally, this parameter can also specify ordering, filtering and limiting of the query (see below).

The first parameter specifies the event to listen to:
`valueChanged`, `childAdded`, `childChanged`, `childRemoved` or `childMoved`.
Additionally, this parameter may also specify ordering, filtering and limiting of the query (see below).

The second parameter specifies the location to be queried.
-}
once : Query -> Location -> Task Error Snapshot
once =
    Native.ElmFire.once


{-| A query specification: event type, possibly ordering with filtering and limiting
-}
type Query
    = ValueChanged OrderOptions
    | ChildAdded OrderOptions
    | ChildChanged OrderOptions
    | ChildRemoved OrderOptions
    | ChildMoved OrderOptions


{-| Build a query with event type "value changed"
-}
valueChanged : OrderOptions -> Query
valueChanged =
    ValueChanged


{-| Build a query with event type "child added"
-}
childAdded : OrderOptions -> Query
childAdded =
    ChildAdded


{-| Build a query with event type "child changed"
-}
childChanged : OrderOptions -> Query
childChanged =
    ChildChanged


{-| Build a query with event type "child removed"
-}
childRemoved : OrderOptions -> Query
childRemoved =
    ChildRemoved


{-| Build a query with event type "child moved"
-}
childMoved : OrderOptions -> Query
childMoved =
    ChildMoved


{-| Type to specify ordering, filtering and limiting of queries
-}
type OrderOptions
    = NoOrder
    | OrderByChild String (RangeOptions JE.Value) LimitOptions
    | OrderByValue (RangeOptions JE.Value) LimitOptions
    | OrderByKey (RangeOptions String) LimitOptions
    | OrderByPriority (RangeOptions ( Priority, Maybe String )) LimitOptions


{-| Type to specify filtering options for the use within an ordered query
-}
type RangeOptions t
    = NoRange
    | StartAt t
    | EndAt t
    | Range t t
    | EqualTo t


{-| Type to specify limiting the size of the query result set. Used within an ordered query
-}
type LimitOptions
    = NoLimit
    | LimitToFirst Int
    | LimitToLast Int


{-| Don't order results
-}
noOrder : OrderOptions
noOrder =
    NoOrder


{-| Order results by the value of a given child
(or deep child, as documented [here](https://www.firebase.com/blog/2015-09-24-atomic-writes-and-more.html))
-}
orderByChild : String -> RangeOptions JE.Value -> LimitOptions -> OrderOptions
orderByChild =
    OrderByChild


{-| Order results by value
-}
orderByValue : RangeOptions JE.Value -> LimitOptions -> OrderOptions
orderByValue =
    OrderByValue


{-| Order results by key
-}
orderByKey : RangeOptions String -> LimitOptions -> OrderOptions
orderByKey =
    OrderByKey


{-| Order results by priority (and maybe secondary by key)
-}
orderByPriority : RangeOptions ( Priority, Maybe String ) -> LimitOptions -> OrderOptions
orderByPriority =
    OrderByPriority


{-| Don't filter the ordered results
-}
noRange : RangeOptions t
noRange =
    NoRange


{-| Filter the ordered results to start at a given value.

The type of the value depends on the order criterium
-}
startAt : t -> RangeOptions t
startAt =
    StartAt


{-| Filter the ordered results to end at a given value.

The type of the value depends on the order criterium
-}
endAt : t -> RangeOptions t
endAt =
    EndAt


{-| Filter the ordered results to start at a given value and to end at another value.

The type of the value depends on the order criterium
-}
range : t -> t -> RangeOptions t
range =
    Range


{-| Filter the ordered results to equal a given value.

The type of the value depends on the order criterium
-}
equalTo : t -> RangeOptions t
equalTo =
    EqualTo


{-| Don't limit the number of children in the result set of an ordered query
-}
noLimit : LimitOptions
noLimit =
    NoLimit


{-| Limit the result set of an ordered query to the first certain number of children.
-}
limitToFirst : Int -> LimitOptions
limitToFirst =
    LimitToFirst


{-| Limit the result set of an ordered query to the last certain number of children.
-}
limitToLast : Int -> LimitOptions
limitToLast =
    LimitToLast


{-| Convert a snapshot's children into a list of snapshots

Ordering of the children is presevered.
So, if the snapshot results from a ordered valueChanged-query
then toSnapshotList allows for conserving this ordering as a list.
-}
toSnapshotList : Snapshot -> List Snapshot
toSnapshotList =
    Native.ElmFire.toSnapshotList


{-| Convert a snapshot's children into a list of its values
-}
toValueList : Snapshot -> List JE.Value
toValueList =
    Native.ElmFire.toValueList


{-| Convert a snapshot's children into a list of its keys
-}
toKeyList : Snapshot -> List String
toKeyList =
    Native.ElmFire.toKeyList


{-| Convert a snapshot's children into a list of key-value-pairs
-}
toPairList : Snapshot -> List ( String, JE.Value )
toPairList =
    Native.ElmFire.toPairList


{-| Exports the entire contents of a Snapshot as a JavaScript object.

This is similar to .value except priority information is included (if available),
making it suitable for backing up your data.
-}
exportValue : Snapshot -> JE.Value
exportValue =
    Native.ElmFire.exportValue


{-| Manually disconnect the client from the server
and disables automatic reconnection.
-}
goOffline : Task x ()
goOffline =
    Native.ElmFire.setOffline True


{-| Manually reestablish a connection to the server
and enables automatic reconnection.
-}
goOnline : Task x ()
goOnline =
    Native.ElmFire.setOffline False


{-| Subscribe to connection state changes
-}
subscribeConnected :
    (Bool -> Task x a)
    -> Location
    -> Task Error Subscription
subscribeConnected createResponseTask location =
    subscribeConditional
        (\snapshot ->
            case JD.decodeValue JD.bool snapshot.value of
                Ok state ->
                    Just (createResponseTask state)

                Err _ ->
                    Nothing
        )
        (always (Task.succeed ()))
        (valueChanged noOrder)
        (location |> root |> child ".info/connected")


{-| Subscribe to server time offset
-}
subscribeServerTimeOffset :
    (Time -> Task x a)
    -> Location
    -> Task Error Subscription
subscribeServerTimeOffset createResponseTask location =
    subscribeConditional
        (\snapshot ->
            case JD.decodeValue JD.float snapshot.value of
                Ok offset ->
                    Just (createResponseTask (offset * Time.millisecond))

                Err _ ->
                    Nothing
        )
        (always (Task.succeed ()))
        (valueChanged noOrder)
        (location |> root |> child ".info/serverTimeOffset")


{-| A placeholder value for auto-populating the current timestamp
(time since the Unix epoch, in milliseconds) by the Firebase servers
-}
serverTimeStamp : JE.Value
serverTimeStamp =
    Native.ElmFire.serverTimeStamp
