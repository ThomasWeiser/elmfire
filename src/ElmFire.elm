module ElmFire
  ( Location
  , Reference
  , Priority (..)
  , Query
  , QueryId
  , Snapshot
  , Action (..)
  , Cancellation (..)
  , Error (..)
  , fromUrl, sub, parent, root, push, location, toUrl, key
  , open, set, setWithPriority, setPriority, update, remove
  , subscribe, unsubscribe, once, transaction, transactionByTask
  , valueChanged, childAdded, childChanged, childRemoved, childMoved
  , orderByChild, orderByValue, orderByKey, orderByPriority
  , startAtValue, startAtKey, startAtPriority
  , endAtValue, endAtKey, endAtPriority
  , limitToFirst, limitToLast
  , toSnapshotList, toValueList, toKeyList,toPairList
  ) where

{-| Elm bindings to Firebase.

# Firebase locations
@docs Location, fromUrl, sub, parent, root

# Firebase references
@docs Reference, open, key, toUrl, location

# Writing
@docs set, setWithPriority, setPriority,  update, remove

# Querying
@docs Query, QueryId, subscribe, unsubscribe, valueChanged,
child, added, changed, removed, moved

# Ordering
@docs orderByChild, orderByValue, orderByKey, orderByPriority

# Filtering
@docs startAtValue, startAtKey, startAtPriority, endAtValue, endAtKey, endAtPriority

# Limiting
@docs limitToFirst, limitToLast

# Query results
@docs Snapshot, Cancellation, toSnapshotList, toValueList, toKeyList,toPairList

# Transactions
@docs Action, transaction, transactionByTask

# Error reporting
@docs Error
-}

import Native.Firebase
import Native.ElmFire
import Array
import Json.Encode as JE
import Signal exposing (Address)
import Task exposing (Task)

{-| Errors reported from Firebase -}
type Error
  = LocationError String
  | PermissionError String
  | UnavailableError String
  | TooBigError String
  | FirebaseError String
  | UnknownQueryId

{-| A Firebase location, which is an opaque type
that represents a literal path into a firebase.

A location can be constructed or obtained from
- an absolute path by `fromUrl`
- relative to another location by `sub`, `parent`, `root`, `push`
- a reference by `location`

Locations are generally unvalidated until their use in a task.
The constructor functions are pure.
-}
type Location
  = UrlLocation String
  | SubLocation String Location
  | ParentLocation Location
  | RootLocation Location
  | PushLocation Location
  | RefLocation Reference

{-| A Firebase reference, which is an opaque type that represents a opened path.

References are returned from many Firebase tasks as well as in query results.
-}
type Reference = Reference

{- Each existing location in a Firebase may be attributed with a priority,
which can be a number or a string.

Priorities can be used for filtering and sorting entries in a query.
-}
type Priority
  = NoPriority
  | NumberPriority Float
  | StringPriority String

{-| Unique opaque identifier for each executed query -}
type QueryId = QueryId

{-| Message about cancelled query -}
type Cancellation
  = Unsubscribed QueryId
  | QueryError QueryId Error

{-| Message about a received value.

- `queryId` can be used to correlate the response to the corresponding query.
- `value`is either `Just` a Json value or it is `Nothing` when the queried location doesn't exist.
- `reference` points to the queried location
- `key` is relevant particular for child queries and specifies the key of the data.
- `prevKey` specifies the key of previous child (or Nothing for the first child), revealing the ordering. It's always Nothing for valueChanged queries.
- `priority` returns the given priority of the data.
-}
type alias Snapshot =
  { queryId: QueryId
  , key: String
  , reference: Reference
  , value: Maybe JE.Value
  , prevKey: Maybe String
  , priority: Priority
  , intern_: SnapshotFB
  }

type SnapshotFB = SnapshotFB

{-| Possible return values for update functions of a transaction -}
type Action
  = Abort
  | Remove
  | Set JE.Value

{-| Construct a new location from a full Firebase URL.

    loc = fromUrl "https://elmfire.firebaseio-demo.com/foo/bar"
-}
fromUrl : String -> Location
fromUrl = UrlLocation

{-| Construct a location for the descendant at the specified relative path.

    locUsers = sub "users" loc
-}
sub : String -> Location -> Location
sub = SubLocation

{-| Construct the parent location from a child location.

    loc2 = parent loc1
-}
parent : Location -> Location
parent = ParentLocation

{-| Construct the root location from descendant location

    loc2 = root loc1
-}
root : Location -> Location
root = RootLocation

{-| Construct a new child location using a to-be-generated key.

A unique key is generated whenever the location is used in one of the tasks,
notably `open`or `set`.
Keys are prefixed with a client-generated timestamp so that a resulting list
will be chronologically-sorted.

You may `open` the location or use `set` to actually generate the key
and get its name.

    set val (push loc) `andThen` (\ref -> ... ref.key ...)
-}
push : Location -> Location
push = PushLocation

