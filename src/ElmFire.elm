module ElmFire
  ( Ref
  , Query
  , QueryId
  , Response (..)
  , DataMsg
  , Error (..)
  , responses
  , location, child, parent
  , open, set, subscribe
  , valueChanged
  ) where

{-| Elm bindings to Firebase.

# References to a Firebase location
@docs Ref, location, child, parent, open

# Writing
@docs set

# Querying
@docs query, QueryId

# Query results
@docs Response, DataMsg, responses

# Error reporting
@docs Error
-}

import Native.ElmFire
import Json.Encode as JE
import Task exposing (Task)

{-| Errors reported from Firebase -}
type Error = FirebaseError String

{-| A reference to a Firebase location. This is an opaque type.
References are constructed with the function `location`, `child`,
`parent` and by running the `open` task.
-}
type Ref
  = Location String
  | Child String Ref
  | Parent Ref
  | RawRef

type Query
  = ValueChanged
--| Child ChildQuery

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
  , value: Maybe JE.Value
  }

{-| Construct a new reference from a full Firebase URL.

    ref = location "https://elmfire.firebaseio-demo.com/"
-}
location : String -> Ref
location = Location

{-| Construct a reference for the location at the specified relative path.

    refUsers = child "users" ref
-}
child : String -> Ref -> Ref
child = Child

{-| Construct a reference to the parent location.

    ref2 = parent ref1
-}
parent : Ref -> Ref
parent = Parent

{-| Actually open a reference and give an internal representation of that reference.

It's generally not necessary to explicitly open a constructed reference.
It can be used to check the reference and to cache Firebase references.

The task fails if the refence construct is invalid.

    openTask =
      (open <| child user <| location "https://elmfire.firebaseio-demo.com/users")
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

{-| Query a Firebase location.

(This early version of ElmFire only supports simple value queries,
without ordering and filtering.)

On success the task returns a QueryId,
which can be used to match the corresponding responses
and to cancel the query.

The query results are reported via the signal `responses`.
-}
subscribe : Query -> Ref -> Task Error QueryId
subscribe = Native.ElmFire.subscribe

{-| Query value changes at the referenced location
-}
valueChanged : Query
valueChanged = ValueChanged

{-| All query responses a reported through this signal `responses`.
See the documentation of type `Response` for details.
-}
responses : Signal Response
responses = Native.ElmFire.responses
