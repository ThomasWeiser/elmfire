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
import Html exposing (Html, div, span, input, output, label, text, a, h1, h2)
import Html.Events exposing (on, targetValue)
import Html.Attributes exposing (href, target, class)
import Debug

import ElmFire exposing
  ( location, sub, parent, open
  , set, remove, subscribe, unsubscribe
  , valueChanged, child, added, changed, removed, moved
  , Ref, Query, Response (..), DataMsg, QueryId, Error (..)
  )

-------------------------------------------------------------------------------

url = "https://elmfire.firebaseio-demo.com/test"

-------------------------------------------------------------------------------

-- All query responses a reported through this mailbox
responses : Signal.Mailbox Response
responses = Signal.mailbox NoResponse

type LogEntry
  = LogNone
  | LogTaskStart String
  | LogTaskSuccess String String
  | LogTaskFailure String String
  | LogResponse Response

notes : Signal.Mailbox LogEntry
notes = Signal.mailbox LogNone

logEntries : Signal LogEntry
logEntries =
  Signal.merge
    notes.signal
    (Signal.map LogResponse responses.signal)

type alias LogList = List LogEntry
type alias TaskList = List (String, LogEntry)

type alias Model =
  { log: LogList
  , tasks: TaskList
  }

startModel : Model
startModel = { log = [], tasks = [] }

progression : LogEntry -> Model -> Model
progression note model =
  { model |
      log <- note :: model.log
    , tasks <-
        case note of
          LogTaskStart   step   -> replaceOrAppend step note model.tasks
          LogTaskSuccess step _ -> replaceOrAppend step note model.tasks
          LogTaskFailure step _ -> replaceOrAppend step note model.tasks
          otherwise -> model.tasks
  }

replaceOrAppend : String -> LogEntry -> TaskList -> TaskList
replaceOrAppend step note tasks =
  case tasks of
    [] -> [(step, note)]
    (s1, n1) :: rest ->
      if s1 == step
        then (step, note) :: rest
        else (s1, n1) :: replaceOrAppend step note rest

state : Signal Model
state = Signal.foldp progression startModel logEntries

view : Model -> Html
view model =
  div []
  [ h1  [] [text "ElmFire Test"]
  , div [] [ a [href url, target "_blank"] [text url] ]
  , div [class "tasks"] ( h2 [] [text "Tasks"] :: viewTasks model.tasks)
  , div [class "logs"]  ( h2 [] [text "Log"] :: viewLog model.log )
  ]

viewLog : LogList -> List Html
viewLog log = List.foldl -- reverses the list for display
  (\entry htmlList ->
    let maybeHtml = viewLogEntry entry in
      case maybeHtml of
        Nothing -> htmlList
        Just html -> html::htmlList
  )
  []
  log

viewTasks : TaskList -> List Html
viewTasks = List.map
  (\(step, logEntry) ->
    div [class "line"]
    [ span [] [text step]
    , case logEntry of
        LogTaskStart   _     -> span [class "started"] [text "..."]
        LogTaskSuccess _ res -> span [class "success"] [text res]
        LogTaskFailure _ err -> span [class "failure"] [text err]
        otherwise            -> text ""

    ]
  )

viewLogEntry : LogEntry -> Maybe Html
viewLogEntry logEntry =
  let
    line c s t = div [class "line"] [ span [] [text s], span [class c] [text t] ]
  in case logEntry of
  LogNone -> Nothing
  LogTaskStart step ->
    Just <| line "started" step "started"
  LogTaskSuccess step res ->
    Just <| line "success" step res
  LogTaskFailure step err ->
    Just <| line "failure" step err
  LogResponse response ->
    Just <| case response of
      Data dataMsg -> line "response" (toString dataMsg.queryId) (viewDataMsg dataMsg)
      otherwise -> line "response" "response" "no dataMsg"

viewDataMsg : DataMsg -> String
viewDataMsg dataMsg =
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
      `onError` \err -> Signal.send notes.address (LogTaskFailure step (errorToString err))
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
  intercept toString step (subscribe responses.address query ref)

doUnsubscribe : String -> QueryId -> Task Error ()
doUnsubscribe step queryId =
  intercept (always "done") step (unsubscribe queryId)

doSleep : String -> Float -> Task () ()
doSleep id seconds =
  let step = "sleep " ++ id ++ " for " ++ (toString seconds) ++ " seconds" in
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
              doSubscribe "query1 value" valueChanged (location url)
  `andAnyway` (Task.spawn <| doSet "async set1 value" (JE.string "start") (location url))
  `andAnyway` doSubscribe "query2 parent value" valueChanged (location url |> parent)
  `andAnyway` doSleep "1" 2
  `andAnyway` doSet "set2 value" (JE.string "hello") (location url)
  `andAnyway` doOpen "open good" (location url)
  `andAnyway` doOpen "open bad" (location url |> parent |> parent)
  `andAnyway` doSubscribe "query3 child added" (child added) (location url)
  `andAnyway` doSubscribe "query4 child changed" (child changed) (location url)
  `andAnyway` doSubscribe "query5 child removed" (child removed) (location url)
  `andAnyway` doSubscribe "query6 child moved" (child moved) (location url)
  `andAnyway` doSleep "2" 2
  `andAnyway` doSet "set3 object value"
      (JE.object [("a", (JE.string "hello")), ("b", (JE.string "Elm"))])
      (location url)
  `andAnyway` doSleep "3" 2
  `andAnyway` doSet "set4 add child" (JE.string "at Firebase") (location url |> sub "c")
  `andAnyway` doSleep "4" 2
  `andAnyway` ( doSubscribe "subscribe" valueChanged (location url)
                `andThen` \queryId -> doUnsubscribe "unsubscribe" queryId
              )
  `andAnyway` doRemove "remove child" (location url |> sub "b")
  `andAnyway` succeed ()
