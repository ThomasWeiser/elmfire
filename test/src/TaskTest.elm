module TaskTest
  ( testDisplay
  , runTest
  , test, sequence
  , succeeds, fails, equals, meets, errorMeets
  , clear, createReporter, map, printResult, printString
  , (|>>), (|>+), (|>-)
  ) where

{- A Sketch of a testing framework for task-based code.

This is work in progress.
We aim to make the logging output look much more nicer.
-}

import Signal exposing (Signal, Mailbox, mailbox)
import Dict exposing (Dict)
import Task exposing (Task, andThen, onError, fail, succeed)
import Html exposing (Html, div, span, text, a, h1, h2)
import Html.Attributes exposing (href, target, class)
import Debug

-------------------------------------------------------------------------------

type Report = Line String Activity String
type Activity = RunSequence | RunTask | TestPass | TestError
              | TestPrint | TestPrintPre | RunReporter

reports: Mailbox (Maybe Report)
reports = mailbox Nothing

report : String -> Activity -> String -> Task x ()
report context activity text =
  Signal.send reports.address <|
    Just (Line context activity text)

type alias Model = Dict String (List Report)

startModel = Dict.empty

progression : Maybe Report -> Model -> Model
progression maybeReport model =
  case maybeReport of
    Nothing -> model
    Just report ->
      case report of
        Line context activity text ->
          Dict.update
            context
            ( \step -> case step of
                Nothing -> Just [report]
                Just prevReports -> Just (report :: prevReports)
            )
            model

state : Signal Model
state = Signal.foldp progression startModel reports.signal

testDisplay : Signal Html
testDisplay = Signal.map view state

-------------------------------------------------------------------------------

view : Model -> Html
view model =
  div [class "report"] <|
    List.map
      viewStep
      (Dict.values model)

viewStep : List Report -> Html
viewStep reports =
  div [class "step"]
    ( List.foldl -- reverses the list for display
        ( \report htmlList -> viewReport report :: htmlList )
        []
        reports
    )

viewReport : Report -> Html
viewReport (Line context activity txt) =
  div
    [ class (
        case activity of
          RunSequence  -> "header-sequence"
          RunTask      -> "header-task"
          RunReporter  -> "header-reporter"
          TestPass     -> "test pass"
          TestError    -> "test error"
          TestPrint    -> "test print"
          TestPrintPre -> "test print pre"
      )
    ]
    [text txt]

-------------------------------------------------------------------------------

type alias Context = String
type alias TestTask x a = Context -> (Task x a)

runTest : TestTask x a -> Task x a
runTest testTask = testTask "no test name"

test : String -> Task x a -> TestTask x a
test description task =
  \context ->
    report context RunTask description
    `andThen`
    \_ -> task

createReporter: String -> TestTask y (b -> Task z ())
createReporter description =
  \context ->
    report context RunReporter description
    `andThen`
    \_ -> succeed ( \val -> report context TestPrint (toString val) )

clear: TestTask y ()
clear =
  \context -> succeed ()

succeeds : TestTask x a -> TestTask x a
succeeds testTask =
  \context ->
    ( testTask context
      `onError` \err ->
        ( report context TestError "task failed"
          `andThen` \_ -> fail err
        )
    )
    `andThen` \val ->
      ( report context TestPass "task succeeds"
        `andThen` \_ -> succeed val
      )

fails: TestTask x a -> TestTask x a
fails testTask =
  \context ->
    ( testTask context
      `onError` \err ->
        ( report context TestPass "task failed as expected"
          `andThen` \_ -> fail err
        )
    )
    `andThen` \val ->
      ( report context TestError "task succeeds unexpectedly"
        `andThen` \_ -> succeed val
      )

equals : String -> a -> TestTask x a -> TestTask x a
equals description expectedValue =
  meets description ((==) expectedValue)

meets : String -> (a -> Bool) -> TestTask x a -> TestTask x a
meets description condition testTask =
  \context ->
    ( testTask context
      `onError` \err ->
        ( report context TestError (description ++ " [task failed]")
          `andThen` \_ -> fail err
        )
    )
    `andThen` \val ->
      ( ( if condition val
            then report context TestPass description
            else report context TestError (description ++ " [unfulfilled]")
        )
        `andThen` \_ -> succeed val
      )

errorMeets : String -> (x -> Bool) -> TestTask x a -> TestTask x a
errorMeets description condition testTask =
  \context ->
    ( testTask context
      `onError` \err ->
        ( ( if condition err
              then report context TestPass description
              else report context TestError (description ++ " [unfulfilled]")
          )
          `andThen` \_ -> fail err
        )
    )
    `andThen` \val ->
      ( report context TestError (description ++ " [task succeeds unexpectedly]")
        `andThen` \_ -> succeed val
      )

printResult : TestTask x a -> TestTask x a
printResult testTask =
  \context ->
    ( testTask context
      `onError` \err ->
        ( report context TestPrint (toString (Err err))
          `andThen` \_ -> fail err
        )
    )
    `andThen` \val ->
      ( report context TestPrint (toString (Ok val))
        `andThen` \_ -> succeed val
      )

printString : TestTask x String -> TestTask x String
printString testTask =
  \context ->
    testTask context
    `andThen` \str ->
      ( report context TestPrintPre str
        `andThen` \_ -> succeed str
      )

map : (a -> b) -> TestTask x a -> TestTask x b
map func testTask =
  \context ->
    Task.map func (testTask context)

infixl 1 |>>
(|>>) : TestTask x a -> (TestTask x a -> TestTask x b) -> TestTask x b
(|>>) = (|>)

infixl 0 |>-
(|>-) : TestTask x a -> TestTask y b -> TestTask y b
(|>-) testTask1 task2 =
  \context ->
    Task.toMaybe (testTask1 (context ++ "-1"))
    `andThen` \_ -> (task2 (context ++ "-2"))

infixl 0 |>+
(|>+) : TestTask x a -> (a -> TestTask x b) -> TestTask x b
(|>+) testTask1 callback2 =
  \context ->
    testTask1 (context ++ "+1")
    `andThen` \res1 ->
      let testTask2 = callback2 res1 in
        testTask2 (context ++ "+2")

sequence : String -> TestTask x a -> TestTask x a
sequence name testTask =
  \context ->
    report name RunSequence name
    `andThen`
    \_ -> testTask name