{-| Obtain a location from a reference.

    reference = location loc
-}
location : Reference -> Location
location = RefLocation

{-| Get the url of a reference. -}
toUrl : Reference -> String
toUrl = Native.ElmFire.toUrl

{-| Get the key of a reference.

The last token in a Firebase location is considered its key.
It's the empty string for the root.
-}
key : Reference -> String
key = Native.ElmFire.key

{-| Actually open a location, which results in a reference
(if the location is valid).

It's generally not necessary to explicitly open a constructed location.
It can be used to check the location and to cache Firebase references.

The task fails if the location construct is invalid.

    openTask =
      (open <| sub user <| fromUrl "https://elmfire.firebaseio-demo.com/users")
      `andThen` (\ref -> Signal.send userRefCache.address (user, ref))
-}
open : Location -> Task Error Reference
open = Native.ElmFire.open

{-| Write a Json value to a Firebase location.

The task completes with a reference to the changed location when
synchronization to the Firebase servers has completed.
The task may result in an error if the location is invalid
or you have no permission to write this data.
-}
set : JE.Value -> Location -> Task Error Reference
set = Native.ElmFire.set

{-| Write a Json value to a Firebase location and specify a priority for that data.
-}
setWithPriority : JE.Value -> Priority -> Location -> Task Error Reference
setWithPriority = Native.ElmFire.setWithPriority

{-| Set a priority for the data at a Firebase location.
-}
setPriority : Priority -> Location -> Task Error Reference
setPriority = Native.ElmFire.setPriority

{-| Write the children in a Json value to a Firebase location.

This will overwrite only children present in the first parameter
and will leave others untouched.

-}
update : JE.Value -> Location -> Task Error Reference
update = Native.ElmFire.update

{-| Delete a Firebase location.

The task completes with a reference to the deleted location when
synchronization to the Firebase servers has completed.
The task may result in an error if the location is invalid
or you have no permission to remove this data.
-}
remove : Location -> Task Error Reference
remove = Native.ElmFire.remove

{-| Transaction: Atomically modify the data at a location

First parameter is a function which will be passed the current data stored at this location (or Nothing if the location contains no data).
The function returns an Action, which is either Set Value, or Abort, or Remove.
The second parameter specifies the location at which the transaction should be performed.
The third parameter denotes whether intermediate states are reported to local query subscriptions (True) or suppressed (False).

On success the task returns a tuple:
Its first element indicates whether the transaction was commited (True) or aborted (False).
Regardless, the second element is a Snapshot containing the resulting data at that location.
-}
transaction : (Maybe JE.Value -> Action)
           -> Location
           -> Bool
           -> Task Error (Bool, Snapshot)
transaction = Native.ElmFire.transaction

{-| Transaction with an update task: Atomically modify the data at a location

This is the same as `transaction` with the exception that the new value is provided by
running a task instead of a pure function.

A failure of the update task results in a abortion of the transaction
(same as success with `Abort`).
-}
transactionByTask : (Maybe JE.Value -> Task x Action)
           -> Location
           -> Bool
           -> Task Error (Bool, Snapshot)
transactionByTask = Native.ElmFire.transactionByTask


{-| Query a Firebase location by subscription

(This early version of ElmFire only supports simple value queries,
without ordering and filtering.)

On success the task returns a QueryId,
which can be used to match the corresponding responses
and to unsubscribe the query.

The query results are reported via running a supplied task.

The first parameter is a function used to construct that task from a response.
The second parameter is a function used to construct a task that is run
when the query gets canceled.
The third parameter specifies the event to listen to:
`valueChanged`, `child added`, `child changed`, `child removed` or `child moved`.
The fourth parameter specifies the location to be queried.
-}
subscribe : (Snapshot -> Task x a)
         -> (Cancellation -> Task y b)
         -> Query q
         -> Location
         -> Task Error QueryId
subscribe = Native.ElmFire.subscribe

{-| Cancel a query subscription -}
unsubscribe : QueryId -> Task Error ()
unsubscribe = Native.ElmFire.unsubscribe

{-| Query a Firebase location once

On success the tasks results in the desired Snapshot.
It results in an error if either the location is invalid
or you have no permission to read this data.

The first parameter specifies the event to listen to:
`valueChanged`, `child added`, `child changed`, `child removed` or `child moved`.
The second parameter specifies the location to be queried.
-}
once : Query q -> Location -> Task Error Snapshot
once = Native.ElmFire.once

type alias Query a = { a | tag : QueryOptions }

type QueryOptions = QueryOptions
emptyOptions =
  { tag = QueryOptions, noOrder = True, noLimit = True, noStart = True, noEnd = True }

type QueryEvent =
  ValueChanged | ChildAdded | ChildChanged | ChildRemoved | ChildMoved

