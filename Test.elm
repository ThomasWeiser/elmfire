{- A ElmFire Testing App

A given sequence of tasks is run on the Firebase API.
Steps and results are logged as Html.

This is work in progress.
We aim to make the logging output look much more nicer.
-}

import Signal exposing (Signal, Mailbox, mailbox, message)
import Task exposing (Task, andThen, onError, fail, succeed, sleep)
import Json.Encode as JE
import Time
import Html exposing (Html, div, input, output, label, text, a)
import Html.Events exposing (on, targetValue)
import Html.Attributes exposing (href, target, style)
import Debug

import ElmFire exposing
  ( location, sub, parent, open
  , set, remove, subscribe, unsubscribe, responses
  , valueChanged, child, added, changed, removed, moved
  , Ref, Query, Response (..), DataMsg, QueryId, Error (..)
  )

-------------------------------------------------------------------------------

url = "https://elmfire.firebaseio-demo.com/test"

-------------------------------------------------------------------------------

type LogEntry
  = LogNone
  | LogTaskStart String
  | LogTaskSuccess String String
  | LogTaskFail String String
  | LogResponse Response

notes : Signal.Mailbox LogEntry
notes = Signal.mailbox LogNone

logEntries : Signal LogEntry
logEntries =
  Signal.merge
    notes.signal
    (Signal.map LogResponse responses)

type alias Model = List LogEntry

startModel : Model
startModel = []

progression : LogEntry -> Model -> Model
progression note model = note :: model

state : Signal Model
state = Signal.foldp progression startModel logEntries

view : Model -> Html
view model =
  div []
  [ div [style [("backgroundColor", "#AF7777")]] [text "ElmFire Test"]
  , div [style [("backgroundColor", "#AFD7DB")]]
    [ a [href url, target "_blank"] [text url] ]
  , div [] (viewModel model)
  ]

viewModel : Model -> List Html
viewModel model = List.foldl -- reverse the list for display
  (\entry htmlList ->
    let maybeHtml = viewLogEntry entry in
      case maybeHtml of
        Nothing -> htmlList
        Just html -> html::htmlList
  )
  []
  model

viewLogEntry : LogEntry -> Maybe Html
viewLogEntry logEntry = case logEntry of
  LogNone -> Nothing
  LogTaskStart step ->
    Just <| div [style [("backgroundColor", "#EFD8B1")]] [text <| step ++ ". Started"]
  LogTaskSuccess step res ->
    Just <| div [style [("backgroundColor", "#EFD871")]] [text <| step ++ ". Success: " ++ res]
  LogTaskFail step err ->
    Just <| div [style [("backgroundColor", "#EFD8F1")]] [text <| step ++ ". Failure: " ++ err]
  LogResponse response ->
    Just <| div [style [("backgroundColor", "#BCD693")]] [case response of
      Data dataMsg -> viewDataMsg dataMsg
      otherwise -> text ("no query response")
    ]

viewDataMsg : DataMsg -> Html
viewDataMsg dataMsg =
  text <|
    (toString dataMsg.queryId) ++ ": " ++
    (Maybe.withDefault "(root)" dataMsg.key) ++ ": " ++
    (Maybe.withDefault "no value" <| Maybe.map viewValue dataMsg.value)

viewValue : JE.Value -> String
viewValue value = JE.encode 0 value

main = Signal.map view state

-------------------------------------------------------------------------------

intercept : (v -> String) -> String -> Task Error v -> Task Error v
intercept valueToString step task =
  Signal.send notes.address (LogTaskStart step)
  `andThen` \_ ->
    ( task
      `onError` \err -> Signal.send notes.address (LogTaskFail step (errorToString err))
      `andThen` \_   -> fail err
    )
    `andThen` \val -> Signal.send notes.address (LogTaskSuccess step (valueToString val))
    `andThen` \_   -> succeed val

errorToString : Error -> String
errorToString error =
  case error of
      FirebaseError str -> str

-------------------------------------------------------------------------------

doOpen : String -> Ref -> Task Error Ref
doOpen step ref =
  intercept toString step (open ref)

doSet : String -> JE.Value -> Ref -> Task Error ()
doSet step value ref =
  intercept (always "synced") step (set value ref)

doRemove : String -> Ref -> Task Error ()
doRemove step ref =
  intercept (always "synced") step (remove ref)

doSubscribe : String -> Query -> Ref -> Task Error QueryId
doSubscribe step query ref =
  intercept toString step (subscribe query ref)

doUnsubscribe : String -> QueryId -> Task Error ()
doUnsubscribe step queryId =
  intercept (always "done") step (unsubscribe queryId)

doSleep : String -> Float -> Task () ()
doSleep step seconds =
  Signal.send notes.address (LogTaskStart step)
  `andThen` \_ -> sleep (seconds * Time.second)
  `andThen` \_ -> Signal.send notes.address (LogTaskSuccess step "awake")


-------------------------------------------------------------------------------

andAnyway : Task x a -> Task y b -> Task y b
andAnyway task1 task2 =
  (Task.map (\_ -> ()) task1 `onError` (\_ -> succeed ()))
  `andThen` (\_ -> task2)

port runTasks : Task () ()
port runTasks =
  doSubscribe "query1 valueChanged" valueChanged (location url)
  `andAnyway` (Task.spawn <| doSet "async set1 value" (JE.string "start") (location url))
  `andAnyway` doSubscribe "query2 parent valueChanged" valueChanged (location url |> parent)
  `andAnyway` doSleep "sleep 2 seconds" 2
  `andAnyway` doSet "set2 value" (JE.string "hello") (location url)
  `andAnyway` doOpen "open good" (location url)
  `andAnyway` doOpen "open bad" (location url |> parent |> parent)
  `andAnyway` doSubscribe "query3 child added" (child added) (location url)
  `andAnyway` doSubscribe "query4 child changed" (child changed) (location url)
  `andAnyway` doSubscribe "query5 child removed" (child removed) (location url)
  `andAnyway` doSubscribe "query6 child moved" (child moved) (location url)
  `andAnyway` doSleep "sleep 2 seconds" 2
  `andAnyway` doSet "set3 object value"
      (JE.object [("a", (JE.string "hello")), ("b", (JE.string "Elm"))])
      (location url)
  `andAnyway` doSleep "sleep 2 seconds" 2
  `andAnyway` doSet "set4 add child" (JE.string "at Firebase") (location url |> sub "c")
  `andAnyway` doSleep "sleep 2 seconds" 2
  -- `andAnyway` doSubscribeAndCancel "subscribe and unsubscribe" valueChanged (location url)
  `andAnyway` ( doSubscribe "subscribe" valueChanged (location url)
                `andThen` \queryId -> doUnsubscribe "unsubscribe" queryId
              )
  `andAnyway` doRemove "remove child" (location url |> sub "b")
  `andAnyway` succeed ()
