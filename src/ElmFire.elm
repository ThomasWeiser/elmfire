module ElmFire
  ( Ref
  , Query
  , QueryId
  , Response (..)
  , DataMsg
  , Error (..)
  , responses
  , location, sub, parent
  , open, set, remove, subscribe, unsubscribe
  , valueChanged, child, added, changed, removed, moved
  ) where

{-| Elm bindings to Firebase.

# References to a Firebase location
@docs Ref, location, sub, parent, open

# Writing
@docs set, remove

# Querying
@docs Query, QueryId, subscribe, unsubscribe, valueChanged, child, added, changed, removed, moved

# Query results
@docs Response, DataMsg, responses

# Error reporting
@docs Error
-}

import Native.ElmFire
import Json.Encode as JE
import Signal exposing (Address)
import Task exposing (Task)

{-| Errors reported from Firebase -}
type Error = FirebaseError String

{-| A reference to a Firebase location. This is an opaque type.
References are constructed with the function `location`, `sub`,
`parent` and by running the `open` task.
-}
type Ref
  = LocationRef String
  | SubRef String Ref
  | ParentRef Ref
  | RawRef

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

{-| Construct a new reference from a full Firebase URL.

    ref = location "https://elmfire.firebaseio-demo.com/"
-}
location : String -> Ref
location = LocationRef

{-| Construct a reference for the descendant at the specified relative path.

    refUsers = sub "users" ref
-}
sub : String -> Ref -> Ref
sub = SubRef

{-| Construct a reference to the parent location.

    ref2 = parent ref1
-}
parent : Ref -> Ref
parent = ParentRef

{-| Actually open a reference and give an internal representation of that reference.

It's generally not necessary to explicitly open a constructed reference.
It can be used to check the reference and to cache Firebase references.

The task fails if the refence construct is invalid.

    openTask =
      (open <| sub user <| location "https://elmfire.firebaseio-demo.com/users")
      `andThen` Signal.send refs.address
-}
open : Ref -> Task Error Ref
open = Native.ElmFire.open

{-| Write a Json value to a Firebase location.

The task completes with `()` when
synchronization to the Firebase servers has completed.
The task may result in an error if the ref is invalid
or you have no permission to write this data.
-}
set : JE.Value -> Ref -> Task Error ()
set = Native.ElmFire.set

{-| Delete a Firebase location.

The task completes with `()` when
synchronization to the Firebase servers has completed.
The task may result in an error if the ref is invalid
or you have no permission to remove this data.
-}
remove : Ref -> Task Error ()
remove = Native.ElmFire.remove

{-| Query a Firebase location.

(This early version of ElmFire only supports simple value queries,
without ordering and filtering.)

On success the task returns a QueryId,
which can be used to match the corresponding responses
and to cancel the query.

The query results are reported via the signal `responses`.
-}
-- subscribe : Address Response -> Query -> Ref -> Task Error QueryId
-- TODO: Don't respond via the global signal `responses`.
--       The addressee should be given as an argument.
subscribe : Query -> Ref -> Task Error QueryId
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

{-| All query responses a reported through this signal `responses`.
See the documentation of type `Response` for details.
-}
responses : Signal Response
responses = Native.ElmFire.responses