{-| Query value changes at the referenced location -}
valueChanged = { emptyOptions | queryEvent = ValueChanged }

{-| Query child added -}
childAdded   = { emptyOptions | queryEvent = ChildAdded }

{-| Query child changed -}
childChanged = { emptyOptions | queryEvent = ChildChanged }

{-| Query child removed -}
childRemoved = { emptyOptions | queryEvent = ChildRemoved }

{-| Query child moved -}
childMoved   = { emptyOptions | queryEvent = ChildMoved }

{-| Order query results by the value of a named child -}
orderByChild : String
  -> { r | noOrder : a }
  -> { r | orderByChildOrValue : Maybe String }
orderByChild key query = { query - noOrder | orderByChildOrValue = Just key }

{-| Order query results by value -}
orderByValue :
     { r | noOrder : a }
  -> { r | orderByChildOrValue : Maybe String }
orderByValue query = { query - noOrder | orderByChildOrValue = Nothing }

{-| Order query results by key -}
orderByKey :
     { r | noOrder : a }
  -> { r | orderByKey : Bool }
orderByKey query = { query - noOrder | orderByKey = True }

{-| Order query results first by priority, then by key -}
orderByPriority :
     { r | noOrder : a }
  -> { r | orderByPriority : Bool }
orderByPriority query = { query - noOrder | orderByPriority = True }

{-| Filter query results by a given start value

The value has to be atomar (number, string, boolean or null).

This is only valid after sorting by value or by child.
-}
startAtValue : JE.Value
  -> { r | noStart : a, orderByChildOrValue : o }
  -> { r | orderByChildOrValue : o, startAtValue: JE.Value }
startAtValue value query =
  { query - noStart | startAtValue = value }

{-| Filter query results by a given end value

The value has to be atomar (number, string, boolean or null).

This is only valid after sorting by value or by child.
-}
endAtValue : JE.Value
  -> { r | noEnd : a, orderByChildOrValue : o }
  -> { r | orderByChildOrValue : o, endAtValue: JE.Value }
endAtValue value query =
  { query - noEnd | endAtValue = value }

{-| Filter query results by a given start key

This is only valid after sorting by key.
-}
startAtKey : String
  -> { r | noStart : a, orderByKey : o }
  -> { r | orderByKey : o, startAtKey: String }
startAtKey key query =
  { query - noStart | startAtKey = key }

{-| Filter query results by a given end key

This is only valid after sorting by key.
-}
endAtKey : String
  -> { r | noEnd : a, orderByKey : o }
  -> { r | orderByKey : o, endAtKey: String }
endAtKey key query =
  { query - noEnd | endAtKey = key }

{-| Filter query results by a given start priority (and key if given)

This is only valid after sorting by priority.
-}
startAtPriority : Priority -> Maybe String
  -> { r | noStart : a, orderByPriority : o }
  -> { r | orderByPriority : o, startAtPriority: (Priority, Maybe String) }
startAtPriority priority key query =
  { query - noStart | startAtPriority = (priority, key) }

{-| Filter query results by a given end priority (and key if given)

This is only valid after sorting by priority.
-}
endAtPriority : Priority -> Maybe String
  -> { r | noEnd : a, orderByPriority : o }
  -> { r | orderByPriority : o, endAtPriority: (Priority, Maybe String) }
endAtPriority priority key query =
  { query - noEnd | endAtPriority = (priority, key) }

{-| Limit the query to the first certain number of children.

The number must be a positive integer.
When combined with ordering and filtering, limiting is done after that steps.
-}
limitToFirst : Int
  -> { r | noLimit : a }
  -> { r | limitToFirst : Int }
limitToFirst num query = { query - noLimit | limitToFirst = num }

{-| Limit the query to the last certain number of children.

The number must be a positive integer.
When combined with ordering and filtering, limiting is done after that steps.
-}
limitToLast : Int
  -> { r | noLimit : a }
  -> { r | limitToLast : Int }
limitToLast num query = { query - noLimit | limitToLast = num }


{-| Convert a snapshot's children into a list of snapshots

Ordering of the children is presevered.
So, if the snapshot results from a ordered valueChanged-query
then toList allows for map this ordering to a list.

NB: The field .prevKey is not set in the listed snapshots.
-}
toSnapshotList : Snapshot -> List Snapshot
toSnapshotList = Native.ElmFire.toSnapshotList

{-| Convert a snapshot's children into a list of its values -}
toValueList : Snapshot -> List JE.Value
toValueList = Native.ElmFire.toValueList

{-| Convert a snapshot's children into a list of its keys -}
toKeyList : Snapshot -> List String
toKeyList = Native.ElmFire.toKeyList

{-| Convert a snapshot's children into a list of key-value-pairs -}
toPairList : Snapshot -> List (String, JE.Value)
toPairList = Native.ElmFire.toPairList
