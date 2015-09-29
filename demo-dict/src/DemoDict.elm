{- A ElmFire Demo App for Dict Syncing
-}


import ElmFire exposing (Error)
import ElmFire.Dict as EFD

import Dict exposing (Dict)
import Json.Encode as JE
import Json.Decode as JD
import Task exposing (Task, andThen, succeed, onError)
import Signal exposing (Mailbox, Address, mailbox, send)
import Time
import Html exposing (Html, text, ol, li, i, div, p)

-------------------------------------------------------------------------------

url = "https://elmfiretest.firebaseio.com/dict"

-------------------------------------------------------------------------------

type alias State = Dict String Int
type alias Delta = EFD.Delta Int

changes : Mailbox Delta
changes = mailbox EFD.Idem

initTask : Task Error ()
initTask =
  EFD.subscribeDelta
    changes.address
    JD.int
    (ElmFire.fromUrl url)

states : Signal State
states =
  EFD.integrate changes.signal
  -- or: `Signal.foldp EFD.update Dict.empty changes.signal`

port initSyncing : Task Error ()
port initSyncing = initTask

type alias History = List Delta

histories : Signal History
histories = Signal.foldp (::) [] changes.signal

main : Signal Html
main = Signal.map2 view states histories

view : State -> History -> Html
view dict history =
  div []
    [ p [] [text "State:"]
    , viewState dict
    , p [] [text "History:"]
    , viewHistory history
    ]

viewState : State -> Html
viewState dict =
  ol [] ( Dict.foldr
      (\key val list ->
            li [] (viewItem key (toString val))
         :: list
      )
      []
      dict
    )

viewHistory : History -> Html
viewHistory history =
  ol [] ( List.foldl
    (\delta list ->
          li [] (viewDelta delta)
       :: list
    )
    []
    history
  )

viewDelta : Delta -> List Html
viewDelta delta =
  case delta of
    EFD.Idem -> [text "idem"]
    EFD.Added key val -> text "added " :: viewItem key (toString val)
    EFD.Changed key val -> text "changed " :: viewItem key (toString val)
    EFD.Removed key val -> text "removed " :: viewItem key (toString val)
    EFD.Undecodable key descr -> text "undecodable " :: viewItem key descr

viewItem : String -> String -> List Html
viewItem key val =
  [ i [] [text key]
  , text ": "
  , text val
  ]

-----------------------------------------------------------------------

gatherOperationTasks : Mailbox (Task Error ())
gatherOperationTasks = mailbox (succeed ())

port runOperationTasks : Signal (Task Error ())
port runOperationTasks = gatherOperationTasks.signal

operationAddressee : Address (EFD.Operation Int)
operationAddressee =
  EFD.forwardOperation
    gatherOperationTasks.address
    JE.int
    (ElmFire.fromUrl url)

infixl 1 =>
(=>) : Task x a -> Task x b -> Task x b
(=>) taskL taskR =
  taskL `andThen` \_ -> taskR

port testOperations : Task () ()
port testOperations =
  let
    sleep = Task.sleep (1 * Time.second)
    op operation = sleep => send operationAddressee operation
  in
      op (EFD.Empty)
   => op (EFD.FromList [("b", 4), ("c", 5)])
   => op (EFD.FromDict <| Dict.fromList [("d", 6), ("e", 7)])
   => op (EFD.Push 1)
   => op (EFD.Insert "a" 2)
   => op (EFD.Insert "a" 3)
   => op (EFD.Remove "d")
