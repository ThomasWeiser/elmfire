module ElmFire.Dict
  ( Delta (..), subscribeDelta, update, integrate, mirror
  , Operation (..), submit, forwardOperation
  ) where


{-| ...

...

# ...
@docs mirror
-}

import ElmFire exposing
  ( Location, Snapshot, Error
  , subscribe, childAdded, childChanged, childRemoved, noOrder, noLimit
  , sub, push, set, remove)

import Signal exposing (Mailbox, Address, mailbox, send)
import Task exposing (Task, succeed, andThen)
import Dict exposing (Dict)
import ElmFire
import Json.Decode as JD
import Json.Encode as JE
import Debug

{- Notes

  - Should allow query options
  - Allow unsubscribing
  - Report cancellations
  - debounce
    - should probably be independent from ElmFire
  - poss. support plugging output directly to input without a real Firebase behind
    - on which level?
      1. Generally in ElmFire by special Location format
      2. Here in module Dict
      3. Abstract this Dict-API from specific back-end, Firebase beeing just one
-}

type Delta v
  = Added String v
  | Changed String v
  | Removed String v
  | Idem
  | Undecodable String String -- poss. include Json Value and the operation verb

subscribeDelta : Address (Delta v) -> JD.Decoder v -> Location -> Task Error ()
subscribeDelta addressee decoder location =
  let
    subscribeEvent event deltaOp =
      subscribe
        (\snapshot ->
          case JD.decodeValue decoder snapshot.value of
            Ok val -> send addressee (deltaOp snapshot.key val)
            Err description -> send addressee (Undecodable snapshot.key description)
        )
        (\cancellation -> succeed ())
        event
        location
  in
    subscribeEvent (childAdded noOrder) Added
    `andThen` \_ -> subscribeEvent (childChanged noOrder) Changed
    `andThen` \_ -> subscribeEvent (childRemoved noOrder) Removed
    `andThen` \_ -> succeed ()

integrate : Signal (Delta v) -> Signal (Dict String v)
integrate deltas =
  Signal.foldp update Dict.empty deltas

update : Delta v -> Dict String v -> Dict String v
update delta dict =
  case delta of
    Added key value -> Dict.insert key value dict
    Changed key value -> Dict.insert key value dict
    Removed key _ -> Dict.remove key dict
    Idem -> dict
    Undecodable _ _ -> dict

mirror : JD.Decoder v -> Location -> (Task Error (), Signal (Dict String v))
mirror decoder location =
  let
    deltas : Mailbox (Delta v)
    deltas = mailbox Idem
    init = subscribeDelta deltas.address decoder location
    sum = integrate deltas.signal
  in
    (init, sum)

type Operation v
  = Empty
  | FromDict (Dict String v)
  | FromList (List (String, v))
  | Insert String v
  | Push v
  | Remove String
  | None

submit : (v -> JD.Value) -> Location -> Operation v -> Task Error ()
submit encoder location operation =
  if operation == None
  then succeed ()
  else
    let
      encodePairs pairs = JE.object <| List.map (\(k, v) -> (k, encoder v)) pairs
    in
      ( case operation of
          Empty
            -> remove location
          FromDict dict
            -> set (encodePairs <| Dict.toList dict) location
          FromList pairs
            -> set (encodePairs pairs) location
          Insert key value
            -> set (encoder value) (sub key location)
          Push value
            -> set (encoder value) (push location)
          Remove key
            -> remove (sub key location)
      )
      `andThen` \_ -> succeed ()

forwardOperation : Address (Task Error ()) -> (v -> JD.Value) -> Location -> Address (Operation v)
forwardOperation taskAddressee encoder location =
  Signal.forwardTo taskAddressee (submit encoder location)

{- TODO:

type Transaction v
  = None
  | Operation (Operation v)
  | Update String (Maybe v -> Maybe v)
  | Filter (String -> v -> Bool)
  | Map (String -> v -> v)
  | FilterMap (String -> v -> Maybe v)
  -- TODO: poss.: union, intersect, diff (?)
  --       poss. specify if operation (on whole dict) should be transactionally or not
  --             (use additional parameter: transaction with and without intermediates, no transaction
  --              TransactionFinal, TransactionIntermediate, NoTransaction

  -- Needs some way to report undecodable values, possibly via a (Maybe) Address
  -- Same mechanism could be used in function mirror.
-}
