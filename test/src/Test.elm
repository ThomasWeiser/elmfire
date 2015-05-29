{- A Sketch of a Test App for ElmFire

A given sequence of tasks is run on the Firebase API.
Steps and results are logged as Html.

This is work in progress.
We aim to make the logging output look much more nicer.
-}

import Signal exposing (Signal, Mailbox, mailbox)
import Task exposing (Task, andThen, onError, fail, succeed)
import Json.Encode as JE
import Html exposing (Html, div, span, text, a, h1, h2)
import Html.Attributes exposing (href, target, class)
import Debug
import String

import ElmFire exposing (..)

-------------------------------------------------------------------------------

url = "https://elmfire.firebaseio-demo.com/test"

-------------------------------------------------------------------------------

type Report = Line Bool String

reports: Mailbox (Maybe Report)
reports = mailbox Nothing

report : String -> String -> Bool -> String -> Task x ()
report context description ok text =
  Signal.send reports.address <|
    Just (Line ok (context ++ ": " ++ description ++ ": " ++ text))

type alias Model = List Report

startModel = []

progression : Maybe Report -> Model -> Model
progression maybeReport model = case maybeReport of
  Just report -> report :: model
  Nothing     -> model

state : Signal Model
state = Signal.foldp progression startModel reports.signal

main = Signal.map view state

-------------------------------------------------------------------------------

view : Model -> Html
view model =
  div []
  [ h1  [] [text "ElmFire Test"]
  , div [] [ a [href url, target "_blank"] [text url] ]
  , div [class "reports"] ( h2 [] [text "Reports"] :: viewReports model)
  ]

viewReports : Model -> List Html
viewReports model = List.foldl -- reverses the list for display
  ( \report htmlList -> viewReport report :: htmlList )
  []
  model

viewReport : Report -> Html
viewReport (Line ok txt) =
  div
    [class (if ok then "report success" else "report failure")]
    [text txt]

-------------------------------------------------------------------------------

type alias Context = String
type alias TestTask x a = Context -> (Task x a)

runTest : TestTask x a -> Task x a
runTest testTask = testTask "no test name"

test : Task x a -> TestTask x a
test task = \context -> task

succeeds : String -> TestTask x a -> TestTask x a
succeeds description testTask =
  \context ->
    ( testTask context
      `onError` \err ->
        ( report context description False "task failed"
          `andThen` \_ -> fail err
        )
    )
    `andThen` \val ->
      ( report context description True "task succeeds"
        `andThen` \x -> succeed val
      )

meets : String -> (a -> Bool) -> TestTask x a -> TestTask x a
meets description condition testTask =
  \context ->
    testTask context
    `andThen` \val ->
      ( ( if condition val
            then report context description True  "task result meets the condition"
            else report context description False "task result misses the condition"
        )
        `andThen` \x -> succeed val
      )

infixl 1 |>>
(|>>) : TestTask x a -> (TestTask x a -> TestTask x b) -> TestTask x b
(|>>) = (|>)

infixl 1 |>-
(|>-) : TestTask x a -> Task x b -> TestTask x b
(|>-) testTask1 task2 =
  \context ->
    testTask1 context
    `andThen` \_ -> task2

infixl 1 |>+
(|>+) : TestTask x a -> (a -> TestTask x b) -> TestTask x b
(|>+) testTask1 callback2 =
  \context ->
    testTask1 context
    `andThen` \res1 ->
      let testTask2 = callback2 res1 in
        testTask2 context

suite : String -> TestTask x a -> TestTask x a
suite name testTask =
  \context ->
    testTask name

test1 =
  suite "test1" <|
      test ( open (fromUrl url |> push) )
  |>> succeeds "open"
  |>> meets "opened ref" (\ref -> url `String.startsWith` toUrl ref )

  |>+ \ref -> test ( setWithPriority (JE.string "Hello Elmies") (NumberPriority 42) (location ref) )
  |>> succeeds "set"
  |>> meets "set returned same ref" (\refSet -> toUrl refSet == toUrl ref)

  |>- (once valueChanged (location ref))
  |>> succeeds "once valueChanged (at child)"
  |>> meets "once returned same key" (\snapshot -> snapshot.key == key ref)
  |>> meets "once returned right value" (\snapshot -> snapshot.value == Just (JE.string "Hello Elmies"))
  |>> meets "once returned right priority" (\snapshot -> snapshot.priority == NumberPriority 42)

  |>- (once (child added) (fromUrl url))
  |>> succeeds "once child added (at parent)"
  |>> meets "once returned right value" (\snapshot -> snapshot.value == Just (JE.string "Hello Elmies"))
  |>> meets "once returned right prevKey" (\snapshot -> snapshot.prevKey == Nothing)

port runTasks : Task Error Snapshot
port runTasks = runTest test1
