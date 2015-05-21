module ElmFire
  ( Location
  , Reference
  , Priority (..)
  , Query
  , QueryId
  , Response (..)
  , DataMsg
  , Error (..)
  , fromUrl, sub, parent, root, push, location, toUrl, key
  , open, set, setWithPriority, setPriority, update, remove
  , subscribe, unsubscribe
  , valueChanged, child, added, changed, removed, moved
  ) where

{-| Elm bindings to Firebase.

# Firebase locations
@docs Location, fromUrl, sub, parent, root

# Firebase references
@docs Reference, open, location

# Writing
@docs set, update, remove

# Querying
@docs Query, QueryId, subscribe, unsubscribe, valueChanged, child, added, changed, removed, moved

# Query results
@docs Response, DataMsg, responses

# Error reporting
@docs Error
-}

import Native.Firebase
import Native.ElmFire
import Json.Encode as JE
import Signal exposing (Address)
import Task exposing (Task)

{-| Errors reported from Firebase -}
type Error = FirebaseError String

{-| A Firebase location, which is a opaque type that represents a literal path into a firebase.

A location can be constructed or obtained from
- an absolute path by `fromUrl`
- relative to another location by `sub`, `parent` and `root`
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

{-| A Firebase reference, which is a opaque type that represents a opened path.

References are returned from many Firebase tasks as well as in query results.
-}
type Reference = Reference

{- Each existing location in a Firebase may be attributed with a priority that can be a number or a string.

Priorities can be used to filter and to sort entries.
-}
type Priority
  = NoPrio
  | NumPrio Float
  | StrPrio String

{-| Specifies the event this query listens to (valueChanged, child added, ...) -}
type Query
  = ValueChanged
  | Child ChildQuery

type ChildQuery
  = Added
  | Changed
  | Removed
  | Moved

{-| Unique opaque identifier for each executed query -}
type QueryId = QueryId

{-| Query response: Either a received data or a query cancellation -}
type Response
  = NoResponse
  | Data DataMsg
  | QueryCanceled QueryId String

{-| A received value.
`queryId` can be used to correlate the response to the corresponding query.
`value`is either `Just` a Json value
or it is `Nothing` when the queried location doesn't exist.
-}
type alias DataMsg =
  { queryId: QueryId
  , key: String
  , reference: Reference
  , value: Maybe JE.Value
  }

{-| Construct a new location from a full Firebase URL.

    location = fromUrl "https://elmfire.firebaseio-demo.com/"
-}
fromUrl : String -> Location
fromUrl = UrlLocation

{-| Construct a location for the descendant at the specified relative path.

    locUsers = sub "users" location
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

{-| Construct a new child location using a generated key.

The unique key generated is prefixed with a client-generated timestamp so that the resulting list will be chronologically-sorted.

You may `open` the location or use the result of `set` to get the generated key.

    open (push loc) `andThen` Signal.send mailboxToReceiveKey.address
-}
push : Location -> Location
push = PushLocation

{-| Obtain a location from a reference.

    reference = location location
-}
location : Reference -> Location
location = RefLocation

{-| Get the url of a reference. -}
toUrl : Reference -> String
toUrl = Native.ElmFire.toUrl

{-| Get the key of a reference.

The last token in a Firebase location is considered its key.
For a refernce to the root key will return the empty string.
-}
key : Reference -> String
key = Native.ElmFire.key

{-| Actually open a location, which results in a reference (if the location is valid).

It's generally not necessary to explicitly open a constructed location.
It can be used to check the location and to cache Firebase references.

The task fails if the location construct is invalid.

    openTask =
      (open <| sub user <| fromUrl "https://elmfire.firebaseio-demo.com/users")
      `andThen` Signal.send locationCache.address
-}
open : Location -> Task Error Reference
open = Native.ElmFire.open

{-| Write a Json value to a Firebase location.

The task completes with `()` when
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

This will overwrite only children present in the first parameter and will leave others untouched.

The task completes with `()` when
synchronization to the Firebase servers has completed.
The task may result in an error if the location is invalid
or you have no permission to write this data.
-}
update : JE.Value -> Location -> Task Error Reference
update = Native.ElmFire.update

{-| Delete a Firebase location.

The task completes with `()` when
synchronization to the Firebase servers has completed.
The task may result in an error if the location is invalid
or you have no permission to remove this data.
-}
remove : Location -> Task Error Reference
remove = Native.ElmFire.remove

{-| Query a Firebase location.

(This early version of ElmFire only supports simple value queries,
without ordering and filtering.)

On success the task returns a QueryId,
which can be used to match the corresponding responses
and to cancel the query.

The query results are reported via a mailbox. The addressee is given as first parameter.
-}
subscribe : Signal.Address Response -> Query -> Location -> Task Error QueryId
subscribe = Native.ElmFire.subscribe

{-| Cancel a query subscription -}
unsubscribe : QueryId -> Task Error ()
unsubscribe = Native.ElmFire.unsubscribe

{-| Query value changes at the referenced location -}
valueChanged : Query
valueChanged = ValueChanged

{-| Query child changes at the referenced location -}
child : ChildQuery -> Query
child = Child

{-| Query child added -}
added : ChildQuery
added = Added

{-| Query child changed -}
changed : ChildQuery
changed = Changed

{-| Query child removed -}
removed : ChildQuery
removed = Removed

{-| Query child moved -}
moved : ChildQuery
moved = Moved
