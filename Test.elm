{- A ElmFire Testing App

A given sequence of tasks is run on the Firebase API.
Steps and results are logged as Html.

This is work in progress.
We aim to make the logging output look much more nicer.
-}

import Signal exposing (Signal, Mailbox, mailbox, message)
import Task exposing (Task, andThen, onError, succeed, sleep)
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

url = "https://elmfire.firebaseio-demo.com/test"

type LogEntry
  = LogNone
  | LogNote String String -- step note
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
  LogNote step note ->
    Just <| div [style [("backgroundColor", "#EFD8A1")]] [text <| step ++ ": " ++ note]
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

reportStep : String -> Task () () -> Task () ()
reportStep step task =
  Signal.send notes.address (LogNote step "(")
  `andThen` \_ -> task
  `andThen` \_ -> Signal.send notes.address (LogNote step ")")

reportError : String -> Error -> Task () ()
reportError step error =
  Signal.send notes.address
  ( case error of
      FirebaseError str -> LogNote step str
  )

reportRef : String -> Ref -> Task x ()
reportRef step ref =
  Signal.send notes.address <| LogNote step (toString ref)

reportQueryId : String -> QueryId -> Task x ()
reportQueryId step queryId =
  Signal.send notes.address <| LogNote step (toString queryId)

reportCompletion : String -> () -> Task x ()
reportCompletion step _ =
  Signal.send notes.address <| LogNote step "completion"

-- TODO: Should return -> Task () Ref
doOpen : String -> Ref -> Task () ()
doOpen step ref =
  reportStep step <|
    open ref
    `andThen` reportRef step
    `onError` reportError step

doSet : String -> JE.Value -> Ref -> Task () ()
doSet step value ref =
  reportStep step <|
    set value ref
    `andThen` reportCompletion step
    `onError` reportError step

doRemove : String -> Ref -> Task () ()
doRemove step ref =
  reportStep step <|
    remove ref
    `andThen` reportCompletion step
    `onError` reportError step

-- TODO: Should return -> Task () QueryId
doSubscribe : String -> Query -> Ref -> Task () ()
doSubscribe step query ref =
  reportStep step <|
    subscribe query ref
    `andThen` reportQueryId step
    `onError` reportError step

-- TODO: Will become `doUnsubscribe`
doSubscribeAndCancel : String -> Query -> Ref -> Task () ()
doSubscribeAndCancel step query ref =
  reportStep step <|
    ( subscribe query ref
     `andThen` \queryId -> unsubscribe queryId
    )
    `andThen` reportCompletion step
    `onError` reportError step

doSleep : String -> Float -> Task () ()
doSleep step seconds =
  reportStep step <|
    sleep (seconds * Time.second)

spawn : Task () a -> Task () ()
spawn task = Task.map (\_ -> ()) (Task.spawn task)

port runTasks : Task () ()
port runTasks =
  doSubscribe "query1 valueChanged" valueChanged (location url)
  `andThen` \_ -> (spawn <| doSet "set1 value" (JE.string "start") (location url))
  `andThen` \_ -> doSubscribe "query2 parent valueChanged" valueChanged (location url |> parent)
  `andThen` \_ -> sleep (3 * Time.second)
  `andThen` \_ -> doSet "set2 value" (JE.string "hello") (location url)
  `andThen` \_ -> doOpen "open" (location url)
  `andThen` \_ -> doSubscribe "query3 child added" (child added) (location url)
  `andThen` \_ -> doSubscribe "query4 child changed" (child changed) (location url)
  `andThen` \_ -> doSubscribe "query5 child removed" (child removed) (location url)
  `andThen` \_ -> doSubscribe "query6 child moved" (child moved) (location url)
  `andThen` \_ -> doSleep "sleep 3 seconds" 3
  `andThen` \_ -> doSet "set3 object value"
      (JE.object [("a", (JE.string "hello")), ("b", (JE.string "Elm"))])
      (location url)
  `andThen` \_ -> doSleep "sleep 3 seconds" 3
  `andThen` \_ -> doSet "set4 add child" (JE.string "at Firebase") (location url |> sub "c")
  `andThen` \_ -> doSleep "sleep 3 seconds" 3
  `andThen` \_ -> doRemove "remove child" (location url |> sub "b")
  `andThen` \_ -> doSubscribeAndCancel "subscribe and unsubscribe" valueChanged (location url)
