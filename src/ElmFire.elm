module ElmFire
  ( Location
  , Reference
  , Query
  , QueryId
  , Response (..)
  , DataMsg
  , Error (..)
  , fromUrl, sub, parent, root, location, toUrl
  , open, set, remove, subscribe, unsubscribe
  , valueChanged, child, added, changed, removed, moved
  ) where

{-| Elm bindings to Firebase.

# Firebase locations
@docs Location, fromUrl, sub, parent, root

# Firebase references
@docs Reference, open, location

# Writing
@docs set, remove

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
  | RefLocation Reference

{-| A Firebase reference, which is a opaque type that represents a opened path.

References are returned from some Firebase actions, notably in query results.
-}
type Reference = Reference

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
  , key: Maybe String
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

{-| Obtain a location from a reference.

    reference = location location
-}
location : Reference -> Location
location = RefLocation

{-| Get the url of a reference.
-}
toUrl : Reference -> String
toUrl = Native.ElmFire.toUrl

{-| Actually open a location and give an internal representation of that reference.

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
set : JE.Value -> Location -> Task Error ()
set = Native.ElmFire.set

{-| Delete a Firebase location.

The task completes with `()` when
synchronization to the Firebase servers has completed.
The task may result in an error if the location is invalid
or you have no permission to remove this data.
-}
remove : Location -> Task Error ()
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
