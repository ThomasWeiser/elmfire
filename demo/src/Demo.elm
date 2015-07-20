{- A ElmFire Demo App

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
  ( fromUrl, toUrl, key, sub, parent, root, push, location, open
  , set, setWithPriority, setPriority, update, remove
  , subscribe, unsubscribe, once
  , valueChanged, childAdded, childChanged, childRemoved, childMoved
  , Location, Reference, Priority (..), Cancellation (..)
  , Snapshot, Subscription, Error, Query
  )

-------------------------------------------------------------------------------

url = "https://elmfire.firebaseio-demo.com/demo"

-------------------------------------------------------------------------------

type Response
  = NoResponse
  | Data Snapshot
  | Canceled Cancellation

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
  [ h1  [] [text "ElmFire Demo"]
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
    line c s t =
      div [class "line"] [ span [] [text s], span [class c] [text t] ]
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
      Data snapshot ->
        line "response" (toString snapshot.subscription) (viewSnapshot snapshot)
      Canceled (cancellation) ->
        case cancellation of
          Unsubscribed id ->
            line "canceled" (toString id) "unsubscribed"
          QueryError id err ->
            line "canceled" (toString id) ("queryError: " ++ toString err)

viewSnapshot : Snapshot -> String
viewSnapshot snapshot =
  let k = key snapshot.reference in
  (if k == "" then "(root)" else k) ++ ": " ++ (viewValue snapshot.value)

viewValue : JE.Value -> String
viewValue value =
  -- Comparing JE.null throws a runtime error,
  -- see https://github.com/elm-lang/core/pull/294
  -- if JE.null == value then "no value" else JE.encode 0 value
  JE.encode 0 value

main = Signal.map view state

-------------------------------------------------------------------------------

intercept : (v -> String) -> String -> Task Error v -> Task Error v
intercept valueToString step task =
  Signal.send notes.address (LogTaskStart step)
  `andThen` \_ ->
    ( task
      `onError` \err ->
        Signal.send notes.address (LogTaskFailure step (toString err))
      `andThen` \_   ->
        fail err
    )
    `andThen` \val ->
      Signal.send notes.address (LogTaskSuccess step (valueToString val))
    `andThen` \_   ->
      succeed val

-------------------------------------------------------------------------------

doOpen : String -> Location -> Task Error Reference
doOpen step location =
  intercept toString step (open location)

doSet : String -> JE.Value -> Location -> Task Error Reference
doSet step value location =
  intercept (always "synced") step (set value location)

doSetPriority : String -> Priority -> Location -> Task Error Reference
doSetPriority step priority location =
  intercept (always "synced") step (setPriority priority location)

doUpdate : String -> JE.Value -> Location -> Task Error Reference
doUpdate step value location =
  intercept (always "synced") step (update value location)

doRemove : String -> Location -> Task Error Reference
doRemove step location =
  intercept (always "synced") step (remove location)

doSubscribe : String -> Query q -> Location -> Task Error Subscription
doSubscribe step query location =
  intercept toString step
    ( subscribe
        (Signal.send responses.address << Data)
        (Signal.send responses.address << Canceled)
        query
        location
    )

doUnsubscribe : String -> Subscription -> Task Error ()
doUnsubscribe step subscription =
  intercept (always "done") step (unsubscribe subscription)

doOnce : String -> Query q -> Location -> Task Error JE.Value
doOnce step query location =
  intercept viewValue step
    ( once query location
      `andThen` \snapshot -> succeed snapshot.value
    )

doSleep : String -> Float -> Task () ()
doSleep id seconds =
  let step = "sleep " ++ id ++ " for " ++ (toString seconds) ++ " seconds" in
  Signal.send notes.address (LogTaskStart step)
  `andThen` \_ -> sleep (seconds * Time.second)
  `andThen` \_ -> Signal.send notes.address (LogTaskSuccess step "awake")

doShowRefLocation : String -> Reference -> Task e ()
doShowRefLocation id ref =
  Signal.send notes.address (LogTaskSuccess id (location ref |> toString))

doRefUrl : String -> Reference -> Task e ()
doRefUrl id ref =
  Signal.send notes.address (LogTaskSuccess id (toUrl ref))

doRefKey : String -> Reference -> Task e ()
doRefKey id ref =
  Signal.send notes.address (LogTaskSuccess id (key ref))

-------------------------------------------------------------------------------

andAnyway : Task x a -> Task y b -> Task y b
andAnyway task1 task2 =
  (Task.map (\_ -> ()) task1 `onError` (\_ -> succeed ()))
  `andThen` (\_ -> task2)

port runTasks : Task () ()
port runTasks =
  let loc = fromUrl url in
              doSubscribe "query1 value" valueChanged loc
  `andAnyway` (Task.spawn <| doSet "async set1 value" (JE.string "start") loc)
  `andAnyway` doSubscribe "query2 parent value" valueChanged (loc |> parent)
  `andAnyway` doSleep "1" 2
  `andAnyway` doOpen "open pushed" (push loc)
  `andThen`   ( \ref ->
                doShowRefLocation "opened location" ref
                `andAnyway` doRefUrl "opened url" ref
                `andAnyway` doRefKey "opened key" ref
              )
  `andAnyway` doSet "set2 value" (JE.string "hello") loc
  `andAnyway` doOpen "root" (loc |> root)
  `andAnyway` doOpen "open bad" (loc |> root |> parent)
  `andAnyway` doSubscribe "query3 child added" (childAdded) loc
  `andAnyway` doSubscribe "query4 child changed" (childChanged) loc
  `andAnyway` doSubscribe "query5 child removed" (childRemoved) loc
  `andAnyway` doSubscribe "query6 child moved" (childMoved) loc
  `andAnyway` doSleep "2" 2
  `andAnyway` doSet "set3 object value"
      (JE.object [("a", (JE.string "hello")), ("b", (JE.string "Elm"))])
      loc
  `andAnyway` doSleep "3" 2
  `andAnyway` doSet "set4 add child" (JE.string "at Firebase") (loc |> sub "c")
  `andAnyway` doSleep "4" 2
  `andAnyway` ( doSubscribe "subscribe" valueChanged loc
                `andThen` \subscription -> doUnsubscribe "unsubscribe" subscription
              )
  `andAnyway` doOnce "query once" valueChanged loc
  `andAnyway` doRemove "remove child" (loc |> sub "b")
  `andAnyway` doUpdate "update object a and d"
      (JE.object [("a", (JE.string "Hello")), ("d", (JE.string "Elmies"))])
      loc
  `andAnyway` ( doOpen "push open" (loc |> sub "e" |> push)
                `andThen`
                \ref -> doSet "push set" (JE.string <| key ref) (location ref)
                `andThen`
                \ref -> doSetPriority "setPriority" (NumberPriority 17) (location ref)
              )
  `andAnyway` succeed ()
